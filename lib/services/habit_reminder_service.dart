import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/habit.dart';
import 'database_service.dart';
import 'notif_log.dart';
import 'notification_service.dart';

/// Per-habit reminder scheduling, restored after the v1 cut for the
/// "final attempt" instrumentation pass.
///
/// Design (re-confirmed for this attempt):
///
/// 1. **Deterministic ids per slot.** The notification id for habit
///    `h` at slot index `i` is `(h.id.hashCode & 0x00ffffff) << 5 | i`.
///    Same habit + same slot = same id every time, so a re-schedule
///    or cancel is idempotent. Up to 32 slots per habit (counter
///    habits with hourly reminders).
/// 2. **Master switch persisted in SharedPreferences.** Flipping off
///    cancels every per-habit slot without touching each habit's
///    `remindersEnabled` field — flipping back on restores choices.
/// 3. **Daily repeat via `matchDateTimeComponents: time`.** The
///    plugin re-arms next-day after each fire. Exact mode required
///    for that re-arm to fire reliably; inexact is a fallback.
/// 4. **Permission state read AT schedule time** (via the
///    notification service's lazy ensureInitialized). Boot-time
///    scheduleAll would previously bail with cached `_granted=false`
///    on cold starts — fixed in NotificationService.
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

  Future<void> scheduleAll() async {
    if (!_globalLoaded) await loadGlobalSetting();
    if (!_globalCache) {
      NotifLog.log('habitReminders: master switch off — skipping schedule');
      return;
    }
    final notif = NotificationService();
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

  Future<void> rescheduleFor(Habit habit) async {
    if (!_globalLoaded) await loadGlobalSetting();
    if (!_globalCache) {
      await _cancelHabit(habit);
      return;
    }
    await NotificationService().ensureInitialized();
    await _scheduleHabit(habit);
  }

  Future<void> cancelAll() async {
    for (final h in _habitBox.values) {
      await _cancelHabit(h);
    }
  }

  Future<void> cancelFor(Habit habit) => _cancelHabit(habit);

  // ─── Internals ─────────────────────────────────────────────────────────

  Future<void> _scheduleHabit(Habit habit) async {
    await _cancelHabit(habit);
    if (habit.isArchived) return;
    if (!habit.remindersEnabled) return;
    if (habit.reminderMinutes.isEmpty) return;
    final notif = NotificationService();
    if (!notif.isInitialized) {
      await notif.ensureInitialized();
    }
    if (!notif.isGranted) {
      NotifLog.log(
          'habitReminders: permission not granted — skipping schedule '
          'for "${habit.title}"');
      return;
    }
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

  /// Deterministic notification id from `(habitId, slotIndex)`.
  /// 24-bit habit-hash + 5-bit slot index → fits in Android int32.
  int _idFor(String habitId, int slotIndex) {
    final base = (habitId.hashCode & 0x00ffffff) << 5;
    return base | (slotIndex & 0x1f);
  }
}
