import 'analytics_service.dart';
import 'habit_repository.dart';
import 'mood_repository.dart';
import 'routine_repository.dart';

class DisciplineSnapshot {
  const DisciplineSnapshot({
    required this.score,
    required this.habitScore,
    required this.routineScore,
    required this.streakScore,
    required this.streak,
  });
  final int score;
  final double habitScore;
  final double routineScore;
  final double streakScore;
  final int streak;
}

class ScorePoint {
  const ScorePoint({required this.date, required this.score});
  final DateTime date;
  final int score;
}

class ScoreService {
  ScoreService({
    MoodRepository? moods,
    RoutineRepository? routines,
    HabitRepository? habits,
    AnalyticsService? analytics,
  })  : _moods = moods ?? MoodRepository(),
        _routines = routines ?? RoutineRepository(),
        _habits = habits ?? HabitRepository(),
        _analytics = analytics ?? AnalyticsService();

  final MoodRepository _moods;
  final RoutineRepository _routines;
  final HabitRepository _habits;
  final AnalyticsService _analytics;

  DisciplineSnapshot getDisciplineSnapshot({DateTime? on}) {
    final date = on ?? DateTime.now();
    final habitScore = _habitScoreFor(date);
    final routineScore = _routineScoreFor(date);
    final streak = _moods.calculateStreak();
    final streakScore = (streak / 30).clamp(0.0, 1.0) * 30;
    final total = (habitScore + routineScore + streakScore).round().clamp(0, 100);
    return DisciplineSnapshot(
      score: total,
      habitScore: habitScore,
      routineScore: routineScore,
      streakScore: streakScore,
      streak: streak,
    );
  }

  int getDisciplineScore() => getDisciplineSnapshot().score;

  /// Percentage-point delta vs the average score of the *previous* 7 days.
  /// Positive = improving.
  double getWeeklyDelta() {
    final today = _dayKey(DateTime.now());
    final current = _avgScoreOver(today.subtract(const Duration(days: 7)), today);
    final previous = _avgScoreOver(
      today.subtract(const Duration(days: 14)),
      today.subtract(const Duration(days: 7)),
    );
    return current - previous;
  }

  List<ScorePoint> getDisciplineScoreHistory(int days) {
    final today = _dayKey(DateTime.now());
    final out = <ScorePoint>[];
    for (var i = days - 1; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      out.add(ScorePoint(date: date, score: _scoreFor(date).round()));
    }
    return out;
  }

  /// 0..1 progress for an identity in the last [days]. Average completion
  /// rate across habits that belong to it.
  double getIdentityProgress(String identity, {int days = 30}) {
    final habits = _habits
        .getActiveHabits()
        .where((h) => h.identity == identity)
        .toList();
    if (habits.isEmpty) return 0;
    var sum = 0.0;
    for (final h in habits) {
      sum += _habits.getCompletionRate(h.id, days);
    }
    return sum / habits.length;
  }

  /// Percentage-point change in identity progress vs the prior period.
  double getIdentityChange(String identity, {int days = 30}) {
    final current = getIdentityProgress(identity, days: days) * 100;
    final habits = _habits
        .getActiveHabits()
        .where((h) => h.identity == identity)
        .toList();
    if (habits.isEmpty) return 0;
    var sum = 0.0;
    for (final h in habits) {
      // Previous-period rate using the analytics helper: rate over (days..2*days).
      sum += _priorPeriodRate(h.id, days);
    }
    final prior = (sum / habits.length) * 100;
    return current - prior;
  }

  Map<String, double> getAllIdentitiesProgress({int days = 30}) =>
      _analytics.getIdentityProgress(days: days);

  // ─── helpers ──────────────────────────────────────────────────────────

  double _scoreFor(DateTime date) {
    return _habitScoreFor(date) +
        _routineScoreFor(date) +
        (_streakAt(date) / 30).clamp(0.0, 1.0) * 30;
  }

  double _habitScoreFor(DateTime date) {
    final habits = _habits.getActiveHabits();
    var scheduled = 0;
    var completed = 0;
    for (final h in habits) {
      if (!h.isScheduledFor(date)) continue;
      scheduled += 1;
      final log = _habits.getLogForDate(h.id, date);
      if (log != null && log.isCompleted) completed += 1;
    }
    if (scheduled == 0) return 0;
    return (completed / scheduled) * 40;
  }

  double _routineScoreFor(DateTime date) {
    final items = _routines.getRoutinesForDate(date);
    if (items.isEmpty) return 0;
    final completed = items.where((r) => r.isCompleted).length;
    return (completed / items.length) * 30;
  }

  int _streakAt(DateTime date) {
    // Approximation: count consecutive days with a mood entry up to [date].
    final entries = _moods.getAllEntries();
    if (entries.isEmpty) return 0;
    final byDay = <DateTime>{
      for (final e in entries) _dayKey(e.timestamp),
    };
    var cursor = _dayKey(date);
    var streak = 0;
    while (byDay.contains(cursor)) {
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  double _avgScoreOver(DateTime from, DateTime to) {
    final days = to.difference(from).inDays.clamp(1, 365);
    var sum = 0.0;
    var counted = 0;
    for (var i = 0; i < days; i++) {
      final date = from.add(Duration(days: i));
      sum += _scoreFor(date);
      counted += 1;
    }
    if (counted == 0) return 0;
    return sum / counted;
  }

  double _priorPeriodRate(String habitId, int days) {
    // Approximate by reusing habit repo's day-range rate. Cheaper than
    // adding a second method just for symmetry.
    return _habits.getCompletionRate(habitId, days * 2) * 0.5 +
        _habits.getCompletionRate(habitId, days) * 0.0;
  }

  static DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);
}
