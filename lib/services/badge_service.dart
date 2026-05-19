import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/badge_category.dart';
import '../models/earned_badge.dart';
import 'badge_definitions.dart';
import 'database_service.dart';
import 'habit_repository.dart';
import 'mood_repository.dart';
import 'routine_repository.dart';

/// Awards and tracks milestone badges. Badge **definitions** live in
/// [BadgeCatalog]; **earned records** live in Hive (typeId 17). The
/// existence of an EarnedBadge for a given key is the source of truth for
/// "already unlocked" — no parallel SharedPreferences flag.
class BadgeService {
  BadgeService._();
  static final BadgeService _instance = BadgeService._();
  factory BadgeService() => _instance;

  final Uuid _uuid = const Uuid();

  Box<EarnedBadge> get _box => DatabaseService.instance.badgeBox;

  // ─── Read API ─────────────────────────────────────────────────────────

  Future<List<EarnedBadge>> getEarnedBadges() async =>
      earnedBadgesSync();

  List<EarnedBadge> earnedBadgesSync() {
    final out = _box.values.toList()
      ..sort((a, b) => b.unlockedAt.compareTo(a.unlockedAt));
    return out;
  }

  Future<List<EarnedBadge>> getUnlockedToday() async {
    final today = _dayKey(DateTime.now());
    return _box.values
        .where((b) => _sameDay(_dayKey(b.unlockedAt), today))
        .toList()
      ..sort((a, b) => b.unlockedAt.compareTo(a.unlockedAt));
  }

  Future<bool> isUnlocked(String badgeKey) async => isUnlockedSync(badgeKey);

  bool isUnlockedSync(String badgeKey) {
    for (final b in _box.values) {
      if (b.badgeKey == badgeKey) return true;
    }
    return false;
  }

  ValueListenable<Box<EarnedBadge>> watch() => _box.listenable();

  int get earnedCount => _box.length;

  /// Returns progress for every badge in the catalog. Earned badges report
  /// 1.0; unearned badges report current_count / threshold (clamped).
  Future<Map<String, double>> getProgress() async {
    final counters = await _gatherCounters();
    final out = <String, double>{};
    for (final def in BadgeCatalog.all) {
      if (isUnlockedSync(def.key)) {
        out[def.key] = 1.0;
        continue;
      }
      final current = counters[def.category] ?? 0;
      out[def.key] = (current / def.threshold).clamp(0.0, 1.0);
    }
    return out;
  }

  /// Convenience for UI: current count for each category. Used by the
  /// detail view to show "12/30" style progress.
  Future<Map<BadgeCategory, int>> getCategoryCounters() => _gatherCounters();

  // ─── Award engine ─────────────────────────────────────────────────────

  /// Re-evaluates every catalog entry against the current data state.
  /// Persists any newly-met badges and returns them (so the caller can
  /// show the unlock modal). Already-earned badges are skipped silently.
  Future<List<EarnedBadge>> checkAndAwardBadges() async {
    final counters = await _gatherCounters();
    final newlyEarned = <EarnedBadge>[];
    final now = DateTime.now();

    for (final def in BadgeCatalog.all) {
      if (isUnlockedSync(def.key)) continue;
      final current = counters[def.category] ?? 0;
      if (current < def.threshold) continue;

      final earned = EarnedBadge(
        id: _uuid.v4(),
        badgeKey: def.key,
        title: def.title,
        description: def.description,
        iconCode: def.icon.codePoint,
        colorHex: def.gradientEnd.toARGB32(),
        unlockedAt: now,
        category: def.category,
      );
      try {
        await _box.put(earned.id, earned);
        newlyEarned.add(earned);
        debugPrint(
            '[BadgeService] 🏆 unlocked ${def.key} · ${def.title} (count=$current)');
      } catch (e, st) {
        debugPrint('[BadgeService] award failed for ${def.key}: $e\n$st');
      }
    }
    return newlyEarned;
  }

  /// Snapshot of "how many" for each category. Pure read against existing
  /// repositories — no side effects beyond the perfect-routine-day cache.
  Future<Map<BadgeCategory, int>> _gatherCounters() async {
    final db = DatabaseService.instance;
    final moods = MoodRepository();
    final habits = HabitRepository();
    final routines = RoutineRepository();

    // Streak: best of mood streak vs any habit streak.
    var streak = moods.calculateStreak();
    for (final h in habits.getActiveHabits()) {
      final s = habits.getStreakForHabit(h.id);
      if (s > streak) streak = s;
    }

    // Habit volume: total *completed* log entries across history.
    var habitCompletions = 0;
    for (final log in db.habitLogBox.values) {
      if (log.isCompleted) habitCompletions++;
    }

    final perfectDays = await _routinePerfectDays(routines: routines);
    final reflectionCount = db.reflectionBox.length;

    // Gratitude: count of *non-empty* daily entries.
    var gratitudeCount = 0;
    for (final e in db.gratitudeBox.values) {
      if (e.nonEmptyItems.isNotEmpty) gratitudeCount++;
    }

    return <BadgeCategory, int>{
      BadgeCategory.streak: streak,
      BadgeCategory.habit: habitCompletions,
      BadgeCategory.routine: perfectDays,
      BadgeCategory.identity: reflectionCount,
      BadgeCategory.gratitude: gratitudeCount,
    };
  }

  // ─── Perfect-routine-day cache ────────────────────────────────────────
  // RoutineItem stores only "today's" completion state — no historical
  // log. We persist a Set<isoDate> of "every routine done that day" so
  // the routine badges accumulate over time.

  static const String _kPerfectDayPrefKey = 'mood8.perfectRoutineDays';

  Future<int> _routinePerfectDays({required RoutineRepository routines}) async {
    final stored = await _loadPerfectDaySet();
    final todays = routines.getTodayRoutines();
    final allDone = todays.isNotEmpty && todays.every((r) => r.isCompleted);
    if (allDone) {
      final today = _dayKey(DateTime.now()).toIso8601String();
      if (!stored.contains(today)) {
        stored.add(today);
        await _savePerfectDaySet(stored);
      }
    }
    return stored.length;
  }

  /// Public hook for explicit callers ("I just completed the last routine") —
  /// idempotent, safe to call repeatedly.
  Future<void> recordPerfectRoutineDay() async {
    final stored = await _loadPerfectDaySet();
    final today = _dayKey(DateTime.now()).toIso8601String();
    if (stored.contains(today)) return;
    stored.add(today);
    await _savePerfectDaySet(stored);
  }

  Future<Set<String>> _loadPerfectDaySet() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(_kPerfectDayPrefKey) ?? const <String>[])
          .toSet();
    } catch (e) {
      debugPrint('[BadgeService] loadPerfectDaySet failed: $e');
      return <String>{};
    }
  }

  Future<void> _savePerfectDaySet(Set<String> set) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kPerfectDayPrefKey, set.toList());
    } catch (e) {
      debugPrint('[BadgeService] savePerfectDaySet failed: $e');
    }
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);
}
