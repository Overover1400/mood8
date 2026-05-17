import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/mood_entry.dart';
import 'database_service.dart';

class MoodRepository {
  MoodRepository({DatabaseService? db})
      : _db = db ?? DatabaseService.instance;

  final DatabaseService _db;
  final Uuid _uuid = const Uuid();

  Box<MoodEntry> get _box => _db.moodBox;

  Future<MoodEntry> addEntry({
    required double mood,
    required double energy,
    required double focus,
    String? note,
    DateTime? timestamp,
  }) async {
    final entry = MoodEntry(
      id: _uuid.v4(),
      timestamp: timestamp ?? DateTime.now(),
      mood: mood,
      energy: energy,
      focus: focus,
      note: note,
    );
    try {
      await _box.put(entry.id, entry);
    } catch (e, st) {
      debugPrint('MoodRepository.addEntry failed: $e\n$st');
      rethrow;
    }
    return entry;
  }

  List<MoodEntry> getAllEntries() {
    final list = _box.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  MoodEntry? getTodayEntry() {
    final now = DateTime.now();
    final entries = getEntriesForDate(now);
    if (entries.isEmpty) return null;
    return entries.first;
  }

  List<MoodEntry> getEntriesForDate(DateTime date) {
    return _box.values
        .where((e) => _sameDay(e.timestamp, date))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  int calculateStreak() {
    if (_box.isEmpty) return 0;
    final byDay = <DateTime>{
      for (final e in _box.values) _dayKey(e.timestamp),
    };
    var streak = 0;
    var cursor = _dayKey(DateTime.now());
    if (!byDay.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (!byDay.contains(cursor)) return 0;
    }
    while (byDay.contains(cursor)) {
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  Future<void> deleteEntry(String id) async {
    try {
      await _box.delete(id);
    } catch (e, st) {
      debugPrint('MoodRepository.deleteEntry failed: $e\n$st');
      rethrow;
    }
  }

  ValueListenable<Box<MoodEntry>> watchEntries() => _box.listenable();

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);
}
