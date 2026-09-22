import 'package:flutter/foundation.dart';

import '../models/habit.dart';
import '../models/habit_type.dart';
import 'bad_day_service.dart';
import 'habit_repository.dart';
import 'miss_reason_service.dart';

/// The third-miss response: park the habit, build a smaller one first.
///
/// ## The escalation
///
/// 1. **First miss** — silence. One miss is noise, not a pattern.
/// 2. **Second miss** — one tap asking why (see [MissReasonService]).
/// 3. **Third miss** — this service. The app says plainly that the habit
///    isn't landing, proposes an easier version to build first, archives
///    the hard one, and remembers to offer it back once the easier one is
///    holding.
///
/// The habit is **archived, never deleted**, and the language is neutral.
/// Deleting someone's own goal on their behalf reads as the app taking
/// something away, and telling them the failure set them back is a
/// judgement delivered at the exact moment they already feel bad — which
/// is one of the best-documented reasons people uninstall.
class SteppingStoneService {
  SteppingStoneService({HabitRepository? habits})
      : _habits = habits ?? HabitRepository();

  final HabitRepository _habits;

  /// Misses inside the trailing week before the app steps in.
  static const int missesBeforeParking = 3;

  /// How long the stepping-stone habit must hold before the parked habit
  /// is offered back. A week is enough to show the smaller version is
  /// genuinely sustainable rather than a two-day burst.
  static const int revivalStreakDays = 7;

  /// The habit worth parking right now, or null.
  ///
  /// Returns at most one. Telling someone three of their habits are
  /// failing in a single sitting is a pile-on, not help.
  Habit? pickCandidate() {
    final logs = _habits.allLogs.toList();
    final misses = MissReasonService();
    Habit? worst;
    var worstCount = 0;
    for (final h in _habits.getAllHabits()) {
      if (h.isArchived) continue;
      // Already a stepping stone — parking it would recurse downward.
      if (h.supportFor != null) continue;
      final n = misses.missesFor(h, logs);
      if (n < missesBeforeParking) continue;
      if (n > worstCount) {
        worst = h;
        worstCount = n;
      }
    }
    return worst;
  }

  /// The easier habit proposed in place of [h], as a short title.
  ///
  /// Reuses the bad-day floor: the smallest version that still counts. The
  /// floor already encodes "what does a trivial version of this look like",
  /// so there's no second definition to keep in sync.
  String steppingStoneTitle(Habit h) {
    final floor = BadDayService().floorLabel(h);
    return floor.isEmpty ? 'A smaller ${h.title.toLowerCase()}' : floor;
  }

  /// Parks [hard] and creates the easier habit in its place.
  ///
  /// Returns the new habit, or null if creation failed — in which case the
  /// hard habit is deliberately left active rather than archiving someone's
  /// goal and giving them nothing back.
  Future<Habit?> park(Habit hard) async {
    try {
      final created = await _habits.addHabit(
        title: steppingStoneTitle(hard),
        icon: hard.icon,
        habitType: HabitType.yesNo,
        identity: hard.identity,
        category: hard.category,
        frequency: hard.frequency,
        color: hard.color,
      );
      created.supportFor = hard.id;
      // Keep the same slot: the time isn't what failed, the size was.
      // Set after creation because addHabit doesn't take reminder fields.
      created.reminderMinutes = List<int>.from(hard.reminderMinutes);
      created.remindersEnabled = hard.remindersEnabled;
      await _habits.updateHabit(created);

      hard.isArchived = true;
      hard.parkedBehind = created.id;
      await _habits.updateHabit(hard);
      return created;
    } catch (e, st) {
      debugPrint('SteppingStoneService.park failed: $e\n$st');
      return null;
    }
  }

  /// Parked habits whose stepping stone is now holding steadily, ready to
  /// be offered back.
  List<({Habit parked, Habit support, int streak})> readyToRevive() {
    final out = <({Habit parked, Habit support, int streak})>[];
    final all = _habits.getAllHabits();
    for (final parked in all) {
      if (!parked.isArchived) continue;
      final supportId = parked.parkedBehind;
      if (supportId == null) continue;
      Habit? support;
      for (final h in all) {
        if (h.id == supportId && !h.isArchived) support = h;
      }
      if (support == null) continue;
      final streak = _habits.getStreakForHabit(support.id);
      if (streak < revivalStreakDays) continue;
      out.add((parked: parked, support: support, streak: streak));
    }
    return out;
  }

  /// Bring a parked habit back. The stepping stone stays — it's working,
  /// and removing it to make room would repeat the original mistake of
  /// asking for too much at once.
  Future<void> revive(Habit parked) async {
    parked.isArchived = false;
    parked.parkedBehind = null;
    await _habits.updateHabit(parked);
  }
}
