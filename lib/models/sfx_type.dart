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
///
/// Calibrated low across the board so nothing jumps out — UI taps sit
/// around 0.22, save/check-mark sounds around 0.32, big celebrations
/// around 0.45. The audioplayers fade-in / fade-out envelope wrapped
/// around each clip in SfxService softens the attack and tail; this
/// map sets the steady-state level the fade-in ramps up to.
const Map<SfxType, double> sfxBaseVolume = {
  // Small confirmations — quiet, polite.
  SfxType.tabSwitch: 0.20,
  SfxType.onboardingStep: 0.22,
  SfxType.errorGentle: 0.25,
  SfxType.aiMessage: 0.28,
  // Medium check-ins — present but not loud.
  SfxType.habitComplete: 0.32,
  SfxType.checkInSuccess: 0.34,
  SfxType.routineDone: 0.35,
  SfxType.insightDiscovered: 0.34,
  // Bigger moments — slightly fuller, still gentle.
  SfxType.streakMilestone: 0.45,
  SfxType.onboardingFinish: 0.48,
};
