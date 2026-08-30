import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/habit.dart';
import '../models/habit_type.dart';

/// Spec 9.1 — "bad day" mode.
///
/// Every habit has a floor: the smallest version that still counts.
/// When the morning check-in reports low energy or low mood (1–2 on the
/// five-point scale), the app offers the floor for that day instead of
/// the full target, and completing the floor **counts as completed** so
/// the streak survives.
///
/// Why this matters more than it looks: the standard abandonment
/// sequence in every habit app is hard day → miss → chain broken →
/// "I've already ruined it" → uninstall. The floor breaks that chain at
/// the first step.
///
/// Deliberately NOT a form field (spec 10.4). The floor is derived from
/// the habit, and the offer appears only on the days it is relevant.
class BadDayService {
  BadDayService._();
  static final BadDayService _instance = BadDayService._();
  factory BadDayService() => _instance;

  static const _kOfferedOn = 'bad_day_offered_on';
  static const _kAcceptedPrefix = 'bad_day_accepted_';

  /// A check-in value (0–1) at or below this is "low" — i.e. 1 or 2 on
  /// the five-point scale the user actually sees.
  static const double lowThreshold = 0.375;

  bool isBadDay({required double energy, required double mood}) =>
      energy <= lowThreshold || mood <= lowThreshold;

  /// The smallest version of [h] that still counts, as a short phrase.
  ///
  /// Countable and timed habits shrink to roughly a fifth of target
  /// (never below 1). Yes/no habits can't shrink numerically, so they
  /// get a "just start it" framing — which is the same idea: make the
  /// entry cost trivially small on a bad day.
  String floorLabel(Habit h) {
    final target = h.targetValue ?? 1;
    switch (h.habitType) {
      case HabitType.counter:
        final f = _floorValue(target);
        return '$f ${h.targetUnit ?? 'times'} instead of $target';
      case HabitType.duration:
        final f = _floorValue(target);
        return '$f min instead of $target';
      case HabitType.yesNo:
        return 'just start it — two minutes counts today';
    }
  }

  int floorValue(Habit h) => _floorValue(h.targetValue ?? 1);

  int _floorValue(int target) {
    if (target <= 1) return 1;
    final f = (target / 5).round();
    return f < 1 ? 1 : f;
  }

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Offer at most once per day, and only after a check-in that
  /// actually reported a low state.
  Future<bool> shouldOfferToday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_kOfferedOn) != _dayKey(DateTime.now());
    } catch (e) {
      debugPrint('[badDay] check failed: $e');
      return false;
    }
  }

  Future<void> markOffered() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kOfferedOn, _dayKey(DateTime.now()));
    } catch (_) {}
  }

  /// Remember that today is a floor day for this habit, so the habit
  /// card can show the reduced target instead of the full one.
  Future<void> acceptFloor(String habitId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          '$_kAcceptedPrefix$habitId', _dayKey(DateTime.now()));
    } catch (_) {}
  }

  Future<bool> isFloorDayFor(String habitId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('$_kAcceptedPrefix$habitId') ==
          _dayKey(DateTime.now());
    } catch (_) {
      return false;
    }
  }
}
