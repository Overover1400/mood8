import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/mood_entry.dart';
import 'database_service.dart';
import 'sync_service.dart';

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
    String? partOfDay,
    double? dayRating,
  }) async {
    final entry = MoodEntry(
      id: _uuid.v4(),
      timestamp: timestamp ?? DateTime.now(),
      mood: mood,
      energy: energy,
      focus: focus,
      note: note,
      updatedAt: DateTime.now(),
      partOfDay: partOfDay,
      dayRating: dayRating,
    );
    try {
      await _box.put(entry.id, entry);
      SyncService().debouncedPush();
    } catch (e, st) {
      debugPrint('MoodRepository.addEntry failed: $e\n$st');
      rethrow;
    }
    return entry;
  }

  /// Auto-save semantics for the home check-in. Upserts within
  /// (today, [partOfDay]) rather than within today as a whole — spec 2.1
  /// needs morning and evening to survive as two distinct rows, because
  /// the adaptation engine's entire job is comparing them. Collapsing the
  /// day into one entry would silently destroy that signal.
  ///
  /// [partOfDay] defaults to whichever half of the day it currently is,
  /// so existing callers keep working and start producing split data.
  Future<MoodEntry> upsertTodayEntry({
    required double mood,
    required double energy,
    required double focus,
    String? partOfDay,
    double? dayRating,
  }) async {
    final part = partOfDay ?? currentPartOfDay();
    final existing = getTodayEntry(partOfDay: part);
    if (existing == null) {
      return addEntry(
        mood: mood,
        energy: energy,
        focus: focus,
        partOfDay: part,
        dayRating: dayRating,
      );
    }
    existing.mood = mood;
    existing.energy = energy;
    existing.focus = focus;
    existing.partOfDay = part;
    if (dayRating != null) existing.dayRating = dayRating;
    existing.updatedAt = DateTime.now();
    try {
      await _box.put(existing.id, existing);
      SyncService().debouncedPush();
    } catch (e, st) {
      debugPrint('MoodRepository.upsertTodayEntry failed: $e\n$st');
      rethrow;
    }
    return existing;
  }

  /// Morning until 16:00, evening after. A fixed boundary beats asking:
  /// the check-in has a 10-second budget (spec 6) and "which check-in is
  /// this?" is not a question worth one of those seconds.
  static String currentPartOfDay() =>
      DateTime.now().hour < 16 ? 'morning' : 'evening';

  List<MoodEntry> getAllEntries() {
    final list = _box.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  /// Today's most recent entry. Pass [partOfDay] to get that half of the
  /// day specifically; omit it for the old "latest today" behaviour that
  /// the header and streak code rely on.
  ///
  /// Entries written before spec 2.1 have a null partOfDay. Those are
  /// treated as morning so a user's history doesn't suddenly read as
  /// "no morning check-ins ever".
  MoodEntry? getTodayEntry({String? partOfDay}) {
    final now = DateTime.now();
    final entries = getEntriesForDate(now);
    if (entries.isEmpty) return null;
    if (partOfDay == null) return entries.first;
    for (final e in entries) {
      final part = e.partOfDay ?? 'morning';
      if (part == partOfDay) return e;
    }
    return null;
  }

  /// True once the user has logged both halves of today (spec 2.1).
  bool hasBothCheckinsToday() =>
      getTodayEntry(partOfDay: 'morning') != null &&
      getTodayEntry(partOfDay: 'evening') != null;

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
      await SyncService().recordTombstone('mood_entry', id);
      await _box.delete(id);
      SyncService().debouncedPush();
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
