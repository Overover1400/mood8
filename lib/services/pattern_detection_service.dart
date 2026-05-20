import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/habit.dart';
import '../models/pattern_alert.dart';
import 'auth_service.dart';
import 'database_service.dart';
import 'gratitude_repository.dart';
import 'habit_repository.dart';
import 'mood_repository.dart';
import 'notification_service.dart';
import 'preferences_service.dart';
import 'reflection_repository.dart';

/// Detects meaningful patterns in user behavior and surfaces them as
/// gentle [PatternAlert]s. Pure-Dart math; the only AI hop is *phrasing*
/// (see [_phrasePatterns]) and even that has an offline fallback.
class PatternDetectionService {
  PatternDetectionService._();
  static final PatternDetectionService _instance =
      PatternDetectionService._();
  factory PatternDetectionService() => _instance;

  static const int _maxAlertsPerWeek = 2;
  static const String _kLastRunPrefKey = 'mood8.patterns.lastRunIso';
  static const String _kLastNotifWeekPrefKey =
      'mood8.patterns.lastNotifWeekKey';

  static const String _baseUrl = 'https://mood8.app/api';
  static const Duration _timeout = Duration(seconds: 30);

  final Uuid _uuid = const Uuid();
  final http.Client _client = http.Client();

  Box<PatternAlert> get _box => DatabaseService.instance.patternAlertBox;

  ValueListenable<Box<PatternAlert>> watch() => _box.listenable();

  // ─── Entry point ──────────────────────────────────────────────────────

  /// Main runner. Gathers raw findings from every detector, dedupes, asks
  /// the backend (or template fallback) to write the copy, persists the
  /// final alerts, returns them. Caps at [_maxAlertsPerWeek] *new* alerts.
  Future<List<PatternAlert>> detectPatterns({
    bool force = false,
  }) async {
    final prefs = PreferencesService.instance;
    if (!prefs.patternAlertsEnabled && !force) {
      debugPrint('[Patterns] master toggle off — skipping');
      return const <PatternAlert>[];
    }
    if (!force && await _ranToday()) {
      debugPrint('[Patterns] already ran today — skipping');
      return const <PatternAlert>[];
    }

    final findings = <_Finding>[];
    if (prefs.patternStreaksEnabled) {
      findings.addAll(await _detectStreakPatterns());
    }
    if (prefs.patternMoodEnabled) {
      findings.addAll(await _detectMoodCorrelations());
    }
    if (prefs.patternDayOfWeekEnabled) {
      findings.addAll(await _detectDayOfWeekPatterns());
    }
    if (prefs.patternGrowthEnabled) {
      findings.addAll(await _detectGrowthPatterns());
    }
    if (prefs.patternCheckInsEnabled) {
      findings.addAll(await _detectGentleCheckIns());
    }

    if (findings.isEmpty) {
      await _markRanToday();
      debugPrint('[Patterns] no findings');
      return const <PatternAlert>[];
    }

    // Sort by relevance, drop ones already alerted this week, cap.
    findings.sort((a, b) => b.relevance.compareTo(a.relevance));
    final fresh = <_Finding>[];
    for (final f in findings) {
      if (_existingThisWeek(f.dedupeKey) != null) continue;
      fresh.add(f);
      if (fresh.length >= _maxAlertsPerWeek) break;
    }
    if (fresh.isEmpty) {
      await _markRanToday();
      return const <PatternAlert>[];
    }

    final phrased = await _phrasePatterns(fresh);
    final saved = <PatternAlert>[];
    final now = DateTime.now();
    for (var i = 0; i < phrased.length; i++) {
      final f = fresh[i];
      final p = phrased[i];
      final alert = PatternAlert(
        id: _uuid.v4(),
        category: f.category,
        title: p.title,
        body: p.body,
        actionLabel: p.actionLabel ?? f.fallbackActionLabel,
        actionRoute: f.actionRoute,
        severity: f.severity,
        detectedAt: now,
        relevanceScore: f.relevance,
        dedupeKey: f.dedupeKey,
      );
      await _box.put(alert.id, alert);
      saved.add(alert);
    }

    await _markRanToday();
    // Optional push notification for the top high-relevance alert.
    await _maybeNotifyTop(saved);

    debugPrint('[Patterns] saved ${saved.length} alerts');
    return saved;
  }

  /// All alerts, newest first.
  List<PatternAlert> all() {
    final out = _box.values.toList()
      ..sort((a, b) => b.detectedAt.compareTo(a.detectedAt));
    return out;
  }

  List<PatternAlert> unread() =>
      all().where((a) => a.isUnread).toList();

  Future<void> dismiss(PatternAlert a) async {
    a.dismissedAt = DateTime.now();
    await a.save();
  }

  Future<void> markViewed(PatternAlert a) async {
    if (a.viewedAt != null) return;
    a.viewedAt = DateTime.now();
    await a.save();
  }

  // ─── Detectors ────────────────────────────────────────────────────────

  Future<List<_Finding>> _detectStreakPatterns() async {
    final out = <_Finding>[];
    final habits = HabitRepository();
    final active = habits.getActiveHabits();
    const milestones = <int>[7, 14, 30, 60, 90, 180, 365];

    for (final h in active) {
      final streak = habits.getStreakForHabit(h.id);
      // Hit a milestone within last few days?
      for (final m in milestones) {
        if (streak == m || streak == m + 1 || streak == m + 2) {
          out.add(_Finding(
            category: PatternCategory.streak,
            severity: PatternSeverity.positive,
            relevance: 0.5 + (m / 365).clamp(0.0, 0.45),
            dedupeKey: 'streak.habit.${h.id}.$m',
            actionRoute: 'habit:${h.id}',
            fallbackActionLabel: 'See habit',
            facts: {
              'habit_name': h.title,
              'streak_days': streak,
              'identity': h.identity,
              'milestone': m,
            },
            templateTitle: '$m days of ${h.title}',
            templateBody:
                "You've shown up for ${h.title} for $m days. That's not a fluke — that's identity.",
          ));
          break;
        }
      }
    }

    // Identity alignment moment — 3+ habits with same identity all
    // completed today.
    final today = DateTime.now();
    final byIdentity = <String, List<Habit>>{};
    for (final h in active) {
      byIdentity.putIfAbsent(h.identity, () => []).add(h);
    }
    byIdentity.forEach((identity, group) {
      if (identity.isEmpty || group.length < 3) return;
      final done = group.where((h) {
        final log = habits.getLogForDate(h.id, today);
        return log != null && log.isCompleted;
      }).length;
      if (done >= 3) {
        out.add(_Finding(
          category: PatternCategory.streak,
          severity: PatternSeverity.positive,
          relevance: 0.55 + (done * 0.05).clamp(0.0, 0.3),
          dedupeKey: 'identity.$identity.${_weekKey(today)}',
          actionRoute: 'progress',
          fallbackActionLabel: 'See progress',
          facts: {
            'identity': identity,
            'aligned_habits': done,
            'group_size': group.length,
          },
          templateTitle: 'Identity X aligned',
          templateBody:
              'You hit $done habits in the $identity identity today. Strong signal.',
        ));
      }
    });

    return out;
  }

  Future<List<_Finding>> _detectMoodCorrelations() async {
    final out = <_Finding>[];
    final moods = MoodRepository();
    final habits = HabitRepository();
    final active = habits.getActiveHabits();
    if (active.isEmpty) return out;

    final today = _dayKey(DateTime.now());
    final start = today.subtract(const Duration(days: 30));

    // Map each day → average mood (skip days with no entry).
    final moodByDay = <DateTime, double>{};
    for (var d = start; !d.isAfter(today); d = d.add(const Duration(days: 1))) {
      final entries = moods.getEntriesForDate(d);
      if (entries.isEmpty) continue;
      final avg = entries.map((e) => e.averageScore).reduce((a, b) => a + b) /
          entries.length;
      moodByDay[d] = avg;
    }
    if (moodByDay.length < 7) return out;

    for (final h in active) {
      final completionDays = <DateTime>{};
      for (final l in habits.getLogsForHabit(h.id, from: start, to: today)) {
        if (l.isCompleted) completionDays.add(_dayKey(l.date));
      }
      if (completionDays.length < 5) continue;

      // Build aligned series across days that have both a mood entry and
      // a known completion (0/1 boolean for this habit).
      final xs = <double>[];
      final ys = <double>[];
      moodByDay.forEach((day, mood) {
        xs.add(completionDays.contains(day) ? 1.0 : 0.0);
        ys.add(mood);
      });
      if (xs.length < 7) continue;
      final r = _pearson(xs, ys);
      if (r.abs() < 0.4) continue;

      // Mean mood on completion days vs others (for the % delta phrasing).
      final compMoods = <double>[];
      final restMoods = <double>[];
      for (var i = 0; i < xs.length; i++) {
        if (xs[i] == 1.0) {
          compMoods.add(ys[i]);
        } else {
          restMoods.add(ys[i]);
        }
      }
      if (compMoods.length < 3 || restMoods.length < 3) continue;
      final mC = compMoods.reduce((a, b) => a + b) / compMoods.length;
      final mR = restMoods.reduce((a, b) => a + b) / restMoods.length;
      final delta = mC - mR;
      final pctDelta = mR == 0 ? 0.0 : (delta / mR) * 100;

      out.add(_Finding(
        category: PatternCategory.moodCorrelation,
        severity: r > 0
            ? PatternSeverity.positive
            : PatternSeverity.neutral,
        relevance: 0.5 + (r.abs() - 0.4).clamp(0.0, 0.5),
        dedupeKey: 'mood.habit.${h.id}.${_weekKey(today)}',
        actionRoute: 'habit:${h.id}',
        fallbackActionLabel: 'See habit',
        facts: {
          'habit_name': h.title,
          'pearson_r': double.parse(r.toStringAsFixed(2)),
          'mood_delta': double.parse(delta.toStringAsFixed(2)),
          'mood_delta_pct': double.parse(pctDelta.toStringAsFixed(1)),
          'completion_days': compMoods.length,
          'comparison_days': restMoods.length,
        },
        templateTitle:
            'Days you do ${h.title} run higher',
        templateBody: r > 0
            ? "On days you do ${h.title}, mood averages ${pctDelta.toStringAsFixed(0)}% higher. Worth holding onto."
            : "Mood patterns look steadier on days you skip ${h.title}. Worth a closer look.",
      ));
    }

    return out;
  }

  Future<List<_Finding>> _detectDayOfWeekPatterns() async {
    final out = <_Finding>[];
    final moods = MoodRepository();
    final today = _dayKey(DateTime.now());
    final start = today.subtract(const Duration(days: 28));

    final byWeekday = <int, List<double>>{};
    for (var d = start; !d.isAfter(today); d = d.add(const Duration(days: 1))) {
      final entries = moods.getEntriesForDate(d);
      if (entries.isEmpty) continue;
      final avg = entries.map((e) => e.averageScore).reduce((a, b) => a + b) /
          entries.length;
      byWeekday.putIfAbsent(d.weekday, () => []).add(avg);
    }
    if (byWeekday.length < 5) return out;

    final allValues = byWeekday.values.expand((v) => v).toList();
    if (allValues.length < 10) return out;
    final overallMean =
        allValues.reduce((a, b) => a + b) / allValues.length;
    final overallSd = _sd(allValues, overallMean);
    if (overallSd < 0.4) return out;

    final means = <int, double>{};
    byWeekday.forEach((wd, list) {
      if (list.length >= 3) {
        means[wd] = list.reduce((a, b) => a + b) / list.length;
      }
    });

    // Pick the most extreme weekday on each side.
    int? worstDay;
    int? bestDay;
    double worstZ = 0;
    double bestZ = 0;
    means.forEach((wd, m) {
      final z = (m - overallMean) / overallSd;
      if (z < worstZ && z < -0.7) {
        worstZ = z;
        worstDay = wd;
      }
      if (z > bestZ && z > 0.7) {
        bestZ = z;
        bestDay = wd;
      }
    });

    if (worstDay != null) {
      out.add(_Finding(
        category: PatternCategory.dayOfWeek,
        severity: PatternSeverity.gentleConcern,
        relevance: 0.45 + (worstZ.abs() * 0.15).clamp(0.0, 0.4),
        dedupeKey:
            'dow.low.$worstDay.${_isoMonth(today)}',
        actionRoute: 'progress',
        fallbackActionLabel: 'Open progress',
        facts: {
          'weekday': _weekdayName(worstDay!),
          'weekday_index': worstDay,
          'weekday_mean': double.parse(means[worstDay]!.toStringAsFixed(2)),
          'overall_mean': double.parse(overallMean.toStringAsFixed(2)),
          'z_score': double.parse(worstZ.toStringAsFixed(2)),
          'side': 'low',
        },
        templateTitle:
            '${_weekdayName(worstDay!)}s have been harder',
        templateBody:
            "Mood averages a bit lower on ${_weekdayName(worstDay!)}s this month. Worth a softer plan?",
      ));
    }
    if (bestDay != null && bestDay != worstDay) {
      out.add(_Finding(
        category: PatternCategory.dayOfWeek,
        severity: PatternSeverity.positive,
        relevance: 0.4 + (bestZ.abs() * 0.15).clamp(0.0, 0.35),
        dedupeKey:
            'dow.high.$bestDay.${_isoMonth(today)}',
        actionRoute: 'progress',
        fallbackActionLabel: 'Open progress',
        facts: {
          'weekday': _weekdayName(bestDay!),
          'weekday_index': bestDay,
          'weekday_mean': double.parse(means[bestDay]!.toStringAsFixed(2)),
          'overall_mean': double.parse(overallMean.toStringAsFixed(2)),
          'z_score': double.parse(bestZ.toStringAsFixed(2)),
          'side': 'high',
        },
        templateTitle: '${_weekdayName(bestDay!)}s are your peak',
        templateBody:
            "Mood tends to run highest on ${_weekdayName(bestDay!)}s. Use that energy.",
      ));
    }
    return out;
  }

  Future<List<_Finding>> _detectGrowthPatterns() async {
    final out = <_Finding>[];
    final moods = MoodRepository();
    final reflections = ReflectionRepository();
    final habits = HabitRepository();
    final today = _dayKey(DateTime.now());

    // Last 14 vs prior 14.
    final lastStart = today.subtract(const Duration(days: 13));
    final priorStart = today.subtract(const Duration(days: 27));
    final priorEnd = today.subtract(const Duration(days: 14));

    // Mood check-in frequency
    int countMoods(DateTime from, DateTime to) {
      var c = 0;
      for (var d = from; !d.isAfter(to); d = d.add(const Duration(days: 1))) {
        if (moods.getEntriesForDate(d).isNotEmpty) c++;
      }
      return c;
    }
    final cLast = countMoods(lastStart, today);
    final cPrior = countMoods(priorStart, priorEnd);
    if (cPrior > 0) {
      final delta = (cLast - cPrior) / cPrior;
      if (delta >= 0.25) {
        out.add(_Finding(
          category: PatternCategory.growth,
          severity: PatternSeverity.positive,
          relevance: 0.5 + (delta.clamp(0.0, 1.0) * 0.3),
          dedupeKey: 'growth.checkin.${_weekKey(today)}',
          actionRoute: 'progress',
          fallbackActionLabel: 'See progress',
          facts: {
            'metric': 'check_in_frequency',
            'last_14_count': cLast,
            'prior_14_count': cPrior,
            'delta_pct': double.parse((delta * 100).toStringAsFixed(1)),
          },
          templateTitle: 'Checking in more often',
          templateBody:
              "Mood check-ins are up ${(delta * 100).round()}% this fortnight. More signal, better insights.",
        ));
      }
    }

    // Reflection avg word count
    final lastRefl = reflections
        .getReflectionsForLastDays(14)
        .where((r) => !r.date.isBefore(lastStart))
        .toList();
    final priorRefl = reflections
        .getReflectionsForLastDays(28)
        .where((r) =>
            !r.date.isBefore(priorStart) && r.date.isBefore(lastStart))
        .toList();
    if (lastRefl.length >= 2 && priorRefl.length >= 2) {
      double wc(List list) =>
          list.fold<int>(0, (a, r) => a + (r.reflection as String).split(RegExp(r'\s+')).length) /
              list.length;
      final lastW = wc(lastRefl);
      final priorW = wc(priorRefl);
      if (priorW > 0) {
        final delta = (lastW - priorW) / priorW;
        if (delta >= 0.30) {
          out.add(_Finding(
            category: PatternCategory.growth,
            severity: PatternSeverity.positive,
            relevance: 0.5 + (delta.clamp(0.0, 1.0) * 0.25),
            dedupeKey: 'growth.reflectionLen.${_weekKey(today)}',
            actionRoute: 'coach',
            fallbackActionLabel: 'Open coach',
            facts: {
              'metric': 'reflection_length',
              'last_avg_words': double.parse(lastW.toStringAsFixed(1)),
              'prior_avg_words': double.parse(priorW.toStringAsFixed(1)),
              'delta_pct': double.parse((delta * 100).toStringAsFixed(1)),
            },
            templateTitle: 'Reflections growing deeper',
            templateBody:
                "Your reflections are ${(delta * 100).round()}% longer than two weeks ago. The looking-in habit is taking hold.",
          ));
        }
      }
    }

    // Habit completion rate (last 14 vs prior 14)
    int countHabitCompletions(DateTime from, DateTime to) {
      var c = 0;
      for (final h in habits.getActiveHabits()) {
        for (final l in habits.getLogsForHabit(h.id, from: from, to: to)) {
          if (l.isCompleted) c++;
        }
      }
      return c;
    }
    final hLast = countHabitCompletions(lastStart, today);
    final hPrior = countHabitCompletions(priorStart, priorEnd);
    if (hPrior > 0) {
      final delta = (hLast - hPrior) / hPrior;
      if (delta >= 0.20) {
        out.add(_Finding(
          category: PatternCategory.growth,
          severity: PatternSeverity.positive,
          relevance: 0.5 + (delta.clamp(0.0, 1.0) * 0.25),
          dedupeKey: 'growth.habits.${_weekKey(today)}',
          actionRoute: 'habits',
          fallbackActionLabel: 'See habits',
          facts: {
            'metric': 'habit_completion',
            'last_14_count': hLast,
            'prior_14_count': hPrior,
            'delta_pct': double.parse((delta * 100).toStringAsFixed(1)),
          },
          templateTitle: 'Momentum is building',
          templateBody:
              "Habit completions are up ${(delta * 100).round()}% this fortnight. Identity in motion.",
        ));
      }
    }
    return out;
  }

  Future<List<_Finding>> _detectGentleCheckIns() async {
    final out = <_Finding>[];
    final moods = MoodRepository();
    final today = _dayKey(DateTime.now());

    // Hard gate: only nudge users who have been active in the last 3 days.
    final lastThreeDaysHasEntry = () {
      for (var i = 0; i < 3; i++) {
        final d = today.subtract(Duration(days: i));
        if (moods.getEntriesForDate(d).isNotEmpty) return true;
      }
      return false;
    }();
    if (!lastThreeDaysHasEntry) {
      debugPrint(
          '[Patterns] gentle check-ins skipped — user inactive last 3 days');
      return out;
    }

    // Habit streak >= 7 now broken for 4+ days.
    final habits = HabitRepository();
    for (final h in habits.getActiveHabits()) {
      // Walk backwards through the past 14 days and find: was there a
      // streak >= 7 followed by a 4+ day gap?
      final logs = habits
          .getLogsForHabit(h.id, from: today.subtract(const Duration(days: 30)), to: today)
          .where((l) => l.isCompleted)
          .map((l) => _dayKey(l.date))
          .toSet();
      if (logs.isEmpty) continue;

      // Find longest active streak that ended.
      // Simple heuristic: count completed days in window [-14, -4], check
      // if recent 4 days [-3, today) are all empty.
      var recentSkips = 0;
      for (var i = 0; i < 4; i++) {
        final d = today.subtract(Duration(days: i));
        if (!logs.contains(d)) recentSkips++;
      }
      if (recentSkips < 4) continue;
      var priorRun = 0;
      for (var i = 4; i < 30; i++) {
        final d = today.subtract(Duration(days: i));
        if (logs.contains(d)) {
          priorRun++;
          if (priorRun >= 7) break;
        } else {
          break;
        }
      }
      if (priorRun < 7) continue;

      out.add(_Finding(
        category: PatternCategory.checkIn,
        severity: PatternSeverity.gentleConcern,
        relevance: 0.55,
        dedupeKey: 'checkin.habit.${h.id}.${_weekKey(today)}',
        actionRoute: 'habit:${h.id}',
        fallbackActionLabel: 'Open ${h.title}',
        facts: {
          'kind': 'habit_quiet',
          'habit_name': h.title,
          'prior_streak': priorRun,
          'quiet_days': recentSkips,
        },
        templateTitle: '${h.title} has been quiet',
        templateBody:
            "You were on a $priorRun-day run with ${h.title}. Anything getting in the way?",
      ));
      break; // one habit-quiet alert per run is plenty
    }

    // Mood last 7 days avg dropped 1.5+ pts vs prior 14.
    final last7 = <double>[];
    final prior14 = <double>[];
    for (var i = 0; i < 7; i++) {
      final d = today.subtract(Duration(days: i));
      final entries = moods.getEntriesForDate(d);
      if (entries.isNotEmpty) {
        last7.add(entries.map((e) => e.averageScore).reduce((a, b) => a + b) /
            entries.length);
      }
    }
    for (var i = 7; i < 21; i++) {
      final d = today.subtract(Duration(days: i));
      final entries = moods.getEntriesForDate(d);
      if (entries.isNotEmpty) {
        prior14.add(entries.map((e) => e.averageScore).reduce((a, b) => a + b) /
            entries.length);
      }
    }
    if (last7.length >= 3 && prior14.length >= 5) {
      final mLast = last7.reduce((a, b) => a + b) / last7.length;
      final mPrior = prior14.reduce((a, b) => a + b) / prior14.length;
      final drop = mPrior - mLast;
      if (drop >= 1.5) {
        out.add(_Finding(
          category: PatternCategory.checkIn,
          severity: PatternSeverity.gentleConcern,
          relevance: 0.65,
          dedupeKey: 'checkin.mood.${_weekKey(today)}',
          actionRoute: 'coach',
          fallbackActionLabel: 'Open coach',
          facts: {
            'kind': 'mood_drop',
            'last_7_avg': double.parse(mLast.toStringAsFixed(2)),
            'prior_14_avg': double.parse(mPrior.toStringAsFixed(2)),
            'drop': double.parse(drop.toStringAsFixed(2)),
          },
          templateTitle: 'This week has felt different',
          templateBody:
              "Mood is averaging ${drop.toStringAsFixed(1)} points below the prior fortnight. Worth a few words with the coach?",
        ));
      }
    }

    // Gratitude streak >=14 now broken for 10+.
    final gratitude = GratitudeRepository();
    final recent = await gratitude.getRecent(30);
    final activeDays = recent
        .where((g) => g.nonEmptyItems.isNotEmpty)
        .map((g) => _dayKey(g.date))
        .toSet();
    var consecutiveSkipsFromToday = 0;
    for (var i = 0; i < 30; i++) {
      final d = today.subtract(Duration(days: i));
      if (activeDays.contains(d)) break;
      consecutiveSkipsFromToday++;
    }
    if (consecutiveSkipsFromToday >= 10) {
      // Was there a >=14-day run before that gap?
      var priorRun = 0;
      for (var i = consecutiveSkipsFromToday;
          i < 30;
          i++) {
        final d = today.subtract(Duration(days: i));
        if (activeDays.contains(d)) {
          priorRun++;
        } else {
          break;
        }
      }
      if (priorRun >= 14) {
        out.add(_Finding(
          category: PatternCategory.checkIn,
          severity: PatternSeverity.gentleConcern,
          relevance: 0.5,
          dedupeKey: 'checkin.gratitude.${_weekKey(today)}',
          actionRoute: 'home',
          fallbackActionLabel: 'Open gratitude',
          facts: {
            'kind': 'gratitude_quiet',
            'prior_run': priorRun,
            'quiet_days': consecutiveSkipsFromToday,
          },
          templateTitle: 'Missed our gratitude moments?',
          templateBody:
              "You had a $priorRun-day gratitude run going. Want to start a new one tonight?",
        ));
      }
    }

    return out;
  }

  // ─── AI phrasing ──────────────────────────────────────────────────────

  Future<List<_PhrasedAlert>> _phrasePatterns(List<_Finding> findings) async {
    final fallback = findings
        .map((f) => _PhrasedAlert(
              title: f.templateTitle,
              body: f.templateBody,
              actionLabel: f.fallbackActionLabel,
            ))
        .toList();

    final token = AuthService().token;
    if (token == null || token.isEmpty) return fallback;

    try {
      final body = jsonEncode({
        'patterns': [
          for (final f in findings)
            {
              'category': f.category.name,
              'raw_facts': f.facts,
              'severity': f.severity.name,
            }
        ],
      });
      final res = await _client
          .post(
            Uri.parse('$_baseUrl/patterns/phrase'),
            headers: {
              'authorization': 'Bearer $token',
              'content-type': 'application/json',
            },
            body: body,
          )
          .timeout(_timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint('[Patterns] phrase failed ${res.statusCode}: ${res.body}');
        return fallback;
      }
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final phrased = json['phrased_patterns'] as List? ?? const [];
      final out = <_PhrasedAlert>[];
      for (var i = 0; i < findings.length; i++) {
        if (i >= phrased.length) {
          out.add(fallback[i]);
          continue;
        }
        final entry = phrased[i] as Map<String, dynamic>;
        out.add(_PhrasedAlert(
          title: (entry['title'] as String?)?.trim().isNotEmpty == true
              ? (entry['title'] as String).trim()
              : fallback[i].title,
          body: (entry['body'] as String?)?.trim().isNotEmpty == true
              ? (entry['body'] as String).trim()
              : fallback[i].body,
          actionLabel: (entry['action_label'] as String?)?.trim(),
        ));
      }
      return out;
    } on TimeoutException {
      debugPrint('[Patterns] phrase timeout — using fallback');
      return fallback;
    } catch (e) {
      debugPrint('[Patterns] phrase error: $e — using fallback');
      return fallback;
    }
  }

  // ─── Notifications ────────────────────────────────────────────────────

  Future<void> _maybeNotifyTop(List<PatternAlert> alerts) async {
    if (alerts.isEmpty) return;
    if (!PreferencesService.instance.patternNotificationsEnabled) return;
    final top = alerts.first;
    if (top.relevanceScore < 0.7) return;
    if (await _alreadyNotifiedThisWeek()) return;
    final notif = NotificationService();
    if (!notif.isSupported || !notif.isGranted) return;
    await notif.showNow(title: top.title, body: top.body);
    await _markNotifiedThisWeek();
  }

  // ─── Helpers ──────────────────────────────────────────────────────────

  PatternAlert? _existingThisWeek(String key) {
    final weekKey = _weekKey(DateTime.now());
    for (final a in _box.values) {
      if (a.dedupeKey == key && _weekKey(a.detectedAt) == weekKey) return a;
    }
    return null;
  }

  Future<bool> _ranToday() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getString(_kLastRunPrefKey);
    if (last == null) return false;
    final parsed = DateTime.tryParse(last);
    if (parsed == null) return false;
    final now = DateTime.now();
    return parsed.year == now.year &&
        parsed.month == now.month &&
        parsed.day == now.day;
  }

  Future<void> _markRanToday() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastRunPrefKey, DateTime.now().toIso8601String());
  }

  Future<bool> _alreadyNotifiedThisWeek() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_kLastNotifWeekPrefKey);
    return v == _weekKey(DateTime.now());
  }

  Future<void> _markNotifiedThisWeek() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kLastNotifWeekPrefKey, _weekKey(DateTime.now()));
  }

  static double _pearson(List<double> x, List<double> y) {
    final n = math.min(x.length, y.length);
    if (n < 2) return 0;
    final meanX = x.reduce((a, b) => a + b) / n;
    final meanY = y.reduce((a, b) => a + b) / n;
    double sumXY = 0, sumX2 = 0, sumY2 = 0;
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

  static double _sd(List<double> xs, double mean) {
    if (xs.length < 2) return 0;
    final v = xs.fold<double>(0, (a, x) => a + (x - mean) * (x - mean)) /
        (xs.length - 1);
    return math.sqrt(v);
  }

  static DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _weekKey(DateTime d) {
    final dayOfYear = d.difference(DateTime(d.year, 1, 1)).inDays + 1;
    final week = (dayOfYear / 7).ceil();
    return '${d.year}-W${week.toString().padLeft(2, '0')}';
  }

  static String _isoMonth(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  static String _weekdayName(int wd) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[(wd - 1).clamp(0, 6)];
  }
}

// ─── Internal types ─────────────────────────────────────────────────────

class _Finding {
  _Finding({
    required this.category,
    required this.severity,
    required this.relevance,
    required this.dedupeKey,
    required this.facts,
    required this.templateTitle,
    required this.templateBody,
    this.actionRoute,
    this.fallbackActionLabel,
  });
  final PatternCategory category;
  final PatternSeverity severity;
  final double relevance;
  final String dedupeKey;
  final Map<String, dynamic> facts;
  final String templateTitle;
  final String templateBody;
  final String? actionRoute;
  final String? fallbackActionLabel;
}

class _PhrasedAlert {
  _PhrasedAlert({required this.title, required this.body, this.actionLabel});
  final String title;
  final String body;
  final String? actionLabel;
}

