enum EffectsIntensity {
  off,
  minimal,
  normal,
  full;

  String get label {
    switch (this) {
      case EffectsIntensity.off:
        return 'Off';
      case EffectsIntensity.minimal:
        return 'Minimal';
      case EffectsIntensity.normal:
        return 'Normal';
      case EffectsIntensity.full:
        return 'Full';
    }
  }

  String get description {
    switch (this) {
      case EffectsIntensity.off:
        return 'No animations at all';
      case EffectsIntensity.minimal:
        return 'Just the essentials';
      case EffectsIntensity.normal:
        return 'Balanced, default';
      case EffectsIntensity.full:
        return 'All celebrations on';
    }
  }
}

enum CelebrationLevel {
  /// Habit complete, small wins. Tiny sparkle, no toast.
  subtle,
  /// Streak maintained, routine done. More sparkles + a brief glow.
  notable,
  /// 7/30/100/365 day streak. Big sparkles, toast, longer duration.
  milestone,
  /// Identity crossed a meaningful threshold. Same as milestone +
  /// identity-themed copy.
  identity,
}
