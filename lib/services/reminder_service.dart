import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/reminder_settings.dart';
import 'database_service.dart';
import 'mood_repository.dart';
import 'notification_service.dart';
import 'sync_service.dart';

/// Owns the scheduling lifecycle for "smart reminders" — daily mood
/// check-in nudges that consult quiet hours and smart-skip rules before
/// firing.
///
/// Web reality check: timers are `Timer.run` instances inside this isolate.
/// They persist only while the tab is open. Closing the tab cancels every
/// scheduled reminder; reopening re-runs [scheduleAllReminders] from
/// `main.dart` so the user gets continued nudges. A real background push
/// system would need a service worker + push server (out of scope).
class ReminderService extends ChangeNotifier {
  ReminderService._();
  static final ReminderService _instance = ReminderService._();
  factory ReminderService() => _instance;

  Box<ReminderSettings> get _box =>
      DatabaseService.instance.reminderSettingsBox;

  /// Active timer per reminder slot. Key: 'slot_$index'.
  final Map<String, Timer> _timers = {};

  /// Randomized copy pool — never feels robotic.
  static const List<String> _copyPool = <String>[
    'How are you feeling right now?',
    "Take a moment — how's your mood?",
    'Quick mood check?',
    "What's your vibe today?",
    'Pause and notice — how are you?',
    'A gentle check-in from Mood8',
    "How's your energy right now?",
    'What would future you want to know about now?',
    'Notice your mood — even briefly',
    'How are you doing, really?',
  ];

  static const String _kLastFiredPrefix = 'mood8.reminder.lastFired.';

  /// Returns the current settings, lazily creating defaults on first run.
  Future<ReminderSettings> getSettings() async {
    final existing = _box.get(ReminderSettings.boxKey);
    if (existing != null) return existing;
    final defaults = ReminderSettings();
    await _box.put(ReminderSettings.boxKey, defaults);
    return defaults;
  }

  /// Reactive listenable for the settings UI.
  ValueListenable<Box<ReminderSettings>> watch() => _box.listenable();

  /// Persists a fresh settings record. Cancels and reschedules so changes
  /// take effect immediately.
  Future<void> updateSettings(ReminderSettings settings) async {
    settings.updatedAt = DateTime.now();
    await _box.put(ReminderSettings.boxKey, settings);
    SyncService().debouncedPush();
    await scheduleAllReminders();
    notifyListeners();
  }

  // ─── Scheduling ───────────────────────────────────────────────────────

  Future<void> scheduleAllReminders() async {
    await cancelAllReminders();
    final settings = await getSettings();
    if (!settings.enabled) {
      debugPrint('[Reminders] disabled — not scheduling');
      return;
    }
    final notif = NotificationService();
    if (!notif.isSupported || !notif.isGranted) {
      debugPrint(
          '[Reminders] notifications unavailable (supported=${notif.isSupported}, granted=${notif.isGranted}) — skipping schedule');
      return;
    }
    for (var i = 0; i < settings.reminderTimes.length; i++) {
      _scheduleOne(slotIndex: i, minuteOfDay: settings.reminderTimes[i]);
    }
    debugPrint(
        '[Reminders] scheduled ${settings.reminderTimes.length} reminders');
  }

  Future<void> cancelAllReminders() async {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
  }

  Future<void> sendTestNotification() async {
    final notif = NotificationService();
    final ok = notif.isGranted ? true : await notif.requestPermission();
    if (!ok) return;
    final body = _randomCopy();
    await notif.showNow(title: 'Mood8', body: body);
  }

  /// Called by the home screen after a mood check-in. If smart-skip is on,
  /// the remaining reminders for today never fire (they reschedule
  /// themselves for tomorrow on next fire-check).
  Future<void> onMoodLogged() async {
    final settings = await getSettings();
    if (!settings.smartSkip) return;
    debugPrint(
        '[Reminders] mood logged — smart-skip remaining reminders for today');
    // Nothing to cancel explicitly: each timer's fire callback consults
    // [shouldSkipToday] before showing. But to keep things tidy, we cancel
    // the slots that haven't fired yet AND reschedule them for tomorrow.
    await scheduleAllReminders();
  }

  // ─── Rules ────────────────────────────────────────────────────────────

  bool isInQuietHours(DateTime time) {
    final s = _box.get(ReminderSettings.boxKey);
    if (s == null || !s.quietHoursEnabled) return false;
    final minute = time.hour * 60 + time.minute;
    // Window may wrap midnight: e.g. start=1320 (22:00) end=420 (07:00).
    if (s.quietStart < s.quietEnd) {
      return minute >= s.quietStart && minute < s.quietEnd;
    }
    return minute >= s.quietStart || minute < s.quietEnd;
  }

  /// True if the user has already logged a mood today AND smart-skip is on.
  bool shouldSkipToday() {
    final s = _box.get(ReminderSettings.boxKey);
    if (s == null || !s.smartSkip) return false;
    final today = MoodRepository().getTodayEntry();
    return today != null;
  }

  /// Stub for a system-level "reminder tap" handler (web: no-op; mobile
  /// will wire this through `flutter_local_notifications` open callbacks).
  Future<void> handleReminderTap() async {
    debugPrint('[Reminders] tap handler invoked (no-op on web)');
  }

  // ─── Internals ────────────────────────────────────────────────────────

  void _scheduleOne({required int slotIndex, required int minuteOfDay}) {
    final key = 'slot_$slotIndex';
    final delay = _delayUntil(minuteOfDay);
    if (delay == null) return;
    _timers[key]?.cancel();
    _timers[key] = Timer(delay, () async {
      await _fireSlot(slotIndex: slotIndex, minuteOfDay: minuteOfDay);
      // Re-schedule for tomorrow on the same slot.
      _scheduleOne(slotIndex: slotIndex, minuteOfDay: minuteOfDay);
    });
    debugPrint(
        '[Reminders] slot $slotIndex (minute $minuteOfDay) → fires in '
        '${delay.inMinutes}min');
  }

  Future<void> _fireSlot({
    required int slotIndex,
    required int minuteOfDay,
  }) async {
    final now = DateTime.now();
    if (await _alreadyFiredToday(slotIndex, now)) {
      debugPrint('[Reminders] slot $slotIndex already fired today — skip');
      return;
    }
    if (isInQuietHours(now)) {
      debugPrint('[Reminders] slot $slotIndex in quiet hours — skip');
      return;
    }
    if (shouldSkipToday()) {
      debugPrint(
          '[Reminders] slot $slotIndex skipped (mood already logged + smart skip)');
      return;
    }
    await NotificationService().showNow(
      title: 'Mood8',
      body: _randomCopy(),
    );
    await _markFiredToday(slotIndex, now);
  }

  /// `null` if minute-of-day is invalid; otherwise duration until the next
  /// time we hit that minute (today if still ahead, tomorrow otherwise).
  Duration? _delayUntil(int minuteOfDay) {
    if (minuteOfDay < 0 || minuteOfDay >= 24 * 60) return null;
    final now = DateTime.now();
    final h = minuteOfDay ~/ 60;
    final m = minuteOfDay % 60;
    var next = DateTime(now.year, now.month, now.day, h, m);
    if (!next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }
    return next.difference(now);
  }

  String _randomCopy() {
    final rng = math.Random();
    return _copyPool[rng.nextInt(_copyPool.length)];
  }

  Future<bool> _alreadyFiredToday(int slotIndex, DateTime now) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_kLastFiredPrefix$slotIndex';
      final last = prefs.getString(key);
      if (last == null) return false;
      final parsed = DateTime.tryParse(last);
      if (parsed == null) return false;
      return parsed.year == now.year &&
          parsed.month == now.month &&
          parsed.day == now.day;
    } catch (_) {
      return false;
    }
  }

  Future<void> _markFiredToday(int slotIndex, DateTime now) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_kLastFiredPrefix$slotIndex',
        now.toIso8601String(),
      );
    } catch (e) {
      debugPrint('[Reminders] markFiredToday failed: $e');
    }
  }
}
