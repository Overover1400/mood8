import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_user.dart';

/// Outcome of an auth call. Either successful with optional [user] / [token],
/// or failed with a friendly [message] for the UI.
class AuthResult {
  const AuthResult({
    required this.success,
    required this.message,
    this.user,
    this.token,
  });

  factory AuthResult.ok({String message = '', AuthUser? user, String? token}) =>
      AuthResult(success: true, message: message, user: user, token: token);

  factory AuthResult.fail(String message) =>
      AuthResult(success: false, message: message);

  final bool success;
  final String message;
  final AuthUser? user;
  final String? token;
}

class AuthService {
  AuthService._();
  static final AuthService _instance = AuthService._();
  factory AuthService() => _instance;

  static const String _baseUrl = 'https://mood8.app/api';
  static const String _tokenKey = 'mood8.authToken';
  static const String _userKey = 'mood8.authUser';
  static const Duration _timeout = Duration(seconds: 30);

  final http.Client _client = http.Client();

  final ValueNotifier<AuthUser?> currentUserNotifier =
      ValueNotifier<AuthUser?>(null);

  String? _token;
  bool _initialized = false;

  bool get isAuthenticated =>
      _token != null && currentUserNotifier.value != null;
  AuthUser? get currentUser => currentUserNotifier.value;
  String? get token => _token;
  String? get authHeader => _token == null ? null : 'Bearer $_token';

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_tokenKey);
      final userRaw = prefs.getString(_userKey);
      debugPrint(
          '[AuthService] initialize · token=${_token == null ? 'null' : 'present'} · userRaw=${userRaw == null ? 'null' : '${userRaw.length}b'}');
      if (userRaw != null && userRaw.isNotEmpty) {
        try {
          currentUserNotifier.value = AuthUser.fromJson(
            jsonDecode(userRaw) as Map<String, dynamic>,
          );
          debugPrint(
              '[AuthService] initialize → restored ${currentUserNotifier.value?.email}');
        } catch (e) {
          debugPrint('[AuthService] cached user parse failed: $e');
        }
      }
    } catch (e) {
      debugPrint('[AuthService] initialize failed: $e');
    }
  }

  Future<AuthResult> register({
    required String email,
    required String password,
    required String name,
  }) async {
    debugPrint('[AuthService] register → $email');
    // sendBearer: true → if we currently hold a guest JWT, the backend
    // upgrades that account in place (same user_id, same data) instead
    // of creating a fresh row.
    return _post(
      path: '/auth/register',
      body: {'email': email.trim(), 'password': password, 'name': name.trim()},
      onSuccess: (json) => AuthResult.ok(
        message: (json['message'] as String?) ??
            'Check your email for a verification code.',
      ),
      fallbackError: "Couldn't create your account. Try again.",
      sendBearer: true,
    );
  }

  /// Creates an anonymous user row on the server and stores the JWT
  /// locally so sync works for "Try without account" users. The same
  /// account upgrades to a full account when the guest later registers.
  Future<AuthResult> createGuestAccount() async {
    debugPrint('[AuthService] createGuestAccount');
    try {
      final res = await _client
          .post(
            Uri.parse('$_baseUrl/auth/guest'),
            headers: const {'content-type': 'application/json'},
            body: '{}',
          )
          .timeout(_timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return AuthResult.fail(_friendlyError(res,
            fallback: "Couldn't start a guest session."));
      }
      final json = _decode(res.body);
      final token = json['token'] as String?;
      if (token == null || token.isEmpty) {
        return AuthResult.fail('Server response missing token.');
      }
      final user = AuthUser.fromJson(_extractUser(json));
      _token = token;
      await _saveToken(token);
      await _saveUser(user);
      currentUserNotifier.value = user;
      debugPrint(
          '[AuthService] guest session started · user=${user.id} · email=${user.email}');
      return AuthResult.ok(user: user, token: token);
    } on TimeoutException {
      return AuthResult.fail("Mood8 didn't reply in time. Try again.");
    } catch (e) {
      return AuthResult.fail(_networkError(e));
    }
  }

  Future<AuthResult> verify({
    required String email,
    required String code,
  }) async {
    debugPrint('[AuthService] verify → $email code=$code');
    return _post(
      path: '/auth/verify',
      body: {'email': email.trim(), 'code': code.trim()},
      onSuccess: (json) => _persistFromAuthBody(json,
          fallbackMessage: 'Email verified — welcome.'),
      fallbackError: 'That code is incorrect or expired.',
    );
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    debugPrint('[AuthService] login → $email');
    return _post(
      path: '/auth/login',
      body: {'email': email.trim(), 'password': password},
      onSuccess: (json) => _persistFromAuthBody(json,
          fallbackMessage: 'Welcome back.'),
      fallbackError: 'Email or password is incorrect.',
    );
  }

  /// Posts a Google ID token to `/api/auth/google` and persists the
  /// returned JWT exactly like a normal login. The endpoint takes
  /// care of the four account-link branches (existing-by-google_sub,
  /// existing-by-email + link, guest-upgrade, new account) so this
  /// method has no client-side branching — the post-login sync that
  /// AuthGate kicks off handles either flow.
  ///
  /// `sendBearer: true` so that when a guest is currently signed in
  /// their JWT goes up and the server upgrades the guest row in
  /// place. AuthGate's `_lastUserId` guard suppresses the wipe for
  /// upgrades and triggers it for switches — same behaviour as
  /// register/verify.
  Future<AuthResult> signInWithGoogleIdToken(String idToken) async {
    debugPrint('[AuthService] signInWithGoogleIdToken (len=${idToken.length})');
    return _post(
      path: '/auth/google',
      body: {'id_token': idToken},
      onSuccess: (json) => _persistFromAuthBody(json,
          fallbackMessage: 'Welcome to Mood8.'),
      fallbackError: "Couldn't sign in with Google. Try again.",
      sendBearer: true,
    );
  }

  Future<AuthResult> forgotPassword({required String email}) async {
    debugPrint('[AuthService] forgotPassword → $email');
    return _post(
      path: '/auth/forgot-password',
      body: {'email': email.trim()},
      onSuccess: (json) => AuthResult.ok(
        message: (json['message'] as String?) ??
            'If that email exists, a reset code is on its way.',
      ),
      fallbackError: "Couldn't send the reset code. Try again.",
    );
  }

  Future<AuthResult> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    debugPrint('[AuthService] resetPassword → $email');
    return _post(
      path: '/auth/reset-password',
      body: {
        'email': email.trim(),
        'code': code.trim(),
        'new_password': newPassword,
      },
      onSuccess: (json) => AuthResult.ok(
        message: (json['message'] as String?) ??
            'Password updated. Sign in with your new password.',
      ),
      fallbackError: "Couldn't reset your password. Try again.",
    );
  }

  /// Fires the new prestige badge name once when the server-reported
  /// `profile_badge` for the current user changes (e.g. cron just
  /// promoted them past a threshold). Pulse-cleared back to null so a
  /// later upgrade can fire again.
  final ValueNotifier<String?> prestigeUnlockedNotifier =
      ValueNotifier<String?>(null);

  Future<AuthResult> refreshMe() async {
    final t = _token;
    if (t == null) return AuthResult.fail('Not signed in.');
    try {
      final res = await _client
          .get(
            Uri.parse('$_baseUrl/auth/me'),
            headers: {'authorization': 'Bearer $t'},
          )
          .timeout(_timeout);
      debugPrint('[AuthService] /auth/me → ${res.statusCode}');
      if (res.statusCode == 401) {
        await logout();
        return AuthResult.fail('Session expired. Sign in again.');
      }
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final body = _decode(res.body);
        final previousBadge = currentUserNotifier.value?.profileBadge;
        final user = AuthUser.fromJson(_extractUser(body));
        await _saveUser(user);
        currentUserNotifier.value = user;
        // Detect a prestige promotion since the last refresh on this
        // device. Skipped on the first /me of a session (previousBadge
        // is null in the cold-start case, but the persisted cache in
        // _saveUser/initialize means the second refresh has a
        // baseline). We pulse the notifier so AuthGate can show the
        // full-screen celebration once.
        if (user.profileBadge != null &&
            user.profileBadge!.isNotEmpty &&
            user.profileBadge != previousBadge &&
            previousBadge != null) {
          prestigeUnlockedNotifier.value = user.profileBadge;
          // Clear on the next microtask so listeners can re-arm.
          Future.microtask(() => prestigeUnlockedNotifier.value = null);
        }
        return AuthResult.ok(user: user);
      }
      return AuthResult.fail(_friendlyError(res));
    } catch (e) {
      return AuthResult.fail(_networkError(e));
    }
  }

  Future<void> logout() async {
    debugPrint('[AuthService] logout');
    _token = null;
    currentUserNotifier.value = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userKey);
    } catch (e) {
      debugPrint('[AuthService] logout storage clear failed: $e');
    }
  }

  // ─── internals ────────────────────────────────────────────────────────

  Future<AuthResult> _post({
    required String path,
    required Map<String, dynamic> body,
    required FutureOr<AuthResult> Function(Map<String, dynamic>) onSuccess,
    required String fallbackError,
    bool sendBearer = false,
  }) async {
    try {
      debugPrint('[AuthService] POST $path');
      final headers = <String, String>{
        'content-type': 'application/json',
      };
      // Used by register-from-guest so the backend can upgrade the
      // existing user row in place instead of creating a new one.
      if (sendBearer && _token != null) {
        headers['authorization'] = 'Bearer $_token';
      }
      final res = await _client
          .post(
            Uri.parse('$_baseUrl$path'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      debugPrint('[AuthService] POST $path → ${res.statusCode}');
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return await onSuccess(_decode(res.body));
      }
      return AuthResult.fail(_friendlyError(res, fallback: fallbackError));
    } on TimeoutException {
      debugPrint('[AuthService] POST $path TIMEOUT');
      return AuthResult.fail("Mood8 didn't reply in time. Try again.");
    } catch (e) {
      return AuthResult.fail(_networkError(e));
    }
  }

  Future<AuthResult> _persistFromAuthBody(
    Map<String, dynamic> json, {
    required String fallbackMessage,
  }) async {
    final data = json['data'];
    final token = (json['token'] ??
            json['access_token'] ??
            json['jwt'] ??
            (data is Map ? data['token'] : null)) as String?;
    if (token == null || token.isEmpty) {
      debugPrint('[AuthService] ❌ persist: response missing token');
      return AuthResult.fail('Server response missing token.');
    }
    final user = AuthUser.fromJson(_extractUser(json));
    _token = token;

    // Persist to SharedPreferences BEFORE flipping the notifier so anything
    // that subscribes and immediately reads getAuthToken() sees the same value.
    await _saveToken(token);
    await _saveUser(user);

    currentUserNotifier.value = user;
    debugPrint(
        '[AuthService] ✅ persisted; currentUserNotifier → ${user.email} (AuthGate should rebuild)');
    return AuthResult.ok(
      message: (json['message'] as String?) ?? fallbackMessage,
      user: user,
      token: token,
    );
  }

  Future<void> _saveToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
    } catch (e) {
      debugPrint('[AuthService] _saveToken failed: $e');
    }
  }

  Future<void> _saveUser(AuthUser user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, jsonEncode(user.toJson()));
    } catch (e) {
      debugPrint('[AuthService] _saveUser failed: $e');
    }
  }

  /// Async accessor for the persisted bearer token. Prefer the synchronous
  /// [token] getter inside this isolate; this is here for callers that want
  /// to read directly from disk (e.g. after a cold start before initialize()).
  Future<String?> getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey);
    } catch (e) {
      debugPrint('[AuthService] getAuthToken failed: $e');
      return null;
    }
  }

  Map<String, dynamic> _extractUser(Map<String, dynamic> json) {
    if (json['user'] is Map<String, dynamic>) {
      return json['user'] as Map<String, dynamic>;
    }
    final data = json['data'];
    if (data is Map<String, dynamic> && data['user'] is Map<String, dynamic>) {
      return data['user'] as Map<String, dynamic>;
    }
    return json;
  }

  Map<String, dynamic> _decode(String raw) {
    if (raw.isEmpty) return const {};
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    return {'data': decoded};
  }

  String _friendlyError(http.Response res, {String? fallback}) {
    try {
      final body = _decode(res.body);
      final msg =
          (body['message'] ?? body['error'] ?? body['detail'])?.toString();
      if (msg != null && msg.isNotEmpty) return msg;
    } catch (_) {}
    if (res.statusCode == 401) return 'Email or password is incorrect.';
    if (res.statusCode == 403) return "You don't have access to that.";
    if (res.statusCode == 404) return 'Account not found.';
    if (res.statusCode == 409) {
      return 'An account with this email already exists.';
    }
    if (res.statusCode == 429) {
      return 'Too many attempts. Wait a moment, then try again.';
    }
    if (res.statusCode >= 500) {
      return 'Mood8 is having a moment. Try again shortly.';
    }
    return fallback ?? 'Something went wrong (${res.statusCode}).';
  }

  String _networkError(Object e) {
    debugPrint('[AuthService] network error: $e');
    return "Couldn't reach Mood8. Check your connection.";
  }
}
