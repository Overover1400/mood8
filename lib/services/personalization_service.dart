import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/personalization.dart';
import 'auth_service.dart';

/// Talks to the rule-based suggestion engine on the server. Every call
/// degrades to null: no network, signed out, or an older server without
/// the endpoint simply means "no suggestions", never an error screen.
class PersonalizationService {
  PersonalizationService._();
  static final PersonalizationService _instance = PersonalizationService._();
  factory PersonalizationService() => _instance;

  static const String _baseUrl = 'https://mood8.app/api';
  static const Duration _timeout = Duration(seconds: 15);

  final http.Client _client = http.Client();

  Map<String, String> get _headers {
    final t = AuthService().token;
    return {
      'content-type': 'application/json',
      if (t != null) 'authorization': 'Bearer $t',
    };
  }

  bool get _signedIn => AuthService().token != null;

  Future<PersonalizationResult?> fetch({int limit = 5}) async {
    if (!_signedIn) return null;
    try {
      final res = await _client
          .get(Uri.parse('$_baseUrl/personalization/suggestions?limit=$limit'),
              headers: _headers)
          .timeout(_timeout);
      return _parse(res);
    } catch (e) {
      debugPrint('[personalization] fetch failed: $e');
      return null;
    }
  }

  /// Answer a follow-up question (or edit a profile answer). [value] is a
  /// String, or a list of strings for multi-select. Returns the refreshed
  /// suggestions.
  Future<PersonalizationResult?> answer(String key, Object value) async {
    if (!_signedIn) return null;
    try {
      final res = await _client
          .post(Uri.parse('$_baseUrl/personalization/answer'),
              headers: _headers,
              body: jsonEncode({'key': key, 'value': value}))
          .timeout(_timeout);
      return _parse(res);
    } catch (e) {
      debugPrint('[personalization] answer failed: $e');
      return null;
    }
  }

  PersonalizationResult? _parse(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    try {
      return PersonalizationResult.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[personalization] bad payload: $e');
      return null;
    }
  }
}
