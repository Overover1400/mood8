import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';

/// Captures the device's IANA timezone (e.g. "Asia/Yerevan") and
/// keeps the server row in sync.
///
/// Called from:
///   • main() on cold boot (fire-and-forget) so a freshly-launched
///     app tells the server about a timezone change from travel.
///   • AuthGate after any successful sign-in / verify so a new
///     user's row is stamped on the FIRST recap-send window.
///   • Google sign-in piggybacks the timezone in the same round-trip
///     via `GoogleSignInService` — this service is the fallback for
///     any auth path that doesn't include it inline.
///
/// Idempotent + rate-limited: at most one HTTP call per calendar
/// day per timezone value, tracked in SharedPreferences so we
/// don't burn a network call every app-open once the daily push
/// has already landed.
class TimezoneSyncService {
  TimezoneSyncService._();
  static final TimezoneSyncService _instance = TimezoneSyncService._();
  factory TimezoneSyncService() => _instance;

  static const String _baseUrl = 'https://mood8.app/api';
  static const Duration _timeout = Duration(seconds: 10);

  static const String _kLastTzKey = 'mood8.tz.lastSent';
  static const String _kLastTzDayKey = 'mood8.tz.lastSentDay';

  final http.Client _client = http.Client();

  /// Reads the current IANA timezone from the device. Never throws —
  /// returns null when `flutter_timezone` can't resolve (e.g. a rare
  /// unmapped region) so callers can silently skip.
  Future<String?> readDeviceTimezone() async {
    try {
      final tz = await FlutterTimezone.getLocalTimezone();
      final trimmed = tz.trim();
      if (trimmed.isEmpty) return null;
      return trimmed;
    } catch (e) {
      debugPrint('[Tz] readDeviceTimezone failed: $e');
      return null;
    }
  }

  /// Sends the device timezone to the server if either (a) it
  /// changed since the last successful send, or (b) at least one
  /// calendar day has passed since the last successful send. No-op
  /// when the client isn't signed in — the auth-aware paths call
  /// this after a token is available.
  Future<void> syncIfNeeded() async {
    final token = AuthService().token;
    if (token == null) {
      debugPrint('[Tz] syncIfNeeded — no token, skipping');
      return;
    }
    final tz = await readDeviceTimezone();
    if (tz == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastTz = prefs.getString(_kLastTzKey);
      final lastDay = prefs.getString(_kLastTzDayKey);
      final today = _today();
      if (lastTz == tz && lastDay == today) {
        // Already sent this exact tz today.
        return;
      }
      final res = await _client
          .post(
            Uri.parse('$_baseUrl/user/timezone'),
            headers: {
              'authorization': 'Bearer $token',
              'content-type': 'application/json',
            },
            body: jsonEncode({'timezone': tz}),
          )
          .timeout(_timeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        await prefs.setString(_kLastTzKey, tz);
        await prefs.setString(_kLastTzDayKey, today);
        debugPrint('[Tz] sync ok → $tz');
      } else {
        debugPrint('[Tz] sync ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      debugPrint('[Tz] sync error: $e');
    }
  }

  /// Clears the local "last sent" markers. Called on logout so the
  /// next user's timezone push always fires on their first sign-in.
  Future<void> clearForLogout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kLastTzKey);
      await prefs.remove(_kLastTzDayKey);
    } catch (e) {
      debugPrint('[Tz] clearForLogout failed: $e');
    }
  }

  String _today() {
    final now = DateTime.now();
    // YYYY-MM-DD in LOCAL time — the rate-limit ceiling is
    // "once per app-open per user's local calendar day," which lines
    // up with when a user could plausibly notice a timezone change.
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)}';
  }
}
