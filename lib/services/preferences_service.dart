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

  // ─── AI insights toggle ───────────────────────────────────────────────

  bool get aiInsightsEnabled => _prefs?.getBool(_kAiInsightsEnabled) ?? true;

  Future<void> setAiInsightsEnabled(bool value) async {
    final p = await _get();
    await p.setBool(_kAiInsightsEnabled, value);
    notifyListeners();
  }

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
