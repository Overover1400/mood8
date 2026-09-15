import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { dark, light, system }

ThemeMode appToFlutterThemeMode(AppThemeMode mode) {
  switch (mode) {
    case AppThemeMode.dark:
      return ThemeMode.dark;
    case AppThemeMode.light:
      return ThemeMode.light;
    case AppThemeMode.system:
      return ThemeMode.system;
  }
}

enum TimeFormat { twelveHour, twentyFourHour }

enum WeekStart { monday, sunday }

enum CoachPersonality { warm, direct, analytical }

class PreferencesService extends ChangeNotifier {
  PreferencesService._();
  static final PreferencesService instance = PreferencesService._();

  static const _kTheme = 'mood8.theme';
  static const _kTimeFormat = 'mood8.timeFormat';
  static const _kWeekStart = 'mood8.weekStart';
  static const _kCoachPersonality = 'mood8.coachPersonality';
  static const _kReflectionHour = 'mood8.reflectionHour';
  static const _kReflectionMinute = 'mood8.reflectionMinute';
  static const _kAiInsightsEnabled = 'mood8.aiInsightsEnabled';
  static const _kCheckinHour = 'mood8.checkinHour';
  static const _kCheckinMinute = 'mood8.checkinMinute';
  static const _kShowMorningIntention = 'show_morning_intention';
  static const _kShowGratitudeCard = 'show_gratitude_card';
  static const _kPatternAlertsEnabled = 'mood8.patternAlertsEnabled';
  static const _kPatternStreaks = 'mood8.patternStreaks';
  static const _kPatternMood = 'mood8.patternMood';
  static const _kPatternDayOfWeek = 'mood8.patternDayOfWeek';
  static const _kPatternGrowth = 'mood8.patternGrowth';
  static const _kPatternCheckIns = 'mood8.patternCheckIns';
  static const _kPatternNotifications = 'mood8.patternNotifications';

  // Spec 1.5 — per-category notification switches + a daily cap.
  static const _kNotifCheckin = 'mood8.notif.checkin';
  static const _kNotifHabits = 'mood8.notif.habits';
  static const _kNotifChallenges = 'mood8.notif.challenges';
  static const _kNotifWeeklyRecap = 'mood8.notif.weeklyRecap';
  static const _kNotifDailyCap = 'mood8.notif.dailyCap';
  static const _kNotifSentDate = 'mood8.notif.sentDate';
  static const _kNotifSentCount = 'mood8.notif.sentCount';

  SharedPreferences? _prefs;

  /// Reactive ThemeMode for `MaterialApp.themeMode`.
  final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.dark);

  Future<SharedPreferences> _get() async =>
      _prefs ??= await SharedPreferences.getInstance();

  // ─── Theme ─────────────────────────────────────────────────────────────

  AppThemeMode get themeMode {
    final raw = _prefs?.getString(_kTheme);
    return _decodeTheme(raw);
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    final p = await _get();
    await p.setString(_kTheme, mode.name);
    themeModeNotifier.value = appToFlutterThemeMode(mode);
    notifyListeners();
  }

  // ─── Time format ───────────────────────────────────────────────────────

  TimeFormat get timeFormat {
    final raw = _prefs?.getString(_kTimeFormat);
    return raw == TimeFormat.twelveHour.name
        ? TimeFormat.twelveHour
        : TimeFormat.twentyFourHour;
  }

  Future<void> setTimeFormat(TimeFormat f) async {
    final p = await _get();
    await p.setString(_kTimeFormat, f.name);
    notifyListeners();
  }

  // ─── Week start ────────────────────────────────────────────────────────

  WeekStart get weekStart {
    final raw = _prefs?.getString(_kWeekStart);
    return raw == WeekStart.sunday.name ? WeekStart.sunday : WeekStart.monday;
  }

  Future<void> setWeekStart(WeekStart w) async {
    final p = await _get();
    await p.setString(_kWeekStart, w.name);
    notifyListeners();
  }

  // ─── Coach personality ─────────────────────────────────────────────────

  CoachPersonality get coachPersonality {
    final raw = _prefs?.getString(_kCoachPersonality);
    if (raw == CoachPersonality.direct.name) return CoachPersonality.direct;
    if (raw == CoachPersonality.analytical.name) {
      return CoachPersonality.analytical;
    }
    return CoachPersonality.warm;
  }

  Future<void> setCoachPersonality(CoachPersonality p) async {
    final prefs = await _get();
    await prefs.setString(_kCoachPersonality, p.name);
    notifyListeners();
  }

  // ─── Reflection time ───────────────────────────────────────────────────

  TimeOfDayLite get reflectionTime {
    return TimeOfDayLite(
      hour: _prefs?.getInt(_kReflectionHour) ?? 21,
      minute: _prefs?.getInt(_kReflectionMinute) ?? 0,
    );
  }

  Future<void> setReflectionTime(int hour, int minute) async {
    final p = await _get();
    await p.setInt(_kReflectionHour, hour);
    await p.setInt(_kReflectionMinute, minute);
    notifyListeners();
  }

  // ─── Check-in time ─────────────────────────────────────────────────────

  TimeOfDayLite get checkinTime {
    return TimeOfDayLite(
      hour: _prefs?.getInt(_kCheckinHour) ?? 9,
      minute: _prefs?.getInt(_kCheckinMinute) ?? 0,
    );
  }

  Future<void> setCheckinTime(int hour, int minute) async {
    final p = await _get();
    await p.setInt(_kCheckinHour, hour);
    await p.setInt(_kCheckinMinute, minute);
    notifyListeners();
  }

  // ─── Notification categories (spec 1.5) ───────────────────────────────
  //
  // An app that sends check-ins, habit reminders, challenge news and a
  // weekly recap — with no way to separate them — gets its notifications
  // turned off wholesale at the OS level. Each category is independently
  // switchable so a user who only wants habit reminders can have exactly
  // that instead of choosing between everything and nothing.

  bool get checkinNotificationsEnabled =>
      _prefs?.getBool(_kNotifCheckin) ?? true;
  bool get habitNotificationsEnabled =>
      _prefs?.getBool(_kNotifHabits) ?? true;
  bool get challengeNotificationsEnabled =>
      _prefs?.getBool(_kNotifChallenges) ?? true;
  bool get weeklyRecapNotificationsEnabled =>
      _prefs?.getBool(_kNotifWeeklyRecap) ?? true;

  Future<void> setCheckinNotificationsEnabled(bool v) =>
      _setNotifFlag(_kNotifCheckin, v);
  Future<void> setHabitNotificationsEnabled(bool v) =>
      _setNotifFlag(_kNotifHabits, v);
  Future<void> setChallengeNotificationsEnabled(bool v) =>
      _setNotifFlag(_kNotifChallenges, v);
  Future<void> setWeeklyRecapNotificationsEnabled(bool v) =>
      _setNotifFlag(_kNotifWeeklyRecap, v);

  Future<void> _setNotifFlag(String key, bool v) async {
    final p = await _get();
    await p.setBool(key, v);
    notifyListeners();
  }

  /// Spec 1.5 — default ceiling of 3 notifications per day. 0 means
  /// "no cap" for the power user who explicitly wants everything.
  int get notificationDailyCap => _prefs?.getInt(_kNotifDailyCap) ?? 3;

  Future<void> setNotificationDailyCap(int v) async {
    final p = await _get();
    await p.setInt(_kNotifDailyCap, v.clamp(0, 20));
    notifyListeners();
  }

  /// Consume one slot from today's budget. Returns false when the cap is
  /// already spent, in which case the caller must not send.
  ///
  /// The counter resets on date change rather than on a timer, so an app
  /// that never runs at midnight still gets a correct fresh budget on the
  /// first send of the next day.
  Future<bool> tryConsumeNotificationBudget() async {
    final cap = notificationDailyCap;
    if (cap <= 0) return true;
    final p = await _get();
    final today = _todayStamp();
    final storedDate = p.getString(_kNotifSentDate);
    final count = storedDate == today ? (p.getInt(_kNotifSentCount) ?? 0) : 0;
    if (count >= cap) return false;
    await p.setString(_kNotifSentDate, today);
    await p.setInt(_kNotifSentCount, count + 1);
    return true;
  }

  /// How many of today's slots are already used — for the settings UI.
  int get notificationsSentToday {
    if (_prefs?.getString(_kNotifSentDate) != _todayStamp()) return 0;
    return _prefs?.getInt(_kNotifSentCount) ?? 0;
  }

  static String _todayStamp() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  // ─── AI insights toggle ───────────────────────────────────────────────

  bool get aiInsightsEnabled => _prefs?.getBool(_kAiInsightsEnabled) ?? true;

  Future<void> setAiInsightsEnabled(bool value) async {
    final p = await _get();
    await p.setBool(_kAiInsightsEnabled, value);
    notifyListeners();
  }

  // ─── Morning intention prompt ─────────────────────────────────────────

  bool get showMorningIntention =>
      _prefs?.getBool(_kShowMorningIntention) ?? true;

  Future<void> setShowMorningIntention(bool value) async {
    final p = await _get();
    await p.setBool(_kShowMorningIntention, value);
    notifyListeners();
  }

  // ─── Gratitude card on home ───────────────────────────────────────────

  bool get showGratitudeCard =>
      _prefs?.getBool(_kShowGratitudeCard) ?? true;

  Future<void> setShowGratitudeCard(bool value) async {
    final p = await _get();
    await p.setBool(_kShowGratitudeCard, value);
    notifyListeners();
  }

  // ─── Pattern alerts ───────────────────────────────────────────────────

  bool get patternAlertsEnabled =>
      _prefs?.getBool(_kPatternAlertsEnabled) ?? true;
  bool get patternStreaksEnabled =>
      _prefs?.getBool(_kPatternStreaks) ?? true;
  bool get patternMoodEnabled =>
      _prefs?.getBool(_kPatternMood) ?? true;
  bool get patternDayOfWeekEnabled =>
      _prefs?.getBool(_kPatternDayOfWeek) ?? true;
  bool get patternGrowthEnabled =>
      _prefs?.getBool(_kPatternGrowth) ?? true;
  bool get patternCheckInsEnabled =>
      _prefs?.getBool(_kPatternCheckIns) ?? true;
  bool get patternNotificationsEnabled =>
      _prefs?.getBool(_kPatternNotifications) ?? false;

  Future<void> setPatternAlertsEnabled(bool v) async {
    final p = await _get();
    await p.setBool(_kPatternAlertsEnabled, v);
    notifyListeners();
  }

  Future<void> setPatternCategoryEnabled(String key, bool v) async {
    final p = await _get();
    await p.setBool(key, v);
    notifyListeners();
  }

  // Keys exposed so the settings screen can call setPatternCategoryEnabled
  // without re-hardcoding the strings.
  String get streaksKey => _kPatternStreaks;
  String get moodKey => _kPatternMood;
  String get dayOfWeekKey => _kPatternDayOfWeek;
  String get growthKey => _kPatternGrowth;
  String get checkInsKey => _kPatternCheckIns;
  String get notificationsKey => _kPatternNotifications;

  // ─── Init ──────────────────────────────────────────────────────────────

  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      themeModeNotifier.value = appToFlutterThemeMode(themeMode);
      notifyListeners();
    } catch (e) {
      debugPrint('PreferencesService.load failed: $e');
    }
  }

  AppThemeMode _decodeTheme(String? raw) {
    if (raw == AppThemeMode.light.name) return AppThemeMode.light;
    if (raw == AppThemeMode.system.name) return AppThemeMode.system;
    return AppThemeMode.dark;
  }
}

class TimeOfDayLite {
  const TimeOfDayLite({required this.hour, required this.minute});
  final int hour;
  final int minute;

  String format(TimeFormat fmt) {
    if (fmt == TimeFormat.twentyFourHour) {
      return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    }
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final period = hour >= 12 ? 'PM' : 'AM';
    return '$h:${minute.toString().padLeft(2, '0')} $period';
  }
}
