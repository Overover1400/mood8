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

  /// Settings icon in the Home screen header.
  static final GlobalKey settingsButton = GlobalKey(debugLabel: 'tut.settings');

  /// The block of three mood / energy / focus sliders on Today.
  static final GlobalKey moodSliders = GlobalKey(debugLabel: 'tut.moodSliders');

  /// Gratitude card on Today.
  static final GlobalKey gratitudeCard = GlobalKey(debugLabel: 'tut.gratitude');

  /// "+" FAB on the Habits screen.
  static final GlobalKey addHabit = GlobalKey(debugLabel: 'tut.addHabit');

  /// "Add routine" CTA on the Routine screen.
  static final GlobalKey addRoutine = GlobalKey(debugLabel: 'tut.addRoutine');

  /// "Share your progress" CTA on the Progress screen.
  static final GlobalKey shareProgress = GlobalKey(debugLabel: 'tut.share');
}
