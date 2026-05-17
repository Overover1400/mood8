import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/analytics_models.dart';
import '../models/habit.dart';
import '../models/insight.dart';
import '../models/insight_type.dart';
import '../models/mood_entry.dart';
import 'habit_repository.dart';
import 'insights_repository.dart';
import 'mood_repository.dart';
import 'routine_repository.dart';
import 'user_repository.dart';

class InsightsEngine {
  InsightsEngine({
    MoodRepository? moods,
    HabitRepository? habits,
    RoutineRepository? routines,
    UserRepository? users,
    InsightsRepository? insights,
  })  : _moods = moods ?? MoodRepository(),
        _habits = habits ?? HabitRepository(),
        _routines = routines ?? RoutineRepository(),
        _users = users ?? UserRepository(),
        _insights = insights ?? InsightsRepository();

  final MoodRepository _moods;
  final HabitRepository _habits;
  final RoutineRepository _routines;
  final UserRepository _users;
  final InsightsRepository _insights;
  final Uuid _uuid = const Uuid();

  static const int _minSamples = 7;
  static const double _significant = 0.30;
  static const int _windowDays = 30;

  int trackedDays() {
    final entries = _moods.getAllEntries();
    if (entries.isEmpty) return 0;
    final days = <DateTime>{
      for (final e in entries) _dayKey(e.timestamp),
    };
    return days.length;
  }

  bool hasEnoughData() => trackedDays() >= _minSamples;

  /// Recompute all insights and persist them. Returns the saved list.
  Future<List<Insight>> discover() async {
    if (!hasEnoughData()) return [];

    final pack = <String, Insight>{};
    void push(String key, Insight? insight) {
      if (insight != null) pack[key] = insight;
    }

    for (final h in _habits.getActiveHabits()) {
      push('habit:${h.id}:mood',
          discoverHabitImpact(h, 'mood', (e) => e.mood));
      push('habit:${h.id}:energy',
          discoverHabitImpact(h, 'energy', (e) => e.energy));
      push('habit:${h.id}:focus',
          discoverHabitImpact(h, 'focus', (e) => e.focus));
    }

    push('pattern:bestDay', discoverBestDays());
    push('pattern:bestTime', discoverBestTimes());
    push('pattern:routineImpact', discoverRoutineCompletionImpact());
    push('pattern:streak', discoverStreakPattern());

    for (final w in discoverWarnings()) {
      push('warn:${w.relatedHabitId ?? w.id}', w);
    }
    for (final d in discoverIdentityDrivers()) {
      push('identity:${d.relatedIdentity}', d);
    }

    await _insights.clearAll();
    await _insights.saveAll(pack);
    return _insights.getActiveInsights();
  }

  // ─── Habit impact on a metric ──────────────────────────────────────────

  Insight? discoverHabitImpact(
    Habit habit,
    String metricLabel,
    double Function(MoodEntry) metric,
  ) {
    final today = _dayKey(DateTime.now());
    final xs = <double>[];
    final ys = <double>[];
    var withSum = 0.0;
    var withCount = 0;
    var withoutSum = 0.0;
    var withoutCount = 0;

    for (var i = 0; i < _windowDays; i++) {
      final date = today.subtract(Duration(days: i));
      final entries = _moods.getEntriesForDate(date);
      if (entries.isEmpty) continue;
      final avg = entries.map(metric).reduce((a, b) => a + b) / entries.length;
      final log = _habits.getLogForDate(habit.id, date);
      final done = log != null && log.isCompleted;
      xs.add(done ? 1 : 0);
      ys.add(avg);
      if (done) {
        withSum += avg;
        withCount += 1;
      } else {
        withoutSum += avg;
        withoutCount += 1;
      }
    }
    if (xs.length < _minSamples) return null;
    if (withCount < 2 || withoutCount < 2) return null;

    final r = _pearson(xs, ys);
    if (r.abs() < _significant) return null;

    final avgWith = withSum / withCount;
    final avgWithout = withoutSum / withoutCount;
    if (avgWithout == 0) return null;
    final pct = ((avgWith - avgWithout) / avgWithout) * 100;

    final positive = r > 0;
    final arrow = positive ? '+' : '';
    final title =
        '${habit.title} → $arrow${pct.toStringAsFixed(0)}% better $metricLabel';

    return Insight(
      id: _uuid.v4(),
      type: positive ? InsightType.habitImpact : InsightType.warning,
      title: title,
      description:
          'On days you completed ${habit.title.toLowerCase()}, '
          'your $metricLabel averaged ${avgWith.toStringAsFixed(1)} vs '
          '${avgWithout.toStringAsFixed(1)} when you didn\'t.',
      confidence: r,
      effectSize: pct.abs(),
      sampleSize: xs.length,
      relatedHabitId: habit.id,
      relatedIdentity: habit.identity,
      actionable: positive,
      actionText: positive ? 'Add to routine' : null,
      discoveredAt: DateTime.now(),
    );
  }

  // ─── Best weekday ──────────────────────────────────────────────────────

  Insight? discoverBestDays() {
    final entries = _recentEntries(_windowDays);
    if (entries.length < _minSamples) return null;
    final perWeekday = <int, List<double>>{};
    for (final e in entries) {
      perWeekday
          .putIfAbsent(e.timestamp.weekday, () => [])
          .add(e.averageScore);
    }
    if (perWeekday.length < 3) return null;
    final means = <int, double>{};
    for (final entry in perWeekday.entries) {
      means[entry.key] =
          entry.value.reduce((a, b) => a + b) / entry.value.length;
    }
    final best = means.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final worst = means.entries.reduce((a, b) => a.value <= b.value ? a : b);
    final spread = best.value - worst.value;
    if (spread < 1.0) return null;
    final pct = (spread / worst.value).clamp(0.0, 5.0) * 100;
    final dayName = DateFormat('EEEE').format(_dateWithWeekday(best.key));
    return Insight(
      id: _uuid.v4(),
      type: InsightType.timePattern,
      title:
          'You feel best on ${dayName}s — +${pct.toStringAsFixed(0)}% above average',
      description:
          '$dayName averages ${best.value.toStringAsFixed(1)}/10 across the last ${entries.length} check-ins.',
      confidence: (spread / 5).clamp(0.0, 0.95),
      effectSize: spread,
      sampleSize: entries.length,
      discoveredAt: DateTime.now(),
    );
  }

  // ─── Best time-of-day block ────────────────────────────────────────────

  Insight? discoverBestTimes() {
    final entries = _recentEntries(_windowDays);
    if (entries.length < _minSamples) return null;
    final buckets = <TimeOfDayBlock, List<double>>{
      for (final b in TimeOfDayBlock.values) b: [],
    };
    for (final e in entries) {
      buckets[TimeOfDayBlock.forHour(e.timestamp.hour)]!
          .add(e.averageScore);
    }
    final means = <TimeOfDayBlock, double>{};
    for (final entry in buckets.entries) {
      if (entry.value.isEmpty) continue;
      means[entry.key] =
          entry.value.reduce((a, b) => a + b) / entry.value.length;
    }
    if (means.length < 2) return null;
    final best = means.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final worst = means.entries.reduce((a, b) => a.value <= b.value ? a : b);
    final spread = best.value - worst.value;
    if (spread < 0.8) return null;
    return Insight(
      id: _uuid.v4(),
      type: InsightType.timePattern,
      title: 'Your peak window is ${best.key.label}',
      description:
          'Averaging ${best.value.toStringAsFixed(1)}/10 between ${best.key.hourRange} — '
          '${spread.toStringAsFixed(1)} points above your low.',
      confidence: (spread / 4).clamp(0.0, 0.95),
      effectSize: spread,
      sampleSize: entries.length,
      discoveredAt: DateTime.now(),
    );
  }

  // ─── Routine completion → mood ─────────────────────────────────────────

  Insight? discoverRoutineCompletionImpact() {
    final today = _dayKey(DateTime.now());
    final xs = <double>[];
    final ys = <double>[];
    for (var i = 0; i < _windowDays; i++) {
      final date = today.subtract(Duration(days: i));
      final entries = _moods.getEntriesForDate(date);
      if (entries.isEmpty) continue;
      final mood =
          entries.map((e) => e.mood).reduce((a, b) => a + b) / entries.length;
      final routines = _routines.getRoutinesForDate(date);
      if (routines.isEmpty) continue;
      final pct =
          routines.where((r) => r.isCompleted).length / routines.length;
      xs.add(pct);
      ys.add(mood);
    }
    if (xs.length < _minSamples) return null;
    final r = _pearson(xs, ys);
    if (r.abs() < _significant) return null;

    // 80%+ vs <80%
    final hi = <double>[];
    final lo = <double>[];
    for (var i = 0; i < xs.length; i++) {
      (xs[i] >= 0.8 ? hi : lo).add(ys[i]);
    }
    if (hi.length < 2 || lo.length < 2) return null;
    final hiAvg = hi.reduce((a, b) => a + b) / hi.length;
    final loAvg = lo.reduce((a, b) => a + b) / lo.length;
    if (loAvg == 0) return null;
    final pct = ((hiAvg - loAvg) / loAvg) * 100;

    return Insight(
      id: _uuid.v4(),
      type: r > 0 ? InsightType.habitImpact : InsightType.warning,
      title:
          'Finishing 80%+ of routines → ${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(0)}% better mood',
      description:
          'Mood averages ${hiAvg.toStringAsFixed(1)}/10 on high-completion days vs ${loAvg.toStringAsFixed(1)} otherwise.',
      confidence: r,
      effectSize: pct.abs(),
      sampleSize: xs.length,
      actionable: false,
      discoveredAt: DateTime.now(),
    );
  }

  // ─── Streak / morning pattern ─────────────────────────────────────────

  Insight? discoverStreakPattern() {
    final actives = _habits.getActiveHabits();
    if (actives.isEmpty) return null;
    Habit? best;
    var bestStreak = 0;
    for (final h in actives) {
      final s = _habits.getStreakForHabit(h.id);
      if (s > bestStreak) {
        bestStreak = s;
        best = h;
      }
    }
    if (best == null || bestStreak < 3) return null;
    return Insight(
      id: _uuid.v4(),
      type: InsightType.streakPattern,
      title: '$bestStreak-day streak on ${best.title}',
      description:
          'Your longest active streak is anchored to ${best.identity}. '
          'Protect this — it’s compounding.',
      confidence: (bestStreak / 14).clamp(0.0, 0.95),
      effectSize: bestStreak.toDouble(),
      sampleSize: bestStreak,
      relatedHabitId: best.id,
      relatedIdentity: best.identity,
      discoveredAt: DateTime.now(),
    );
  }

  // ─── Identity drivers ──────────────────────────────────────────────────

  List<Insight> discoverIdentityDrivers() {
    final user = _users.getCurrentUser();
    final today = _dayKey(DateTime.now());
    final identities = <String>{
      ...?user?.identities,
      for (final h in _habits.getActiveHabits()) h.identity,
    }..removeWhere((i) => i.isEmpty || i == 'General');

    final out = <Insight>[];
    for (final id in identities) {
      final habits =
          _habits.getActiveHabits().where((h) => h.identity == id).toList();
      if (habits.isEmpty) continue;

      final allDone = <double>[];
      final noneDone = <double>[];
      for (var i = 0; i < _windowDays; i++) {
        final date = today.subtract(Duration(days: i));
        final entries = _moods.getEntriesForDate(date);
        if (entries.isEmpty) continue;
        final mood =
            entries.map((e) => e.averageScore).reduce((a, b) => a + b) /
                entries.length;
        var done = 0;
        var scheduled = 0;
        for (final h in habits) {
          if (!h.isScheduledFor(date)) continue;
          scheduled += 1;
          final log = _habits.getLogForDate(h.id, date);
          if (log != null && log.isCompleted) done += 1;
        }
        if (scheduled == 0) continue;
        if (done == scheduled) allDone.add(mood);
        if (done == 0) noneDone.add(mood);
      }
      if (allDone.length < 3 || noneDone.length < 3) continue;
      final allAvg = allDone.reduce((a, b) => a + b) / allDone.length;
      final noneAvg = noneDone.reduce((a, b) => a + b) / noneDone.length;
      final lift = allAvg - noneAvg;
      if (lift < 0.6) continue;
      final pct = (lift / (noneAvg == 0 ? 1 : noneAvg)) * 100;
      out.add(Insight(
        id: _uuid.v4(),
        type: InsightType.identityDriver,
        title:
            '$id habits lift your day by +${pct.toStringAsFixed(0)}%',
        description:
            'On days you complete every $id habit, average mood is ${allAvg.toStringAsFixed(1)}/10 vs ${noneAvg.toStringAsFixed(1)} on days you skip them.',
        confidence: (lift / 5).clamp(0.0, 0.95),
        effectSize: lift,
        sampleSize: allDone.length + noneDone.length,
        relatedIdentity: id,
        discoveredAt: DateTime.now(),
      ));
    }
    return out;
  }

  // ─── Warnings (late check-ins → next day mood) ─────────────────────────

  List<Insight> discoverWarnings() {
    final entries = _moods
        .getAllEntries()
        .where((e) =>
            e.timestamp.isAfter(DateTime.now().subtract(const Duration(days: 30))))
        .toList();
    if (entries.length < _minSamples) return const [];
    final byDay = <DateTime, List<MoodEntry>>{};
    for (final e in entries) {
      byDay.putIfAbsent(_dayKey(e.timestamp), () => []).add(e);
    }
    final dates = byDay.keys.toList()..sort();
    final lateNext = <double>[];
    final earlyNext = <double>[];
    for (var i = 0; i < dates.length - 1; i++) {
      final hadLate = byDay[dates[i]]!.any((e) => e.timestamp.hour >= 22);
      final next = byDay[dates[i + 1]];
      if (next == null) continue;
      final mood =
          next.map((e) => e.mood).reduce((a, b) => a + b) / next.length;
      (hadLate ? lateNext : earlyNext).add(mood);
    }
    if (lateNext.length < 2 || earlyNext.length < 2) return const [];
    final lateAvg = lateNext.reduce((a, b) => a + b) / lateNext.length;
    final earlyAvg = earlyNext.reduce((a, b) => a + b) / earlyNext.length;
    if (earlyAvg - lateAvg < 0.6) return const [];
    final pct = ((earlyAvg - lateAvg) / earlyAvg) * 100;
    return [
      Insight(
        id: _uuid.v4(),
        type: InsightType.warning,
        title:
            'Late nights cost you ${pct.toStringAsFixed(0)}% the next day',
        description:
            'After check-ins past 10 PM, next-day mood drops from ${earlyAvg.toStringAsFixed(1)} to ${lateAvg.toStringAsFixed(1)} on average.',
        confidence: ((earlyAvg - lateAvg) / 3).clamp(0.0, 0.95),
        effectSize: pct.abs(),
        sampleSize: lateNext.length + earlyNext.length,
        discoveredAt: DateTime.now(),
      ),
    ];
  }

  // ─── Helpers ──────────────────────────────────────────────────────────

  List<MoodEntry> _recentEntries(int days) {
    final cutoff = _dayKey(DateTime.now()).subtract(Duration(days: days));
    return _moods
        .getAllEntries()
        .where((e) => e.timestamp.isAfter(cutoff))
        .toList();
  }

  static double _pearson(List<double> x, List<double> y) {
    final n = x.length;
    if (n < 2) return 0;
    final meanX = x.reduce((a, b) => a + b) / n;
    final meanY = y.reduce((a, b) => a + b) / n;
    double sumXY = 0;
    double sumX2 = 0;
    double sumY2 = 0;
    for (var i = 0; i < n; i++) {
      final dx = x[i] - meanX;
      final dy = y[i] - meanY;
      sumXY += dx * dy;
      sumX2 += dx * dx;
      sumY2 += dy * dy;
    }
    final denom = math.sqrt(sumX2 * sumY2);
    return denom == 0 ? 0 : sumXY / denom;
  }

  static DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime _dateWithWeekday(int weekday) {
    var d = DateTime.now();
    while (d.weekday != weekday) {
      d = d.subtract(const Duration(days: 1));
    }
    return d;
  }
}
