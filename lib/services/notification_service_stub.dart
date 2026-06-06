// Mobile (Android + iOS) implementation. Uses flutter_local_notifications
// to schedule real OS-level notifications that survive app-close and
// device reboot. The conditional import in notification_service.dart
// picks notification_service_web.dart on dart.library.html targets, so
// this file is only compiled into mobile builds.
//
// Web compatibility: flutter_local_notifications 17+ ships a web no-op
// platform implementation, so even if this file were imported on web
// the package itself would not fail to compile — but we never hit
// that path because of the conditional import.

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationServiceImpl {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _supported = true;
  bool _granted = false;

  /// Stable Android notification channel for general Mood8 reminders
  /// (morning/evening/streak). Per-habit reminders use a separate
  /// channel so the user can mute one without the other from system
  /// settings.
  static const _generalChannel = AndroidNotificationChannel(
    'mood8_general',
    'Mood8 reminders',
    description: 'Morning, evening and streak nudges from Mood8.',
    importance: Importance.high,
  );

  static const _habitChannel = AndroidNotificationChannel(
    'mood8_habits',
    'Habit reminders',
    description: "Per-habit reminders you set on individual habits.",
    importance: Importance.high,
  );

  bool get isSupported => _supported;
  bool get isGranted => _granted;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    _initialized = true;
    try {
      tz_data.initializeTimeZones();
      try {
        final localName = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(localName));
      } catch (e) {
        debugPrint('[Notif] timezone lookup failed: $e — using UTC');
        tz.setLocalLocation(tz.UTC);
      }

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        const InitializationSettings(
            android: androidInit, iOS: darwinInit),
      );

      // Register channels once. Idempotent — Android merges by id.
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        await android.createNotificationChannel(_generalChannel);
        await android.createNotificationChannel(_habitChannel);
      }

      // Refresh permission cache without prompting — the actual prompt
      // fires from requestPermission() driven by user gesture.
      _granted = await _checkGranted();
    } catch (e, st) {
      debugPrint('[Notif] init failed: $e\n$st');
      _supported = false;
    }
  }

  Future<bool> _checkGranted() async {
    try {
      final status = await Permission.notification.status;
      return status.isGranted;
    } catch (e) {
      debugPrint('[Notif] permission status failed: $e');
      return false;
    }
  }

  Future<bool> requestPermission() async {
    await _ensureInit();
    if (!_supported) return false;
    try {
      // permission_handler covers Android 13+ POST_NOTIFICATIONS AND
      // iOS in one call. flutter_local_notifications has its own iOS
      // path too — we fall through to that as a backup so we don't
      // silently fail on platforms permission_handler doesn't cover.
      final status = await Permission.notification.request();
      if (status.isGranted) {
        _granted = true;
        return true;
      }
      // iOS-specific request as a fallback.
      final iOS = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final iosGranted = await iOS?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
      _granted = iosGranted;
      return iosGranted;
    } catch (e, st) {
      debugPrint('[Notif] requestPermission failed: $e\n$st');
      return false;
    }
  }

  // ─── Scheduling ────────────────────────────────────────────────────────

  Future<void> scheduleMorningCheckIn({
    required String name,
    required int hour,
    required int minute,
  }) async {
    await _scheduleDaily(
      id: 100001,
      hour: hour,
      minute: minute,
      title: 'Good morning, $name ✨',
      body: 'How are you today?',
      channel: _generalChannel,
    );
  }

  Future<void> scheduleEveningReflection({
    required int hour,
    required int minute,
  }) async {
    await _scheduleDaily(
      id: 100002,
      hour: hour,
      minute: minute,
      title: "Tonight's reflection is ready 💫",
      body: 'Take 30 seconds with Mood8.',
      channel: _generalChannel,
    );
  }

  Future<void> scheduleStreakWarning({required int hoursLeft}) async {
    await _ensureInit();
    if (!_granted) return;
    try {
      final when =
          tz.TZDateTime.now(tz.local).add(Duration(hours: hoursLeft.clamp(1, 23)));
      await _plugin.zonedSchedule(
        100003,
        '🔥 Your streak ends soon',
        'Log a quick check-in to keep it alive.',
        when,
        _notifDetails(_generalChannel),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('[Notif] streak warning schedule failed: $e');
    }
  }

  Future<void> scheduleHabitReminder({
    required String habitTitle,
    required int hour,
    required int minute,
  }) async {
    // Legacy entry-point kept for the existing settings screen call
    // sites. Per-habit reminders managed by HabitReminderService use
    // [scheduleHabitReminderAt] with deterministic IDs so they can
    // be cancelled individually.
    await _scheduleDaily(
      id: 100004,
      hour: hour,
      minute: minute,
      title: 'Time for $habitTitle',
      body: 'A small vote for who you are becoming.',
      channel: _habitChannel,
    );
  }

  /// Schedules a daily-repeating notification at [hour]:[minute] under
  /// the given [id]. Used by HabitReminderService — caller picks a
  /// deterministic id so cancel() can target it. Idempotent: a fresh
  /// call with the same id replaces the previous schedule.
  Future<void> scheduleHabitReminderAt({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    await _scheduleDaily(
      id: id,
      hour: hour,
      minute: minute,
      title: title,
      body: body,
      channel: _habitChannel,
    );
  }

  Future<void> cancelById(int id) async {
    await _ensureInit();
    try {
      await _plugin.cancel(id);
    } catch (e) {
      debugPrint('[Notif] cancelById($id) failed: $e');
    }
  }

  Future<void> testNotification() async {
    await _ensureInit();
    if (!_granted) {
      final ok = await requestPermission();
      if (!ok) return;
    }
    await showNow(
      title: 'Mood8 test notification ✨',
      body: "You're wired up.",
    );
  }

  Future<void> showNow({required String title, required String body}) async {
    await _ensureInit();
    if (!_granted) return;
    try {
      await _plugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000 & 0x7fffffff,
        title,
        body,
        _notifDetails(_generalChannel),
      );
    } catch (e) {
      debugPrint('[Notif] showNow failed: $e');
    }
  }

  Future<void> cancelAll() async {
    await _ensureInit();
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('[Notif] cancelAll failed: $e');
    }
  }

  // ─── internals ────────────────────────────────────────────────────────

  Future<void> _scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
    required AndroidNotificationChannel channel,
  }) async {
    await _ensureInit();
    if (!_supported) return;
    // We don't gate on _granted here — caller is expected to have
    // requested permission already. If they haven't, the platform
    // silently drops the schedule, which is fine: a later
    // requestPermission() + reschedule will recover.
    final when = _nextInstanceOf(hour, minute);
    try {
      // Cancel any existing schedule under this id first to keep
      // re-runs idempotent.
      await _plugin.cancel(id);
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        _notifDetails(channel),
        // inexactAllowWhileIdle: doze-mode-friendly, doesn't need the
        // SCHEDULE_EXACT_ALARM permission. We accept up to ~15 min
        // jitter on aggressive battery-saving OEMs in exchange for
        // working out-of-the-box on every Android 12+ device.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      debugPrint(
          '[Notif] scheduled id=$id @ $hour:$minute (next $when) "$title"');
    } catch (e, st) {
      debugPrint('[Notif] _scheduleDaily id=$id failed: $e\n$st');
    }
  }

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  NotificationDetails _notifDetails(AndroidNotificationChannel channel) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }
}

NotificationServiceImpl createNotificationServiceImpl() =>
    NotificationServiceImpl();
