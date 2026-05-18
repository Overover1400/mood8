import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/subscription.dart';

/// Lightweight tier facade. Today everyone is `free`. Real billing wires
/// into [setTier] later (Stripe/RevenueCat/App Store) — the rest of the app
/// reads the same accessors regardless.
class SubscriptionService extends ChangeNotifier {
  SubscriptionService._();
  static final SubscriptionService _instance = SubscriptionService._();
  factory SubscriptionService() => _instance;

  static const String _kTierKey = 'mood8.subscriptionTier';
  static const String _kExpiresKey = 'mood8.subscriptionExpiresAt';

  SubscriptionTier _tier = SubscriptionTier.free;
  DateTime? _expiresAt;
  bool _loaded = false;

  SubscriptionTier get tier => _tier;
  bool get isPremium => _tier.isPaid && !_isExpired();
  DateTime? get expiresAt => _expiresAt;

  bool _isExpired() {
    if (_tier == SubscriptionTier.premiumLifetime) return false;
    if (_expiresAt == null) return false;
    return DateTime.now().isAfter(_expiresAt!);
  }

  // ─── feature gates ───────────────────────────────────────────────────

  bool get hasUnlimitedAi => isPremium;
  bool get hasAdvancedInsights => isPremium;
  bool get hasMultiDeviceSync => isPremium;
  bool get hasUnlimitedHabits => isPremium;
  bool get hasUnlimitedRoutines => isPremium;
  bool get hasExport => true; // free for now

  /// Per-month AI Coach interactions. -1 == unlimited.
  int get aiReflectionsPerMonth => isPremium ? -1 : 50;
  int get maxHabits => isPremium ? -1 : 10;
  int get maxRoutines => isPremium ? -1 : 20;
  int get maxIdentitiesOnProgress => isPremium ? -1 : 1;

  bool habitLimitReached(int current) =>
      maxHabits != -1 && current >= maxHabits;
  bool routineLimitReached(int current) =>
      maxRoutines != -1 && current >= maxRoutines;

  // ─── lifecycle ───────────────────────────────────────────────────────

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
      debugPrint('SubscriptionService.load failed: $e');
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> setTier(SubscriptionTier tier, {DateTime? expiresAt}) async {
    _tier = tier;
    _expiresAt = tier == SubscriptionTier.premiumLifetime ? null : expiresAt;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kTierKey, tier.name);
      if (_expiresAt == null) {
        await prefs.remove(_kExpiresKey);
      } else {
        await prefs.setInt(_kExpiresKey, _expiresAt!.millisecondsSinceEpoch);
      }
    } catch (e) {
      debugPrint('SubscriptionService.setTier persist failed: $e');
    }
  }
}
