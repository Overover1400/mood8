import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/gratitude_entry.dart';
import 'database_service.dart';
import 'sync_service.dart';

class GratitudeRepository {
  GratitudeRepository({DatabaseService? db})
      : _db = db ?? DatabaseService.instance;

  final DatabaseService _db;
  final Uuid _uuid = const Uuid();

  Box<GratitudeEntry> get _box => _db.gratitudeBox;

  /// One-shot migration that undoes the historical UTC-shift bug in
  /// the sync codec — see `_HabitLogCodec` for the full diagnosis.
  /// Any GratitudeEntry whose `date` is UTC-flagged OR has a non-zero
  /// time component (the fingerprint of a pulled row) gets snapped
  /// back to its LOCAL calendar day. Safe to call on every cold start.
  Future<void> repairCorruptedDates() async {
    var repaired = 0;
    for (final e in _box.values.toList()) {
      final d = e.date;
      if (d.isUtc ||
          d.hour != 0 ||
          d.minute != 0 ||
          d.second != 0 ||
          d.millisecond != 0) {
        final local = d.isUtc ? d.toLocal() : d;
        e.date = DateTime(local.year, local.month, local.day);
        await _box.put(e.id, e);
        repaired += 1;
      }
    }
    if (repaired > 0) {
      debugPrint('[Gratitude] repaired $repaired UTC-shifted date(s)');
    }
  }

  GratitudeEntry? getTodaysEntry() {
    final today = _dayKey(DateTime.now());
    for (final e in _box.values) {
      if (_sameDay(e.date, today)) return e;
    }
    return null;
  }

  bool hasLoggedToday() {
    final e = getTodaysEntry();
    return e != null && e.nonEmptyItems.isNotEmpty;
  }

  Future<GratitudeEntry> saveEntry(List<String> items) async {
    final now = DateTime.now();
    final today = _dayKey(now);
    final existing = getTodaysEntry();
    final entry = existing ??
        GratitudeEntry(
          id: _uuid.v4(),
          date: today,
          items: items,
          createdAt: now,
        );
    entry.date = today;
    // Reuse the model's normalization (trim, cap at 3, pad to 3 slots).
    entry.items = GratitudeEntry(
      id: entry.id,
      date: today,
      items: items,
      createdAt: now,
    ).items;
    if (existing == null) entry.createdAt = now;
    entry.updatedAt = now;
    try {
      await _box.put(entry.id, entry);
      SyncService().debouncedPush();
    } catch (e, st) {
      debugPrint('GratitudeRepository.saveEntry failed: $e\n$st');
      rethrow;
    }
    return entry;
  }

  Future<List<GratitudeEntry>> getRecent(int days) async {
    final cutoff = _dayKey(DateTime.now().subtract(Duration(days: days)));
    final out = _box.values
        .where((e) => !e.date.isBefore(cutoff))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return out;
  }

  /// Consecutive days (ending today or yesterday) with at least one
  /// non-empty gratitude item. Async signature is kept for API symmetry —
  /// the computation itself is synchronous (see [currentStreakSync]).
  Future<int> getCurrentStreak() async => currentStreakSync();

  /// Synchronous variant of [getCurrentStreak] for use inside `build`.
  int currentStreakSync() {
    final dayKeys = <DateTime>{
      for (final e in _box.values)
        if (e.nonEmptyItems.isNotEmpty) _dayKey(e.date),
    };
    if (dayKeys.isEmpty) return 0;
    var cursor = _dayKey(DateTime.now());
    if (!dayKeys.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (!dayKeys.contains(cursor)) return 0;
    }
    var streak = 0;
    while (dayKeys.contains(cursor)) {
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  int countThisMonth() {
    final now = DateTime.now();
    var count = 0;
    for (final e in _box.values) {
      if (e.date.year == now.year &&
          e.date.month == now.month &&
          e.nonEmptyItems.isNotEmpty) {
        count++;
      }
    }
    return count;
  }

  ValueListenable<Box<GratitudeEntry>> watchEntries() => _box.listenable();

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);
}
