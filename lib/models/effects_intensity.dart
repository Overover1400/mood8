enum EffectsIntensity {
  off,
  subtle,
  normal,
  cinematic;

  /// Multiplier applied to per-effect duration. `normal` is the reference.
  double get durationScale {
    switch (this) {
      case EffectsIntensity.off:
        return 0.0;
      case EffectsIntensity.subtle:
        return 0.55;
      case EffectsIntensity.normal:
        return 1.0;
      case EffectsIntensity.cinematic:
        return 1.5;
    }
  }

  /// Multiplier applied to particle counts. Subtle halves; cinematic ~+25%.
  double get particleScale {
    switch (this) {
      case EffectsIntensity.off:
        return 0.0;
      case EffectsIntensity.subtle:
        return 0.55;
      case EffectsIntensity.normal:
        return 1.0;
      case EffectsIntensity.cinematic:
        return 1.25;
    }
  }

  String get label {
    switch (this) {
      case EffectsIntensity.off:
        return 'Off';
      case EffectsIntensity.subtle:
        return 'Subtle';
      case EffectsIntensity.normal:
        return 'Normal';
      case EffectsIntensity.cinematic:
        return 'Cinematic';
    }
  }

  String get description {
    switch (this) {
      case EffectsIntensity.off:
        return 'No animations at all';
      case EffectsIntensity.subtle:
        return 'Quick, low-key versions';
      case EffectsIntensity.normal:
        return 'Full premium effects · default';
      case EffectsIntensity.cinematic:
        return 'Extra-long, extra-premium';
    }
  }
}

/// Legacy level retained so existing call sites don't need a rewrite.
/// `subtle` and `notable` map to [EffectsService.celebrateHabitComplete];
/// `milestone` and `identity` map to the larger celebrations.
enum CelebrationLevel {
  subtle,
  notable,
  milestone,
  identity,
}
