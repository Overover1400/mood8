import 'package:flutter/material.dart';

/// Global registry of GlobalKeys for widgets the welcome tutorial can
/// spotlight. Each screen attaches the appropriate key to the widget
/// when it builds; the tutorial reads the key's RenderBox at draw time
/// to compute the spotlight rect.
///
/// Falling back gracefully: if a key is unmounted (the relevant tab
/// isn't visible yet), the tutorial reverts to spotlighting the tab
/// in the bottom nav and the step still reads correctly.
class TutorialTargets {
  TutorialTargets._();

  /// Avatar in the Home screen header — opens Settings.
  static final GlobalKey settingsButton = GlobalKey(debugLabel: 'tut.settings');

  /// The "+" button in the Home header that opens the intention /
  /// gratitude sheet. Distinct from [settingsButton] (the avatar) — the
  /// two sit side by side and the tutorial points at each separately.
  static final GlobalKey addButton = GlobalKey(debugLabel: 'tut.add');

  /// The block of three mood / energy / focus sliders on Today.
  static final GlobalKey moodSliders = GlobalKey(debugLabel: 'tut.moodSliders');

  /// Progress | Insights segmented toggle at the top of the Progress tab.
  static final GlobalKey insightsToggle =
      GlobalKey(debugLabel: 'tut.insightsToggle');

  /// Gratitude card on Today.
  static final GlobalKey gratitudeCard = GlobalKey(debugLabel: 'tut.gratitude');

  /// "+" FAB on the Habits screen.
  static final GlobalKey addHabit = GlobalKey(debugLabel: 'tut.addHabit');

  /// "Add routine" CTA on the Routine screen.
  static final GlobalKey addRoutine = GlobalKey(debugLabel: 'tut.addRoutine');

  /// "Share your progress" CTA on the Progress screen.
  static final GlobalKey shareProgress = GlobalKey(debugLabel: 'tut.share');
}
