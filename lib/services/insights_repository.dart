import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/insight.dart';
import '../models/insight_type.dart';
import 'database_service.dart';

class InsightsRepository {
  InsightsRepository({DatabaseService? db})
      : _db = db ?? DatabaseService.instance;

  final DatabaseService _db;

  Box<Insight> get _box => _db.insightBox;

  Future<void> saveInsight(Insight insight, {String? key}) async {
    try {
      await _box.put(key ?? insight.id, insight);
    } catch (e, st) {
      debugPrint('InsightsRepository.saveInsight failed: $e\n$st');
      rethrow;
    }
  }

  Future<void> saveAll(Map<String, Insight> insights) async {
    try {
      await _box.putAll(insights);
    } catch (e, st) {
      debugPrint('InsightsRepository.saveAll failed: $e\n$st');
      rethrow;
    }
  }

  List<Insight> getAllInsights() {
    return _box.values.toList()
      ..sort((a, b) => b.confidence.abs().compareTo(a.confidence.abs()));
  }

  List<Insight> getActiveInsights() =>
      getAllInsights().where((i) => !i.dismissed).toList();

  List<Insight> getInsightsByType(InsightType type) =>
      getActiveInsights().where((i) => i.type == type).toList();

  List<Insight> getInsightsByConfidence(double threshold) =>
      getActiveInsights()
          .where((i) => i.confidence.abs() >= threshold)
          .toList();

  Future<void> dismissInsight(String id) async {
    final keyToUpdate = _findKeyById(id);
    if (keyToUpdate == null) return;
    final item = _box.get(keyToUpdate);
    if (item == null) return;
    item.dismissed = true;
    await item.save();
  }

  Future<void> markActionTaken(String id) async {
    final keyToUpdate = _findKeyById(id);
    if (keyToUpdate == null) return;
    final item = _box.get(keyToUpdate);
    if (item == null) return;
    item.actionable = false;
    await item.save();
  }

  Future<void> clearOldInsights({Duration olderThan = const Duration(days: 30)}) async {
    final cutoff = DateTime.now().subtract(olderThan);
    final stale = <dynamic>[];
    for (final k in _box.keys) {
      final item = _box.get(k);
      if (item != null && item.discoveredAt.isBefore(cutoff)) {
        stale.add(k);
      }
    }
    if (stale.isNotEmpty) await _box.deleteAll(stale);
  }

  Future<void> clearAll() async => _box.clear();

  ValueListenable<Box<Insight>> watchInsights() => _box.listenable();

  Insight? mostRecent() {
    final all = _box.values.toList()
      ..sort((a, b) => b.discoveredAt.compareTo(a.discoveredAt));
    return all.isEmpty ? null : all.first;
  }

  dynamic _findKeyById(String id) {
    for (final k in _box.keys) {
      final item = _box.get(k);
      if (item != null && item.id == id) return k;
    }
    return null;
  }
}
