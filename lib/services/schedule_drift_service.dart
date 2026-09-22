import '../models/habit.dart';
import '../models/habit_log.dart';
import 'habit_repository.dart';

/// One habit whose real completion time has drifted away from the time it
/// was scheduled for.
class ScheduleDrift {
  const ScheduleDrift({
    required this.habit,
    required this.scheduledMinute,
    required this.actualMinute,
    required this.sampleSize,
  });

  final Habit habit;

  /// Minute-of-day the reminder is set to (e.g. 600 = 10:00).
  final int scheduledMinute;

  /// Median minute-of-day the user actually completes it (e.g. 720 = 12:00).
  final int actualMinute;

  /// How many completions the median was computed from.
  final int sampleSize;

  int get driftMinutes => actualMinute - scheduledMinute;
  int get actualHour => actualMinute ~/ 60;
  int get actualMinuteOfHour => actualMinute % 60;

  bool get isLater => driftMinutes > 0;
}

/// Learns the hour a habit actually happens, rather than the hour it was
/// planned for.
///
/// ## The gap this closes
///
/// The adaptation engine only proposes a new time after a habit has been
/// **missed** three times. But the most common real pattern isn't missing —
/// it's drifting: you set language study for 10:00, you genuinely do it, but
/// always around noon. Every day gets ticked, no miss is ever recorded, and
/// so nothing ever adapts. The schedule stays permanently wrong while the
/// data needed to fix it sits unused in the logs.
///
/// This service reads the completion timestamps already stored on every
/// [HabitLog], takes the median hour over the trailing window, and compares
/// it to the scheduled reminder. When the two disagree consistently, the app
/// offers to move the habit to when the user actually does it.
///
/// Median rather than mean: one 3 a.m. insomnia entry should not drag a
/// month of 12:00 completions two hours earlier.
class ScheduleDriftService {
  ScheduleDriftService({HabitRepository? habits})
      : _habits = habits ?? HabitRepository();

  final HabitRepository _habits;

  /// How far back to look. Three weeks is long enough to establish a rhythm
  /// and short enough that a genuine change of routine surfaces quickly.
  static const int windowDays = 21;

  /// Minimum completions before a median means anything. Below this, a
  /// couple of late days would masquerade as a pattern.
  static const int minSamples = 5;

  /// How far the real time must sit from the scheduled time before it's
  /// worth interrupting the user. 75 minutes ignores ordinary daily
  /// scatter — nobody does anything at exactly the same minute — while
  /// still catching the "set for 10, actually noon" case.
  static const int minDriftMinutes = 75;

  /// If the completion times are spread wider than this, there is no single
  /// "time they do it" to move to, and a median across a 14-hour spread is
  /// a meaningless number. Also sidesteps midnight wrap-around, where a
  /// naive median of 23:30 and 00:30 lands absurdly at noon.
  static const int maxSpreadMinutes = 8 * 60;

  /// Every habit currently drifting, strongest first.
  List<ScheduleDrift> detectAll() {
    final out = <ScheduleDrift>[];
    final logs = _habits.allLogs.toList();
    for (final h in _habits.getAllHabits()) {
      final d = detectFor(h, logs);
      if (d != null) out.add(d);
    }
    out.sort((a, b) => b.driftMinutes.abs().compareTo(a.driftMinutes.abs()));
    return out;
  }

  /// Drift for one habit, or null when there isn't a clear one.
  ScheduleDrift? detectFor(Habit habit, [List<HabitLog>? allLogs]) {
    if (habit.isArchived) return null;
    // Nothing to drift from if no time was ever set.
    if (habit.reminderMinutes.isEmpty) return null;
    final scheduled = habit.reminderMinutes.first;
    if (scheduled < 0 || scheduled >= 24 * 60) return null;

    final logs = allLogs ?? _habits.allLogs.toList();
    final cutoff = DateTime.now().subtract(const Duration(days: windowDays));
    final minutes = <int>[];
    for (final l in logs) {
      if (l.habitId != habit.id) continue;
      if (l.timestamp.isBefore(cutoff)) continue;
      minutes.add(l.timestamp.hour * 60 + l.timestamp.minute);
    }
    if (minutes.length < minSamples) return null;

    minutes.sort();
    if (minutes.last - minutes.first > maxSpreadMinutes) return null;

    final median = minutes[minutes.length ~/ 2];
    if ((median - scheduled).abs() < minDriftMinutes) return null;

    return ScheduleDrift(
      habit: habit,
      scheduledMinute: scheduled,
      actualMinute: median,
      sampleSize: minutes.length,
    );
  }

  /// Rewrites the habit's reminder to the time it actually happens.
  ///
  /// Only the drifted slot moves. A counter habit with several reminders a
  /// day keeps the rest of its schedule — shifting all of them because one
  /// drifted would break a deliberately spaced-out plan.
  Future<void> applyDrift(ScheduleDrift d) async {
    final habit = d.habit;
    final updated = List<int>.from(habit.reminderMinutes);
    if (updated.isEmpty) return;
    updated[0] = d.actualMinute;
    updated.sort();
    habit.reminderMinutes = updated;
    await _habits.updateHabit(habit);
  }

  /// "10:00" for 600.
  static String formatMinute(int minuteOfDay) {
    final h = (minuteOfDay ~/ 60) % 24;
    final m = minuteOfDay % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
}
