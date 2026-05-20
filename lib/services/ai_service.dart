import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/chat_message.dart';
import 'auth_service.dart';
import '../models/daily_data.dart';
import '../models/routine_category.dart';

class AiException implements Exception {
  AiException(
    this.message, {
    this.retryable = true,
    this.dailyLimitReached = false,
  });
  final String message;
  final bool retryable;
  /// Backend returned 402 with `daily_limit_reached: true` (free-tier
  /// chat cap). Callers should surface the paywall, not a generic error.
  final bool dailyLimitReached;

  @override
  String toString() => 'AiException: $message';
}

class ReflectionResult {
  ReflectionResult({
    required this.reflection,
    this.suggestion,
    this.identityScores,
  });

  final String reflection;
  final String? suggestion;
  final Map<String, double>? identityScores;
}

class RoutineSuggestion {
  RoutineSuggestion({
    required this.title,
    required this.hour,
    required this.minute,
    required this.durationMinutes,
    required this.category,
    required this.meta,
  });

  final String title;
  final int hour;
  final int minute;
  final int durationMinutes;
  final RoutineCategory category;
  final String meta;
}

class AiService {
  AiService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? 'https://mood8.app/api';

  final http.Client _client;
  final String _baseUrl;
  static const Duration _timeout = Duration(seconds: 30);

  Future<bool> healthCheck() async {
    try {
      final res = await _client
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(_timeout);
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (e) {
      debugPrint('AiService.healthCheck failed: $e');
      return false;
    }
  }

  Future<ReflectionResult> getReflection(DailyData data) async {
    final body = await _postJson('/reflect', data.toJson());
    final text = _pickString(body, const ['reflection', 'text', 'content']);
    if (text == null || text.isEmpty) {
      throw AiException('Empty reflection from server.', retryable: true);
    }
    return ReflectionResult(
      reflection: text,
      suggestion: _pickString(body, const ['suggestion', 'next_action']),
      identityScores: _readIdentityScores(body['identity_scores']),
    );
  }

  Future<String> chat(
    List<ChatMessage> messages, {
    DailyData? context,
  }) async {
    final payload = <String, dynamic>{
      'messages': messages
          .map((m) => {'role': m.role, 'content': m.content})
          .toList(),
      if (context != null) 'context': context.toJson(),
    };
    final body = await _postJson('/chat', payload);
    final text = _pickString(
        body, const ['message', 'response', 'reply', 'content']);
    if (text == null || text.isEmpty) {
      throw AiException('Empty reply from server.', retryable: true);
    }
    return text;
  }

  Future<String> explainInsight({
    required String title,
    String? description,
  }) async {
    final body = await _postJson('/chat', {
      'messages': [
        {
          'role': 'system',
          'content':
              'You are Mood8 coach. Given a discovered personal pattern, '
                  'explain in 2 short, warm sentences why it likely matters '
                  'and one concrete next action. No emoji, no preamble.',
        },
        {
          'role': 'user',
          'content': description == null ? title : '$title\n\n$description',
        },
      ],
    });
    return _pickString(
            body, const ['message', 'response', 'reply', 'content']) ??
        '';
  }

  Future<String> weeklyNarrative({
    required String summary,
    DailyData? context,
  }) async {
    final body = await _postJson('/chat', {
      'messages': [
        {
          'role': 'system',
          'content':
              'You are Mood8 coach. Write 3-5 sentences of an honest, '
                  'warm narrative about the user\'s week using only the '
                  'facts provided. No bullet points, no emoji.',
        },
        {'role': 'user', 'content': summary},
      ],
      if (context != null) 'context': context.toJson(),
    });
    return _pickString(
            body, const ['message', 'response', 'reply', 'content']) ??
        '';
  }

  Future<RoutineSuggestion?> getSuggestion(DailyData data) async {
    final body = await _postJson('/suggest', data.toJson());
    final suggestion = body['suggestion'] is Map<String, dynamic>
        ? body['suggestion'] as Map<String, dynamic>
        : body;
    final title = _pickString(suggestion, const ['title', 'name']);
    if (title == null || title.isEmpty) return null;

    final timeStr = _pickString(suggestion, const ['time']);
    int hour = 9;
    int minute = 0;
    if (timeStr != null && timeStr.contains(':')) {
      final parts = timeStr.split(':');
      hour = int.tryParse(parts[0]) ?? hour;
      minute = int.tryParse(parts[1]) ?? minute;
    } else {
      hour = (suggestion['hour'] as num?)?.toInt() ?? hour;
      minute = (suggestion['minute'] as num?)?.toInt() ?? minute;
    }

    final duration = (suggestion['duration_minutes'] as num?)?.toInt() ??
        (suggestion['duration'] as num?)?.toInt() ??
        30;
    final catRaw = _pickString(suggestion, const ['category']) ?? 'work';
    final category = RoutineCategory.values.firstWhere(
      (c) => c.name == catRaw.toLowerCase(),
      orElse: () => RoutineCategory.work,
    );

    return RoutineSuggestion(
      title: title,
      hour: hour,
      minute: minute,
      durationMinutes: duration,
      category: category,
      meta: _pickString(suggestion, const ['meta', 'note', 'description']) ??
          '',
    );
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> payload,
  ) async {
    final uri = Uri.parse('$_baseUrl$path');
    final headers = <String, String>{
      'content-type': 'application/json',
    };
    final token = AuthService().token;
    if (token != null) {
      headers['authorization'] = 'Bearer $token';
    }
    http.Response res;
    try {
      res = await _client
          .post(
            uri,
            headers: headers,
            body: jsonEncode(payload),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw AiException(
        'Mood8 is thinking deeply… try again in a moment.',
        retryable: true,
      );
    } catch (e) {
      throw AiException(
        "Can't reach Mood8 right now. Check your connection.",
        retryable: true,
      );
    }

    if (res.statusCode == 402) {
      throw AiException(
        "You've hit today's free-tier limit. Upgrade for unlimited chat.",
        retryable: false,
        dailyLimitReached: true,
      );
    }
    if (res.statusCode == 429) {
      throw AiException(
        'Too many requests right now. Take a breath, try again soon.',
        retryable: true,
      );
    }
    if (res.statusCode >= 500) {
      throw AiException(
        'Mood8 is having a moment. Try again in a bit.',
        retryable: true,
      );
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AiException(
        'Request failed (${res.statusCode}).',
        retryable: false,
      );
    }

    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is String) return {'message': decoded};
      throw const FormatException('unexpected JSON shape');
    } catch (e) {
      throw AiException('Got a confused response from the server.',
          retryable: false);
    }
  }

  String? _pickString(Map<String, dynamic> map, List<String> keys) {
    for (final k in keys) {
      final v = map[k];
      if (v is String && v.isNotEmpty) return v;
    }
    return null;
  }

  Map<String, double>? _readIdentityScores(dynamic raw) {
    if (raw is! Map) return null;
    final result = <String, double>{};
    raw.forEach((k, v) {
      if (k is String && v is num) result[k] = v.toDouble();
    });
    return result.isEmpty ? null : result;
  }

  void close() => _client.close();
}
