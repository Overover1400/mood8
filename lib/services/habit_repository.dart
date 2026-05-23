import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/frequency.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';
import '../models/habit_polarity.dart';
import '../models/habit_type.dart';
import '../models/routine_category.dart';
import 'database_service.dart';
import 'sync_service.dart';

class HabitRepository {
  HabitRepository({DatabaseService? db})
      : _db = db ?? DatabaseService.instance;

  final DatabaseService _db;
  final Uuid _uuid = const Uuid();

  Box<Habit> get _habitBox => _db.habitBox;
  Box<HabitLog> get _logBox => _db.habitLogBox;

  // ─── Habits ───────────────────────────────────────────────────────────

  Future<Habit> addHabit({
    required String title,
    required String icon,
    required HabitType habitType,
    required String identity,
    required RoutineCategory category,
    required Frequency frequency,
    int? targetValue,
    String? targetUnit,
    String? description,
    List<int>? frequencyDays,
    int? color,
    int? sortOrder,
    HabitPolarity polarity = HabitPolarity.build,
    AvoidMode? avoidMode,
    int? avoidDurationDays,
  }) async {
    final habit = Habit(
      id: _uuid.v4(),
      title: title,
      icon: icon,
      habitType: habitType,
      identity: identity,
      category: category,
      frequency: frequency,
      color: color ?? category.color.toARGB32(),
      createdAt: DateTime.now(),
      description: description,
      targetValue: targetValue,
      targetUnit: targetUnit,
      frequencyDays: frequencyDays,
      sortOrder: sortOrder ?? _habitBox.length,
      updatedAt: DateTime.now(),
      polarity: polarity,
      avoidMode: avoidMode,
      avoidDurationDays: avoidDurationDays,
    );
    try {
      await _habitBox.put(habit.id, habit);
      SyncService().debouncedPush();
    } catch (e, st) {
      debugPrint('HabitRepository.addHabit failed: $e\n$st');
      rethrow;
    }
    return habit;
  }

  Future<void> updateHabit(Habit habit) async {
    try {
      habit.updatedAt = DateTime.now();
      await _habitBox.put(habit.id, habit);
      SyncService().debouncedPush();
    } catch (e, st) {
      debugPrint('HabitRepository.updateHabit failed: $e\n$st');
      rethrow;
    }
  }

  Future<void> deleteHabit(String id) async {
    try {
      // Tombstone the habit and every log that belongs to it BEFORE the
      // Hive delete so sync can propagate the soft-delete to other devices.
      await SyncService().recordTombstone('habit', id);
      await _habitBox.delete(id);
      final logsToDelete = _logBox.values
          .where((l) => l.habitId == id)
          .toList();
      for (final l in logsToDelete) {
        await SyncService().recordTombstone('habit_log', l.id);
      }
      if (logsToDelete.isNotEmpty) {
        await _logBox.deleteAll(logsToDelete.map((l) => l.id));
      }
      SyncService().debouncedPush();
    } catch (e, st) {
      debugPrint('HabitRepository.deleteHabit failed: $e\n$st');
      rethrow;
    }
  }

  Future<void> archiveHabit(String id) async {
    final h = _habitBox.get(id);
    if (h == null) return;
    h.isArchived = true;
    h.updatedAt = DateTime.now();
    await h.save();
    SyncService().debouncedPush();
  }

  List<Habit> getAllHabits() {
    return _habitBox.values.toList()
      ..sort((a, b) {
        final c = a.sortOrder.compareTo(b.sortOrder);
        if (c != 0) return c;
        return a.createdAt.compareTo(b.createdAt);
      });
  }

  List<Habit> getActiveHabits() =>
      getAllHabits().where((h) => !h.isArchived).toList();

  List<Habit> getHabitsForIdentity(String identity) =>
      getActiveHabits().where((h) => h.identity == identity).toList();

  List<Habit> getHabitsForDate(DateTime date) =>
      getActiveHabits().where((h) => h.isScheduledFor(date)).toList();

  Future<void> reorderHabits(int oldIndex, int newIndex) async {
    final list = getActiveHabits();
    if (oldIndex < 0 || oldIndex >= list.length) return;
    final adjustedNew = newIndex > oldIndex ? newIndex - 1 : newIndex;
    final moved = list.removeAt(oldIndex);
    list.insert(adjustedNew.clamp(0, list.length), moved);
    final now = DateTime.now();
    for (var i = 0; i < list.length; i++) {
      list[i].sortOrder = i;
      list[i].updatedAt = now;
      await list[i].save();
    }
    SyncService().debouncedPush();
  }

  ValueListenable<Box<Habit>> watchHabits() => _habitBox.listenable();
  ValueListenable<Box<HabitLog>> watchLogs() => _logBox.listenable();

  // ─── Logs ─────────────────────────────────────────────────────────────

  Future<HabitLog> logHabit({
    required String habitId,
    required int value,
    DateTime? date,
    String? note,
  }) async {
    final habit = _habitBox.get(habitId);
    final target = habit?.effectiveTarget ?? 1;
    final on = _dayKey(date ?? DateTime.now());

    final existing = _findLog(habitId, on);
    if (existing != null) {
      existing.value = value;
      existing.targetValue = target;
      existing.timestamp = DateTime.now();
      existing.updatedAt = DateTime.now();
      if (note != null) existing.note = note;
      // Round-trip through put() rather than HiveObject.save() so we
      // get the same write semantics as new logs — and follow with
      // an explicit flush() so the counter value survives the user
      // backgrounding the app immediately after a tap. Hive's
      // HiveObject.save() queues a disk write but doesn't guarantee
      // fsync — flush() does.
      await _logBox.put(existing.id, existing);
      await _logBox.flush();
      SyncService().debouncedPush();
      return existing;
    }

    final log = HabitLog(
      id: _uuid.v4(),
      habitId: habitId,
      date: on,
      value: value,
      targetValue: target,
      timestamp: DateTime.now(),
      note: note,
      updatedAt: DateTime.now(),
    );
    try {
      await _logBox.put(log.id, log);
      await _logBox.flush();
      SyncService().debouncedPush();
    } catch (e, st) {
      debugPrint('HabitRepository.logHabit failed: $e\n$st');
      rethrow;
    }
    return log;
  }

  Future<void> incrementLog({
    required String habitId,
    int by = 1,
    DateTime? date,
  }) async {
    final on = date ?? DateTime.now();
    final habit = _habitBox.get(habitId);
    final existing = _findLog(habitId, on);
    final current = existing?.value ?? 0;
    // Cap at effectiveTarget so duration / counter habits don't exceed
    // their target (e.g. 30/10m bug from mobile testing). Min stays at 0.
    final cap = habit?.effectiveTarget ?? (1 << 30);
    final next = (current + by).clamp(0, cap);
    if (next == current) return;
    await logHabit(habitId: habitId, value: next, date: on);
  }

  Future<void> toggleYesNoLog({
    required String habitId,
    DateTime? date,
  }) async {
    final on = date ?? DateTime.now();
    final existing = _findLog(habitId, on);
    final next = (existing?.value ?? 0) > 0 ? 0 : 1;
    await logHabit(habitId: habitId, value: next, date: on);
  }

  List<HabitLog> getLogsForHabit(
    String habitId, {
    DateTime? from,
    DateTime? to,
  }) {
    return _logBox.values.where((l) {
      if (l.habitId != habitId) return false;
      if (from != null && l.date.isBefore(_dayKey(from))) return false;
      if (to != null && l.date.isAfter(_dayKey(to))) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  HabitLog? getLogForDate(String habitId, DateTime date) =>
      _findLog(habitId, date);

  int getStreakForHabit(String habitId) {
    final habit = _habitBox.get(habitId);
    if (habit == null) return 0;
    final dayKeys = <DateTime>{
      for (final l in _logBox.values)
        if (l.habitId == habitId && l.isCompleted) _dayKey(l.date),
    };
    // A frozen day keeps the streak alive without a log.
    final frozenKeys = <DateTime>{
      for (final d in habit.frozenDates) _dayKey(d),
    };
    if (dayKeys.isEmpty && frozenKeys.isEmpty) return 0;
    bool counts(DateTime d) => dayKeys.contains(d) || frozenKeys.contains(d);

    var streak = 0;
    var cursor = _dayKey(DateTime.now());
    if (!counts(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (!counts(cursor)) return 0;
    }
    while (counts(cursor)) {
      // Frozen days protect but don't add to the visible streak number.
      if (dayKeys.contains(cursor)) streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  int getBestStreak(String habitId) {
    final dayKeys = <DateTime>{
      for (final l in _logBox.values)
        if (l.habitId == habitId && l.isCompleted) _dayKey(l.date),
    };
    if (dayKeys.isEmpty) return 0;
    final sorted = dayKeys.toList()..sort();
    var best = 1;
    var current = 1;
    for (var i = 1; i < sorted.length; i++) {
      final diff = sorted[i].difference(sorted[i - 1]).inDays;
      if (diff == 1) {
        current += 1;
        if (current > best) best = current;
      } else {
        current = 1;
      }
    }
    return best;
  }

  double getCompletionRate(String habitId, int days) {
    final habit = _habitBox.get(habitId);
    if (habit == null || days <= 0) return 0;
    final today = _dayKey(DateTime.now());
    var scheduled = 0;
    var completed = 0;
    for (var i = 0; i < days; i++) {
      final date = today.subtract(Duration(days: i));
      if (!habit.isScheduledFor(date)) continue;
      scheduled += 1;
      final log = _findLog(habitId, date);
      if (log != null && log.isCompleted) completed += 1;
    }
    if (scheduled == 0) return 0;
    return completed / scheduled;
  }

  List<HabitLog> getLast30Days(String habitId) {
    final cutoff = _dayKey(DateTime.now())
        .subtract(const Duration(days: 29));
    return getLogsForHabit(habitId, from: cutoff);
  }

  HabitLog? _findLog(String habitId, DateTime date) {
    final key = _dayKey(date);
    for (final l in _logBox.values) {
      if (l.habitId == habitId && _sameDay(l.date, key)) return l;
    }
    return null;
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);
}
