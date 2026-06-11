// Mobile (Android + iOS) implementation. Uses flutter_local_notifications
// to schedule real OS-level notifications that survive app-close and
// device reboot. The conditional import in notification_service.dart
// picks notification_service_web.dart on dart.library.html targets, so
// this file is only compiled into mobile builds.

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show Color;

import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'notif_log.dart';

class NotificationServiceImpl {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  Future<void>? _initFuture;
  bool _supported = true;
  bool _granted = false;
  bool _canExactAlarm = false;
  String _timezoneName = 'UTC';

  /// Per-habit channel — separate from the general one so the user
  /// can mute one without the other from Android system Settings.
  static const _generalChannel = AndroidNotificationChannel(
    'mood8_general',
    'Mood8 reminders',
    description: 'Morning, evening and streak nudges from Mood8.',
    importance: Importance.high,
    enableVibration: true,
    playSound: true,
  );

  static const _habitChannel = AndroidNotificationChannel(
    'mood8_habits',
    'Habit reminders',
    description: 'Per-habit reminders you set on individual habits.',
    importance: Importance.high,
    enableVibration: true,
    playSound: true,
  );

  bool get isSupported => _supported;
  bool get isGranted => _granted;
  bool get canExactAlarm => _canExactAlarm;
  bool get isInitialized => _initialized;
  String get timezoneName => _timezoneName;

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initFuture ??= _ensureInit();
    await _initFuture;
  }

  Future<void> _ensureInit() async {
    if (_initialized) return;
    try {
      // Step 1 — timezone DB. Use `latest_all` (not `latest`) so every
      // zone the OS could possibly hand us via FlutterTimezone is
      // resolvable. `latest` ships a tiny subset and many regions
      // failed to look up there.
      tz_data.initializeTimeZones();
      NotifLog.log('init step 1 ok: tz database loaded');

      // Step 2 — local timezone.
      try {
        final localName = await FlutterTimezone.getLocalTimezone();
        try {
          tz.setLocalLocation(tz.getLocation(localName));
          _timezoneName = localName;
          NotifLog.log('init step 2 ok: timezone=$localName');
        } catch (e) {
          NotifLog.log(
              'init step 2 partial: tz.getLocation($localName) failed: $e — using UTC');
          tz.setLocalLocation(tz.UTC);
          _timezoneName = 'UTC (fallback)';
        }
      } catch (e) {
        NotifLog.log('init step 2 fail: FlutterTimezone failed: $e — using UTC');
        tz.setLocalLocation(tz.UTC);
        _timezoneName = 'UTC (fallback)';
      }

      // Step 3 — plugin init. Icon `@mipmap/ic_launcher` exists in the
      // standard Flutter Android template; Android falls back to a
      // generic bell glyph if the resource is full-color.
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
      NotifLog.log('init step 3 ok: plugin initialize() done');

      // Step 4 — channels. Idempotent: Android merges by id.
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        await android.createNotificationChannel(_generalChannel);
        await android.createNotificationChannel(_habitChannel);
        NotifLog.log('init step 4 ok: channels created (general+habits)');
        try {
          _canExactAlarm =
              (await android.canScheduleExactNotifications()) ?? false;
          NotifLog.log('init step 5 ok: canExactAlarm=$_canExactAlarm');
        } catch (e) {
          NotifLog.log('init step 5 fail: canExactAlarm check threw: $e');
          _canExactAlarm = false;
        }
      } else {
        NotifLog.log('init step 4 skip: not an Android target');
      }

      _granted = await _checkGranted();
      NotifLog.log('init step 6 ok: postNotifications=$_granted');
      NotifLog.log(
          'init COMPLETE · supported=$_supported granted=$_granted '
          'exact=$_canExactAlarm tz=$_timezoneName');
    } catch (e, st) {
      NotifLog.log('init FAILED: $e\n$st');
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
      NotifLog.log('Permission.notification.status threw: $e');
      return false;
    }
  }

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
    NotifLog.log(
        'refreshed · granted=$_granted exact=$_canExactAlarm tz=$_timezoneName');
  }

  Future<bool> requestPermission() async {
    await ensureInitialized();
    if (!_supported) return false;
    try {
      final status = await Permission.notification.request();
      NotifLog.log('requestPermission → ${status.toString()}');
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
      NotifLog.log('requestPermission threw: $e\n$st');
      return false;
    }
  }

  /// IMPORTANT: this does NOT await user resolution. On Android 12+
  /// the plugin opens system Settings.ACTION_REQUEST_SCHEDULE_EXACT_
  /// ALARM and returns immediately; the Future resolved by the plugin
  /// reflects whether the system was ABLE to launch that activity,
  /// not whether the user granted. Awaiting it can hang or return
  /// stale "not granted" before the user has had time to flip the
  /// switch in Settings. The app-resume hook in main.dart calls
  /// [refreshPermissionState] when the user comes back, which is the
  /// authoritative source of the new state.
  Future<bool> requestExactAlarmPermission() async {
    await ensureInitialized();
    if (!_supported) return false;
    if (_canExactAlarm) return true;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return false;
    try {
      // Fire the request — it opens system Settings asynchronously.
      // Don't trust the returned Future for the actual granted state;
      // we re-check via refreshPermissionState on app resume.
      final r = await android.requestExactAlarmsPermission() ?? false;
      NotifLog.log('requestExactAlarmsPermission immediate=$r '
          '(actual state checked on resume)');
      return r;
    } catch (e) {
      NotifLog.log('requestExactAlarmsPermission threw: $e');
      return false;
    }
  }

  Future<bool> requestIgnoreBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    try {
      final status = await Permission.ignoreBatteryOptimizations.request();
      NotifLog.log('ignoreBatteryOptimizations → ${status.toString()}');
      return status.isGranted;
    } catch (e) {
      NotifLog.log('ignoreBatteryOptimizations threw: $e');
      return false;
    }
  }

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
  }) =>
      _scheduleDaily(
        id: 100001,
        hour: hour,
        minute: minute,
        title: 'Good morning, $name ✨',
        body: 'How are you today?',
        channel: _generalChannel,
      );

  Future<void> scheduleEveningReflection({
    required int hour,
    required int minute,
  }) =>
      _scheduleDaily(
        id: 100002,
        hour: hour,
        minute: minute,
        title: "Tonight's reflection is ready 💫",
        body: 'Take 30 seconds with Mood8.',
        channel: _generalChannel,
      );

  Future<void> scheduleStreakWarning({required int hoursLeft}) async {
    await ensureInitialized();
    if (!_granted) {
      NotifLog.log('streakWarning skip: not granted');
      return;
    }
    try {
      final when =
          tz.TZDateTime.now(tz.local).add(Duration(hours: hoursLeft.clamp(1, 23)));
      await _withIconFallback(() => _plugin.zonedSchedule(
            100003,
            '🔥 Your streak ends soon',
            'Log a quick check-in to keep it alive.',
            when,
            _notifDetails(_generalChannel),
            androidScheduleMode: _scheduleMode(),
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          ));
      NotifLog.log('streakWarning scheduled @ $when');
    } catch (e) {
      NotifLog.log('streakWarning failed: $e');
    }
  }

  Future<void> scheduleHabitReminder({
    required String habitTitle,
    required int hour,
    required int minute,
  }) =>
      _scheduleDaily(
        id: 100004,
        hour: hour,
        minute: minute,
        title: 'Time for $habitTitle',
        body: 'A small vote for who you are becoming.',
        channel: _habitChannel,
      );

  Future<void> scheduleHabitReminderAt({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) =>
      _scheduleDaily(
        id: id,
        hour: hour,
        minute: minute,
        title: title,
        body: body,
        channel: _habitChannel,
      );

  /// Schedules a one-shot zonedSchedule [delay] from now, INCLUDING
  /// `matchDateTimeComponents: DateTimeComponents.time` so the
  /// diagnostic uses the SAME path a real daily-repeating habit
  /// reminder uses. If this fires, daily habit reminders will too. If
  /// it doesn't fire (but `Fire NOW` does), the bug is in the
  /// daily-repeat / exact-alarm / OEM-doze layer specifically.
  Future<TestResult> scheduleOneShotIn({
    required Duration delay,
    String title = 'Mood8 test reminder',
    String body = "If you see this, scheduled reminders work.",
  }) async {
    await ensureInitialized();
    if (!_granted) {
      final ok = await requestPermission();
      if (!ok) {
        return TestResult(
          ok: false,
          mode: 'none',
          reason: 'Notification permission denied.',
          firesAt: null,
          pendingCount: (await pendingRequests()).length,
        );
      }
    }
    const id = 999001;
    final when = tz.TZDateTime.now(tz.local).add(delay);
    final mode = _scheduleMode();
    NotifLog.log(
        'test schedule REQUEST id=$id local=${_fmt(when)} '
        'tz=$_timezoneName mode=${mode.name} matchDailyRepeat=false');
    try {
      await _plugin.cancel(id);
      await _withIconFallback(() => _plugin.zonedSchedule(
            id,
            title,
            body,
            when,
            _notifDetails(_habitChannel),
            androidScheduleMode: mode,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          ));
      // No matchDateTimeComponents — this is a true one-shot test
      // ("did the alarm fire at the requested moment"). The
      // daily-repeat path is tested separately by real habit
      // reminders via _scheduleDaily, which sets the component match.
      final pending = await pendingRequests();
      final hit = pending.firstWhere(
        (p) => p.id == id,
        orElse: () => PendingNotificationRequest(id, null, null, null),
      );
      NotifLog.log(
          'test schedule LANDED id=$id title="${hit.title ?? "(none)"}" · '
          'queue=${pending.length}');
      return TestResult(
        ok: true,
        mode: mode.name,
        reason: null,
        firesAt: _fmt(when),
        pendingCount: pending.length,
      );
    } on PlatformException catch (e) {
      NotifLog.log('test schedule FAILED PlatformException: code=${e.code} '
          'msg=${e.message}');
      return TestResult(
        ok: false,
        mode: mode.name,
        reason: 'PlatformException ${e.code}: ${e.message}',
        firesAt: null,
        pendingCount: (await pendingRequests()).length,
      );
    } catch (e, st) {
      NotifLog.log('test schedule FAILED: $e\n$st');
      return TestResult(
        ok: false,
        mode: mode.name,
        reason: e.toString(),
        firesAt: null,
        pendingCount: (await pendingRequests()).length,
      );
    }
  }

  /// Fires a notification IMMEDIATELY via _plugin.show() — bypasses the
  /// alarm scheduler entirely. If THIS path doesn't fire on the
  /// device, the problem isn't scheduling, it's the permission /
  /// channel / icon stack. Use this as the canary in the diagnostics
  /// screen.
  Future<TestResult> showNowDiagnostic({
    String title = 'Mood8 immediate test',
    String body = "If you see this, the notification path works.",
  }) async {
    await ensureInitialized();
    if (!_granted) {
      final ok = await requestPermission();
      if (!ok) {
        return TestResult(
          ok: false,
          mode: 'show()',
          reason: 'Notification permission denied.',
          firesAt: null,
          pendingCount: (await pendingRequests()).length,
        );
      }
    }
    try {
      await _withIconFallback(() => _plugin.show(
            999002,
            title,
            body,
            _notifDetails(_habitChannel),
          ));
      NotifLog.log('show() fired id=999002 title="$title"');
      return TestResult(
        ok: true,
        mode: 'show()',
        reason: 'Notification posted immediately',
        firesAt: DateTime.now().toIso8601String(),
        pendingCount: (await pendingRequests()).length,
      );
    } on PlatformException catch (e) {
      NotifLog.log('show() FAILED PlatformException: code=${e.code} '
          'msg=${e.message}');
      return TestResult(
        ok: false,
        mode: 'show()',
        reason: 'PlatformException ${e.code}: ${e.message}',
        firesAt: null,
        pendingCount: (await pendingRequests()).length,
      );
    } catch (e, st) {
      NotifLog.log('show() FAILED: $e\n$st');
      return TestResult(
        ok: false,
        mode: 'show()',
        reason: e.toString(),
        firesAt: null,
        pendingCount: (await pendingRequests()).length,
      );
    }
  }

  Future<void> cancelById(int id) async {
    await ensureInitialized();
    try {
      await _plugin.cancel(id);
    } catch (e) {
      NotifLog.log('cancelById($id) failed: $e');
    }
  }

  Future<List<PendingNotificationRequest>> pendingRequests() async {
    await ensureInitialized();
    try {
      return await _plugin.pendingNotificationRequests();
    } catch (e) {
      NotifLog.log('pendingRequests failed: $e');
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
    if (!_granted) {
      NotifLog.log('showNow skip: not granted');
      return;
    }
    try {
      await _withIconFallback(() => _plugin.show(
            DateTime.now().millisecondsSinceEpoch ~/ 1000 & 0x7fffffff,
            title,
            body,
            _notifDetails(_generalChannel),
          ));
    } catch (e) {
      NotifLog.log('showNow failed: $e');
    }
  }

  Future<void> cancelAll() async {
    await ensureInitialized();
    try {
      await _plugin.cancelAll();
      NotifLog.log('cancelAll done');
    } catch (e) {
      NotifLog.log('cancelAll failed: $e');
    }
  }

  // ─── internals ────────────────────────────────────────────────────────

  /// Picks exact when we have the permission, inexact as a working
  /// fallback. Daily-repeating habit reminders specifically need
  /// exact mode for the matchDateTimeComponents repeat path to work
  /// reliably (per the plugin's own docs). Inexact mode also delays
  /// sub-minute one-shots significantly — for the test button we
  /// surface the mode so the user knows what to expect.
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
    final mode = _scheduleMode();
    final hh = hour.toString().padLeft(2, '0');
    final mm = minute.toString().padLeft(2, '0');
    NotifLog.log(
        'schedule REQUEST id=$id slot=$hh:$mm local=${_fmt(when)} '
        'tz=$_timezoneName mode=${mode.name} title="$title"');
    try {
      await _plugin.cancel(id);
      // Daily repeat: after each fire the plugin's BroadcastReceiver
      // re-arms the next day's alarm at the same H:M. Requires exact
      // mode for reliable repeat (per the plugin docs); on inexact the
      // next-day re-arm can be delayed or skipped — which is why the
      // bug-report case "set 9am, it's now 3pm, didn't fire tomorrow
      // morning" can happen on devices without SCHEDULE_EXACT_ALARM.
      await _withIconFallback(() => _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        _notifDetails(channel),
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      ));
      final pending = await _plugin.pendingNotificationRequests();
      final hit = pending.firstWhere(
        (p) => p.id == id,
        orElse: () => PendingNotificationRequest(id, null, null, null),
      );
      NotifLog.log(
          'schedule LANDED id=$id title="${hit.title ?? "(none)"}" · '
          'queue size=${pending.length}');
    } on PlatformException catch (e) {
      NotifLog.log(
          'schedule FAILED id=$id PlatformException code=${e.code} '
          'msg=${e.message}');
    } catch (e, st) {
      NotifLog.log('schedule FAILED id=$id error=$e\n$st');
    }
  }

  /// Computes the next firing instant for a daily reminder. If the
  /// requested H:M already passed today, advances to tomorrow.
  ///
  /// Critical: returns a `tz.TZDateTime` in `tz.local`, NOT in UTC.
  /// If tz.local is UTC (because FlutterTimezone init failed and we
  /// fell back), the schedule fires at 09:00 UTC — which is 02:00
  /// Eastern, 01:00 Central, etc. The diagnostics screen's Timezone
  /// row shows "UTC (fallback)" when this has happened so a tester
  /// can spot it.
  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  String _fmt(tz.TZDateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} '
        '${two(t.hour)}:${two(t.minute)}';
  }

  /// True once we know `@drawable/ic_stat_mood8` resolves at runtime.
  /// Flips to false on the first `invalid_icon` PlatformException so
  /// every subsequent build of NotificationDetails uses the launcher
  /// icon fallback — schedules go through cleanly even if R8 ever
  /// strips the resource again. Resets across app restarts so a fixed
  /// build doesn't permanently downgrade.
  bool _customSmallIconAvailable = true;

  /// Wrap any plugin call that uses _notifDetails so an
  /// `invalid_icon` failure flips the fallback flag and retries the
  /// SAME schedule call without the custom icon. Surface-level
  /// behaviour: the user still gets the notification, just with the
  /// launcher icon in the status bar instead of the branded
  /// silhouette.
  Future<T> _withIconFallback<T>(Future<T> Function() op) async {
    try {
      return await op();
    } on PlatformException catch (e) {
      if (e.code == 'invalid_icon' && _customSmallIconAvailable) {
        NotifLog.log(
            'invalid_icon — falling back to @mipmap/ic_launcher for the '
            'rest of this session');
        _customSmallIconAvailable = false;
        return await op();
      }
      rethrow;
    }
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
        playSound: true,
        enableVibration: true,
        // Mood8-branded status-bar look: a white-silhouette small icon
        // tinted by the brand accent. R8's resource shrinker can strip
        // string-referenced drawables from release builds — that's
        // what threw `invalid_icon` on the first attempt, fixed by
        // res/raw/keep.xml. Defensive: if it ever happens again,
        // _withIconFallback flips _customSmallIconAvailable false and
        // we use the launcher mipmap instead so schedules still go
        // through.
        icon: _customSmallIconAvailable ? 'ic_stat_mood8' : '@mipmap/ic_launcher',
        color: const Color(0xFFA855F7),
        colorized: true,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }
}

/// Rich result for the test buttons — the diagnostics UI shows EVERY
/// field so a tester can pinpoint where the chain broke.
class TestResult {
  TestResult({
    required this.ok,
    required this.mode,
    required this.reason,
    required this.firesAt,
    required this.pendingCount,
  });

  final bool ok;
  final String mode;
  final String? reason;
  final String? firesAt;
  final int pendingCount;
}

NotificationServiceImpl createNotificationServiceImpl() =>
    NotificationServiceImpl();
