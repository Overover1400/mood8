import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/routine_category.dart';
import '../models/routine_item.dart';
import 'database_service.dart';

class RoutineRepository {
  RoutineRepository({DatabaseService? db})
      : _db = db ?? DatabaseService.instance;

  final DatabaseService _db;
  final Uuid _uuid = const Uuid();

  Box<RoutineItem> get _box => _db.routineBox;

  Future<RoutineItem> addRoutine({
    required String title,
    required DateTime time,
    required int durationMinutes,
    required RoutineCategory category,
    required String meta,
    int? sortOrder,
  }) async {
    final item = RoutineItem(
      id: _uuid.v4(),
      title: title,
      time: time,
      durationMinutes: durationMinutes,
      category: category,
      meta: meta,
      sortOrder: sortOrder ?? _box.length,
    );
    try {
      await _box.put(item.id, item);
      debugPrint(
          'RoutineRepository.addRoutine: "${item.title}" stored; box.length=${_box.length}');
    } catch (e, st) {
      debugPrint('RoutineRepository.addRoutine failed: $e\n$st');
      rethrow;
    }
    return item;
  }

  Future<void> updateRoutine(RoutineItem item) async {
    try {
      await _box.put(item.id, item);
    } catch (e, st) {
      debugPrint('RoutineRepository.updateRoutine failed: $e\n$st');
      rethrow;
    }
  }

  Future<void> deleteRoutine(String id) async {
    try {
      await _box.delete(id);
    } catch (e, st) {
      debugPrint('RoutineRepository.deleteRoutine failed: $e\n$st');
      rethrow;
    }
  }

  List<RoutineItem> getAllRoutines() {
    return _box.values.toList()
      ..sort((a, b) {
        final c = a.sortOrder.compareTo(b.sortOrder);
        if (c != 0) return c;
        return a.time.compareTo(b.time);
      });
  }

  List<RoutineItem> getTodayRoutines() {
    return getAllRoutines()..sort((a, b) => a.time.compareTo(b.time));
  }

  RoutineItem? getCurrentRoutine() {
    final now = DateTime.now();
    final today = getTodayRoutines();
    if (today.isEmpty) return null;

    for (final r in today) {
      final start = _todayAt(r.time);
      final end = start.add(Duration(minutes: r.durationMinutes));
      if (!now.isBefore(start) && now.isBefore(end)) {
        return r;
      }
    }
    for (final r in today) {
      final start = _todayAt(r.time);
      if (start.isAfter(now) && !r.isCompleted) return r;
    }
    return null;
  }

  Future<void> markComplete(String id) async {
    final item = _box.get(id);
    if (item == null) return;
    item.isCompleted = true;
    item.completedAt = DateTime.now();
    try {
      await item.save();
    } catch (e, st) {
      debugPrint('RoutineRepository.markComplete failed: $e\n$st');
      rethrow;
    }
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final items = getAllRoutines();
    if (oldIndex < 0 || oldIndex >= items.length) return;
    final adjustedNew = newIndex > oldIndex ? newIndex - 1 : newIndex;
    final moved = items.removeAt(oldIndex);
    items.insert(adjustedNew.clamp(0, items.length), moved);
    for (var i = 0; i < items.length; i++) {
      items[i].sortOrder = i;
      await items[i].save();
    }
  }

  ValueListenable<Box<RoutineItem>> watchRoutines() => _box.listenable();

  List<RoutineItem> getRoutinesForDate(DateTime date) {
    return getAllRoutines()..sort((a, b) => a.time.compareTo(b.time));
  }

  double getCompletionPercentage(DateTime date) {
    final items = getRoutinesForDate(date);
    if (items.isEmpty) return 0;
    final isToday = _sameDay(date, DateTime.now());
    if (!isToday) return 0;
    final done = items.where((r) => r.isCompleted).length;
    return done / items.length;
  }

  List<RoutineItem> filterByCategory(RoutineCategory category) {
    return getAllRoutines().where((r) => r.category == category).toList();
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> seedDefaultRoutines() async {
    if (_box.isNotEmpty) return;
    final now = DateTime.now();
    DateTime at(int h, int m) =>
        DateTime(now.year, now.month, now.day, h, m);

    final defaults = <RoutineItem>[
      RoutineItem(
        id: _uuid.v4(),
        title: 'Morning reset',
        time: at(7, 30),
        durationMinutes: 20,
        category: RoutineCategory.mindful,
        meta: '20 min · Set intention',
        sortOrder: 0,
      ),
      RoutineItem(
        id: _uuid.v4(),
        title: 'Deep work block',
        time: at(9, 30),
        durationMinutes: 90,
        category: RoutineCategory.work,
        meta: '90 min · Peak focus',
        sortOrder: 1,
      ),
      RoutineItem(
        id: _uuid.v4(),
        title: 'Walk & sunlight',
        time: at(13, 0),
        durationMinutes: 20,
        category: RoutineCategory.health,
        meta: '20 min · Zone 2',
        sortOrder: 2,
      ),
      RoutineItem(
        id: _uuid.v4(),
        title: 'Creative session',
        time: at(16, 0),
        durationMinutes: 45,
        category: RoutineCategory.creative,
        meta: '45 min · Make something',
        sortOrder: 3,
      ),
      RoutineItem(
        id: _uuid.v4(),
        title: 'Evening reset',
        time: at(21, 0),
        durationMinutes: 30,
        category: RoutineCategory.rest,
        meta: 'Journal · stretch · plan',
        sortOrder: 4,
      ),
    ];

    final entries = {for (final r in defaults) r.id: r};
    try {
      await _box.putAll(entries);
    } catch (e, st) {
      debugPrint('RoutineRepository.seedDefaultRoutines failed: $e\n$st');
      rethrow;
    }
  }

  static DateTime _todayAt(DateTime t) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, t.hour, t.minute);
  }
}
