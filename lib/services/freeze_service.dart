import 'package:flutter/foundation.dart';

import '../models/habit.dart';
import '../models/routine_item.dart';
import '../models/user_profile.dart';

/// Streak-freeze accounting. A freeze marks a specific date as "covered" so a
/// missed habit / routine doesn't break the streak.
///
/// Tier rules:
///   - Free:    1 freeze per Sunday, max 1 stored
///   - Premium: 1 freeze per Sunday, max 3 stored
class FreezeService {
  FreezeService._();
  static final FreezeService _instance = FreezeService._();
  factory FreezeService() => _instance;

  static const int freeMaxFreezes = 1;
  static const int premiumMaxFreezes = 3;

  int getMaxFreezes({bool isPremium = false}) =>
      isPremium ? premiumMaxFreezes : freeMaxFreezes;

  /// Add 1 freeze for every Sunday that has passed since
  /// [UserProfile.lastFreezeReplenish], capped at the tier's max.
  Future<void> checkAndReplenish(
    UserProfile profile, {
    bool isPremium = false,
  }) async {
    final now = DateTime.now();
    final last = profile.lastFreezeReplenish;

    if (last == null) {
      profile.lastFreezeReplenish = now;
      await profile.save();
      return;
    }

    if (now.difference(last).inDays < 7 && !_crossedSunday(last, now)) {
      return;
    }

    final sundaysPassed = _countSundaysBetween(last, now);
    if (sundaysPassed == 0) return;

    final max = getMaxFreezes(isPremium: isPremium);
    final next =
        (profile.freezesAvailable + sundaysPassed).clamp(0, max).toInt();
    debugPrint(
        '[FreezeService] replenish · +$sundaysPassed (cap $max) · ${profile.freezesAvailable} → $next');
    profile.freezesAvailable = next;
    profile.lastFreezeReplenish = now;
    await profile.save();
  }

  bool _crossedSunday(DateTime start, DateTime end) {
    DateTime d = DateTime(start.year, start.month, start.day)
        .add(const Duration(days: 1));
    final stop = DateTime(end.year, end.month, end.day);
    while (!d.isAfter(stop)) {
      if (d.weekday == DateTime.sunday) return true;
      d = d.add(const Duration(days: 1));
    }
    return false;
  }

  int _countSundaysBetween(DateTime start, DateTime end) {
    int count = 0;
    DateTime current = DateTime(start.year, start.month, start.day)
        .add(const Duration(days: 1));
    final stop = DateTime(end.year, end.month, end.day);
    while (!current.isAfter(stop)) {
      if (current.weekday == DateTime.sunday) count++;
      current = current.add(const Duration(days: 1));
    }
    return count;
  }

  Future<bool> freezeHabit(
    Habit habit,
    UserProfile profile,
    DateTime date,
  ) async {
    if (profile.freezesAvailable <= 0) return false;
    final d = DateTime(date.year, date.month, date.day);
    if (habit.isFrozenOn(d)) return false;

    habit.frozenDates.add(d);
    profile.freezesAvailable -= 1;
    profile.totalFreezesUsed += 1;
    await habit.save();
    await profile.save();
    debugPrint(
        '[FreezeService] froze habit ${habit.id} on $d · remaining=${profile.freezesAvailable}');
    return true;
  }

  Future<bool> freezeRoutine(
    RoutineItem routine,
    UserProfile profile,
    DateTime date,
  ) async {
    if (profile.freezesAvailable <= 0) return false;
    final d = DateTime(date.year, date.month, date.day);
    if (routine.isFrozenOn(d)) return false;

    routine.frozenDates.add(d);
    profile.freezesAvailable -= 1;
    profile.totalFreezesUsed += 1;
    await routine.save();
    await profile.save();
    debugPrint(
        '[FreezeService] froze routine ${routine.id} on $d · remaining=${profile.freezesAvailable}');
    return true;
  }

  bool canFreeze(UserProfile profile) => profile.freezesAvailable > 0;

  // ─── Session prompt gate ────────────────────────────────────────────────
  // Tracks which (kind, id, date) combinations have already been offered a
  // freeze prompt during this session, so we don't re-pester the user.

  final Set<String> _promptedThisSession = <String>{};

  bool wasPrompted({
    required String kind,
    required String id,
    required DateTime date,
  }) {
    final d = DateTime(date.year, date.month, date.day);
    return _promptedThisSession
        .contains('$kind|$id|${d.toIso8601String()}');
  }

  void markPrompted({
    required String kind,
    required String id,
    required DateTime date,
  }) {
    final d = DateTime(date.year, date.month, date.day);
    _promptedThisSession.add('$kind|$id|${d.toIso8601String()}');
  }
}
