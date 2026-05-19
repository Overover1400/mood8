import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/morning_intention.dart';
import 'database_service.dart';

class IntentionRepository {
  IntentionRepository({DatabaseService? db})
      : _db = db ?? DatabaseService.instance;

  final DatabaseService _db;
  final Uuid _uuid = const Uuid();

  Box<MorningIntention> get _box => _db.intentionBox;

  MorningIntention? getTodaysIntention() {
    final today = _dayKey(DateTime.now());
    for (final i in _box.values) {
      if (_sameDay(i.date, today)) return i;
    }
    return null;
  }

  bool hasSetTodaysIntention() => getTodaysIntention() != null;

  /// Returns true if a non-skipped intention exists for today.
  bool hasActiveIntentionToday() {
    final i = getTodaysIntention();
    return i != null && !i.wasSkipped && i.text.trim().isNotEmpty;
  }

  Future<MorningIntention> saveIntention(String text) async {
    final trimmed = text.trim();
    return _upsert(text: trimmed, skipped: false);
  }

  Future<MorningIntention> skipToday() async {
    return _upsert(text: '', skipped: true);
  }

  Future<MorningIntention> _upsert({
    required String text,
    required bool skipped,
  }) async {
    final now = DateTime.now();
    final today = _dayKey(now);
    final existing = getTodaysIntention();
    final entry = existing ??
        MorningIntention(
          id: _uuid.v4(),
          date: today,
          text: text,
          createdAt: now,
        );
    entry.date = today;
    entry.text = text;
    entry.wasSkipped = skipped;
    // Keep first createdAt — only set on brand-new.
    if (existing == null) entry.createdAt = now;
    try {
      await _box.put(entry.id, entry);
    } catch (e, st) {
      debugPrint('IntentionRepository._upsert failed: $e\n$st');
      rethrow;
    }
    return entry;
  }

  Future<List<MorningIntention>> getRecent(int days) async {
    final cutoff = _dayKey(DateTime.now().subtract(Duration(days: days)));
    final out = _box.values
        .where((i) => !i.date.isBefore(cutoff))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return out;
  }

  ValueListenable<Box<MorningIntention>> watchIntentions() =>
      _box.listenable();

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);
}
