import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:play_install_referrer/play_install_referrer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart' show rootNavigatorKey, rootScaffoldMessengerKey;
import '../screens/auth/register_screen.dart';
import '../screens/challenges/challenge_detail_screen.dart';
import 'auth_service.dart';
import 'referral_service.dart';

/// An invite that arrived before the user was ready to act on it:
/// an invite code, a challenge invite link, and where it came from.
class PendingInvite {
  const PendingInvite({
    this.ref,
    this.challengeToken,
    this.source,
    this.campaign,
    this.medium,
    required this.capturedAt,
  });

  final String? ref;
  final String? challengeToken;
  final String? source;
  final String? campaign;
  final String? medium;
  final DateTime capturedAt;

  bool get isEmpty => ref == null && challengeToken == null;

  Map<String, dynamic> toJson() => {
        'ref': ref,
        'challenge': challengeToken,
        'source': source,
        'campaign': campaign,
        'medium': medium,
        'at': capturedAt.toIso8601String(),
      };

  factory PendingInvite.fromJson(Map<String, dynamic> j) => PendingInvite(
        ref: j['ref'] as String?,
        challengeToken: j['challenge'] as String?,
        source: j['source'] as String?,
        campaign: j['campaign'] as String?,
        medium: j['medium'] as String?,
        capturedAt:
            DateTime.tryParse((j['at'] as String?) ?? '') ?? DateTime.now(),
      );
}

/// Holds an invite until the user is signed in, then acts on it.
///
/// Entry points that [capture] an invite: `https://mood8.app/r/CODE` and
/// `/c/TOKEN?ref=CODE` links, `mood8://invite` / `mood8://challenge`,
/// the web app's `?ref=` / `?c=` query, and the Google Play install
/// referrer (a user who installed from an invite link). [process] then
/// runs after sign-in: claim the inviter's code, and join the challenge
/// if the link was a challenge invite.
class PendingInviteService {
  PendingInviteService._();
  static final PendingInviteService _instance = PendingInviteService._();
  factory PendingInviteService() => _instance;

  static const _kPending = 'invite.pending.v1';
  static const _kReferrerChecked = 'invite.installReferrerChecked';
  static const Duration _ttl = Duration(days: 7);

  bool _processing = false;

  Future<PendingInvite?> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPending);
      if (raw == null) return null;
      final p = PendingInvite.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      if (DateTime.now().difference(p.capturedAt) > _ttl || p.isEmpty) {
        await prefs.remove(_kPending);
        return null;
      }
      return p;
    } catch (_) {
      return null;
    }
  }

  Future<void> _save(PendingInvite? p) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (p == null || p.isEmpty) {
        await prefs.remove(_kPending);
      } else {
        await prefs.setString(_kPending, jsonEncode(p.toJson()));
      }
    } catch (e) {
      debugPrint('[invite] persist failed: $e');
    }
  }

  /// The stored inviter code, if any — sent along with sign-up so the
  /// server can attribute the new account in the same round-trip.
  Future<String?> peekRef() async => (await _load())?.ref;

  String? _clean(String? s) {
    final t = (s ?? '').trim();
    return t.isEmpty ? null : t;
  }

  /// Remember an invite. The first inviter code wins (a later link must
  /// not steal the attribution); the latest challenge link wins.
  Future<void> capture({
    String? ref,
    String? challengeToken,
    String? source,
    String? campaign,
    String? medium,
  }) async {
    final cur = await _load();
    final next = PendingInvite(
      ref: cur?.ref ?? _clean(ref),
      challengeToken: _clean(challengeToken) ?? cur?.challengeToken,
      source: cur?.ref != null ? cur?.source : (_clean(source) ?? cur?.source),
      campaign: cur?.ref != null ? cur?.campaign : _clean(campaign),
      medium: cur?.ref != null ? cur?.medium : _clean(medium),
      capturedAt: DateTime.now(),
    );
    await _save(next);
  }

  /// Parse any supported invite link. Returns true when it was one.
  Future<bool> captureFromUri(Uri uri) async {
    final q = uri.queryParameters;
    final segs = uri.pathSegments;
    String? ref = q['ref'];
    String? challenge;
    var source = 'invite_link';

    if (uri.scheme == 'mood8') {
      if (uri.host == 'invite') {
        // ref only
      } else if (uri.host == 'challenge') {
        challenge = q['token'];
      } else {
        return false;
      }
    } else if (uri.host.endsWith('mood8.app')) {
      if (segs.length >= 2 && segs[0] == 'r') {
        ref = segs[1];
      } else if (segs.length >= 2 && segs[0] == 'c') {
        challenge = segs[1];
      } else if (q['c'] != null) {
        challenge = q['c']; // web app: /app/?c=TOKEN&ref=CODE
      } else if (ref == null) {
        return false;
      }
    } else {
      return false;
    }
    if (_clean(ref) == null && _clean(challenge) == null) return false;
    await capture(
      ref: ref,
      challengeToken: challenge,
      source: source,
      campaign: q['utm_campaign'],
      medium: q['utm_medium'] ?? 'link',
    );
    return true;
  }

  /// Android only, once per install: read the Google Play install
  /// referrer. A user who installed through our Play link carries the
  /// inviter's code (`ref=`) and any UTM fields; install-source tracking
  /// reports those even when there is no inviter.
  Future<void> checkInstallReferrer() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kReferrerChecked) == true) return;
      final details = await PlayInstallReferrer.installReferrer;
      await prefs.setBool(_kReferrerChecked, true);
      final raw = details.installReferrer;
      if (raw == null || raw.isEmpty) return;
      final q = Uri(query: raw).queryParameters;
      await _save(PendingInvite(
        ref: _clean(q['ref']) ?? (await _load())?.ref,
        challengeToken: (await _load())?.challengeToken,
        source: 'play_referrer',
        campaign: _clean(q['utm_campaign']),
        medium: _clean(q['utm_medium']),
        capturedAt: DateTime.now(),
      ));
      _installUtm = (
        source: _clean(q['utm_source']),
        medium: _clean(q['utm_medium']),
        campaign: _clean(q['utm_campaign']),
      );
      await prefs.setString(
          _kInstallUtm, jsonEncode({
            'source': _installUtm!.source,
            'medium': _installUtm!.medium,
            'campaign': _installUtm!.campaign,
          }));
    } catch (e) {
      // Not installed from Play, no Play services, or API unavailable.
      debugPrint('[invite] install referrer unavailable: $e');
    }
  }

  static const _kInstallUtm = 'invite.installUtm';
  ({String? source, String? medium, String? campaign})? _installUtm;

  Future<void> _reportInstallSource() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kInstallUtm);
      if (raw == null) return;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      await ReferralService().reportAttribution(
        source: j['source'] as String?,
        medium: j['medium'] as String?,
        campaign: j['campaign'] as String?,
      );
      await prefs.remove(_kInstallUtm);
    } catch (e) {
      debugPrint('[invite] report install source failed: $e');
    }
  }

  void _snack(String text, {SnackBarAction? action}) {
    rootScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(text),
        action: action,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  /// Act on a stored invite. Safe to call any time; a no-op when there
  /// is nothing pending or the user isn't signed in yet.
  Future<void> process() async {
    if (_processing || AuthService().token == null) return;
    _processing = true;
    try {
      await _reportInstallSource();
      var p = await _load();
      if (p == null) return;
      final isGuest = AuthService().currentUser?.isGuest ?? false;

      // 1) Inviter code — fine for guests too; the reward is paid once
      //    the account becomes real and verified.
      if (p.ref != null) {
        final r = await ReferralService().claim(
          p.ref!,
          source: p.source,
          campaign: p.campaign,
          medium: p.medium,
          challengeToken: p.challengeToken,
        );
        if (r.ok || r.definitive) {
          p = PendingInvite(
            challengeToken: p.challengeToken,
            capturedAt: p.capturedAt,
          );
          await _save(p);
          if (r.ok && !r.pendingReward) {
            _snack('Invite applied — you both get Premium days.');
          } else if (r.ok) {
            _snack('Invite saved. Create your account to unlock your '
                'Premium days.');
          }
        }
      }

      // 2) Challenge link — needs a real account.
      if (p.challengeToken != null) {
        if (isGuest) {
          _snack(
            'Create a free account to join this challenge.',
            action: SnackBarAction(
              label: 'Sign up',
              onPressed: () => rootNavigatorKey.currentState?.push(
                MaterialPageRoute<void>(
                    builder: (_) => const RegisterScreen()),
              ),
            ),
          );
          return;
        }
        final r = await ReferralService().joinViaInvite(p.challengeToken!);
        if (r.ok && r.challengeId != null) {
          await _save(null);
          rootNavigatorKey.currentState?.push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  ChallengeDetailScreen(challengeId: r.challengeId!),
            ),
          );
        } else if (r.definitive) {
          await _save(null);
          _snack(r.message ?? 'Couldn\'t join the challenge.');
        } else if (r.message != null && !r.needsAccount) {
          _snack(r.message!); // transient — keep it for the next launch
        }
      }
    } catch (e) {
      debugPrint('[invite] process failed: $e');
    } finally {
      _processing = false;
    }
  }
}
