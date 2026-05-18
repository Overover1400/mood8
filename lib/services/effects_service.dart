import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/effects_intensity.dart';
import '../models/milestone.dart';
import '../theme/app_theme.dart';
import '../widgets/effects/sparkle_overlay.dart';

/// Central facade for celebratory effects. The service decides how big the
/// effect should be based on [EffectsIntensity], whether the user has the
/// `Celebrate milestones` toggle on, and whether the system has reduce-motion
/// enabled.
class EffectsService extends ChangeNotifier {
  EffectsService._();
  static final EffectsService _instance = EffectsService._();
  factory EffectsService() => _instance;

  static const _kIntensityKey = 'mood8.effects.intensity';
  static const _kMilestonesKey = 'mood8.effects.celebrateMilestones';
  static const _kBatterySaverKey = 'mood8.effects.batterySaverAware';
  static const int _maxConcurrent = 3;

  EffectsIntensity _intensity = EffectsIntensity.normal;
  bool _celebrateMilestones = true;
  bool _batterySaverAware = true;
  bool _loaded = false;
  int _active = 0;

  EffectsIntensity get intensity => _intensity;
  bool get celebrateMilestones => _celebrateMilestones;
  bool get batterySaverAware => _batterySaverAware;
  bool get isLoaded => _loaded;

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
    } catch (e) {
      debugPrint('EffectsService.initialize failed: $e');
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> setIntensity(EffectsIntensity i) async {
    if (i == _intensity) return;
    _intensity = i;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kIntensityKey, i.name);
    } catch (e) {
      debugPrint('EffectsService.setIntensity persist failed: $e');
    }
  }

  Future<void> setCelebrateMilestones(bool value) async {
    if (value == _celebrateMilestones) return;
    _celebrateMilestones = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kMilestonesKey, value);
    } catch (_) {}
  }

  Future<void> setBatterySaverAware(bool value) async {
    if (value == _batterySaverAware) return;
    _batterySaverAware = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kBatterySaverKey, value);
    } catch (_) {}
  }

  /// Trigger a celebration. Safe to call from anywhere — degrades to a no-op
  /// when intensity is `off`, the OS has reduce-motion enabled, or we're
  /// already at the concurrent-effect cap.
  ///
  /// [origin] is the screen-space point sparkles emit from. If null,
  /// emission falls back to the centre of the [context]'s screen.
  void celebrate({
    required BuildContext context,
    required CelebrationLevel level,
    Offset? origin,
    String? message,
    Milestone? milestone,
    String? identity,
  }) {
    if (_intensity == EffectsIntensity.off) return;
    final media = MediaQuery.maybeOf(context);
    if (media?.disableAnimations ?? false) {
      // Honor reduce-motion: only show toast (if any).
      if (message != null) _showToast(context, message);
      return;
    }
    if (_active >= _maxConcurrent) return;

    // Map level → sparkle count + spread + duration, scaled by intensity.
    final params = _paramsFor(level);
    if (params.sparkleCount <= 0) {
      if (message != null) _showToast(context, message);
      return;
    }

    // Resolve origin in screen coordinates.
    final size = media?.size ?? const Size(360, 640);
    final effectiveOrigin = origin ?? Offset(size.width / 2, size.height / 2);

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      if (message != null) _showToast(context, message);
      return;
    }

    final spread = params.spread;
    final box = Rect.fromCenter(
      center: effectiveOrigin,
      width: spread * 2.4,
      height: spread * 2.4,
    );

    late OverlayEntry entry;
    entry = OverlayEntry(builder: (_) {
      return Positioned(
        left: box.left,
        top: box.top,
        width: box.width,
        height: box.height,
        child: SparkleOverlay(
          sparkleCount: params.sparkleCount,
          spread: spread,
          duration: params.duration,
          onComplete: () {
            entry.remove();
            _active = (_active - 1).clamp(0, _maxConcurrent);
          },
        ),
      );
    });

    _active += 1;
    overlay.insert(entry);

    if (message != null) {
      _showToast(context, message, important: level != CelebrationLevel.subtle);
    }
  }

  _SparkleParams _paramsFor(CelebrationLevel level) {
    // Intensity scales counts/spread/duration. `minimal` halves; `full`
    // boosts a touch; `normal` is baseline.
    final scale = switch (_intensity) {
      EffectsIntensity.off => 0.0,
      EffectsIntensity.minimal => 0.55,
      EffectsIntensity.normal => 1.0,
      EffectsIntensity.full => 1.25,
    };
    switch (level) {
      case CelebrationLevel.subtle:
        return _SparkleParams(
          sparkleCount: (5 * scale).round(),
          spread: 38 * scale,
          duration: const Duration(milliseconds: 700),
        );
      case CelebrationLevel.notable:
        return _SparkleParams(
          sparkleCount: (10 * scale).round(),
          spread: 64 * scale,
          duration: const Duration(milliseconds: 1100),
        );
      case CelebrationLevel.milestone:
      case CelebrationLevel.identity:
        // Milestones still respect the toggle — degrade to subtle if off.
        final base = _celebrateMilestones ? 22 : 8;
        return _SparkleParams(
          sparkleCount: (base * scale).round(),
          spread: 110 * scale,
          duration: const Duration(milliseconds: 1700),
        );
    }
  }

  void _showToast(BuildContext context, String message,
      {bool important = false}) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: AppColors.ink,
            fontWeight: important ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        backgroundColor: AppColors.bgCard,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: AppColors.purple.withValues(alpha: important ? 0.55 : 0.25),
          ),
        ),
        duration: Duration(seconds: important ? 4 : 2),
      ),
    );
  }
}

class _SparkleParams {
  const _SparkleParams({
    required this.sparkleCount,
    required this.spread,
    required this.duration,
  });
  final int sparkleCount;
  final double spread;
  final Duration duration;
}
