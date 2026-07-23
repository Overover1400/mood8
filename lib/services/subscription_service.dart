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
  // Free-mode mirror (server-authoritative) so the first frame after a
  // cold start reflects the promo before /status returns.
  static const String _kFreeModeKey = 'mood8.freeModeActive';
  static const String _kFreeModeEndsKey = 'mood8.freeModeEndsAt';
  static const String _kHabitLimitKey = 'mood8.habitLimit'; // -1 == unlimited
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

  // ── Free mode / entitlement (server-authoritative) ──────────────────
  // The client renders what /status reports; it never decides entitlement
  // locally. `isPremium` above stays REAL premium; these carry the promo
  // layer so features unlock + upsell hides without mislabelling a
  // non-payer as a subscriber.
  bool _freeModeActive = false;
  DateTime? _freeModeEndsAt;
  bool _featuresPremium = false; // server: real premium OR free-mode
  int? _habitLimit; // null = unlimited; server-provided
  int _habitsOverLimit = 0;
  DateTime? _graceEndsAt; // set only while in a grace window
  bool _restrictionsActive = false; // grace expired + over limit
  List<String> _activeHabitIds = const [];

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
    if (_tier.isLifetime) return false;
    if (_expiresAt == null) return false;
    return DateTime.now().isAfter(_expiresAt!);
  }

  // ─── Feature gates ──────────────────────────────────────────────────
  // Free tier (per the launch spec):
  //   3 habits · 5 routines · 5 AI Coach messages/day
  // Premium — a single paid tier that covers EVERYTHING:
  //   unlimited habits + routines + AI messages, premium effects,
  //   custom identity themes, advanced insights, weekly recap emails,
  //   the 10 curated habit packages, AI-designed habit packages
  //   (Coach can add habits directly), priority support.

  // ── Free-mode entitlement getters ───────────────────────────────────
  /// True during the promotional period (server-driven).
  bool get freeModeActive => _freeModeActive;
  DateTime? get freeModeEndsAt => _freeModeEndsAt;

  /// Features (packages, AI packages, premium effects, unlimited habits…)
  /// are unlocked for REAL premium OR anyone during free mode.
  bool get featuresUnlocked => isPremium || _featuresPremium || _freeModeActive;

  /// Whether to show ANY premium-upsell surface (upgrade bar, paywall
  /// CTAs, "Premium" badges). Hidden during free mode and for payers.
  bool get showPremiumUpsell => !isPremium && !_freeModeActive;

  int? get habitLimit => _habitLimit;
  int get habitsOverLimit => _habitsOverLimit;
  DateTime? get graceEndsAt => _graceEndsAt;
  bool get inGrace => _graceEndsAt != null;
  bool get restrictionsActive => _restrictionsActive;
  List<String> get activeHabitIds => _activeHabitIds;

  int? get graceDaysRemaining {
    if (_graceEndsAt == null) return null;
    final d = _graceEndsAt!.difference(DateTime.now()).inDays;
    return d < 0 ? 0 : d;
  }

  // ── Feature gates (route through featuresUnlocked) ───────────────────
  bool get hasUnlimitedAi => featuresUnlocked;
  bool get hasAdvancedInsights => featuresUnlocked;
  bool get hasMultiDeviceSync => featuresUnlocked;
  bool get hasUnlimitedHabits => featuresUnlocked;
  bool get hasUnlimitedRoutines => featuresUnlocked;
  bool get hasPremiumEffects => featuresUnlocked;
  bool get hasCustomThemes => featuresUnlocked;
  bool get hasWeeklyRecapEmail => featuresUnlocked;
  bool get hasExport => true; // free for now
  /// Habit Packages (the 10 curated + AI-designed) are unlocked for
  /// every paying user, and everyone during free mode.
  bool get hasHabitPackages => featuresUnlocked;

  /// Habit cap: server-provided during free mode / grace (null =
  /// unlimited). Falls back to premium=unlimited / free=3 before /status.
  int get maxHabits {
    if (isPremium || _freeModeActive) return -1;
    return _habitLimit ?? 3;
  }

  int get maxRoutines => featuresUnlocked ? -1 : 5;
  int get aiMessagesPerDay => featuresUnlocked ? -1 : 5;
  int get maxIdentitiesOnProgress => featuresUnlocked ? -1 : 1;

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
      _freeModeActive = prefs.getBool(_kFreeModeKey) ?? false;
      final fmEnds = prefs.getString(_kFreeModeEndsKey);
      _freeModeEndsAt = fmEnds == null ? null : DateTime.tryParse(fmEnds);
      final hl = prefs.getInt(_kHabitLimitKey);
      _habitLimit = (hl == null || hl < 0) ? null : hl;
      _featuresPremium = _freeModeActive;
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
    _freeModeActive = false;
    _freeModeEndsAt = null;
    _featuresPremium = false;
    _habitLimit = null;
    _habitsOverLimit = 0;
    _graceEndsAt = null;
    _restrictionsActive = false;
    _activeHabitIds = const [];
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

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kTierKey, _tier.name);
      if (_expiresAt == null) {
        await prefs.remove(_kExpiresKey);
      } else {
        await prefs.setInt(_kExpiresKey, _expiresAt!.millisecondsSinceEpoch);
      }
      await prefs.setBool(_kFreeModeKey, _freeModeActive);
      if (_freeModeEndsAt == null) {
        await prefs.remove(_kFreeModeEndsKey);
      } else {
        await prefs.setString(
            _kFreeModeEndsKey, _freeModeEndsAt!.toIso8601String());
      }
      await prefs.setInt(_kHabitLimitKey, _habitLimit ?? -1);
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
      final expiresIso = body['premium_expires_at'] as String?;
      final isLifetime = type == 'lifetime';
      if (!apiIsPremium) {
        _tier = SubscriptionTier.free;
        _expiresAt = null;
      } else if (isLifetime) {
        _tier = SubscriptionTier.premiumLifetime;
        _expiresAt = null;
      } else {
        _tier = SubscriptionTier.premium;
        _expiresAt = expiresIso != null ? DateTime.tryParse(expiresIso) : null;
      }
      // ── Free-mode / entitlement block ──────────────────────────────
      _freeModeActive = body['free_mode_active'] as bool? ?? false;
      final fmEnds = body['free_mode_ends_at'] as String?;
      _freeModeEndsAt = fmEnds != null ? DateTime.tryParse(fmEnds) : null;
      _featuresPremium = body['features_premium'] as bool? ?? false;
      _habitLimit = body['habit_limit'] as int?; // null = unlimited
      _habitsOverLimit = (body['habits_over_limit'] as num?)?.toInt() ?? 0;
      final graceIso = body['grace_ends_at'] as String?;
      _graceEndsAt = graceIso != null ? DateTime.tryParse(graceIso) : null;
      _restrictionsActive = body['restrictions_active'] as bool? ?? false;
      _activeHabitIds = (body['active_habit_ids'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [];
      await _persist();
      notifyListeners();
      debugPrint(
          '[Subscription] refreshed · isPremium=$apiIsPremium · type=$type · expires=$expiresIso');
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

  /// Redeem a free-access / comp code. Grants Premium server-side via the
  /// SAME entitlement path Stripe uses (tagged source="promo"), so on
  /// success we just refresh status and the whole app sees Premium.
  ///
  /// This is a FREE path only — it never touches checkout or prices, so
  /// it's safe to surface inside the Android app (Play policy).
  Future<PromoRedeemResult> redeemPromoCode(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      return const PromoRedeemResult(
        success: false, message: 'Enter a code to redeem.');
    }
    if (_bearer == null) {
      return const PromoRedeemResult(
        success: false, message: 'Please sign in to redeem a code.');
    }
    try {
      final res = await _client
          .post(
            Uri.parse('$_baseUrl/promo/redeem'),
            headers: {..._authHeaders, 'content-type': 'application/json'},
            body: jsonEncode({'code': trimmed}),
          )
          .timeout(_timeout);
      final body = _tryDecode(res.body);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        // Pull the canonical entitlement so every gated surface flips to
        // Premium immediately — no app restart, no manual refresh.
        await refreshStatus();
        final msg = body?['message'] as String? ?? 'Code redeemed 🎉';
        return PromoRedeemResult(success: true, message: msg);
      }
      // Backend sends {"detail": {"error": ..., "message": ...}} for the
      // friendly cases. Fall back to a generic line otherwise.
      final detail = body?['detail'];
      String message = 'That code could not be redeemed.';
      if (detail is Map && detail['message'] is String) {
        message = detail['message'] as String;
      } else if (detail is String) {
        message = detail;
      }
      return PromoRedeemResult(success: false, message: message);
    } on TimeoutException {
      return const PromoRedeemResult(
        success: false, message: 'Timed out — check your connection.');
    } catch (e) {
      debugPrint('[Subscription] redeemPromoCode error: $e');
      return const PromoRedeemResult(
        success: false, message: 'Something went wrong. Try again.');
    }
  }

  /// Persist the user's chosen active habits once restrictions apply (the
  /// rest go read-only). The server trims to the free limit + echoes it in
  /// /status; we refresh so the UI reflects the new active set immediately.
  Future<bool> setActiveHabits(List<String> habitIds) async {
    if (_bearer == null) return false;
    try {
      final res = await _client
          .post(
            Uri.parse('$_baseUrl/entitlement/active-habits'),
            headers: _authHeaders,
            body: jsonEncode({'habit_ids': habitIds}),
          )
          .timeout(_timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint('[Subscription] setActiveHabits ${res.statusCode}');
        return false;
      }
      final body = _tryDecode(res.body);
      _activeHabitIds = (body?['active_habit_ids'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          habitIds;
      notifyListeners();
      // Pull canonical entitlement (habits_over_limit, restrictions) again.
      await refreshStatus();
      return true;
    } catch (e) {
      debugPrint('[Subscription] setActiveHabits error: $e');
      return false;
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

/// Result of a promo-code redemption attempt. [message] is always
/// user-facing copy (success celebration or a friendly error).
class PromoRedeemResult {
  const PromoRedeemResult({required this.success, required this.message});
  final bool success;
  final String message;
}

/// Stripe-computed quote for what an in-place cadence swap (monthly
/// ↔ annual) will cost the user TODAY. Returned by
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
