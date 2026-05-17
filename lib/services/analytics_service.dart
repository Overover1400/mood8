import 'package:intl/intl.dart';

import '../models/analytics_models.dart';
import '../models/habit.dart';
import '../models/mood_entry.dart';
import 'database_service.dart';
import 'habit_repository.dart';
import 'mood_repository.dart';
import 'user_repository.dart';

class _CacheEntry {
  _CacheEntry(this.value, this.at);
  final Object? value;
  final DateTime at;
}

class AnalyticsService {
  AnalyticsService({
    DatabaseService? db,
    MoodRepository? moods,
    HabitRepository? habits,
    UserRepository? users,
  })  : _moods = moods ?? MoodRepository(),
        _habits = habits ?? HabitRepository(),
        _users = users ?? UserRepository();

  final MoodRepository _moods;
  final HabitRepository _habits;
  final UserRepository _users;

  final Map<String, _CacheEntry> _cache = {};
  static const Duration _ttl = Duration(minutes: 1);

  void invalidate() => _cache.clear();

  T _memo<T>(String key, T Function() compute) {
    final hit = _cache[key];
    if (hit != null && DateTime.now().difference(hit.at) < _ttl) {
      return hit.value as T;
    }
    final v = compute();
    _cache[key] = _CacheEntry(v, DateTime.now());
    return v;
  }

  // ─── Series ────────────────────────────────────────────────────────────

  List<DataPoint> getMoodEnergyFocusOverTime(int days) {
    return _memo('series:$days', () {
      final today = _dayKey(DateTime.now());
      final out = <DataPoint>[];
      for (var i = days - 1; i >= 0; i--) {
        final date = today.subtract(Duration(days: i));
        final entries = _moods.getEntriesForDate(date);
        if (entries.isEmpty) {
          out.add(DataPoint(date: date, mood: null, energy: null, focus: null));
        } else {
          out.add(DataPoint(
            date: date,
            mood: _avg(entries, (e) => e.mood),
            energy: _avg(entries, (e) => e.energy),
            focus: _avg(entries, (e) => e.focus),
          ));
        }
      }
      return out;
    });
  }

  List<HeatmapDay> getStreakHeatmapData(int days) {
    return _memo('heatmap:$days', () {
      final today = _dayKey(DateTime.now());
      final out = <HeatmapDay>[];
      for (var i = days - 1; i >= 0; i--) {
        final date = today.subtract(Duration(days: i));
        final entries = _moods.getEntriesForDate(date);
        if (entries.isEmpty) {
          out.add(
              HeatmapDay(date: date, completionScore: 0, hasData: false));
        } else {
          final avg = entries.map((e) => e.averageScore).reduce((a, b) => a + b) /
              entries.length;
          out.add(HeatmapDay(
            date: date,
            completionScore: (avg / 10.0).clamp(0.0, 1.0),
            hasData: true,
          ));
        }
      }
      return out;
    });
  }

  // ─── Identity ──────────────────────────────────────────────────────────

  Map<String, double> getIdentityProgress({int days = 30}) {
    return _memo('identityProgress:$days', () {
      final user = _users.getCurrentUser();
      final identities = <String>{
        ...?user?.identities,
        for (final h in _habits.getActiveHabits()) h.identity,
      }.where((i) => i.isNotEmpty).toList();

      final map = <String, double>{};
      for (final id in identities) {
        final habits =
            _habits.getActiveHabits().where((h) => h.identity == id).toList();
        if (habits.isEmpty) {
          map[id] = 0;
          continue;
        }
        var sum = 0.0;
        for (final h in habits) {
          sum += _habits.getCompletionRate(h.id, days);
        }
        map[id] = sum / habits.length;
      }
      final sortedEntries = map.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return {for (final e in sortedEntries) e.key: e.value};
    });
  }

  // ─── Habits ────────────────────────────────────────────────────────────

  List<HabitStats> getTopHabits(int limit, {int days = 30}) {
    return _memo('topHabits:$limit:$days', () {
      final result = <HabitStats>[];
      for (final h in _habits.getActiveHabits()) {
        result.add(HabitStats(
          habit: h,
          completionRate: _habits.getCompletionRate(h.id, days),
          streak: _habits.getStreakForHabit(h.id),
          last30Days: _habits.getLast30Days(h.id),
        ));
      }
      result.sort((a, b) => b.completionRate.compareTo(a.completionRate));
      return result.take(limit).toList();
    });
  }

  // ─── Highlights ────────────────────────────────────────────────────────

  Highlights getHighlights(int days) {
    return _memo('highlights:$days', () {
      final today = _dayKey(DateTime.now());
      final from = today.subtract(Duration(days: days - 1));

      // Best day in period.
      final inWindow = _moods
          .getAllEntries()
          .where((e) => !e.timestamp.isBefore(from))
          .toList();
      HighlightItem? bestDay;
      if (inWindow.isNotEmpty) {
        final byDay = <DateTime, List<MoodEntry>>{};
        for (final e in inWindow) {
          byDay.putIfAbsent(_dayKey(e.timestamp), () => []).add(e);
        }
        final avgs = byDay.map(
          (k, v) => MapEntry(
            k,
            v.map((e) => e.averageScore).reduce((a, b) => a + b) / v.length,
          ),
        );
        final best = avgs.entries
            .reduce((a, b) => a.value >= b.value ? a : b);
        bestDay = HighlightItem(
          emoji: '🌅',
          label: 'Best day',
          value: DateFormat('EEE, MMM d').format(best.key),
          subtitle: 'avg ${best.value.toStringAsFixed(1)}/10',
        );
      }

      // Top habit by completion rate.
      final topHabits = getTopHabits(1, days: days);
      HighlightItem? topHabit;
      if (topHabits.isNotEmpty) {
        final t = topHabits.first;
        topHabit = HighlightItem(
          emoji: '🎯',
          label: 'Top habit',
          value: t.habit.title,
          subtitle: '${(t.completionRate * 100).round()}% completion',
        );
      }

      // Longest current habit streak.
      HighlightItem? longestStreak;
      Habit? topStreakHabit;
      var bestStreak = 0;
      for (final h in _habits.getActiveHabits()) {
        final s = _habits.getStreakForHabit(h.id);
        if (s > bestStreak) {
          bestStreak = s;
          topStreakHabit = h;
        }
      }
      if (topStreakHabit != null && bestStreak > 0) {
        longestStreak = HighlightItem(
          emoji: '⭐',
          label: 'Longest streak',
          value: '$bestStreak day${bestStreak == 1 ? '' : 's'}',
          subtitle: topStreakHabit.title,
        );
      }

      // Best time-of-day.
      HighlightItem? bestTime;
      final tod = getTimeOfDayPatterns();
      if (tod.isNotEmpty) {
        final best = tod.entries.reduce((a, b) => a.value >= b.value ? a : b);
        bestTime = HighlightItem(
          emoji: '🌙',
          label: 'Best time',
          value: best.key.label,
          subtitle: 'avg ${best.value.toStringAsFixed(1)} mood',
        );
      }

      // Most improved metric vs prior period.
      HighlightItem? improvedMost;
      final comparisons = getPeriodComparison(days);
      if (comparisons.isNotEmpty) {
        final best = comparisons.reduce(
            (a, b) => a.changePercent.abs() >= b.changePercent.abs() ? a : b);
        if (best.change != 0) {
          final sign = best.isUp ? '+' : '';
          improvedMost = HighlightItem(
            emoji: best.isUp ? '📈' : '📉',
            label: best.isUp ? 'Improved most' : 'Dropped most',
            value: best.metric,
            subtitle:
                '$sign${(best.changePercent * 100).round()}% vs last period',
          );
        }
      }

      // Best week (7-day window with highest mood avg).
      HighlightItem? bestWeek;
      final series = getMoodEnergyFocusOverTime(days);
      if (series.length >= 7) {
        double sum = 0;
        var count = 0;
        var winStart = 0;
        var bestStart = 0;
        double bestAvg = -1;
        for (var i = 0; i < series.length; i++) {
          if (series[i].mood != null) {
            sum += series[i].mood!;
            count += 1;
          }
          if (i >= 6) {
            if (i - 7 >= 0 && series[i - 7].mood != null) {
              sum -= series[i - 7].mood!;
              count -= 1;
            }
            if (count >= 4) {
              final avg = sum / count;
              if (avg > bestAvg) {
                bestAvg = avg;
                bestStart = winStart;
              }
            }
            winStart += 1;
          }
        }
        if (bestAvg > 0) {
          final s = series[bestStart].date;
          final e = series[bestStart + 6].date;
          bestWeek = HighlightItem(
            emoji: '💪',
            label: 'Best week',
            value:
                '${DateFormat('MMM d').format(s)} – ${DateFormat('MMM d').format(e)}',
            subtitle: 'avg ${bestAvg.toStringAsFixed(1)}/10',
          );
        }
      }

      return Highlights(
        bestDay: bestDay,
        bestWeek: bestWeek,
        topHabit: topHabit,
        longestStreak: longestStreak,
        improvedMost: improvedMost,
        bestTime: bestTime,
      );
    });
  }

  // ─── Time-of-day ───────────────────────────────────────────────────────

  Map<TimeOfDayBlock, double> getTimeOfDayPatterns({int days = 30}) {
    return _memo('todPatterns:$days', () {
      final today = _dayKey(DateTime.now());
      final from = today.subtract(Duration(days: days - 1));
      final buckets = <TimeOfDayBlock, List<double>>{
        for (final b in TimeOfDayBlock.values) b: <double>[],
      };
      for (final e in _moods.getAllEntries()) {
        if (e.timestamp.isBefore(from)) continue;
        buckets[TimeOfDayBlock.forHour(e.timestamp.hour)]!
            .add(e.averageScore);
      }
      final result = <TimeOfDayBlock, double>{};
      for (final entry in buckets.entries) {
        if (entry.value.isEmpty) continue;
        result[entry.key] =
            entry.value.reduce((a, b) => a + b) / entry.value.length;
      }
      return result;
    });
  }

  // ─── Period comparison ────────────────────────────────────────────────

  List<Comparison> getPeriodComparison(int days) {
    return _memo('periodCompare:$days', () {
      double avgMood(int from, int to) {
        final entries = _moodsInRange(from, to);
        if (entries.isEmpty) return 0;
        return entries.map((e) => e.mood).reduce((a, b) => a + b) /
            entries.length;
      }

      double avgEnergy(int from, int to) {
        final entries = _moodsInRange(from, to);
        if (entries.isEmpty) return 0;
        return entries.map((e) => e.energy).reduce((a, b) => a + b) /
            entries.length;
      }

      double habitCompletion(int from, int to) {
        final habits = _habits.getActiveHabits();
        if (habits.isEmpty) return 0;
        final dayCount = to - from + 1;
        var scheduled = 0;
        var completed = 0;
        final today = _dayKey(DateTime.now());
        for (var i = 0; i < dayCount; i++) {
          final date = today.subtract(Duration(days: from + i));
          for (final h in habits) {
            if (!h.isScheduledFor(date)) continue;
            scheduled += 1;
            final log = _habits.getLogForDate(h.id, date);
            if (log != null && log.isCompleted) completed += 1;
          }
        }
        if (scheduled == 0) return 0;
        return completed / scheduled;
      }

      final current = (from: 0, to: days - 1);
      final prior = (from: days, to: days * 2 - 1);

      return [
        Comparison(
          metric: 'Mood',
          current: avgMood(current.from, current.to),
          previous: avgMood(prior.from, prior.to),
          unit: '/10',
        ),
        Comparison(
          metric: 'Energy',
          current: avgEnergy(current.from, current.to),
          previous: avgEnergy(prior.from, prior.to),
          unit: '/10',
        ),
        Comparison(
          metric: 'Habit completion',
          current: habitCompletion(current.from, current.to) * 100,
          previous: habitCompletion(prior.from, prior.to) * 100,
          unit: '%',
        ),
      ];
    });
  }

  // ─── Hero stats ────────────────────────────────────────────────────────

  int getCurrentStreak() => _moods.calculateStreak();

  double getAverageMood(int days) {
    return _memo('avgMood:$days', () {
      final entries = _moodsInRange(0, days - 1);
      if (entries.isEmpty) return 0;
      return entries.map((e) => e.mood).reduce((a, b) => a + b) /
          entries.length;
    });
  }

  double getHabitsCompletionRate(int days) {
    return _memo('habitRate:$days', () {
      final habits = _habits.getActiveHabits();
      if (habits.isEmpty) return 0;
      var sum = 0.0;
      for (final h in habits) {
        sum += _habits.getCompletionRate(h.id, days);
      }
      return sum / habits.length;
    });
  }

  // ─── Helpers ───────────────────────────────────────────────────────────

  List<MoodEntry> _moodsInRange(int fromDaysAgo, int toDaysAgo) {
    final today = _dayKey(DateTime.now());
    final from = today.subtract(Duration(days: toDaysAgo));
    final to = today.subtract(Duration(days: fromDaysAgo));
    return _moods.getAllEntries().where((e) {
      final d = _dayKey(e.timestamp);
      return !d.isBefore(from) && !d.isAfter(to);
    }).toList();
  }

  static double _avg(List<MoodEntry> e, double Function(MoodEntry) f) =>
      e.map(f).reduce((a, b) => a + b) / e.length;

  static DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);
}
