import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/adaptive_suggestion.dart';
import '../models/analytics_models.dart';
import '../models/routine_category.dart';
import 'analytics_service.dart';
import 'mood_repository.dart';
import 'routine_repository.dart';

class AdaptiveRoutineService {
  AdaptiveRoutineService({
    AnalyticsService? analytics,
    MoodRepository? moods,
    RoutineRepository? routines,
  })  : _analytics = analytics ?? AnalyticsService(),
        _moods = moods ?? MoodRepository(),
        _routines = routines ?? RoutineRepository();

  final AnalyticsService _analytics;
  final MoodRepository _moods;
  final RoutineRepository _routines;
  final Uuid _uuid = const Uuid();

  static const String _dismissedPrefsKey = 'mood8.adaptive.dismissed';

  /// Returns the suggestion the home screen should surface (if any). At
  /// most one suggestion shows at a time — strongest confidence wins.
  Future<AdaptiveSuggestion?> topSuggestion() async {
    final all = await suggestions();
    if (all.isEmpty) return null;
    return all.first;
  }

  Future<List<AdaptiveSuggestion>> suggestions() async {
    final dismissed = await _dismissedTodayIds();
    final result = <AdaptiveSuggestion>[];

    final morningSimplify = _ruleMorningSkips();
    if (morningSimplify != null) result.add(morningSimplify);

    final afternoonDeepWork = _ruleAfternoonFocusDrop();
    if (afternoonDeepWork != null) result.add(afternoonDeepWork);

    final addWalk = _ruleAfternoonEnergyDip();
    if (addWalk != null) result.add(addWalk);

    final addChallenge = _rulePerfectWeekChallenge();
    if (addChallenge != null) result.add(addChallenge);

    final morningRitual = _ruleNoMorningRitual();
    if (morningRitual != null) result.add(morningRitual);

    result.sort((a, b) => b.confidence.compareTo(a.confidence));
    return result.where((s) => !dismissed.contains(s.id)).toList();
  }

  Future<void> dismiss(AdaptiveSuggestion suggestion) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _dayKey(DateTime.now());
      final raw = prefs.getStringList(_dismissedPrefsKey) ?? const <String>[];
      final fresh = raw.where((entry) {
        final parts = entry.split('|');
        if (parts.length != 2) return false;
        return parts[0] == today.toIso8601String();
      }).toList();
      fresh.add('${today.toIso8601String()}|${suggestion.id}');
      await prefs.setStringList(_dismissedPrefsKey, fresh);
    } catch (e) {
      debugPrint('AdaptiveRoutineService.dismiss failed: $e');
    }
  }

  /// Applies a suggestion if Mood8 can do it automatically. Returns a
  /// human-readable confirmation string; null if applying isn't supported
  /// (e.g. the suggestion is just an observation).
  Future<String?> apply(AdaptiveSuggestion s) async {
    switch (s.actionType) {
      case AdaptiveActionType.moveRoutine:
        if (s.targetRoutineId == null ||
            s.newHour == null ||
            s.newMinute == null) {
          return null;
        }
        final all = _routines.getAllRoutines();
        final target = all.firstWhere(
          (r) => r.id == s.targetRoutineId,
          orElse: () => all.first,
        );
        target.time = DateTime(
          target.time.year,
          target.time.month,
          target.time.day,
          s.newHour!,
          s.newMinute!,
        );
        await _routines.updateRoutine(target);
        return 'Moved "${target.title}" to ${_fmtTime(s.newHour!, s.newMinute!)}.';
      case AdaptiveActionType.addRoutine:
        if (s.newHour == null) return null;
        await _routines.addRoutine(
          title: s.title.replaceAll(RegExp(r'^[A-Z][a-z]+ '), ''),
          time: DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
            s.newHour!,
            s.newMinute ?? 0,
          ),
          durationMinutes: 20,
          category: RoutineCategory.health,
          meta: s.reason,
        );
        return 'Added to your routine.';
      case AdaptiveActionType.addHabit:
      case AdaptiveActionType.simplify:
      case AdaptiveActionType.challenge:
        return null;
    }
  }

  // ─── Rules ────────────────────────────────────────────────────────────

  AdaptiveSuggestion? _ruleMorningSkips() {
    final today = _dayKey(DateTime.now());
    var skipped = 0;
    for (var i = 1; i <= 5; i++) {
      final date = today.subtract(Duration(days: i));
      final morning = _routines
          .getRoutinesForDate(date)
          .where((r) => r.time.hour >= 5 && r.time.hour <= 10)
          .toList();
      if (morning.isEmpty) continue;
      final done = morning.where((r) => r.isCompleted).length;
      if (done == 0) skipped += 1;
    }
    if (skipped < 3) return null;
    return AdaptiveSuggestion(
      id: 'morning_simplify',
      title: 'Simplify your morning to 5 minutes',
      reason:
          "You've skipped your morning routine $skipped days in a row. A shorter version is easier to start.",
      actionType: AdaptiveActionType.simplify,
      confidence: 0.75,
    );
  }

  AdaptiveSuggestion? _ruleAfternoonFocusDrop() {
    final tod = _analytics.getTimeOfDayPatterns(days: 14);
    final morning = tod[TimeOfDayBlock.morning];
    final afternoon = tod[TimeOfDayBlock.afternoon];
    if (morning == null || afternoon == null) return null;
    if (morning - afternoon < 1.2) return null;

    final candidates = _routines
        .getAllRoutines()
        .where((r) =>
            r.category == RoutineCategory.work &&
            r.time.hour >= 14 &&
            r.time.hour <= 17)
        .toList();
    if (candidates.isEmpty) return null;
    final target = candidates.first;
    return AdaptiveSuggestion(
      id: 'move_deep_work_${target.id}',
      title: 'Move "${target.title}" to 9–11 AM',
      reason:
          'Your focus drops ${(morning - afternoon).toStringAsFixed(1)} points by afternoon. Morning is your peak.',
      actionType: AdaptiveActionType.moveRoutine,
      confidence: 0.70,
      targetRoutineId: target.id,
      newHour: 9,
      newMinute: 30,
    );
  }

  AdaptiveSuggestion? _ruleAfternoonEnergyDip() {
    final today = _dayKey(DateTime.now());
    final samples = <double>[];
    for (var i = 0; i < 14; i++) {
      final date = today.subtract(Duration(days: i));
      final entries = _moods
          .getEntriesForDate(date)
          .where((e) =>
              e.timestamp.hour >= 13 && e.timestamp.hour <= 16)
          .toList();
      if (entries.isEmpty) continue;
      final avg =
          entries.map((e) => e.energy).reduce((a, b) => a + b) /
              entries.length;
      samples.add(avg);
    }
    if (samples.length < 4) return null;
    final avg = samples.reduce((a, b) => a + b) / samples.length;
    if (avg >= 5.0) return null;

    // No existing walk routine?
    final hasWalk = _routines.getAllRoutines().any((r) =>
        r.title.toLowerCase().contains('walk') ||
        r.title.toLowerCase().contains('sunlight'));
    if (hasWalk) return null;

    return AdaptiveSuggestion(
      id: 'add_afternoon_walk',
      title: 'Try a 10-minute walk at 2 PM',
      reason:
          'Energy averages ${avg.toStringAsFixed(1)}/10 in your afternoons. Sunlight + movement reliably lifts both.',
      actionType: AdaptiveActionType.addRoutine,
      confidence: 0.65,
      newHour: 14,
      newMinute: 0,
    );
  }

  AdaptiveSuggestion? _rulePerfectWeekChallenge() {
    final today = _dayKey(DateTime.now());
    var perfect = 0;
    for (var i = 1; i <= 7; i++) {
      final date = today.subtract(Duration(days: i));
      final routines = _routines.getRoutinesForDate(date);
      if (routines.isEmpty) continue;
      final done = routines.where((r) => r.isCompleted).length;
      if (done >= routines.length) perfect += 1;
    }
    if (perfect < 7) return null;
    return AdaptiveSuggestion(
      id: 'add_challenge_habit',
      title: 'Add a stretch habit — you\'re ready',
      reason:
          'You hit 100% routine completion 7 days running. Time to raise the bar.',
      actionType: AdaptiveActionType.challenge,
      confidence: 0.85,
    );
  }

  AdaptiveSuggestion? _ruleNoMorningRitual() {
    final hasMorning = _routines
        .getAllRoutines()
        .any((r) => r.time.hour >= 5 && r.time.hour <= 9);
    if (hasMorning) return null;

    final today = _dayKey(DateTime.now());
    var earlyCheckins = 0;
    for (var i = 0; i < 7; i++) {
      final date = today.subtract(Duration(days: i));
      final hasEarly = _moods
          .getEntriesForDate(date)
          .any((e) => e.timestamp.hour >= 6 && e.timestamp.hour <= 9);
      if (hasEarly) earlyCheckins += 1;
    }
    if (earlyCheckins < 3) return null;
    return AdaptiveSuggestion(
      id: 'create_morning_ritual',
      title: 'Create a 3-step morning ritual',
      reason:
          "You're checking in early — anchor that window with a short ritual to protect it.",
      actionType: AdaptiveActionType.addRoutine,
      confidence: 0.55,
      newHour: 7,
      newMinute: 0,
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────

  Future<Set<String>> _dismissedTodayIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_dismissedPrefsKey) ?? const <String>[];
      final today = _dayKey(DateTime.now()).toIso8601String();
      return raw
          .where((entry) => entry.startsWith('$today|'))
          .map((entry) => entry.split('|').last)
          .toSet();
    } catch (_) {
      return const {};
    }
  }

  static DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

  String _fmtTime(int hour, int minute) {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  // Kept for future rule keys that need uuids; uuid import stays alive.
  // ignore: unused_element
  String _newId() => _uuid.v4();
}
