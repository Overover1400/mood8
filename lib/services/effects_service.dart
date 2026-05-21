import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/effects_intensity.dart';
import '../widgets/effects/cosmic_bloom.dart';
import '../widgets/effects/identity_constellation.dart';
import '../widgets/effects/phoenix_rise.dart';
import '../widgets/effects/premium_bloom.dart';
import 'overlay_coordinator.dart';
import 'subscription_service.dart';

/// Central celebration facade. Each method spawns the right premium widget
/// in the root [Overlay], handles its own queueing, and degrades gracefully
/// to no-op when effects are off / system reduce-motion is on / we've hit
/// the concurrency cap.
class EffectsService extends ChangeNotifier {
  EffectsService._();
  static final EffectsService _instance = EffectsService._();
  factory EffectsService() => _instance;

  static const _kIntensityKey = 'mood8.effects.intensity';
  static const _kMilestonesKey = 'mood8.effects.celebrateMilestones';
  static const _kBatterySaverKey = 'mood8.effects.batterySaverAware';
  // One-shot hint for free users the first time a premium-only effect
  // (Cosmic/Phoenix/Constellation) would have fired. After consumption
  // we just play the free fallback and stay silent.
  static const _kPremiumHintShownKey = 'mood8.effects.premiumHintShown';
  static const int _maxConcurrent = 2;

  /// Fires once with the paywall context note the first time a free
  /// user hits a premium-effect moment. Surfaced via a snackbar/banner
  /// near where the event happened.
  final ValueNotifier<String?> premiumEffectHintNotifier =
      ValueNotifier<String?>(null);

  EffectsIntensity _intensity = EffectsIntensity.normal;
  bool _celebrateMilestones = true;
  bool _batterySaverAware = true;
  bool _loaded = false;
  int _active = 0;

  EffectsIntensity get intensity => _intensity;
  bool get celebrateMilestones => _celebrateMilestones;
  bool get batterySaverAware => _batterySaverAware;
  bool get isLoaded => _loaded;

  // ─── lifecycle ────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kIntensityKey);
      _intensity = EffectsIntensity.values.firstWhere(
        (i) => i.name == raw,
        orElse: () => EffectsIntensity.normal,
      );
      _celebrateMilestones = prefs.getBool(_kMilestonesKey) ?? true;
      _batterySaverAware = prefs.getBool(_kBatterySaverKey) ?? true;
    } catch (_) {
      // best-effort
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> setIntensity(EffectsIntensity i) async {
    if (i == _intensity) return;
    _intensity = i;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kIntensityKey, i.name);
  }

  Future<void> setCelebrateMilestones(bool v) async {
    if (v == _celebrateMilestones) return;
    _celebrateMilestones = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kMilestonesKey, v);
  }

  Future<void> setBatterySaverAware(bool v) async {
    if (v == _batterySaverAware) return;
    _batterySaverAware = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBatterySaverKey, v);
  }

  // ─── celebrations ────────────────────────────────────────────────────

  Future<void> celebrateHabitComplete({
    required BuildContext context,
    Offset? origin,
  }) async {
    if (!_canPlay(context)) return;
    final media = MediaQuery.maybeOf(context);
    final size = media?.size ?? const Size(360, 640);
    final effectiveOrigin = origin ?? Offset(size.width / 2, size.height / 2);
    await _insert(
      context,
      (entry) => PremiumBloom(
        origin: effectiveOrigin,
        intensity: _intensity,
        onComplete: () => _remove(entry),
      ),
      fallbackTimeout:
          _scaledDuration(const Duration(milliseconds: 2200)),
    );
  }

  Future<void> celebrateRoutinesComplete({
    required BuildContext context,
    String? userName,
  }) async {
    if (!_canPlay(context)) return;
    if (!SubscriptionService().isPremium) {
      // Free users: still acknowledge the moment with the lightweight
      // PremiumBloom (the same effect that fires for habit completion),
      // and surface a one-time hint about premium effects.
      // ignore: discarded_futures
      _maybeShowPremiumHint();
      return celebrateHabitComplete(context: context);
    }
    await _insert(
      context,
      (entry) => CosmicBloom(
        intensity: _intensity,
        userName: userName,
        onComplete: () => _remove(entry),
      ),
      fallbackTimeout:
          _scaledDuration(const Duration(milliseconds: 3400)),
    );
  }

  /// Alias that matches the spec's preferred name. Same as
  /// [celebrateRoutinesComplete].
  Future<void> celebrateAllRoutinesComplete({
    required BuildContext context,
    String? userName,
  }) =>
      celebrateRoutinesComplete(context: context, userName: userName);

  Future<void> celebrateStreakMilestone({
    required BuildContext context,
    required int days,
    Offset? flameOrigin,
  }) async {
    if (!_canPlay(context)) return;
    if (!_celebrateMilestones) {
      await celebrateHabitComplete(context: context, origin: flameOrigin);
      return;
    }
    if (!SubscriptionService().isPremium) {
      // ignore: discarded_futures
      _maybeShowPremiumHint();
      return celebrateHabitComplete(context: context, origin: flameOrigin);
    }
    await _insert(
      context,
      (entry) => PhoenixRise(
        days: days,
        intensity: _intensity,
        flameOrigin: flameOrigin,
        onComplete: () => _remove(entry),
      ),
      fallbackTimeout:
          _scaledDuration(const Duration(milliseconds: 2900)),
    );
  }

  Future<void> celebrateIdentityLevelUp({
    required BuildContext context,
    required String identity,
    required double progress,
  }) async {
    if (!_canPlay(context)) return;
    if (!_celebrateMilestones) {
      await celebrateHabitComplete(context: context);
      return;
    }
    if (!SubscriptionService().isPremium) {
      // ignore: discarded_futures
      _maybeShowPremiumHint();
      return celebrateHabitComplete(context: context);
    }
    await _insert(
      context,
      (entry) => IdentityConstellation(
        identity: identity,
        progress: progress,
        intensity: _intensity,
        onComplete: () => _remove(entry),
      ),
      fallbackTimeout:
          _scaledDuration(const Duration(milliseconds: 3400)),
    );
  }

  /// One-time hint for free users when a premium effect was suppressed.
  /// Reads/writes a SharedPreferences flag so it fires at most once.
  /// Listeners on [premiumEffectHintNotifier] are responsible for the
  /// actual UI (a snackbar with a tap-to-upgrade action).
  Future<void> _maybeShowPremiumHint() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kPremiumHintShownKey) ?? false) return;
      await prefs.setBool(_kPremiumHintShownKey, true);
      premiumEffectHintNotifier.value =
          'Premium unlocks cinematic celebrations ✨';
      // Pulse-clear so the same listener can be ready for a future
      // (unrelated) hint surface — defensive even though this fires once.
      Future<void>.delayed(const Duration(milliseconds: 50), () {
        premiumEffectHintNotifier.value = null;
      });
    } catch (_) {
      // Pref store unavailable — silently swallow. The free fallback
      // effect still plays; we just don't surface the hint.
    }
  }

  /// Back-compat shim for the older [CelebrationLevel]-style API. Maps the
  /// generic level to the closest specific method so existing call sites
  /// keep compiling.
  Future<void> celebrate({
    required BuildContext context,
    required CelebrationLevel level,
    Offset? origin,
    String? message,
  }) {
    switch (level) {
      case CelebrationLevel.subtle:
      case CelebrationLevel.notable:
        return celebrateHabitComplete(context: context, origin: origin);
      case CelebrationLevel.milestone:
      case CelebrationLevel.identity:
        return celebrateRoutinesComplete(context: context);
    }
  }

  // ─── internals ────────────────────────────────────────────────────────

  bool _canPlay(BuildContext context) {
    if (_intensity == EffectsIntensity.off) return false;
    final media = MediaQuery.maybeOf(context);
    if (media?.disableAnimations ?? false) return false;
    if (_active >= _maxConcurrent) return false;
    return true;
  }

  Duration _scaledDuration(Duration base) {
    final ms = (base.inMilliseconds * _intensity.durationScale).round();
    return Duration(milliseconds: ms.clamp(400, 8000));
  }

  Future<void> _insert(
    BuildContext context,
    Widget Function(OverlayEntry entry) builder, {
    required Duration fallbackTimeout,
  }) async {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    late OverlayEntry entry;
    entry = OverlayEntry(builder: (_) => builder(entry));
    _active += 1;
    OverlayCoordinator().push();
    overlay.insert(entry);
    // Safety net for paused / background tabs.
    Future<void>.delayed(fallbackTimeout, () => _remove(entry));
  }

  void _remove(OverlayEntry entry) {
    if (!entry.mounted) return;
    try {
      entry.remove();
    } catch (_) {}
    _active = (_active - 1).clamp(0, _maxConcurrent);
    OverlayCoordinator().pop();
  }
}
