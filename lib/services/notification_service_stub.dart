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

import 'dart:io' show Platform;

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
  /// In-flight init future — multiple callers calling [ensureInitialized]
  /// while the first one is still awaiting timezone lookup all share the
  /// same future instead of racing through `_ensureInit` in parallel
  /// (which would double-create channels and double-fetch the timezone).
  Future<void>? _initFuture;
  bool _supported = true;
  bool _granted = false;
  bool _canExactAlarm = false;

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
    description: 'Per-habit reminders you set on individual habits.',
    importance: Importance.high,
  );

  bool get isSupported => _supported;
  bool get isGranted => _granted;
  bool get canExactAlarm => _canExactAlarm;
  bool get isInitialized => _initialized;

  /// Public, awaitable initializer. Call from `main()` BEFORE any
  /// scheduling code runs so [_granted] / [_canExactAlarm] reflect the
  /// real OS state on the very first frame. The sync getters above
  /// can't trigger init themselves, and `_scheduleHabit`'s permission
  /// gate used to bail forever on cold boot because nothing had ever
  /// awoken `_ensureInit`.
  Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initFuture ??= _ensureInit();
    await _initFuture;
  }

  Future<void> _ensureInit() async {
    if (_initialized) return;
    try {
      tz_data.initializeTimeZones();
      try {
        final localName = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(localName));
        debugPrint('[Notif] timezone set to $localName');
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

      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        // Register channels once. Idempotent — Android merges by id.
        await android.createNotificationChannel(_generalChannel);
        await android.createNotificationChannel(_habitChannel);
        // Refresh exact-alarm capability cache. On Android 12+ this
        // reflects the SCHEDULE_EXACT_ALARM "special permission"; on
        // Android 13+ devices with USE_EXACT_ALARM declared this
        // returns true without a user prompt.
        try {
          _canExactAlarm =
              (await android.canScheduleExactNotifications()) ?? false;
        } catch (e) {
          debugPrint('[Notif] canScheduleExactNotifications check failed: $e');
          _canExactAlarm = false;
        }
      }

      _granted = await _checkGranted();
      debugPrint(
          '[Notif] init complete · granted=$_granted · exact=$_canExactAlarm');
    } catch (e, st) {
      debugPrint('[Notif] init failed: $e\n$st');
      _supported = false;
    } finally {
      _initialized = true;
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

  /// Re-read both permission states from the OS. Call after returning
  /// from Settings (Android lets the user toggle SCHEDULE_EXACT_ALARM
  /// from a special Settings page that we can't subscribe to).
  Future<void> refreshPermissionState() async {
    await ensureInitialized();
    _granted = await _checkGranted();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      try {
        _canExactAlarm =
            (await android.canScheduleExactNotifications()) ?? false;
      } catch (_) {}
    }
    debugPrint(
        '[Notif] refreshed · granted=$_granted · exact=$_canExactAlarm');
  }

  Future<bool> requestPermission() async {
    await ensureInitialized();
    if (!_supported) return false;
    try {
      final status = await Permission.notification.request();
      if (status.isGranted) {
        _granted = true;
        return true;
      }
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

  /// Android 12+ "special permission" that unlocks exact alarms.
  /// Returns true if it's granted (or not required on this platform);
  /// otherwise opens the system Settings page where the user grants
  /// it, then returns the eventual state.
  Future<bool> requestExactAlarmPermission() async {
    await ensureInitialized();
    if (!_supported) return false;
    if (_canExactAlarm) return true;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return false;
    try {
      final granted = (await android.requestExactAlarmsPermission()) ?? false;
      _canExactAlarm = granted;
      return granted;
    } catch (e) {
      debugPrint('[Notif] requestExactAlarmPermission failed: $e');
      return false;
    }
  }

  /// Battery-optimization opt-out — the single most effective lever
  /// for reminder reliability on Xiaomi/Samsung/Huawei/OnePlus/Oppo/
  /// Vivo. Opens the system "ignore battery optimization for this
  /// app" prompt directly when supported; returns the granted state.
  Future<bool> requestIgnoreBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    try {
      final status = await Permission.ignoreBatteryOptimizations.request();
      return status.isGranted;
    } catch (e) {
      debugPrint('[Notif] ignoreBatteryOptimizations request failed: $e');
      return false;
    }
  }

  /// True when the device is already exempt from Android battery
  /// optimization for Mood8 (so reminders are highly reliable).
  Future<bool> isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    try {
      final status = await Permission.ignoreBatteryOptimizations.status;
      return status.isGranted;
    } catch (_) {
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
    await ensureInitialized();
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
        androidScheduleMode: _scheduleMode(),
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

  /// Schedules a one-shot notification [delay] from now. Used by the
  /// "Test reminder" button so a tester can verify the whole chain
  /// (permission → exact-alarm → channel → fire) end-to-end without
  /// waiting until 9:00 AM.
  Future<bool> scheduleOneShotIn({
    required Duration delay,
    String title = 'Mood8 test reminder',
    String body = "If you see this, reminders work.",
  }) async {
    await ensureInitialized();
    if (!_granted) {
      final ok = await requestPermission();
      if (!ok) return false;
    }
    final id = 999001;
    final when = tz.TZDateTime.now(tz.local).add(delay);
    try {
      await _plugin.cancel(id);
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        _notifDetails(_habitChannel),
        androidScheduleMode: _scheduleMode(),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint(
          '[Notif] test scheduled id=$id at $when (mode=${_scheduleMode().name})');
      return true;
    } catch (e, st) {
      debugPrint('[Notif] test schedule failed: $e\n$st');
      return false;
    }
  }

  Future<void> cancelById(int id) async {
    await ensureInitialized();
    try {
      await _plugin.cancel(id);
    } catch (e) {
      debugPrint('[Notif] cancelById($id) failed: $e');
    }
  }

  /// Debug dump — returns every notification currently queued in the
  /// OS, surfaced by the test screen so a tester can confirm the
  /// schedule landed.
  Future<List<PendingNotificationRequest>> pendingRequests() async {
    await ensureInitialized();
    try {
      return await _plugin.pendingNotificationRequests();
    } catch (e) {
      debugPrint('[Notif] pendingRequests failed: $e');
      return const [];
    }
  }

  Future<void> testNotification() async {
    await ensureInitialized();
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
    await ensureInitialized();
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
    await ensureInitialized();
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('[Notif] cancelAll failed: $e');
    }
  }

  // ─── internals ────────────────────────────────────────────────────────

  /// Pick the schedule mode. Daily-repeating habit reminders need
  /// exact mode for the `matchDateTimeComponents: time` repeat to work
  /// reliably (per flutter_local_notifications' own docs — inexact
  /// mode lets the OS coalesce + drop the next-day reschedule). When
  /// exact-alarm permission isn't granted we fall back to inexact so
  /// reminders still fire (just with up to ~15 min jitter) rather
  /// than not fire at all.
  AndroidScheduleMode _scheduleMode() => _canExactAlarm
      ? AndroidScheduleMode.exactAllowWhileIdle
      : AndroidScheduleMode.inexactAllowWhileIdle;

  Future<void> _scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
    required AndroidNotificationChannel channel,
  }) async {
    await ensureInitialized();
    if (!_supported) return;
    final when = _nextInstanceOf(hour, minute);
    try {
      await _plugin.cancel(id);
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        _notifDetails(channel),
        androidScheduleMode: _scheduleMode(),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      debugPrint(
          '[Notif] scheduled id=$id @ $hour:$minute (next $when, '
          'mode=${_scheduleMode().name}) "$title"');
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
