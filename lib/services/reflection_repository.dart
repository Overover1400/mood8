import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/reflection.dart';
import 'database_service.dart';

class ReflectionRepository {
  ReflectionRepository({DatabaseService? db})
      : _db = db ?? DatabaseService.instance;

  final DatabaseService _db;
  final Uuid _uuid = const Uuid();

  Box<Reflection> get _box => _db.reflectionBox;

  Future<Reflection> saveReflection({
    required String text,
    String? suggestion,
    Map<String, double>? identityScores,
    DateTime? date,
  }) async {
    final on = date ?? DateTime.now();
    final dayKey = _dayKey(on);
    final existing = _box.values.firstWhere(
      (r) => _sameDay(r.date, on),
      orElse: () => Reflection(
        id: _uuid.v4(),
        date: dayKey,
        reflection: text,
        generatedAt: DateTime.now(),
      ),
    );

    existing.date = dayKey;
    existing.reflection = text;
    existing.suggestion = suggestion;
    existing.identityScores = identityScores;
    existing.generatedAt = DateTime.now();

    try {
      await _box.put(existing.id, existing);
    } catch (e, st) {
      debugPrint('ReflectionRepository.saveReflection failed: $e\n$st');
      rethrow;
    }
    return existing;
  }

  Reflection? getTodayReflection() {
    final now = DateTime.now();
    for (final r in _box.values) {
      if (_sameDay(r.date, now)) return r;
    }
    return null;
  }

  List<Reflection> getReflectionsForLastDays(int days) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return _box.values.where((r) => r.date.isAfter(cutoff)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  ValueListenable<Box<Reflection>> watchReflections() => _box.listenable();

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);
}
