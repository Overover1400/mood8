import 'package:flutter/animation.dart';

/// Curated easing curves for the premium effects system. All are calibrated
/// for *cinematic* motion — slow accelerations, controlled landings.
class PremiumEasing {
  PremiumEasing._();

  /// Slow → fast → slow. Default cinematic timing for hero moments.
  static const Cubic cinematic = Cubic(0.33, 0.0, 0.67, 1.0);

  /// Gentle overshoot near the end. Use for entrance moments where a tiny
  /// "land" feels alive without being cartoony.
  static const Cubic subtleBounce = Cubic(0.34, 1.56, 0.64, 1.0);

  /// Slow start, very smooth landing. The Linear / Vision Pro "luxe" curve.
  static const Cubic luxe = Cubic(0.16, 1, 0.3, 1);

  /// Pulls back before launching forward. Anticipation builds tension.
  static const Cubic anticipate = Cubic(0.36, 0, 0.66, -0.56);
}
