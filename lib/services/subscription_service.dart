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
  // Flipped to true while a Stripe checkout flow is mid-air (the user
  // has tapped "Start Premium" and we've launched the checkout URL).
  // On the next AppLifecycleState.resumed we force a status refresh
  // and announce the premium unlock if it just happened. Cleared after
  // consumption either way.
  static const String _kCheckoutInProgressKey = 'mood8.checkoutInProgress';

  /// Fires `true` exactly once after a refresh in which the user just
  /// transitioned from non-premium to premium. AuthGate listens to
  /// surface a "Welcome to Premium ✨" snackbar.
  final ValueNotifier<bool> premiumJustUnlockedNotifier =
      ValueNotifier<bool>(false);

  final http.Client _client = http.Client();

  SubscriptionTier _tier = SubscriptionTier.free;
  DateTime? _expiresAt;
  bool _loaded = false;

  SubscriptionTier get tier => _tier;
  bool get isPremium => _tier.isPaid && !_isExpired();

  /// True only for Premium Plus tiers — gates the AI Habit Packages.
  /// Plus is a strict superset of Premium, so anything gated by
  /// `isPremium` is also unlocked for Plus users.
  bool get isPremiumPlus => _tier.isPlus && !_isExpired();

  DateTime? get expiresAt => _expiresAt;
  String? get premiumType {
    switch (_tier) {
      case SubscriptionTier.premium:
      case SubscriptionTier.premiumPlus:
        return 'monthly_or_annual';
      case SubscriptionTier.premiumLifetime:
      case SubscriptionTier.premiumPlusLifetime:
        return 'lifetime';
      case SubscriptionTier.free:
        return null;
    }
  }

  bool _isExpired() {
    if (_tier.isLifetime) return false;
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
    _expiresAt = tier.isLifetime ? null : expiresAt;
    notifyListeners();
    await _persist();
  }

  /// Drop in-memory + persisted subscription state. Called by the
  /// logout flow so the next user (or the welcome screen itself)
  /// doesn't inherit the previous user's premium UI. The next
  /// refreshStatus call after sign-in repopulates from the server.
  Future<void> clearForLogout() async {
    debugPrint('[Subscription] clearForLogout');
    _tier = SubscriptionTier.free;
    _expiresAt = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kTierKey);
      await prefs.remove(_kExpiresKey);
      await prefs.remove(_kCheckoutInProgressKey);
    } catch (e) {
      debugPrint('[Subscription] clearForLogout prefs failed: $e');
    }
    notifyListeners();
  }

  /// Premium-feature gates apply to BOTH Premium and Premium Plus —
  /// the latter is a strict superset that adds the Habit Packages.
  bool get hasHabitPackages => isPremiumPlus;

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
  /// Returns `true` if this call observed a fresh free→premium upgrade
  /// (so callers can surface a celebration); `false` otherwise.
  Future<bool> refreshStatus() async {
    final token = _bearer;
    if (token == null) {
      debugPrint('[Subscription] refreshStatus: no token, skipping');
      return false;
    }
    final wasPremium = isPremium;
    try {
      final res = await _client
          .get(
            Uri.parse('$_baseUrl/subscription/status'),
            headers: _authHeaders,
          )
          .timeout(_timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint('[Subscription] status ${res.statusCode}: ${res.body}');
        return false;
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final apiIsPremium = body['is_premium'] as bool? ?? false;
      final type = body['premium_type'] as String?;
      // premium_plan distinguishes "premium" vs "premium_plus". Legacy
      // backends or fresh free users may return null — collapse to
      // "premium" for paying users so we don't drop them to free.
      final plan = body['premium_plan'] as String?;
      final expiresIso = body['premium_expires_at'] as String?;
      final isLifetime = type == 'lifetime';
      final isPlus = plan == 'premium_plus';
      if (!apiIsPremium) {
        _tier = SubscriptionTier.free;
        _expiresAt = null;
      } else if (isPlus && isLifetime) {
        _tier = SubscriptionTier.premiumPlusLifetime;
        _expiresAt = null;
      } else if (isPlus) {
        _tier = SubscriptionTier.premiumPlus;
        _expiresAt = expiresIso != null ? DateTime.tryParse(expiresIso) : null;
      } else if (isLifetime) {
        _tier = SubscriptionTier.premiumLifetime;
        _expiresAt = null;
      } else {
        _tier = SubscriptionTier.premium;
        _expiresAt = expiresIso != null ? DateTime.tryParse(expiresIso) : null;
      }
      await _persist();
      notifyListeners();
      debugPrint(
          '[Subscription] refreshed · isPremium=$apiIsPremium · type=$type · plan=$plan · expires=$expiresIso');
      final justUnlocked = !wasPremium && isPremium;
      if (justUnlocked) {
        // Pulse the notifier so AuthGate can show its celebration.
        // Reset to false synchronously afterwards so it can fire again
        // if the user ever cancels + re-subscribes later.
        premiumJustUnlockedNotifier.value = true;
        premiumJustUnlockedNotifier.value = false;
      }
      return justUnlocked;
    } on TimeoutException {
      debugPrint('[Subscription] refreshStatus timeout');
      return false;
    } catch (e) {
      debugPrint('[Subscription] refreshStatus error: $e');
      return false;
    }
  }

  /// Mark the checkout flow as "in progress" so the next app resume
  /// forces a status refresh. Best-effort — pref store failures are
  /// non-fatal (the resume hook ALSO refreshes unconditionally).
  Future<void> _markCheckoutInProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kCheckoutInProgressKey, true);
    } catch (e) {
      debugPrint('[Subscription] markCheckoutInProgress failed: $e');
    }
  }

  /// Read + clear the checkout-in-progress flag in one shot. Returns
  /// `true` if the flag was set (i.e. the user just came back from
  /// Stripe checkout), `false` otherwise.
  Future<bool> consumeCheckoutInProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getBool(_kCheckoutInProgressKey) ?? false;
      if (v) await prefs.remove(_kCheckoutInProgressKey);
      return v;
    } catch (e) {
      debugPrint('[Subscription] consumeCheckoutInProgress failed: $e');
      return false;
    }
  }

  /// Returns the Stripe Checkout URL for the given plan, or null on
  /// failure. Caller is responsible for opening it (web: same-tab or
  /// new-tab redirect; mobile: in-app or external browser). Also flips
  /// a "checkout in progress" pref so the next app resume forces a
  /// premium refresh and announces the unlock if it happened.
  ///
  /// On native mobile, pass [returnUrl] = `mood8://checkout-complete`
  /// so Stripe's hosted-checkout success/cancel redirects deep-link
  /// directly back into the app (handled by the AndroidManifest
  /// intent-filter + the app_links listener). On web, leave null so
  /// the server falls back to `https://mood8.app/?checkout=success`.
  Future<String?> startCheckout(String plan, {String? returnUrl}) async {
    if (_bearer == null) return null;
    try {
      final payload = <String, dynamic>{'plan': plan};
      if (returnUrl != null) {
        payload['return_url'] = returnUrl;
      }
      final res = await _client
          .post(
            Uri.parse('$_baseUrl/stripe/create-checkout-session'),
            headers: _authHeaders,
            body: jsonEncode(payload),
          )
          .timeout(_timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint(
            '[Subscription] checkout ${res.statusCode}: ${res.body}');
        return null;
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final url = body['checkout_url'] as String?;
      if (url != null) {
        await _markCheckoutInProgress();
      }
      return url;
    } catch (e) {
      debugPrint('[Subscription] startCheckout error: $e');
      return null;
    }
  }

  /// Asks the backend what Stripe will charge TODAY for [plan]. Returns
  /// a populated [UpgradePreview] on success, or null on any failure —
  /// callers fall back to displaying the sticker price. The numbers are
  /// authoritative (Stripe-computed, see /api/stripe/preview-upgrade in
  /// the backend) so the paywall can promise "you'll be charged $X
  /// today" without us doing client-side proration math.
  Future<UpgradePreview?> previewUpgrade(String plan) async {
    if (_bearer == null) return null;
    try {
      final res = await _client
          .post(
            Uri.parse('$_baseUrl/stripe/preview-upgrade'),
            headers: _authHeaders,
            body: jsonEncode({'plan': plan}),
          )
          .timeout(_timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint(
            '[Subscription] preview ${res.statusCode}: ${res.body}');
        return null;
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return UpgradePreview(
        currency: (body['currency'] as String? ?? 'USD').toUpperCase(),
        amountDueCents: (body['amount_due_cents'] as num?)?.toInt() ?? 0,
        prorationCreditCents:
            (body['proration_credit_cents'] as num?)?.toInt() ?? 0,
        newPriceCents:
            (body['new_price_cents'] as num?)?.toInt() ?? 0,
        isProration: body['is_proration'] as bool? ?? false,
        interval: body['interval'] as String?,
      );
    } catch (e) {
      debugPrint('[Subscription] previewUpgrade error: $e');
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

/// Stripe-computed quote for what an in-place subscription upgrade
/// (Premium → Premium Plus) will cost the user TODAY. Returned by
/// SubscriptionService.previewUpgrade; consumed by the paywall to
/// display "You'll be charged $X.XX today (prorated)".
class UpgradePreview {
  UpgradePreview({
    required this.currency,
    required this.amountDueCents,
    required this.prorationCreditCents,
    required this.newPriceCents,
    required this.isProration,
    this.interval,
  });

  final String currency;
  final int amountDueCents;
  final int prorationCreditCents;
  final int newPriceCents;
  final bool isProration;
  final String? interval;

  String format(int cents) {
    final dollars = (cents / 100).toStringAsFixed(2);
    final symbol = currency == 'USD' ? r'$' : '$currency ';
    return '$symbol$dollars';
  }

  String get formattedAmountDue => format(amountDueCents);
  String get formattedCredit => format(prorationCreditCents);
  String get formattedSticker => format(newPriceCents);
}
