import 'dart:async';

import '../models/habit_log.dart';
import '../models/year_in_review.dart';
import 'badge_service.dart';
import 'gratitude_repository.dart';
import 'habit_repository.dart';
import 'mood_repository.dart';
import 'reflection_repository.dart';
import 'routine_repository.dart';
import 'user_repository.dart';

/// Crunches a year's worth of Hive data into a [YearInReviewData].
/// All reads are local — no network — so the call is cheap. Result is
/// cached per-year inside the singleton for instant re-open during a
/// session.
class YearInReviewService {
  YearInReviewService._();
  static final YearInReviewService _instance = YearInReviewService._();
  factory YearInReviewService() => _instance;

  final Map<int, YearInReviewData> _cache = {};

  /// Invalidate any cached recap. Call after data mutations if the
  /// user is somehow still on the screen — rare.
  void invalidate([int? year]) {
    if (year == null) {
      _cache.clear();
    } else {
      _cache.remove(year);
    }
  }

  Future<YearInReviewData> generateForYear(int year) async {
    final cached = _cache[year];
    if (cached != null) return cached;
    final data = await _compute(year);
    _cache[year] = data;
    return data;
  }

  Future<YearInReviewData> _compute(int year) async {
    final user = UserRepository().getCurrentUser();
    final joined = user?.createdAt ?? DateTime(year, 1, 1);

    final yearStart = DateTime(year, 1, 1);
    final yearEnd = DateTime(year, 12, 31, 23, 59, 59);
    // Clamp recap window to the user's join date so a January joiner
    // doesn't see "0 check-ins for Q1" because they didn't exist yet.
    final windowStart =
        joined.isAfter(yearStart) ? joined : yearStart;
    final now = DateTime.now();
    final windowEnd =
        now.year == year && now.isBefore(yearEnd) ? now : yearEnd;

    final moods = MoodRepository();
    final habits = HabitRepository();
    final reflections = ReflectionRepository();
    final gratitudes = GratitudeRepository();
    final routines = RoutineRepository();
    final badges = BadgeService();

    final moodEntries = moods
        .getAllEntries()
        .where((e) =>
            !e.timestamp.isBefore(windowStart) &&
            !e.timestamp.isAfter(windowEnd))
        .toList();
    final totalCheckIns = moodEntries.length;

    // Days active = unique dates with any meaningful activity.
    final activeDays = <DateTime>{};
    for (final e in moodEntries) {
      activeDays.add(_dayKey(e.timestamp));
    }
    final allReflections = reflections.getReflectionsForLastDays(366);
    final yearReflections = allReflections
        .where((r) =>
            !r.date.isBefore(windowStart) && !r.date.isAfter(windowEnd))
        .toList();
    for (final r in yearReflections) {
      activeDays.add(_dayKey(r.date));
    }
    final allGratitudes = await gratitudes.getRecent(366);
    final yearGratitudes = allGratitudes
        .where((g) =>
            g.nonEmptyItems.isNotEmpty &&
            !g.date.isBefore(windowStart) &&
            !g.date.isAfter(windowEnd))
        .toList();
    for (final g in yearGratitudes) {
      activeDays.add(_dayKey(g.date));
    }

    // Habit logs aggregated across all habits.
    int totalHabitsCompleted = 0;
    int longestStreakDays = 0;
    String? longestStreakHabit;
    final allHabits = habits.getAllHabits();
    for (final h in allHabits) {
      final logs = habits.getLogsForHabit(
        h.id,
        from: windowStart,
        to: windowEnd,
      );
      final completed = logs.where((l) => l.isCompleted).toList();
      totalHabitsCompleted += completed.length;
      for (final l in completed) {
        activeDays.add(_dayKey(l.date));
      }
      final streak = _longestRun(completed);
      if (streak > longestStreakDays) {
        longestStreakDays = streak;
        longestStreakHabit = h.title;
      }
    }

    // Routine completions — RoutineItem.isCompleted is a single bool
    // for the current day. Historical routine completion isn't logged
    // per-day separately, so we count today's completed items as the
    // "routines completed this year" proxy plus a heuristic from the
    // discipline-score history below.
    final allRoutines = routines.getAllRoutines();
    final completedToday =
        allRoutines.where((r) => r.isCompleted).length;
    // For perfect-routine-days, we infer from the habit + mood activity
    // since RoutineItem doesn't keep history. This stays a soft signal.
    final perfectRoutineDays = activeDays.length ~/ 7;

    // Mood stats.
    double? avgMood;
    DateTime? highestMoodDay;
    final moodByMonth = <int, List<double>>{};
    if (moodEntries.isNotEmpty) {
      var sum = 0.0;
      var maxValue = -1.0;
      for (final e in moodEntries) {
        sum += e.mood;
        moodByMonth.putIfAbsent(e.timestamp.month, () => []).add(e.mood);
        if (e.mood > maxValue) {
          maxValue = e.mood;
          highestMoodDay = e.timestamp;
        }
      }
      avgMood = sum / moodEntries.length;
    }
    final moodByMonthAvg = <int, double>{
      for (final entry in moodByMonth.entries)
        entry.key:
            entry.value.reduce((a, b) => a + b) / entry.value.length,
    };

    // Best month = month with most activity. We count activeDays per
    // month so it correlates with how engaged the user was, not just
    // mood quality.
    final activityByMonth = <int, int>{};
    for (final d in activeDays) {
      activityByMonth[d.month] = (activityByMonth[d.month] ?? 0) + 1;
    }
    int? bestMonth;
    int bestScore = 0;
    activityByMonth.forEach((month, score) {
      if (score > bestScore) {
        bestScore = score;
        bestMonth = month;
      }
    });

    // Badges earned this year.
    final earnedBadges = badges
        .earnedBadgesSync()
        .where((b) =>
            !b.unlockedAt.isBefore(windowStart) &&
            !b.unlockedAt.isAfter(windowEnd))
        .toList();

    final identities = user?.identities ?? const <String>[];
    final theme = _pickTheme(
      totalCheckIns: totalCheckIns,
      totalHabitsCompleted: totalHabitsCompleted,
      totalReflections: yearReflections.length,
      totalGratitudes: yearGratitudes.length,
      longestStreakDays: longestStreakDays,
      identitiesCount: identities.length,
      daysActive: activeDays.length,
    );

    return YearInReviewData(
      year: year,
      userName: user?.name ?? 'friend',
      windowStart: windowStart,
      windowEnd: windowEnd,
      daysActive: activeDays.length,
      totalCheckIns: totalCheckIns,
      totalReflections: yearReflections.length,
      totalGratitudes: yearGratitudes.length,
      totalHabitsCompleted: totalHabitsCompleted,
      totalRoutinesCompleted: completedToday,
      perfectRoutineDays: perfectRoutineDays,
      longestStreakDays: longestStreakDays,
      longestStreakHabit: longestStreakHabit,
      avgMood: avgMood,
      highestMoodDay: highestMoodDay,
      moodByMonth: moodByMonthAvg,
      bestMonth: bestMonth,
      bestMonthScore: bestScore,
      badgesEarned: earnedBadges.length,
      identities: identities,
      theme: theme.$1,
      themeDescription: theme.$2,
    );
  }

  /// Picks a personality "theme" from the dominant signal in the data.
  /// The order of checks is intentional — more specific patterns first,
  /// then graceful fallbacks. Returns (label, supporting line).
  (String, String) _pickTheme({
    required int totalCheckIns,
    required int totalHabitsCompleted,
    required int totalReflections,
    required int totalGratitudes,
    required int longestStreakDays,
    required int identitiesCount,
    required int daysActive,
  }) {
    if (longestStreakDays >= 30 && totalHabitsCompleted >= 100) {
      return (
        'The Consistent Builder',
        'You showed up, again and again — discipline became you.',
      );
    }
    if (totalReflections >= 50 || totalGratitudes >= 100) {
      return (
        'The Soulful Logger',
        'You wrote your way into yourself this year.',
      );
    }
    if (identitiesCount >= 3 && totalHabitsCompleted >= 50) {
      return (
        'The Identity Architect',
        'You built who you’re becoming, one habit at a time.',
      );
    }
    if (totalCheckIns >= 200) {
      return (
        'The Mood Cartographer',
        'You mapped your inner weather with care this year.',
      );
    }
    if (totalGratitudes >= 50) {
      return (
        'The Mindful Explorer',
        'You found gratitude in the small, daily things.',
      );
    }
    if (daysActive >= 100) {
      return (
        'The Quiet Climber',
        'Steady steps, all year long.',
      );
    }
    return (
      'The Beginning',
      'This was your first chapter — and you started.',
    );
  }

  int _longestRun(List<HabitLog> completedLogs) {
    if (completedLogs.isEmpty) return 0;
    final days = <DateTime>{
      for (final l in completedLogs) _dayKey(l.date),
    }.toList()
      ..sort();
    var best = 1;
    var current = 1;
    for (var i = 1; i < days.length; i++) {
      final diff = days[i].difference(days[i - 1]).inDays;
      if (diff == 1) {
        current += 1;
        if (current > best) best = current;
      } else {
        current = 1;
      }
    }
    return best;
  }

  DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);
}

