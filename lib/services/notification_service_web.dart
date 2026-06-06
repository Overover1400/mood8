import 'dart:async';
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

import 'package:flutter/foundation.dart';

/// Web implementation backed by the browser's `Notification` API. Uses
/// `Timer` to schedule the *next* occurrence of each daily slot, then
/// reschedules itself after each fire (rolling daily cron).
class NotificationServiceImpl {
  bool get isSupported {
    try {
      return html.Notification.supported;
    } catch (_) {
      return false;
    }
  }

  bool get isGranted {
    try {
      return html.Notification.permission == 'granted';
    } catch (_) {
      return false;
    }
  }

  final Map<String, Timer> _timers = {};

  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    if (isGranted) return true;
    try {
      final result = await html.Notification.requestPermission();
      return result == 'granted';
    } catch (e) {
      debugPrint('[Notif] requestPermission failed: $e');
      return false;
    }
  }

  Future<void> scheduleMorningCheckIn({
    required String name,
    required int hour,
    required int minute,
  }) async {
    _scheduleDaily(
      key: 'morning',
      hour: hour,
      minute: minute,
      title: 'Good morning, $name ✨',
      body: 'How are you today?',
    );
  }

  Future<void> scheduleEveningReflection({
    required int hour,
    required int minute,
  }) async {
    _scheduleDaily(
      key: 'evening',
      hour: hour,
      minute: minute,
      title: "Tonight's reflection is ready 💫",
      body: 'Take 30 seconds with Mood8.',
    );
  }

  Future<void> scheduleStreakWarning({required int hoursLeft}) async {
    if (!isGranted) return;
    final delay = Duration(hours: hoursLeft.clamp(1, 23));
    _timers['streak']?.cancel();
    _timers['streak'] = Timer(delay, () {
      _show('🔥 Your streak ends soon',
          'Log a quick check-in to keep it alive.');
    });
  }

  Future<void> scheduleHabitReminder({
    required String habitTitle,
    required int hour,
    required int minute,
  }) async {
    _scheduleDaily(
      key: 'habit_$habitTitle',
      hour: hour,
      minute: minute,
      title: 'Time for $habitTitle',
      body: 'A small vote for who you are becoming.',
    );
  }

  Future<void> testNotification() async {
    if (!isGranted) {
      final ok = await requestPermission();
      if (!ok) return;
    }
    _show('Mood8 test notification ✨', 'You\'re wired up.');
  }

  Future<void> showNow({required String title, required String body}) async {
    if (!isGranted) return;
    _show(title, body);
  }

  /// Web-equivalent of the mobile per-habit reminder. Stored under
  /// the id-derived key so HabitReminderService can cancel an
  /// individual slot.
  Future<void> scheduleHabitReminderAt({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    _scheduleDaily(
      key: 'habit_$id',
      hour: hour,
      minute: minute,
      title: title,
      body: body,
    );
  }

  Future<void> cancelById(int id) async {
    final t = _timers.remove('habit_$id');
    t?.cancel();
  }

  Future<void> cancelAll() async {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
  }

  // ─── internals ────────────────────────────────────────────────────────

  void _scheduleDaily({
    required String key,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) {
    if (!isSupported) return;
    if (!isGranted) {
      // Best effort: skip silently. The settings screen has the user-visible
      // "request permission" hook.
      return;
    }
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, hour, minute);
    if (!next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }
    final delay = next.difference(now);
    _timers[key]?.cancel();
    _timers[key] = Timer(delay, () {
      _show(title, body);
      // Reschedule for tomorrow.
      _scheduleDaily(
        key: key,
        hour: hour,
        minute: minute,
        title: title,
        body: body,
      );
    });
    debugPrint('[Notif] scheduled $key in ${delay.inMinutes}min');
  }

  void _show(String title, String body) {
    if (!isSupported || !isGranted) return;
    try {
      html.Notification(title, body: body);
    } catch (e) {
      debugPrint('[Notif] show failed: $e');
    }
  }
}

NotificationServiceImpl createNotificationServiceImpl() =>
    NotificationServiceImpl();
