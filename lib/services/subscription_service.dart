import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/subscription.dart';
import 'auth_service.dart';

/// Premium subscription state — backend (Stripe) is the source of truth.
/// We mirror it into SharedPreferences so the app knows offline and so
/// the first frame can paint gated UI without a network round-trip.
class SubscriptionService extends ChangeNotifier {
  SubscriptionService._();
  static final SubscriptionService _instance = SubscriptionService._();
  factory SubscriptionService() => _instance;

  static const String _baseUrl = 'https://mood8.app/api';
  static const Duration _timeout = Duration(seconds: 15);

  static const String _kTierKey = 'mood8.subscriptionTier';
  static const String _kExpiresKey = 'mood8.subscriptionExpiresAt';

  final http.Client _client = http.Client();

  SubscriptionTier _tier = SubscriptionTier.free;
  DateTime? _expiresAt;
  bool _loaded = false;

  SubscriptionTier get tier => _tier;
  bool get isPremium => _tier.isPaid && !_isExpired();
  DateTime? get expiresAt => _expiresAt;
  String? get premiumType {
    switch (_tier) {
      case SubscriptionTier.premium:
        return 'monthly_or_annual';
      case SubscriptionTier.premiumLifetime:
        return 'lifetime';
      case SubscriptionTier.free:
        return null;
    }
  }

  bool _isExpired() {
    if (_tier == SubscriptionTier.premiumLifetime) return false;
    if (_expiresAt == null) return false;
    return DateTime.now().isAfter(_expiresAt!);
  }

  // ─── Feature gates ──────────────────────────────────────────────────
  // Free tier (per the launch spec):
  //   3 habits · 5 routines · 5 AI Coach messages/day · 1 freeze/week
  // Premium:
  //   unlimited everything · 3 freezes/week · premium effects · custom
  //   identity themes · advanced insights · weekly recap · priority flag

  bool get hasUnlimitedAi => isPremium;
  bool get hasAdvancedInsights => isPremium;
  bool get hasMultiDeviceSync => isPremium;
  bool get hasUnlimitedHabits => isPremium;
  bool get hasUnlimitedRoutines => isPremium;
  bool get hasPremiumEffects => isPremium;
  bool get hasCustomThemes => isPremium;
  bool get hasWeeklyRecapEmail => isPremium;
  bool get hasExport => true; // free for now

  int get maxHabits => isPremium ? -1 : 3;
  int get maxRoutines => isPremium ? -1 : 5;
  int get aiMessagesPerDay => isPremium ? -1 : 5;
  int get maxIdentitiesOnProgress => isPremium ? -1 : 1;

  bool habitLimitReached(int current) =>
      maxHabits != -1 && current >= maxHabits;
  bool routineLimitReached(int current) =>
      maxRoutines != -1 && current >= maxRoutines;

  // ─── Lifecycle ──────────────────────────────────────────────────────

  /// Loads the persisted tier from SharedPreferences. Call once on boot.
  /// [refreshStatus] should be called after this when a JWT is available.
  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kTierKey);
      _tier = SubscriptionTier.values.firstWhere(
        (t) => t.name == raw,
        orElse: () => SubscriptionTier.free,
      );
      final expRaw = prefs.getInt(_kExpiresKey);
      _expiresAt =
          expRaw == null ? null : DateTime.fromMillisecondsSinceEpoch(expRaw);
    } catch (e) {
      debugPrint('[Subscription] load failed: $e');
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  /// Manual override (rarely needed — webhook-driven state is canonical).
  Future<void> setTier(SubscriptionTier tier, {DateTime? expiresAt}) async {
    _tier = tier;
    _expiresAt = tier == SubscriptionTier.premiumLifetime ? null : expiresAt;
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kTierKey, _tier.name);
      if (_expiresAt == null) {
        await prefs.remove(_kExpiresKey);
      } else {
        await prefs.setInt(_kExpiresKey, _expiresAt!.millisecondsSinceEpoch);
      }
    } catch (e) {
      debugPrint('[Subscription] persist failed: $e');
    }
  }

  // ─── Backend ────────────────────────────────────────────────────────

  String? get _bearer => AuthService().token;

  Map<String, String> get _authHeaders => {
        if (_bearer != null) 'authorization': 'Bearer $_bearer',
        'content-type': 'application/json',
      };

  /// Pulls the canonical state from /api/subscription/status and updates
  /// local mirror. Safe to call repeatedly. No-op when not signed in.
  Future<void> refreshStatus() async {
    final token = _bearer;
    if (token == null) {
      debugPrint('[Subscription] refreshStatus: no token, skipping');
      return;
    }
    try {
      final res = await _client
          .get(
            Uri.parse('$_baseUrl/subscription/status'),
            headers: _authHeaders,
          )
          .timeout(_timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint('[Subscription] status ${res.statusCode}: ${res.body}');
        return;
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final isPremium = body['is_premium'] as bool? ?? false;
      final type = body['premium_type'] as String?;
      final expiresIso = body['premium_expires_at'] as String?;
      if (!isPremium) {
        _tier = SubscriptionTier.free;
        _expiresAt = null;
      } else if (type == 'lifetime') {
        _tier = SubscriptionTier.premiumLifetime;
        _expiresAt = null;
      } else {
        _tier = SubscriptionTier.premium;
        _expiresAt = expiresIso != null ? DateTime.tryParse(expiresIso) : null;
      }
      await _persist();
      notifyListeners();
      debugPrint(
          '[Subscription] refreshed · isPremium=$isPremium · type=$type · expires=$expiresIso');
    } on TimeoutException {
      debugPrint('[Subscription] refreshStatus timeout');
    } catch (e) {
      debugPrint('[Subscription] refreshStatus error: $e');
    }
  }

  /// Returns the Stripe Checkout URL for the given plan, or null on
  /// failure. Caller is responsible for opening it (web: same-tab or
  /// new-tab redirect; mobile: in-app or external browser).
  Future<String?> startCheckout(String plan) async {
    if (_bearer == null) return null;
    try {
      final res = await _client
          .post(
            Uri.parse('$_baseUrl/stripe/create-checkout-session'),
            headers: _authHeaders,
            body: jsonEncode({'plan': plan}),
          )
          .timeout(_timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint(
            '[Subscription] checkout ${res.statusCode}: ${res.body}');
        return null;
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['checkout_url'] as String?;
    } catch (e) {
      debugPrint('[Subscription] startCheckout error: $e');
      return null;
    }
  }

  /// Returns the Stripe Billing Portal URL so the user can manage or
  /// cancel their subscription themselves. Returns null on failure.
  Future<String?> openBillingPortal() async {
    if (_bearer == null) return null;
    try {
      final res = await _client
          .post(
            Uri.parse('$_baseUrl/stripe/create-portal-session'),
            headers: _authHeaders,
          )
          .timeout(_timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint('[Subscription] portal ${res.statusCode}: ${res.body}');
        return null;
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['portal_url'] as String?;
    } catch (e) {
      debugPrint('[Subscription] openBillingPortal error: $e');
      return null;
    }
  }
}
