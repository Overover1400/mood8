import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.unauthorized = false});
  final String message;
  final int? statusCode;
  final bool unauthorized;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Thin HTTP wrapper used by feature services that want a shared Bearer
/// header and consistent error handling. AuthService stays self-contained
/// for its own /auth/* endpoints to avoid a circular import.
class ApiClient {
  ApiClient._();
  static final ApiClient _instance = ApiClient._();
  factory ApiClient() => _instance;

  static const String _baseUrl = 'https://mood8.app/api';
  static const Duration _timeout = Duration(seconds: 30);

  final http.Client _client = http.Client();

  Map<String, String> _headers({bool useAuth = false, Map<String, String>? extra}) {
    final h = <String, String>{
      'content-type': 'application/json',
      'accept': 'application/json',
    };
    if (useAuth) {
      final t = AuthService().authHeader;
      if (t != null) h['authorization'] = t;
    }
    if (extra != null) h.addAll(extra);
    return h;
  }

  Future<Map<String, dynamic>> get(
    String path, {
    bool useAuth = false,
    Map<String, String>? query,
  }) {
    final uri = Uri.parse('$_baseUrl$path')
        .replace(queryParameters: query ?? {});
    return _send(() => _client.get(uri, headers: _headers(useAuth: useAuth)));
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool useAuth = false,
  }) {
    return _send(() => _client.post(
          Uri.parse('$_baseUrl$path'),
          headers: _headers(useAuth: useAuth),
          body: jsonEncode(body ?? const {}),
        ));
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
    bool useAuth = false,
  }) {
    return _send(() => _client.put(
          Uri.parse('$_baseUrl$path'),
          headers: _headers(useAuth: useAuth),
          body: jsonEncode(body ?? const {}),
        ));
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    bool useAuth = false,
  }) {
    return _send(() => _client.delete(
          Uri.parse('$_baseUrl$path'),
          headers: _headers(useAuth: useAuth),
        ));
  }

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request,
  ) async {
    http.Response res;
    try {
      res = await request().timeout(_timeout);
    } on TimeoutException {
      throw ApiException("Mood8 didn't reply in time.");
    } catch (e) {
      debugPrint('ApiClient network error: $e');
      throw ApiException("Couldn't reach Mood8.");
    }

    if (res.statusCode == 401) {
      // Auto sign-out on token rejection.
      await AuthService().logout();
      throw ApiException('Session expired.',
          statusCode: 401, unauthorized: true);
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(
        _friendly(res),
        statusCode: res.statusCode,
      );
    }
    if (res.body.isEmpty) return const {};
    final decoded = jsonDecode(res.body);
    if (decoded is Map<String, dynamic>) return decoded;
    return {'data': decoded};
  }

  String _friendly(http.Response res) {
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map) {
        final msg = (decoded['message'] ?? decoded['error'] ?? decoded['detail'])
            ?.toString();
        if (msg != null && msg.isNotEmpty) return msg;
      }
    } catch (_) {}
    if (res.statusCode >= 500) return 'Mood8 is having a moment.';
    if (res.statusCode == 429) return 'Too many requests.';
    return 'Request failed (${res.statusCode}).';
  }
}
