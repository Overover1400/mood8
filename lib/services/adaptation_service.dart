import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

/// One proposed change to the user's plan.
///
/// The adaptation engine lives entirely on the server: it correlates
/// the user's check-ins with their completion history and decides when
/// a habit needs a different time, a smaller target, or a bigger one.
/// The client's only job is to render a single card and send back
/// accept or decline.
class AdaptationProposal {
  const AdaptationProposal({
    required this.id,
    required this.habitId,
    required this.habitTitle,
    required this.kind,
    required this.rationale,
    this.fromValue,
    this.toValue,
  });

  final int id;
  final String habitId;
  final String habitTitle;
  /// time · quantity · increase · floor
  final String kind;
  final String rationale;
  final String? fromValue;
  final String? toValue;

  factory AdaptationProposal.fromJson(Map<String, dynamic> j) =>
      AdaptationProposal(
        id: (j['id'] as num).toInt(),
        habitId: (j['habit_id'] as String?) ?? '',
        habitTitle: (j['habit_title'] as String?) ?? 'this habit',
        kind: (j['kind'] as String?) ?? 'time',
        rationale: (j['rationale'] as String?) ?? '',
        fromValue: j['from'] as String?,
        toValue: j['to'] as String?,
      );

  /// Label for the accept button — phrased as the action, not "OK".
  String get acceptLabel {
    switch (kind) {
      case 'time':
        return 'Move it';
      case 'quantity':
        return 'Make it smaller';
      case 'increase':
        return 'Level up';
      default:
        return 'Do it';
    }
  }

  String get declineLabel => kind == 'increase' ? 'Not yet' : 'Keep it';
}

/// One past adaptation with its measured outcome. Powers the
/// "we moved your workout to 6 PM — completion went 30% → 85%" list.
class AdaptationRecord {
  const AdaptationRecord({
    required this.habitTitle,
    required this.kind,
    required this.status,
    required this.rationale,
    this.fromValue,
    this.toValue,
    this.beforeRate,
    this.afterRate,
    this.delta,
    this.decidedAt,
  });

  final String habitTitle;
  final String kind;
  final String status;
  final String rationale;
  final String? fromValue;
  final String? toValue;
  final double? beforeRate;
  final double? afterRate;
  final double? delta;
  final DateTime? decidedAt;

  bool get hasOutcome => beforeRate != null && afterRate != null;

  factory AdaptationRecord.fromJson(Map<String, dynamic> j) =>
      AdaptationRecord(
        habitTitle: (j['habit_title'] as String?) ?? '',
        kind: (j['kind'] as String?) ?? '',
        status: (j['status'] as String?) ?? '',
        rationale: (j['rationale'] as String?) ?? '',
        fromValue: j['from'] as String?,
        toValue: j['to'] as String?,
        beforeRate: (j['before_rate'] as num?)?.toDouble(),
        afterRate: (j['after_rate'] as num?)?.toDouble(),
        delta: (j['delta'] as num?)?.toDouble(),
        decidedAt: j['decided_at'] is String
            ? DateTime.tryParse(j['decided_at'] as String)
            : null,
      );
}

class AdaptationService {
  AdaptationService._();
  static final AdaptationService _instance = AdaptationService._();
  factory AdaptationService() => _instance;

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

  /// Today's card, if the engine has one. Returns null for signed-out
  /// users, on any error, and on the (common) days with nothing to say.
  Future<AdaptationProposal?> todaysProposal() async {
    if (!_signedIn) return null;
    try {
      final res = await _client
          .get(Uri.parse('$_baseUrl/adapt/proposal'), headers: _headers)
          .timeout(_timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final p = body['proposal'];
      if (p == null) return null;
      return AdaptationProposal.fromJson(p as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[adapt] proposal fetch failed: $e');
      return null;
    }
  }

  Future<bool> accept(int id) => _decide(id, 'accept');

  Future<bool> decline(int id) => _decide(id, 'decline');

  Future<bool> _decide(int id, String what) async {
    if (!_signedIn) return false;
    try {
      final res = await _client
          .post(Uri.parse('$_baseUrl/adapt/$id/$what'), headers: _headers)
          .timeout(_timeout);
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (e) {
      debugPrint('[adapt] $what failed: $e');
      return false;
    }
  }

  /// Fixed-option reason, one tap, sent after a second miss.
  Future<void> reportMissReason({
    required String habitId,
    required String reason,
  }) async {
    if (!_signedIn) return;
    try {
      await _client
          .post(Uri.parse('$_baseUrl/habits/miss-reason'),
              headers: _headers,
              body: jsonEncode({'habit_id': habitId, 'reason': reason}))
          .timeout(_timeout);
    } catch (e) {
      debugPrint('[adapt] miss reason failed: $e');
    }
  }

  Future<List<AdaptationRecord>> history() async {
    if (!_signedIn) return const [];
    try {
      final res = await _client
          .get(Uri.parse('$_baseUrl/adapt/history'), headers: _headers)
          .timeout(_timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) return const [];
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return ((body['adaptations'] as List?) ?? const [])
          .map((e) => AdaptationRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[adapt] history failed: $e');
      return const [];
    }
  }

  /// Save the six onboarding answers. These seed the cold-start engine,
  /// which is what makes day one useful before any personal data exists.
  Future<void> saveOnboarding(Map<String, dynamic> answers) async {
    if (!_signedIn) return;
    try {
      await _client
          .post(Uri.parse('$_baseUrl/onboarding'),
              headers: _headers, body: jsonEncode(answers))
          .timeout(_timeout);
    } catch (e) {
      debugPrint('[adapt] onboarding save failed: $e');
    }
  }
}
