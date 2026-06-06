import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    show PendingNotificationRequest;

import 'notification_service_stub.dart'
    if (dart.library.html) 'notification_service_web.dart';

export 'notification_service_stub.dart'
    if (dart.library.html) 'notification_service_web.dart' show TestResult;

export 'package:flutter_local_notifications/flutter_local_notifications.dart'
    show PendingNotificationRequest;

/// Cross-platform notification facade. On web it backs onto the
/// browser's `Notification` API (see `notification_service_web.dart`).
/// On Android/iOS it wraps `flutter_local_notifications` — see
/// `notification_service_stub.dart`.
class NotificationService {
  NotificationService._() : _impl = createNotificationServiceImpl();
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;

  final NotificationServiceImpl _impl;

  /// Eagerly run the platform init. Call once from `main()` BEFORE any
  /// schedule code so the sync getters below ([isGranted], [isSupported],
  /// [canExactAlarm]) reflect the real OS state on the first frame.
  /// Skipping this used to cause every boot-time HabitReminderService
  /// schedule call to bail with `isGranted == false` (its cached default)
  /// even when the user had already granted permission in a prior
  /// session.
  Future<void> ensureInitialized() => _impl.ensureInitialized();

  /// Re-read the permission cache (call after returning from Settings).
  Future<void> refreshPermissionState() => _impl.refreshPermissionState();

  bool get isSupported => _impl.isSupported;
  bool get isGranted => _impl.isGranted;
  bool get canExactAlarm => _impl.canExactAlarm;
  bool get isInitialized => _impl.isInitialized;
  String get timezoneName => _impl.timezoneName;

  Future<bool> requestPermission() => _impl.requestPermission();

  /// Android 12+ special permission for exact alarms. Returns true if
  /// already granted (or not required); otherwise opens the system
  /// Settings page and returns the eventual state.
  Future<bool> requestExactAlarmPermission() =>
      _impl.requestExactAlarmPermission();

  /// Opens the Android "ignore battery optimizations" prompt for
  /// Mood8 — the single biggest reliability lever on aggressive
  /// OEMs.
  Future<bool> requestIgnoreBatteryOptimizations() =>
      _impl.requestIgnoreBatteryOptimizations();

  /// True when Mood8 is currently exempt from Android battery
  /// optimization.
  Future<bool> isIgnoringBatteryOptimizations() =>
      _impl.isIgnoringBatteryOptimizations();

  Future<void> scheduleMorningCheckIn({
    required String name,
    required int hour,
    required int minute,
  }) =>
      _impl.scheduleMorningCheckIn(name: name, hour: hour, minute: minute);

  Future<void> scheduleEveningReflection({
    required int hour,
    required int minute,
  }) =>
      _impl.scheduleEveningReflection(hour: hour, minute: minute);

  Future<void> scheduleStreakWarning({required int hoursLeft}) =>
      _impl.scheduleStreakWarning(hoursLeft: hoursLeft);

  Future<void> scheduleHabitReminder({
    required String habitTitle,
    required int hour,
    required int minute,
  }) =>
      _impl.scheduleHabitReminder(
          habitTitle: habitTitle, hour: hour, minute: minute);

  /// Schedules a daily-repeating per-habit reminder under a caller-
  /// supplied id (so cancelling the same id removes the slot — used
  /// by HabitReminderService when the user disables a habit reminder
  /// or edits its time).
  Future<void> scheduleHabitReminderAt({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) =>
      _impl.scheduleHabitReminderAt(
        id: id,
        hour: hour,
        minute: minute,
        title: title,
        body: body,
      );

  /// Cancels a single notification by id.
  Future<void> cancelById(int id) => _impl.cancelById(id);

  /// Schedules a one-shot zonedSchedule [delay] from now and returns
  /// a rich [TestResult] (success + mode + queued count + reason on
  /// failure) so the diagnostics UI can pinpoint where it broke.
  Future<TestResult> scheduleOneShotIn({
    required Duration delay,
    String title = 'Mood8 test reminder',
    String body = "If you see this, reminders work.",
  }) =>
      _impl.scheduleOneShotIn(delay: delay, title: title, body: body);

  /// Fires a notification IMMEDIATELY via _plugin.show() — bypasses
  /// the alarm scheduler. If THIS works but [scheduleOneShotIn]
  /// doesn't, the problem is scheduling/exact-alarm permission, not
  /// channel/icon/permission. Canary for the diagnostics screen.
  Future<TestResult> showNowDiagnostic({
    String title = 'Mood8 immediate test',
    String body = "If you see this, the notification path works.",
  }) =>
      _impl.showNowDiagnostic(title: title, body: body);

  /// Returns every notification currently queued in the OS — used by
  /// the test screen so a tester can confirm the schedule landed.
  Future<List<PendingNotificationRequest>> pendingRequests() =>
      _impl.pendingRequests();

  Future<void> testNotification() => _impl.testNotification();

  Future<void> cancelAll() => _impl.cancelAll();

  /// Low-level: push a notification right now. Used by [ReminderService] to
  /// fire smart reminders after consulting quiet-hours / smart-skip rules.
  Future<void> showNow({required String title, required String body}) =>
      _impl.showNow(title: title, body: body);
}
