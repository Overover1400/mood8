import 'notification_service_stub.dart'
    if (dart.library.html) 'notification_service_web.dart';

/// Cross-platform notification facade. On web it backs onto the browser's
/// `Notification` API (see `notification_service_web.dart`). On all other
/// platforms it's a no-op stub today — wire `flutter_local_notifications`
/// in `notification_service_stub.dart` when you're ready to ship mobile
/// reminders.
class NotificationService {
  NotificationService._() : _impl = createNotificationServiceImpl();
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;

  final NotificationServiceImpl _impl;

  bool get isSupported => _impl.isSupported;
  bool get isGranted => _impl.isGranted;

  Future<bool> requestPermission() => _impl.requestPermission();

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

  Future<void> testNotification() => _impl.testNotification();

  Future<void> cancelAll() => _impl.cancelAll();

  /// Low-level: push a notification right now. Used by [ReminderService] to
  /// fire smart reminders after consulting quiet-hours / smart-skip rules.
  Future<void> showNow({required String title, required String body}) =>
      _impl.showNow(title: title, body: body);
}
