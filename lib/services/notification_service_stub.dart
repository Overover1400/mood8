// No-op implementation used on non-web platforms. Real local notifications
// for Android/iOS would require `flutter_local_notifications` + platform
// config; we ship this stub so the rest of the app can call the same API
// without breaking compilation.

class NotificationServiceImpl {
  bool get isSupported => false;
  bool get isGranted => false;

  Future<bool> requestPermission() async => false;

  Future<void> scheduleMorningCheckIn({
    required String name,
    required int hour,
    required int minute,
  }) async {}

  Future<void> scheduleEveningReflection({
    required int hour,
    required int minute,
  }) async {}

  Future<void> scheduleStreakWarning({required int hoursLeft}) async {}

  Future<void> scheduleHabitReminder({
    required String habitTitle,
    required int hour,
    required int minute,
  }) async {}

  Future<void> testNotification() async {}

  Future<void> showNow({required String title, required String body}) async {}

  Future<void> cancelAll() async {}
}

NotificationServiceImpl createNotificationServiceImpl() =>
    NotificationServiceImpl();
