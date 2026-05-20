import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/weekly_recap.dart';
import 'auth_service.dart';
import 'database_service.dart';
import 'gratitude_repository.dart';
import 'habit_repository.dart';
import 'intention_repository.dart';
import 'mood_repository.dart';
import 'reflection_repository.dart';
import 'routine_repository.dart';
import 'user_repository.dart';

/// Aggregated 7-day snapshot built client-side from Hive boxes. The
/// backend's `/api/recap/generate-and-send` consumes the JSON form.
class WeeklyRecapData {
  WeeklyRecapData({
    required this.weekStart,
    required this.weekEnd,
    required this.moodEntries,
    required this.habitCompletions,
    required this.perfectRoutineDays,
    required this.totalRoutineCompletions,
    required this.reflections,
    required this.intentions,
    required this.gratitudeItems,
    required this.identities,
  });

  final DateTime weekStart;
  final DateTime weekEnd;
  final List<Map<String, dynamic>> moodEntries;
  final List<Map<String, dynamic>> habitCompletions;
  final int perfectRoutineDays;
  final int totalRoutineCompletions;
  final List<String> reflections;
  final List<String> intentions;
  final List<String> gratitudeItems;
  final List<String> identities;

  /// True when nothing meaningful happened — recap isn't worth generating.
  bool get isEmpty =>
      moodEntries.isEmpty &&
      habitCompletions.isEmpty &&
      totalRoutineCompletions == 0 &&
      reflections.isEmpty &&
      intentions.isEmpty &&
      gratitudeItems.isEmpty;

  Map<String, dynamic> toJson({required bool sendEmail}) => {
        'week_start': weekStart.toIso8601String(),
        'week_end': weekEnd.toIso8601String(),
        'mood_entries': moodEntries,
        'habit_completions': habitCompletions,
        'routine_stats': {
          'perfect_days': perfectRoutineDays,
          'total_completed': totalRoutineCompletions,
        },
        'reflections': reflections,
        'intentions': intentions,
        'gratitude_items': gratitudeItems,
        'identities': identities,
        'send_email': sendEmail,
      };
}

class WeeklyRecapService {
  WeeklyRecapService._();
  static final WeeklyRecapService _instance = WeeklyRecapService._();
  factory WeeklyRecapService() => _instance;

  static const String _baseUrl = 'https://mood8.app/api';
  static const Duration _timeout = Duration(seconds: 60);

  final http.Client _client = http.Client();

  Box<WeeklyRecap> get _box => DatabaseService.instance.weeklyRecapBox;

  ValueListenable<Box<WeeklyRecap>> watch() => _box.listenable();

  // ─── Gather ──────────────────────────────────────────────────────────

  /// Reads every relevant box and rolls the last 7 days into a single
  /// payload. Pure client-side — no network.
  Future<WeeklyRecapData> gatherWeeklyData() async {
    final now = DateTime.now();
    final weekEnd = DateTime(now.year, now.month, now.day, 23, 59);
    final weekStart = weekEnd.subtract(const Duration(days: 7));

    final user = UserRepository().getCurrentUser();
    final identities = List<String>.from(user?.identities ?? const <String>[]);

    final moods = MoodRepository();
    final moodEntries = <Map<String, dynamic>>[];
    for (var d = weekStart;
        !d.isAfter(weekEnd);
        d = d.add(const Duration(days: 1))) {
      final dayKey = DateTime(d.year, d.month, d.day);
      final entries = moods.getEntriesForDate(dayKey);
      if (entries.isEmpty) continue;
      final avg = entries
              .map((e) => e.averageScore)
              .reduce((a, b) => a + b) /
          entries.length;
      moodEntries.add({
        'date': dayKey.toIso8601String(),
        'score': double.parse(avg.toStringAsFixed(2)),
        'note': null,
      });
    }

    final habits = HabitRepository();
    final habitCompletions = <Map<String, dynamic>>[];
    for (final h in habits.getActiveHabits()) {
      final logs = habits.getLogsForHabit(
        h.id,
        from: weekStart,
        to: weekEnd,
      );
      final completedDays = logs.where((l) => l.isCompleted).length;
      if (completedDays == 0) continue;
      habitCompletions.add({
        'habit_name': h.title,
        'completed_days': completedDays,
        'streak': habits.getStreakForHabit(h.id),
      });
    }

    final routines = RoutineRepository();
    // Perfect-day count comes from the same SharedPreferences store the
    // BadgeService uses — kept in sync so both surfaces agree.
    final perfectDays = await _perfectDaysInRange(weekStart, weekEnd);
    // Today's completions are the only routine state Hive currently
    // exposes; use them as a proxy for the week's total.
    final routineToday = routines.getTodayRoutines();
    final routinesCompletedToday =
        routineToday.where((r) => r.isCompleted).length;
    final totalRoutineCompletions =
        // crude: perfect days × today's plan size + today's completed if
        // today isn't already counted as perfect. Better than 0.
        perfectDays * routineToday.length + routinesCompletedToday;

    final reflectionRepo = ReflectionRepository();
    final reflections = reflectionRepo
        .getReflectionsForLastDays(7)
        .map((r) => r.reflection)
        .where((s) => s.trim().isNotEmpty)
        .take(7)
        .toList();

    final intentionsRepo = IntentionRepository();
    final recentIntentions = <String>[];
    final intentions = await _safeRecentIntentions(intentionsRepo);
    for (final i in intentions) {
      if (i.wasSkipped) continue;
      final text = i.text.trim();
      if (text.isEmpty) continue;
      recentIntentions.add(text);
    }

    final gratitudeRepo = GratitudeRepository();
    final gratitudeItems = <String>[];
    final recent = await gratitudeRepo.getRecent(7);
    for (final entry in recent) {
      for (final item in entry.nonEmptyItems) {
        if (!gratitudeItems.contains(item)) {
          gratitudeItems.add(item);
        }
        if (gratitudeItems.length >= 12) break;
      }
      if (gratitudeItems.length >= 12) break;
    }

    return WeeklyRecapData(
      weekStart: weekStart,
      weekEnd: weekEnd,
      moodEntries: moodEntries,
      habitCompletions: habitCompletions,
      perfectRoutineDays: perfectDays,
      totalRoutineCompletions: totalRoutineCompletions,
      reflections: reflections,
      intentions: recentIntentions,
      gratitudeItems: gratitudeItems,
      identities: identities,
    );
  }

  Future<List<dynamic>> _safeRecentIntentions(
      IntentionRepository repo) async {
    try {
      // IntentionRepository doesn't expose a `getRecent` helper, so we
      // pull every entry from the box and filter ourselves.
      final box = DatabaseService.instance.intentionBox;
      final cutoff = DateTime.now().subtract(const Duration(days: 7));
      return box.values.where((i) => !i.date.isBefore(cutoff)).toList();
    } catch (_) {
      return const <dynamic>[];
    }
  }

  Future<int> _perfectDaysInRange(DateTime from, DateTime to) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored =
          prefs.getStringList('mood8.perfectRoutineDays') ?? const <String>[];
      var count = 0;
      for (final iso in stored) {
        final d = DateTime.tryParse(iso);
        if (d == null) continue;
        if (!d.isBefore(from) && !d.isAfter(to)) count++;
      }
      return count;
    } catch (_) {
      return 0;
    }
  }

  // ─── Cache ───────────────────────────────────────────────────────────

  /// Returns the most recent recap whose week brackets today, or null.
  WeeklyRecap? getCurrentWeeksRecap() {
    final now = DateTime.now();
    for (final r in _box.values) {
      if (!now.isBefore(r.weekStart) && !now.isAfter(r.weekEnd)) {
        return r;
      }
    }
    return null;
  }

  /// Sunday or Monday, AND no recap exists yet for this week.
  bool shouldShowRecapPrompt() {
    final now = DateTime.now();
    final weekday = now.weekday; // 1=Mon, 7=Sun
    if (weekday != DateTime.sunday && weekday != DateTime.monday) {
      return false;
    }
    return getCurrentWeeksRecap() == null;
  }

  static String _isoYearWeekKey(DateTime d) {
    // Cheap, robust week key (year-ordinal-of-week). DateTime in Dart
    // doesn't expose ISO week directly; we approximate via day-of-year/7.
    final dayOfYear = d.difference(DateTime(d.year, 1, 1)).inDays + 1;
    final week = (dayOfYear / 7).ceil();
    return '${d.year}-W${week.toString().padLeft(2, '0')}';
  }

  static String bannerDismissedPrefKey(DateTime when) {
    return 'recap_banner_dismissed_${_isoYearWeekKey(when)}';
  }

  // ─── Backend call ────────────────────────────────────────────────────

  /// POSTs gathered data, parses the AI response, persists locally.
  /// `sendEmail` defaults to true (matches spec). Returns null on failure.
  Future<WeeklyRecap?> generateAndSendRecap({
    bool sendEmail = true,
    WeeklyRecapData? prebuiltData,
  }) async {
    final token = AuthService().token;
    if (token == null || token.isEmpty) {
      debugPrint('[Recap] generateAndSendRecap: no auth token');
      return null;
    }
    final data = prebuiltData ?? await gatherWeeklyData();
    try {
      final res = await _client
          .post(
            Uri.parse('$_baseUrl/recap/generate-and-send'),
            headers: {
              'content-type': 'application/json',
              'authorization': 'Bearer $token',
            },
            body: jsonEncode(data.toJson(sendEmail: sendEmail)),
          )
          .timeout(_timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint(
            '[Recap] generate failed ${res.statusCode}: ${res.body}');
        return null;
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final recap = WeeklyRecap(
        id: '${body['recap_id']}',
        weekStart: data.weekStart,
        weekEnd: data.weekEnd,
        narrative: body['narrative'] as String? ?? '',
        patterns: (body['patterns'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const <String>[],
        lookingAhead: body['looking_ahead'] as String? ?? '',
        gratitudeThemes: (body['gratitude_themes'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const <String>[],
        moodSummary: _moodSummary(data),
        stats: {
          'mood_entries': data.moodEntries.length,
          'habits': data.habitCompletions
              .fold<int>(0, (acc, h) => acc + (h['completed_days'] as int)),
          'routines': data.totalRoutineCompletions,
          'perfect_days': data.perfectRoutineDays,
          'discipline': _discipline(data),
        },
        generatedAt: DateTime.now(),
        emailSent: body['email_sent'] as bool? ?? false,
      );
      await _box.put(recap.id, recap);
      debugPrint(
          '[Recap] saved ${recap.id} · email=${recap.emailSent}');
      return recap;
    } on TimeoutException {
      debugPrint('[Recap] generate timeout');
      return null;
    } catch (e) {
      debugPrint('[Recap] generate exception: $e');
      return null;
    }
  }

  String _moodSummary(WeeklyRecapData data) {
    if (data.moodEntries.isEmpty) return 'No mood data this week.';
    final scores = data.moodEntries
        .map((m) => (m['score'] as num?)?.toDouble() ?? 0)
        .toList();
    final avg = scores.reduce((a, b) => a + b) / scores.length;
    return 'Avg mood ${avg.toStringAsFixed(1)} / 10';
  }

  int _discipline(WeeklyRecapData data) {
    final habitTotal = data.habitCompletions
        .fold<int>(0, (acc, h) => acc + (h['completed_days'] as int));
    final routineTotal = data.totalRoutineCompletions;
    final expected = (7 + habitTotal + routineTotal).clamp(7, 9999);
    final v = ((habitTotal + routineTotal) / expected) * 100;
    return v.clamp(0, 100).round();
  }

  /// History sorted newest first.
  List<WeeklyRecap> getAll() {
    final out = _box.values.toList()
      ..sort((a, b) => b.weekStart.compareTo(a.weekStart));
    return out;
  }
}
