import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

/// Client for the device-linking (Wear OS pairing) endpoints.
///
/// Two roles share this one service:
///  * The **watch** calls [requestCode] (no auth) to get a pairing code +
///    secret poll token, then polls [pollStatus] until it receives a JWT.
///  * The **phone/web** app calls [approveCode] (JWT-authed) to bind a
///    code the user typed to their signed-in account.
class DeviceLinkService {
  DeviceLinkService._();
  static final DeviceLinkService _instance = DeviceLinkService._();
  factory DeviceLinkService() => _instance;

  static const String _baseUrl = 'https://mood8.app/api';
  static const Duration _timeout = Duration(seconds: 12);
  final http.Client _client = http.Client();

  /// Watch side: mint a pairing code. Returns null on any failure so the
  /// caller can show a "couldn't get a code" retry state.
  Future<DeviceLinkRequest?> requestCode() async {
    try {
      final res = await _client
          .post(Uri.parse('$_baseUrl/device/link/request'))
          .timeout(_timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint('[DeviceLink] request ${res.statusCode}: ${res.body}');
        return null;
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final code = body['code'] as String?;
      final pollToken = body['poll_token'] as String?;
      if (code == null || pollToken == null) return null;
      return DeviceLinkRequest(
        code: code,
        pollToken: pollToken,
        expiresAt: DateTime.tryParse(body['expires_at'] as String? ?? ''),
      );
    } catch (e) {
      debugPrint('[DeviceLink] requestCode error: $e');
      return null;
    }
  }

  /// Watch side: poll pairing status. On approval the response carries the
  /// JWT exactly once. Network hiccups surface as [DeviceLinkState.pending]
  /// so the caller just keeps polling rather than aborting.
  Future<DeviceLinkStatus> pollStatus(String pollToken) async {
    try {
      final res = await _client
          .get(Uri.parse(
              '$_baseUrl/device/link/status?poll_token=$pollToken'))
          .timeout(_timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint('[DeviceLink] status ${res.statusCode}: ${res.body}');
        return const DeviceLinkStatus(state: DeviceLinkState.pending);
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final raw = body['status'] as String? ?? 'pending';
      final token = body['token'] as String?;
      return DeviceLinkStatus(
        state: _stateFrom(raw),
        token: token,
      );
    } on TimeoutException {
      return const DeviceLinkStatus(state: DeviceLinkState.pending);
    } catch (e) {
      debugPrint('[DeviceLink] pollStatus error: $e');
      return const DeviceLinkStatus(state: DeviceLinkState.pending);
    }
  }

  /// Phone/web side: approve a code the user typed while signed in. Returns
  /// a user-facing result. Requires an authenticated session (any method —
  /// password or Google).
  Future<DeviceLinkApproveResult> approveCode(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      return const DeviceLinkApproveResult(
          success: false, message: 'Enter the code shown on your device.');
    }
    final auth = AuthService().authHeader;
    if (auth == null) {
      return const DeviceLinkApproveResult(
          success: false, message: 'Please sign in first.');
    }
    try {
      final res = await _client
          .post(
            Uri.parse('$_baseUrl/device/link/approve'),
            headers: {'authorization': auth, 'content-type': 'application/json'},
            body: jsonEncode({'code': trimmed}),
          )
          .timeout(_timeout);
      final body = _tryDecode(res.body);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return DeviceLinkApproveResult(
          success: true,
          message: body?['message'] as String? ?? 'Device linked 🎉',
        );
      }
      final detail = body?['detail'];
      String message = 'Code not found or expired.';
      if (detail is Map && detail['message'] is String) {
        message = detail['message'] as String;
      } else if (detail is String) {
        message = detail;
      }
      return DeviceLinkApproveResult(success: false, message: message);
    } on TimeoutException {
      return const DeviceLinkApproveResult(
          success: false, message: 'Timed out — check your connection.');
    } catch (e) {
      debugPrint('[DeviceLink] approveCode error: $e');
      return const DeviceLinkApproveResult(
          success: false, message: 'Something went wrong. Try again.');
    }
  }

  DeviceLinkState _stateFrom(String raw) {
    switch (raw) {
      case 'approved':
        return DeviceLinkState.approved;
      case 'expired':
      case 'consumed':
        return DeviceLinkState.expired;
      default:
        return DeviceLinkState.pending;
    }
  }

  Map<String, dynamic>? _tryDecode(String body) {
    try {
      final v = jsonDecode(body);
      return v is Map<String, dynamic> ? v : null;
    } catch (_) {
      return null;
    }
  }
}

class DeviceLinkRequest {
  const DeviceLinkRequest({
    required this.code,
    required this.pollToken,
    required this.expiresAt,
  });
  final String code;
  final String pollToken;
  final DateTime? expiresAt;
}

enum DeviceLinkState { pending, approved, expired }

class DeviceLinkStatus {
  const DeviceLinkStatus({required this.state, this.token});
  final DeviceLinkState state;
  final String? token;
}

class DeviceLinkApproveResult {
  const DeviceLinkApproveResult({required this.success, required this.message});
  final bool success;
  final String message;
}
