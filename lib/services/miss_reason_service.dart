import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/habit.dart';
import '../models/habit_log.dart';
import 'adaptation_service.dart';
import 'habit_repository.dart';

/// Spec 2.2, step 2 — ask *why* on the second miss.
///
/// The escalation is deliberately gentle:
///   1st miss  — silence. One miss is noise, not a pattern.
///   2nd miss  — one tap, fixed options, dismissible.
///   3rd miss  — the server proposes a concrete change (that's the
///               adaptation card; this service does not handle it).
///
/// Without this the engine has to guess the reason from behaviour
/// alone. One tap converts a guess into a fact, and the fact changes
/// which adjustment gets proposed.
class MissReasonService {
  MissReasonService._();
  static final MissReasonService _instance = MissReasonService._();
  factory MissReasonService() => _instance;

  static const _kAskedPrefix = 'miss_reason_asked_';
  static const _kLastAskedAny = 'miss_reason_last_any';
  static const int windowDays = 7;
  static const int missesBeforeAsking = 2;

  /// Never ask about the same habit more than once a fortnight, and
  /// never ask about anything more than once a day. Nagging is the
  /// failure mode this whole flow exists to avoid.
  static const int cooldownDaysPerHabit = 14;

  final HabitRepository _habits = HabitRepository();

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Misses in the trailing [windowDays], excluding today (the user may
  /// still do it) and any day before the habit existed.
  int missesFor(Habit h, Iterable<HabitLog> logs) {
    final done = <String>{};
    for (final l in logs) {
      if (l.habitId == h.id) done.add(_dayKey(l.date));
    }
    final today = DateTime.now();
    final createdDay = DateTime(
        h.createdAt.year, h.createdAt.month, h.createdAt.day);
    var misses = 0;
    for (var i = 1; i <= windowDays; i++) {
      final day = today.subtract(Duration(days: i));
      if (day.isBefore(createdDay)) continue;
      if (!h.isScheduledFor(day)) continue;
      if (!done.contains(_dayKey(day))) misses++;
    }
    return misses;
  }

  /// The habit worth asking about right now, or null. Returns at most
  /// one — a prompt about three habits at once is an interrogation.
  Future<Habit?> habitToAskAbout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayKey = _dayKey(DateTime.now());
      if (prefs.getString(_kLastAskedAny) == todayKey) return null;

      final logs = _habits.allLogs.toList(growable: false);
      final candidates = <Habit>[];
      for (final h in _habits.getActiveHabits()) {
        final m = missesFor(h, logs);
        // Exactly the second-miss band. At three the engine proposes a
        // fix instead, so asking again there would be redundant.
        if (m < missesBeforeAsking || m > missesBeforeAsking) continue;
        final asked = prefs.getString('$_kAskedPrefix${h.id}');
        if (asked != null) {
          final when = DateTime.tryParse(asked);
          if (when != null &&
              DateTime.now().difference(when).inDays <
                  cooldownDaysPerHabit) {
            continue;
          }
        }
        candidates.add(h);
      }
      if (candidates.isEmpty) return null;
      return candidates.first;
    } catch (e) {
      debugPrint('[missReason] scan failed: $e');
      return null;
    }
  }

  /// Record the answer locally (for cooldown) and send it to the
  /// engine. Called for a real answer AND for a skip, so a dismissed
  /// prompt doesn't come back tomorrow.
  Future<void> recordAnswer({
    required String habitId,
    String? reason,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          '$_kAskedPrefix$habitId', DateTime.now().toIso8601String());
      await prefs.setString(_kLastAskedAny, _dayKey(DateTime.now()));
    } catch (e) {
      debugPrint('[missReason] persist failed: $e');
    }
    if (reason != null) {
      await AdaptationService()
          .reportMissReason(habitId: habitId, reason: reason);
    }
  }
}
