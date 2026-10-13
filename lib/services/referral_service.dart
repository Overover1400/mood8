import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/entitlement.dart';
import 'auth_service.dart';

/// The signed-in user's own referral state.
class ReferralInfo {
  const ReferralInfo({
    required this.code,
    required this.url,
    required this.rewardDays,
    this.invited = 0,
    this.joined = 0,
    this.pending = 0,
    this.daysEarned = 0,
    this.maxRewarded = 20,
    this.invitedBy,
    this.rewards = RewardsProgress.empty,
  });

  final String code;
  final String url;
  final int rewardDays;
  final int invited;
  final int joined;
  final int pending;
  final int daysEarned;
  final int maxRewarded;

  /// Name of whoever invited this user, if they came through an invite.
  final String? invitedBy;

  /// Progress toward the 1-month rewards; empty when the server doesn't
  /// send it.
  final RewardsProgress rewards;

  factory ReferralInfo.fromJson(Map<String, dynamic> j) => ReferralInfo(
        code: (j['code'] as String?) ?? '',
        url: (j['url'] as String?) ?? '',
        rewardDays: (j['reward_days'] as num?)?.toInt() ?? 7,
        invited: (j['invited'] as num?)?.toInt() ?? 0,
        joined: (j['joined'] as num?)?.toInt() ?? 0,
        pending: (j['pending'] as num?)?.toInt() ?? 0,
        daysEarned: (j['days_earned'] as num?)?.toInt() ?? 0,
        maxRewarded: (j['max_rewarded'] as num?)?.toInt() ?? 20,
        invitedBy: j['invited_by'] as String?,
        rewards: RewardsProgress.fromJson(j['rewards']),
      );
}

/// Outcome of a call that can fail for a reason worth showing.
class ReferralResult {
  const ReferralResult.ok({this.message, this.challengeId, this.pendingReward = false})
      : ok = true,
        needsAccount = false,
        definitive = false;
  const ReferralResult.fail(this.message,
      {this.needsAccount = false, this.definitive = false})
      : ok = false,
        challengeId = null,
        pendingReward = false;

  final bool ok;
  final String? message;
  final int? challengeId;

  /// The server accepted the code but pays out only once the account is
  /// a real, verified one (the user is still a guest).
  final bool pendingReward;

  /// The server said "sign in or create an account first".
  final bool needsAccount;

  /// A retry can never succeed (bad code, already used, too late, ...),
  /// so a stored pending invite should be dropped.
  final bool definitive;
}

/// Thin client for the referral + invite-link endpoints. The rules
/// (who gets rewarded, caps, anti-abuse) all live on the server.
class ReferralService {
  ReferralService._();
  static final ReferralService _instance = ReferralService._();
  factory ReferralService() => _instance;

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

  bool get signedIn => AuthService().token != null;

  String _detail(http.Response res, String fallback) {
    try {
      final b = jsonDecode(res.body);
      if (b is Map && b['detail'] is String) return b['detail'] as String;
    } catch (_) {}
    return fallback;
  }

  /// Own code, link and counters. Null for guests, signed-out users
  /// and on any error. [guestBlocked] is set when the server refused
  /// because the account is a guest.
  Future<ReferralInfo?> me() async {
    if (!signedIn) return null;
    try {
      final res = await _client
          .get(Uri.parse('$_baseUrl/referral/me'), headers: _headers)
          .timeout(_timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      return ReferralInfo.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[referral] me failed: $e');
      return null;
    }
  }

  Future<ReferralResult> claim(
    String code, {
    String? source,
    String? campaign,
    String? medium,
    String? challengeToken,
  }) async {
    if (!signedIn) return const ReferralResult.fail('Sign in first.');
    try {
      final res = await _client
          .post(Uri.parse('$_baseUrl/referral/claim'),
              headers: _headers,
              body: jsonEncode({
                'code': code,
                'source': ?source,
                'campaign': ?campaign,
                'medium': ?medium,
                'challenge_token': ?challengeToken,
              }))
          .timeout(_timeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final b = jsonDecode(res.body) as Map<String, dynamic>;
        return ReferralResult.ok(
            pendingReward: b['reward_pending'] == true);
      }
      return ReferralResult.fail(
        _detail(res, 'Couldn\'t use that code.'),
        // 5xx / rate limits are worth retrying; the 4xx answers are final.
        definitive: res.statusCode >= 400 && res.statusCode < 500,
      );
    } catch (e) {
      debugPrint('[referral] claim failed: $e');
      return const ReferralResult.fail('No connection. Try again.');
    }
  }

  /// Join a challenge through its invite link. Needs a real account.
  Future<ReferralResult> joinViaInvite(String token, {String? ref}) async {
    if (!signedIn) {
      return const ReferralResult.fail('Sign in to join.', needsAccount: true);
    }
    try {
      final res = await _client
          .post(Uri.parse('$_baseUrl/c/${Uri.encodeComponent(token)}/join'),
              headers: _headers, body: jsonEncode({'ref': ?ref}))
          .timeout(_timeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final b = jsonDecode(res.body) as Map<String, dynamic>;
        return ReferralResult.ok(
            challengeId: (b['challenge_id'] as num?)?.toInt());
      }
      return ReferralResult.fail(
        _detail(res, 'Couldn\'t join the challenge.'),
        needsAccount: res.statusCode == 401,
        definitive: res.statusCode == 400 || res.statusCode == 404,
      );
    } catch (e) {
      debugPrint('[referral] join failed: $e');
      return const ReferralResult.fail('No connection. Try again.');
    }
  }

  /// Install-source tracking (Play install referrer UTM fields).
  Future<void> reportAttribution({
    String? source,
    String? medium,
    String? campaign,
  }) async {
    if (!signedIn) return;
    try {
      await _client
          .post(Uri.parse('$_baseUrl/attribution'),
              headers: _headers,
              body: jsonEncode({
                'source': ?source,
                'medium': ?medium,
                'campaign': ?campaign,
              }))
          .timeout(_timeout);
    } catch (e) {
      debugPrint('[referral] attribution failed: $e');
    }
  }
}
