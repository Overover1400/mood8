import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'auth_service.dart';
import 'challenge_service.dart';

/// Obtains this device's FCM push token and registers it with the
/// backend so the server can deliver daily challenge reminders + invite
/// pushes (see mood8-backend/push_service.py + challenge_daily_job.py).
///
/// Entirely best-effort and defensive: on web, when the user isn't
/// signed in, when Firebase/FCM isn't configured (no google-services.json
/// / APNs key yet), or on any error, every method is a silent no-op. It
/// must never block or crash app startup — mirrors _initCrashlytics.
class PushRegistrationService {
  PushRegistrationService._();
  static final PushRegistrationService _instance =
      PushRegistrationService._();
  factory PushRegistrationService() => _instance;

  bool _wired = false;
  String? _lastToken;

  /// Call once the user is signed in (token present). Requests
  /// permission, fetches the FCM token, registers it, and wires a
  /// refresh listener. Safe to call more than once.
  Future<void> registerIfPossible() async {
    // FCM tokens on web need a VAPID key + service worker; skip until
    // that's set up. Native only for now.
    if (kIsWeb) return;
    if (AuthService().token == null) return;
    try {
      final messaging = FirebaseMessaging.instance;
      // Ask for permission (no-op-ish on Android < 13; real prompt on
      // iOS / Android 13+). We register regardless of the outcome so a
      // user who later enables notifications in settings still works.
      await messaging.requestPermission();
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        _lastToken = token;
        await ChallengeService()
            .registerPushToken(token, platform: _platform());
      }
      if (!_wired) {
        _wired = true;
        FirebaseMessaging.instance.onTokenRefresh.listen((t) {
          _lastToken = t;
          ChallengeService().registerPushToken(t, platform: _platform());
        });
      }
    } catch (e) {
      debugPrint('PushRegistrationService.registerIfPossible failed: $e');
    }
  }

  /// Call on sign-out so a shared device stops receiving the previous
  /// user's reminders.
  Future<void> unregister() async {
    final token = _lastToken;
    if (token == null) return;
    try {
      await ChallengeService().unregisterPushToken(token);
    } catch (e) {
      debugPrint('PushRegistrationService.unregister failed: $e');
    }
  }

  String _platform() {
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    return 'other';
  }
}
