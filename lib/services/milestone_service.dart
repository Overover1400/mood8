import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/milestone.dart';

/// Watches simple counters (streaks, identity progress %) and surfaces a
/// [Milestone] the first time it crosses a threshold. Persists per-milestone
/// "already shown" flags so we don't celebrate the same 7-day streak twice.
class MilestoneService {
  MilestoneService._();
  static final MilestoneService _instance = MilestoneService._();
  factory MilestoneService() => _instance;

  /// Returns the milestone the user just crossed, or null if [streak] isn't a
  /// threshold day or it's already been shown. Marks it shown on success.
  Future<Milestone?> checkStreak(int streak) async {
    Milestone? hit;
    if (streak == 7) hit = Milestone.firstWeek;
    if (streak == 30) hit = Milestone.firstMonth;
    if (streak == 100) hit = Milestone.century;
    if (streak == 365) hit = Milestone.year;
    if (hit == null) return null;
    if (await _alreadyShown(hit.key())) return null;
    await _markShown(hit.key());
    return hit;
  }

  /// Identity progress in 0..1. Crosses 0.25 / 0.5 / 0.75 / 1.0 fire once
  /// each per identity.
  Future<Milestone?> checkIdentityProgress({
    required String identity,
    required double progress,
  }) async {
    Milestone? hit;
    if (progress >= 1.0) {
      hit = Milestone.identityComplete;
    } else if (progress >= 0.75) {
      hit = Milestone.identity75;
    } else if (progress >= 0.50) {
      hit = Milestone.identity50;
    } else if (progress >= 0.25) {
      hit = Milestone.identity25;
    }
    if (hit == null) return null;
    final key = hit.key(identity);
    if (await _alreadyShown(key)) return null;
    await _markShown(key);
    return hit;
  }

  Future<void> resetAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stale = prefs.getKeys()
          .where((k) => k.startsWith('mood8.milestone.'))
          .toList();
      for (final k in stale) {
        await prefs.remove(k);
      }
    } catch (e) {
      debugPrint('MilestoneService.resetAll failed: $e');
    }
  }

  Future<bool> _alreadyShown(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(key) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _markShown(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, true);
    } catch (e) {
      debugPrint('MilestoneService.markShown failed: $e');
    }
  }
}
