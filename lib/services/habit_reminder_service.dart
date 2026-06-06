import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/habit.dart';
import 'database_service.dart';
import 'notif_log.dart';
import 'notification_service.dart';

/// Per-habit reminder scheduling. Owns the conversion from the
/// `remindersEnabled` + `reminderMinutes` fields on each [Habit] to
/// OS-level scheduled notifications via [NotificationService].
///
/// Two design rules:
///
/// 1. Deterministic ids — the notification id for habit `h` at slot
///    `i` is [_idFor]`(h.id, i)`. Same habit + same slot = same id,
///    so a re-schedule or cancel is idempotent and never leaves
///    orphan notifications behind.
/// 2. A global "habit reminders" master switch persisted in
///    SharedPreferences via [globallyEnabled]. When the user flips
///    it off in Settings, [scheduleAll] cancels every per-habit slot
///    without touching each habit's `remindersEnabled` flag — so
///    flipping it back on restores their choices.
class HabitReminderService {
  HabitReminderService._();
  static final HabitReminderService _instance = HabitReminderService._();
  factory HabitReminderService() => _instance;

  static const String _kGlobalEnabledKey =
      'mood8.habitReminders.globalEnabled';

  Box<Habit> get _habitBox => DatabaseService.instance.habitBox;

  // ─── Global master switch ──────────────────────────────────────────────

  bool _globalCache = true;
  bool _globalLoaded = false;

  /// Read-side accessor. Returns the cached value (defaults true) until
  /// [loadGlobalSetting] resolves at boot.
  bool get globallyEnabled => _globalCache;

  Future<bool> loadGlobalSetting() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _globalCache = prefs.getBool(_kGlobalEnabledKey) ?? true;
    } catch (e) {
      NotifLog.log('habitReminders: loadGlobalSetting failed: $e');
    }
    _globalLoaded = true;
    return _globalCache;
  }

  Future<void> setGloballyEnabled(bool enabled) async {
    _globalCache = enabled;
    _globalLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kGlobalEnabledKey, enabled);
    } catch (e) {
      NotifLog.log('habitReminders: setGloballyEnabled persist failed: $e');
    }
    if (enabled) {
      await scheduleAll();
    } else {
      await cancelAll();
    }
  }

  // ─── Scheduling ────────────────────────────────────────────────────────

  /// Re-schedules notifications for every habit in the local box.
  /// Call this on app start, after the post-login sync pull, and
  /// after any change to a habit's reminder fields.
  Future<void> scheduleAll() async {
    if (!_globalLoaded) await loadGlobalSetting();
    if (!_globalCache) {
      NotifLog.log('habitReminders: master switch off — skipping schedule');
      return;
    }
    final notif = NotificationService();
    // CRITICAL: await init so isSupported/isGranted reflect the real
    // OS state. Without this the boot-time scheduleAll call used to
    // bail before doing anything because the cached defaults claimed
    // permission wasn't granted, even when it was.
    await notif.ensureInitialized();
    if (!notif.isSupported) {
      NotifLog.log('habitReminders: notifications unsupported on platform');
      return;
    }
    for (final h in _habitBox.values) {
      await _scheduleHabit(h);
    }
    NotifLog.log(
        'habitReminders: re-scheduled all habits (${_habitBox.length}) · '
        'granted=${notif.isGranted} exact=${notif.canExactAlarm}');
  }

  /// Re-schedule a single habit. Used by repos after an in-place
  /// edit AND by the sync codec after a pull writes a habit, so a
  /// reminder added on one device propagates to others.
  Future<void> rescheduleFor(Habit habit) async {
    if (!_globalLoaded) await loadGlobalSetting();
    if (!_globalCache) {
      // Master switch off — defensively cancel even though scheduleAll
      // already wiped everything.
      await _cancelHabit(habit);
      return;
    }
    await NotificationService().ensureInitialized();
    await _scheduleHabit(habit);
  }

  /// Cancel every scheduled per-habit slot. Doesn't touch the
  /// general (morning/evening/streak) notifications.
  Future<void> cancelAll() async {
    for (final h in _habitBox.values) {
      await _cancelHabit(h);
    }
  }

  Future<void> cancelFor(Habit habit) => _cancelHabit(habit);

  // ─── Internals ─────────────────────────────────────────────────────────

  Future<void> _scheduleHabit(Habit habit) async {
    // Always cancel the habit's existing slots first — if the user
    // dropped a slot or changed a time, we don't want a stale slot
    // firing in addition to the new one. The cancel range (32) is
    // generous enough for any reasonable counter habit while staying
    // a fixed cost.
    await _cancelHabit(habit);
    if (habit.isArchived) return;
    if (!habit.remindersEnabled) return;
    if (habit.reminderMinutes.isEmpty) return;
    final notif = NotificationService();
    // Permission state was refreshed by scheduleAll / rescheduleFor
    // via ensureInitialized — but defense-in-depth: if we're called
    // from a code path that didn't go through those, init now. Safe
    // and cheap (idempotent + single in-flight future).
    if (!notif.isInitialized) {
      await notif.ensureInitialized();
    }
    if (!notif.isGranted) {
      NotifLog.log(
          'habitReminders: permission not granted — skipping schedule '
          'for "${habit.title}"');
      return;
    }
    // Body copy — tuned to feel like Mood8, not a generic alarm.
    // Counter habits show the daily target as a soft anchor (live
    // count would require re-scheduling on every log, deferred to
    // v2). Yes/no habits get an identity-flavoured nudge.
    //
    // Reduce-mode (avoid) habits get a separate gentle copy so we
    // don't say "vote for who you are becoming" for a quit-smoking
    // habit, which would feel jarring.
    final hasNumericTarget =
        habit.targetValue != null && habit.habitType.name != 'yesNo';
    final unitPart = habit.targetUnit != null && habit.targetUnit!.isNotEmpty
        ? ' ${habit.targetUnit}'
        : '';
    final body = habit.isAvoid
        ? 'Pause. Notice. You can ride this one out.'
        : hasNumericTarget
            ? "Time to chip away at today's ${habit.targetValue}$unitPart."
            : 'A small vote for the version of you who shows up.';
    for (var i = 0; i < habit.reminderMinutes.length && i < 32; i++) {
      final m = habit.reminderMinutes[i];
      if (m < 0 || m >= 24 * 60) continue;
      final hour = m ~/ 60;
      final minute = m % 60;
      await notif.scheduleHabitReminderAt(
        id: _idFor(habit.id, i),
        hour: hour,
        minute: minute,
        title: '${habit.icon} ${habit.title}',
        body: body,
      );
    }
  }

  Future<void> _cancelHabit(Habit habit) async {
    final notif = NotificationService();
    for (var i = 0; i < 32; i++) {
      await notif.cancelById(_idFor(habit.id, i));
    }
  }

  /// Deterministic notification id from `(habitId, slotIndex)`. We use
  /// the lower 24 bits of habitId.hashCode so we have room to shift
  /// left by 5 (for up to 32 slots per habit) without overflowing
  /// Android's signed int32 id space. Same habit + same slot = same
  /// id, every time.
  int _idFor(String habitId, int slotIndex) {
    final base = (habitId.hashCode & 0x00ffffff) << 5;
    return base | (slotIndex & 0x1f);
  }
}
