import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/challenge.dart';
import 'auth_service.dart';

/// HTTP wrapper around `/api/challenges/*`. Singleton, owns one http
/// client, threads the auth JWT through every call.
class ChallengeService {
  ChallengeService._();
  static final ChallengeService _instance = ChallengeService._();
  factory ChallengeService() => _instance;

  static const String _baseUrl = 'https://mood8.app/api';
  static const Duration _timeout = Duration(seconds: 20);

  final http.Client _client = http.Client();

  Map<String, String> get _headers {
    final token = AuthService().token;
    return {
      'content-type': 'application/json',
      if (token != null) 'authorization': 'Bearer $token',
    };
  }

  // ── Create ────────────────────────────────────────────────────────

  Future<ChallengeCreateResult> create({
    required String title,
    required String description,
    required String category,
    required int durationDays,
    required int dailyDeadlineMinutesUtc,
    int? maxParticipants,
  }) async {
    final body = <String, dynamic>{
      'title': title,
      'description': description,
      'category': category,
      'duration_days': durationDays,
      'daily_deadline_minutes': dailyDeadlineMinutesUtc,
    };
    if (maxParticipants != null) {
      body['max_participants'] = maxParticipants;
    }
    final res = await _client
        .post(Uri.parse('$_baseUrl/challenges/create'),
            headers: _headers, body: jsonEncode(body))
        .timeout(_timeout);
    _throwIfHttpError(res);
    return ChallengeCreateResult.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  // ── List + mine + detail ──────────────────────────────────────────

  Future<List<ChallengeSummary>> list({
    String? category,
    String? search,
  }) async {
    final params = <String, String>{};
    if (category != null && category.isNotEmpty) params['category'] = category;
    if (search != null && search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }
    final qs = params.isEmpty
        ? ''
        : '?${params.entries.map((e) =>
            '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&')}';
    final res = await _client
        .get(Uri.parse('$_baseUrl/challenges/list$qs'),
            headers: _headers)
        .timeout(_timeout);
    _throwIfHttpError(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (body['challenges'] as List?) ?? const [];
    return list
        .map((c) => ChallengeSummary.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  Future<({List<ChallengeSummary> created, List<ChallengeSummary> joined})>
      mine() async {
    final res = await _client
        .get(Uri.parse('$_baseUrl/challenges/mine'), headers: _headers)
        .timeout(_timeout);
    _throwIfHttpError(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (
      created: ((body['created'] as List?) ?? [])
          .map((c) => ChallengeSummary.fromJson(c as Map<String, dynamic>))
          .toList(),
      joined: ((body['joined'] as List?) ?? [])
          .map((c) => ChallengeSummary.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<ChallengeDetail> detail(int challengeId) async {
    final res = await _client
        .get(Uri.parse('$_baseUrl/challenges/$challengeId'),
            headers: _headers)
        .timeout(_timeout);
    _throwIfHttpError(res);
    return ChallengeDetail.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  // ── Join request flow ─────────────────────────────────────────────

  /// Requests to join. Throws ChallengeError on backend rejection
  /// (already a participant, previously removed, full, request exists).
  Future<int> requestJoin(int challengeId) async {
    final res = await _client
        .post(
          Uri.parse('$_baseUrl/challenges/$challengeId/join-request'),
          headers: _headers,
          body: '{}',
        )
        .timeout(_timeout);
    _throwIfHttpError(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['request_id'] as num).toInt();
  }

  Future<List<JoinRequest>> joinRequests(int challengeId) async {
    final res = await _client
        .get(
          Uri.parse('$_baseUrl/challenges/$challengeId/join-requests'),
          headers: _headers,
        )
        .timeout(_timeout);
    _throwIfHttpError(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (body['requests'] as List?) ?? const [];
    return list
        .map((r) => JoinRequest.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<bool> resolveJoinRequest({
    required int challengeId,
    required int requestId,
    required bool approve,
  }) async {
    final res = await _client
        .post(
          Uri.parse(
              '$_baseUrl/challenges/$challengeId/join-requests/$requestId/resolve'),
          headers: _headers,
          body: jsonEncode({'approve': approve}),
        )
        .timeout(_timeout);
    _throwIfHttpError(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return body['approved'] as bool? ?? false;
  }

  // ── Check-in + report ─────────────────────────────────────────────

  Future<CheckinResult> checkin(int challengeId) async {
    final res = await _client
        .post(Uri.parse('$_baseUrl/challenges/$challengeId/checkin'),
            headers: _headers, body: '{}')
        .timeout(_timeout);
    _throwIfHttpError(res);
    return CheckinResult.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  /// Fetch the global Challenge Ranking. Returns the top-100 public
  /// list + the requester's own {position, score, tier}. Server-side
  /// authoritative — the client can't influence what comes back.
  Future<Leaderboard> leaderboard() async {
    final res = await _client
        .get(Uri.parse('$_baseUrl/ranking/leaderboard'),
            headers: _headers)
        .timeout(_timeout);
    _throwIfHttpError(res);
    return Leaderboard.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  Future<void> report(int challengeId, String reason) async {
    final res = await _client
        .post(
          Uri.parse('$_baseUrl/challenges/$challengeId/report'),
          headers: _headers,
          body: jsonEncode({'reason': reason}),
        )
        .timeout(_timeout);
    _throwIfHttpError(res);
  }

  /// Owner-only hard delete. Removes the challenge and every child
  /// row (participants, checkins, join requests, comments, upvotes,
  /// reports, related notifications) server-side in one transaction.
  /// Returns 404 for callers who aren't the creator — the client
  /// should treat that identically to "already gone."
  Future<void> delete(int challengeId) async {
    final res = await _client
        .delete(
          Uri.parse('$_baseUrl/challenges/$challengeId'),
          headers: _headers,
        )
        .timeout(_timeout);
    _throwIfHttpError(res);
  }

  // ── Leave (voluntary give-up; may auto-close the challenge) ────────

  /// Voluntarily leave a challenge you're an active participant in.
  /// Returns true when leaving emptied the challenge and the server
  /// auto-closed it.
  Future<bool> leave(int challengeId) async {
    final res = await _client
        .post(
          Uri.parse('$_baseUrl/challenges/$challengeId/leave'),
          headers: _headers,
          body: '{}',
        )
        .timeout(_timeout);
    _throwIfHttpError(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return body['challenge_closed'] as bool? ?? false;
  }

  // ── Friends (follow) + invites ────────────────────────────────────

  /// Search users to follow / invite by display name (>= 2 chars).
  Future<List<ChallengeUser>> searchUsers(String query) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    final res = await _client
        .get(
          Uri.parse(
              '$_baseUrl/users/search?q=${Uri.encodeQueryComponent(q)}'),
          headers: _headers,
        )
        .timeout(_timeout);
    _throwIfHttpError(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return ((body['results'] as List?) ?? const [])
        .map((r) => ChallengeUser.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// The people you follow — your invite candidates.
  Future<List<ChallengeUser>> friends() async {
    final res = await _client
        .get(Uri.parse('$_baseUrl/friends'), headers: _headers)
        .timeout(_timeout);
    _throwIfHttpError(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return ((body['friends'] as List?) ?? const [])
        .map((r) => ChallengeUser.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> follow(int userId) async {
    final res = await _client
        .post(Uri.parse('$_baseUrl/users/$userId/follow'), headers: _headers)
        .timeout(_timeout);
    _throwIfHttpError(res);
  }

  Future<void> unfollow(int userId) async {
    final res = await _client
        .delete(Uri.parse('$_baseUrl/users/$userId/follow'), headers: _headers)
        .timeout(_timeout);
    _throwIfHttpError(res);
  }

  /// Invite users (by id) to a challenge. Returns how many invites the
  /// server actually sent (skips already-joined / already-invited).
  Future<int> invite(int challengeId, List<int> inviteeIds) async {
    if (inviteeIds.isEmpty) return 0;
    final res = await _client
        .post(
          Uri.parse('$_baseUrl/challenges/$challengeId/invite'),
          headers: _headers,
          body: jsonEncode({'invitee_ids': inviteeIds}),
        )
        .timeout(_timeout);
    _throwIfHttpError(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['invited'] as num?)?.toInt() ?? 0;
  }

  // ── Push token registration (real OS push) ────────────────────────

  /// Register this device's push token so the backend can send daily
  /// challenge reminders + invite pushes. Best-effort — never throws.
  Future<void> registerPushToken(String token, {String? platform}) async {
    try {
      final res = await _client
          .post(
            Uri.parse('$_baseUrl/push/register'),
            headers: _headers,
            body: jsonEncode({'token': token, 'platform': platform}),
          )
          .timeout(_timeout);
      _throwIfHttpError(res);
    } catch (e) {
      debugPrint('registerPushToken failed: $e');
    }
  }

  Future<void> unregisterPushToken(String token) async {
    try {
      await _client
          .post(
            Uri.parse('$_baseUrl/push/unregister'),
            headers: _headers,
            body: jsonEncode({'token': token}),
          )
          .timeout(_timeout);
    } catch (e) {
      debugPrint('unregisterPushToken failed: $e');
    }
  }

  // ── Upvotes ────────────────────────────────────────────────────────

  /// Toggle the signed-in user's upvote. Returns the new state +
  /// total count so callers can flip optimistically + reconcile.
  Future<({bool upvoted, int count})> toggleUpvote(int challengeId) async {
    final res = await _client
        .post(Uri.parse('$_baseUrl/challenges/$challengeId/upvote'),
            headers: _headers, body: '{}')
        .timeout(_timeout);
    _throwIfHttpError(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (
      upvoted: body['upvoted'] as bool? ?? false,
      count: (body['upvote_count'] as num?)?.toInt() ?? 0,
    );
  }

  // ── Comments ───────────────────────────────────────────────────────

  /// Post a comment. The server runs AI moderation; on rejection
  /// returns `{saved:false, reason}` which we surface as a typed
  /// result rather than throwing.
  Future<CommentCreateResult> postComment({
    required int challengeId,
    required String text,
  }) async {
    final res = await _client
        .post(
          Uri.parse('$_baseUrl/challenges/$challengeId/comments'),
          headers: _headers,
          body: jsonEncode({'text': text}),
        )
        .timeout(_timeout);
    _throwIfHttpError(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['saved'] == false) {
      return CommentCreateResult.rejected(
        body['reason'] as String? ?? 'Please rephrase.',
      );
    }
    return CommentCreateResult.saved(
      ChallengeComment.fromJson(
        body['comment'] as Map<String, dynamic>,
      ),
    );
  }

  Future<List<ChallengeComment>> listComments(int challengeId) async {
    final res = await _client
        .get(Uri.parse('$_baseUrl/challenges/$challengeId/comments'),
            headers: _headers)
        .timeout(_timeout);
    _throwIfHttpError(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return ((body['comments'] as List?) ?? const [])
        .map((c) => ChallengeComment.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteComment({
    required int challengeId,
    required int commentId,
  }) async {
    final res = await _client
        .delete(
          Uri.parse(
              '$_baseUrl/challenges/$challengeId/comments/$commentId'),
          headers: _headers,
        )
        .timeout(_timeout);
    _throwIfHttpError(res);
  }

  Future<void> reportComment({
    required int commentId,
    required String reason,
  }) async {
    final res = await _client
        .post(
          Uri.parse('$_baseUrl/challenges/comments/$commentId/report'),
          headers: _headers,
          body: jsonEncode({'reason': reason}),
        )
        .timeout(_timeout);
    _throwIfHttpError(res);
  }

  // ── Plumbing ──────────────────────────────────────────────────────

  void _throwIfHttpError(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    String message;
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['detail'] is String) {
        message = body['detail'] as String;
      } else {
        message = res.body;
      }
    } catch (_) {
      message = res.body;
    }
    debugPrint(
        '[Challenges] HTTP ${res.statusCode}: $message');
    throw ChallengeError(res.statusCode, message);
  }
}

/// Tagged-union result for the comment-create endpoint.
class CommentCreateResult {
  const CommentCreateResult._({this.comment, this.rejectionReason});
  final ChallengeComment? comment;
  final String? rejectionReason;
  bool get isSaved => comment != null;
  bool get isRejected => rejectionReason != null;
  factory CommentCreateResult.saved(ChallengeComment c) =>
      CommentCreateResult._(comment: c);
  factory CommentCreateResult.rejected(String reason) =>
      CommentCreateResult._(rejectionReason: reason);
}

/// Thrown by [ChallengeService] when the backend returns a non-2xx.
/// UI surfaces [message] directly to the user.
class ChallengeError implements Exception {
  ChallengeError(this.statusCode, this.message);
  final int statusCode;
  final String message;
  @override
  String toString() => 'ChallengeError($statusCode): $message';
}
