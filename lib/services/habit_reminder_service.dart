import 'package:shared_preferences/shared_preferences.dart';

import '../models/habit.dart';
import 'notif_log.dart';
import 'notification_service.dart';

/// **v1 cut.** Per-habit reminders are disabled — three attempts could
/// not make scheduled notifications fire reliably across Android OEMs
/// (Xiaomi/Samsung/Huawei aggressively kill background scheduling, and
/// `matchDateTimeComponents` + inexact alarms doesn't survive on the
/// devices we tested). The feature is deferred to v2, where it needs
/// dedicated time and a real device matrix.
///
/// What this file does in v1:
///   • Every method is a no-op (keeps the call sites compiling and
///     gives v2 a single place to revive the feature without grepping
///     the codebase).
///   • [cancelV1Schedules] does a ONE-TIME, prefs-gated wipe of any
///     OS-side notifications that were queued by previous v1 attempts,
///     so users with stale schedules don't get late-arriving fires
///     after the feature was removed.
///
/// What's intentionally LEFT IN PLACE for v2 (and not touched here):
///   • flutter_local_notifications dependency (pubspec)
///   • Android manifest permissions + boot receivers
///   • Timezone init + notification channels (still registered)
///   • Habit model's `remindersEnabled` + `reminderMinutes` Hive
///     fields — keep persisting any v1 data so v2 doesn't have to
///     migrate
///
/// TODO(v2): re-enable habit reminders — see Mood8 v2 reminders work.
class HabitReminderService {
  HabitReminderService._();
  static final HabitReminderService _instance = HabitReminderService._();
  factory HabitReminderService() => _instance;

  static const String _kV1WipeDoneKey = 'mood8.reminders.v1Wiped';

  /// Always returns false — the master switch reads as off in v1 so
  /// no UI surfaces a "reminders are on" claim.
  bool get globallyEnabled => false;

  Future<bool> loadGlobalSetting() async => false;
  Future<void> setGloballyEnabled(bool enabled) async {}

  /// v1: no-op.
  Future<void> scheduleAll() async {}

  /// v1: no-op.
  Future<void> rescheduleFor(Habit habit) async {}

  /// v1: cancel any leftover slots. The bulk wipe in
  /// [cancelV1Schedules] covers this, but call sites that explicitly
  /// cancel a habit's slots (delete/archive flows) still work.
  Future<void> cancelAll() async {}

  Future<void> cancelFor(Habit habit) async {}

  /// One-time wipe of every notification flutter_local_notifications
  /// has queued — clears stale v1 schedules that would otherwise fire
  /// "Time to drink water!" days after the user uninstalled the
  /// reminder UI. Prefs-gated so it runs once per device, not on
  /// every boot (which would also wipe v2 schedules later).
  Future<void> cancelV1Schedules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kV1WipeDoneKey) == true) return;
      await NotificationService().ensureInitialized();
      await NotificationService().cancelAll();
      await prefs.setBool(_kV1WipeDoneKey, true);
      NotifLog.log('v1 cut: cancelled all queued reminders (one-time)');
    } catch (e) {
      NotifLog.log('v1 cut: cancelV1Schedules failed: $e');
    }
  }
}
