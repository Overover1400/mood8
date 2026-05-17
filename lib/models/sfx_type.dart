enum SfxType {
  checkInSuccess,
  habitComplete,
  routineDone,
  streakMilestone,
  onboardingStep,
  onboardingFinish,
  aiMessage,
  insightDiscovered,
  tabSwitch,
  errorGentle,
}

/// Per-sound asset paths relative to the assets root (no `assets/` prefix —
/// `AssetSource` adds that for you).
const Map<SfxType, String> sfxAssetPaths = {
  SfxType.checkInSuccess: 'sounds/check_in_success.mp3',
  SfxType.habitComplete: 'sounds/habit_complete.mp3',
  SfxType.routineDone: 'sounds/routine_done.mp3',
  SfxType.streakMilestone: 'sounds/streak_milestone.mp3',
  SfxType.onboardingStep: 'sounds/onboarding_step.mp3',
  SfxType.onboardingFinish: 'sounds/onboarding_finish.mp3',
  SfxType.aiMessage: 'sounds/ai_message.mp3',
  SfxType.insightDiscovered: 'sounds/insight_discovered.mp3',
  SfxType.tabSwitch: 'sounds/tab_switch.mp3',
  SfxType.errorGentle: 'sounds/error_gentle.mp3',
};

/// Per-sound preferred volume in [0.0, 1.0]. Multiplied by the user's
/// master volume at play time.
const Map<SfxType, double> sfxBaseVolume = {
  SfxType.checkInSuccess: 0.55,
  SfxType.habitComplete: 0.50,
  SfxType.routineDone: 0.55,
  SfxType.streakMilestone: 0.75,
  SfxType.onboardingStep: 0.40,
  SfxType.onboardingFinish: 0.80,
  SfxType.aiMessage: 0.45,
  SfxType.insightDiscovered: 0.55,
  SfxType.tabSwitch: 0.30,
  SfxType.errorGentle: 0.35,
};
