import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../feature_flags.dart';
import '../screens/main_navigation.dart';
import '../services/haptic_service.dart';
import '../services/overlay_coordinator.dart';
import '../services/sync_service.dart';
import '../services/user_repository.dart';
import '../theme/app_theme.dart';
import 'bottom_nav.dart';
import 'tutorial_targets.dart';

const String _kTutorialCompletedPrefKey = 'tutorial_completed';

/// Reactive flag for the tutorial-completion state. Other prompt
/// surfaces (morning intention, freeze offer) listen to this so they
/// can hold off until the tutorial is dismissed and then fire in turn.
/// Initialized once from SharedPreferences via [warmUpTutorialState].
final ValueNotifier<bool> tutorialCompletedNotifier =
    ValueNotifier<bool>(false);

/// Loads the persisted flag into [tutorialCompletedNotifier]. Call once
/// on app boot before any screen reads it. The synced UserProfile field
/// (when present) takes priority over the device-local pref so a user
/// who completed the tutorial on another device doesn't see it again.
Future<void> warmUpTutorialState() async {
  bool seen = false;
  try {
    final synced = UserRepository().getCurrentUser()?.tutorialCompleted;
    if (synced == true) seen = true;
  } catch (_) {/* user not loaded yet */}
  if (!seen) {
    try {
      final prefs = await SharedPreferences.getInstance();
      seen = prefs.getBool(_kTutorialCompletedPrefKey) ?? false;
    } catch (_) {}
  }
  tutorialCompletedNotifier.value = seen;
}

/// Returns true if the user has already seen (or skipped) the tutorial
/// — either on this device or on any other device (via UserProfile sync).
Future<bool> isTutorialCompleted() async {
  try {
    if (UserRepository().getCurrentUser()?.tutorialCompleted == true) {
      return true;
    }
  } catch (_) {}
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kTutorialCompletedPrefKey) ?? false;
  } catch (_) {
    return false;
  }
}

Future<void> markTutorialCompleted() async {
  tutorialCompletedNotifier.value = true;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kTutorialCompletedPrefKey, true);
  } catch (_) {/* best effort */}
  // Flip the synced field too so registering / signing in on another
  // device keeps the tutorial dismissed. UserRepository tags the row
  // with updatedAt so SyncService picks it up on the next push.
  try {
    final user = UserRepository().getCurrentUser();
    if (user != null && !user.tutorialCompleted) {
      user.tutorialCompleted = true;
      await UserRepository().saveUser(user);
      // Debounced push catches the change without a full sync round-trip.
      SyncService().debouncedPush();
    }
  } catch (_) {/* offline / not signed in */}
}

Future<void> resetTutorial() async {
  tutorialCompletedNotifier.value = false;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kTutorialCompletedPrefKey, false);
  } catch (_) {}
  // Mirror to the synced profile so "Replay tutorial" actually replays
  // across devices the next time the user signs in elsewhere.
  try {
    final user = UserRepository().getCurrentUser();
    if (user != null && user.tutorialCompleted) {
      user.tutorialCompleted = false;
      await UserRepository().saveUser(user);
      SyncService().debouncedPush();
    }
  } catch (_) {}
}

class _TutorialStep {
  const _TutorialStep({
    required this.tabIndex,
    required this.icon,
    required this.label,
    required this.title,
    required this.body,
    this.targetKey,
    this.requiresTarget = false,
  });
  /// Tab to switch to before showing this step. Also the fallback
  /// spotlight target (the bottom-nav button for this tab) if
  /// [targetKey] is null or its widget isn't yet mounted.
  final int tabIndex;
  final IconData icon;
  final String label;
  final String title;
  final String body;
  /// Optional in-screen widget to spotlight, picked up from
  /// [TutorialTargets]. When the target is on-screen we compute its
  /// rect from the RenderBox; otherwise we degrade to the tab-nav
  /// spotlight so the step still reads.
  final GlobalKey? targetKey;

  /// When true this step only makes sense pointing at [targetKey] — the
  /// generic bottom-nav fallback would highlight the wrong thing. If the
  /// target isn't mounted and on-screen when the step runs (e.g. a CTA
  /// scrolled below the fold), the step is skipped gracefully rather than
  /// spotlighting empty space. Nav-level steps (no meaningful in-screen
  /// anchor) leave this false so they fall back to their tab button.
  final bool requiresTarget;
}

List<_TutorialStep> get _kSteps => <_TutorialStep>[
      // ── Today + check-in ────────────────────────────────────────────
      _TutorialStep(
        tabIndex: 0,
        icon: Icons.today_rounded,
        label: 'TODAY',
        title: 'Your daily moment.',
        body:
            'Check in with your mood, energy, and focus, and feel the shape of your day at a glance.',
      ),
      _TutorialStep(
        tabIndex: 0,
        icon: Icons.tune_rounded,
        label: 'CHECK-IN',
        title: 'Slide. Done.',
        body:
            'Adjust Mood, Energy, and Focus — Mood8 saves automatically a moment after you stop.',
        targetKey: TutorialTargets.moodSliders,
        requiresTarget: true,
      ),
      _TutorialStep(
        tabIndex: 0,
        icon: Icons.add_rounded,
        label: 'INTENTION + GRATITUDE',
        title: 'The “+” adds depth.',
        body:
            'Tap the plus in the header to set today’s intention or log three gratitudes.',
        targetKey: TutorialTargets.addButton,
        requiresTarget: true,
      ),
      // ── Habits ──────────────────────────────────────────────────────
      _TutorialStep(
        tabIndex: kHabitsTabIndex,
        icon: Icons.check_circle_outline_rounded,
        label: 'HABITS',
        title: 'Small votes, big identity.',
        body:
            'Each habit is a quiet vote for who you are becoming. Tap to complete, hold to edit, sort however suits you.',
      ),
      _TutorialStep(
        tabIndex: kHabitsTabIndex,
        icon: Icons.add_rounded,
        label: 'ADD A HABIT',
        title: 'Build one in seconds.',
        body:
            'The + button opens a quick sheet: name, identity, cadence. That’s the whole flow.',
        targetKey: TutorialTargets.addHabit,
        requiresTarget: true,
      ),
      // ── Routine ─────────────────────────────────────────────────────
      // Hidden behind kRoutineEnabled — both Routine steps drop out
      // of the tutorial list when the feature is off so the user
      // doesn't see a "Routine" card pointing at a tab that doesn't
      // exist. Flip the flag and these come back automatically.
      if (kRoutineEnabled) ...[
        _TutorialStep(
          tabIndex: kRoutineTabIndex,
          icon: Icons.schedule_rounded,
          label: 'ROUTINE',
          title: 'A flow that fits you.',
          body:
              "Lay out the rhythm of your day. We'll surface what's next and celebrate when it's done.",
        ),
        _TutorialStep(
          tabIndex: kRoutineTabIndex,
          icon: Icons.add_rounded,
          label: 'ADD A ROUTINE',
          title: 'Stack your day.',
          body:
              'Tap + to drop a new ritual into your timeline — meditate, write, walk, anything.',
          targetKey: TutorialTargets.addRoutine,
          requiresTarget: true,
        ),
      ],
      // ── Challenge ───────────────────────────────────────────────────
      _TutorialStep(
        tabIndex: kChallengeTabIndex,
        icon: Icons.flag_rounded,
        label: 'CHALLENGE',
        title: 'Push together. Rank up.',
        body:
            'Join (or start) a group challenge. One check-in a day before the deadline keeps your military rank climbing — Recruit to Legend.',
      ),
      // ── Coach ───────────────────────────────────────────────────────
      _TutorialStep(
        tabIndex: kCoachTabIndex,
        icon: Icons.chat_bubble_outline_rounded,
        label: 'COACH',
        title: 'Quiet, warm, available.',
        body:
            'Ask the coach anything. Get a nightly reflection that reads your day with care.',
      ),
      // ── Progress (now also hosts Insights) ──────────────────────────
      _TutorialStep(
        tabIndex: kProgressTabIndex,
        icon: Icons.bar_chart_rounded,
        label: 'PROGRESS',
        title: 'Identity in motion.',
        body:
            'Streaks, completion rates, identity progress — the long view of who you are becoming.',
      ),
      _TutorialStep(
        tabIndex: kProgressTabIndex,
        icon: Icons.auto_awesome_rounded,
        label: 'INSIGHTS',
        title: 'Patterns made visible.',
        body:
            'Flip to “Insights” at the top of Progress to see what lifts you, what drains you, and what to try next.',
        targetKey: TutorialTargets.insightsToggle,
        requiresTarget: true,
      ),
      _TutorialStep(
        tabIndex: kProgressTabIndex,
        icon: Icons.ios_share_rounded,
        label: 'SHARE',
        title: 'Make it visible.',
        body:
            'Export a beautiful card of your week — for your story, feed, or fridge.',
        targetKey: TutorialTargets.shareProgress,
        requiresTarget: true,
      ),
      // ── Settings ────────────────────────────────────────────────────
      _TutorialStep(
        tabIndex: 0,
        icon: Icons.settings_rounded,
        label: 'SETTINGS',
        title: 'It’s your space.',
        body:
            'Tap your avatar to customize the experience, manage your account, and upgrade to Premium.',
        targetKey: TutorialTargets.settingsButton,
        requiresTarget: true,
      ),
    ];

/// Mounts the tutorial as a floating overlay above MainNavigation so the
/// app's bottom nav + tab body remain interactive (we drive them) while
/// the tutorial dims everything except the highlighted spot. Fire and
/// forget — the entry removes itself on Skip or final Next.
void showTutorial(BuildContext context) async {
  // Wait for any in-flight reward/celebration overlay to dismiss FIRST
  // so the tutorial spotlight isn't buried under confetti / orbs.
  //
  // Guarded by a timeout: the first run is the busiest moment for
  // celebration overlays, and if a producer ever leaks its counter
  // (push without a matching pop — e.g. an overlay torn down by a
  // route change) whenIdle() would hang forever and the tutorial would
  // silently never appear. That is the "doesn't reliably show to first
  // users" failure. After the grace period we show regardless.
  await OverlayCoordinator().whenIdle().timeout(
        const Duration(seconds: 5),
        onTimeout: () {},
      );
  if (!context.mounted) return;
  // The tutorial drives + spotlights the bottom-nav tabs, so it MUST render
  // over MainNavigation. When launched from a PUSHED route — most commonly
  // "Replay tutorial" inside Settings — that route sits on top of the tabs,
  // and the overlay would dim Settings while its GlobalKey targets resolve
  // to Home/Habits widgets hidden behind it (highlights landing on empty
  // space — exactly the reported breakage). Pop back to the root route so
  // the overlay always sits above the live tab screens.
  final navigator = Navigator.of(context, rootNavigator: true);
  navigator.popUntil((route) => route.isFirst);
  final overlay = navigator.overlay;
  if (overlay == null) return;
  HapticService().light();
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => _TutorialOverlay(
      onFinish: () async {
        await markTutorialCompleted();
        entry.remove();
      },
      onSkip: () async {
        await markTutorialCompleted();
        entry.remove();
      },
    ),
  );
  overlay.insert(entry);
  // Mark as seen the instant it's committed to render — not only on
  // Finish/Skip. If the user force-quits the app mid-walkthrough, the
  // tutorial has still been "shown once" and must not reappear on the
  // next launch (item: show exactly once per user). The onFinish/onSkip
  // handlers still call this; markTutorialCompleted is idempotent.
  markTutorialCompleted();
}

class _TutorialOverlay extends StatefulWidget {
  const _TutorialOverlay({
    required this.onFinish,
    required this.onSkip,
  });
  final VoidCallback onFinish;
  final VoidCallback onSkip;

  @override
  State<_TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<_TutorialOverlay> {
  int _index = 0;
  // Navigation direction of the last move (+1 = forward, -1 = back). Used
  // when a step has to be skipped because its target isn't on screen, so
  // we skip in the direction the user was already heading.
  int _dir = 1;

  @override
  void initState() {
    super.initState();
    // Sync the visible tab with the first step the moment the overlay
    // appears so the user sees Home behind the dim layer.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _switchToCurrentTab();
    });
  }

  void _switchToCurrentTab() {
    final step = _kSteps[_index];
    MainNavigation.goToTab(context, step.tabIndex);
    // Give the freshly-mounted tab a frame to build so its
    // TutorialTargets GlobalKeys have a RenderBox, rebuild to pick up
    // that geometry, then — once it's settled — decide whether the step
    // is actually anchorable or should be skipped.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _resolveOrSkip();
      });
    });
  }

  /// If the current step needs an in-screen target that isn't mounted /
  /// on-screen (e.g. a CTA below the fold), skip past it in the current
  /// navigation direction instead of spotlighting empty space.
  void _resolveOrSkip() {
    final step = _kSteps[_index];
    if (!step.requiresTarget) return;
    if (_isTargetVisible(step)) return;
    if (_dir >= 0) {
      if (_index >= _kSteps.length - 1) {
        widget.onFinish();
        return;
      }
      setState(() => _index++);
    } else {
      if (_index <= 0) {
        // Nothing earlier to fall back to — search forward so we never
        // dead-end on the very first step.
        _dir = 1;
        if (_index >= _kSteps.length - 1) {
          widget.onFinish();
          return;
        }
        setState(() => _index++);
      } else {
        setState(() => _index--);
      }
    }
    _switchToCurrentTab();
  }

  void _next() {
    HapticService().selection();
    _dir = 1;
    if (_index >= _kSteps.length - 1) {
      widget.onFinish();
      return;
    }
    setState(() => _index++);
    _switchToCurrentTab();
  }

  void _back() {
    if (_index <= 0) return;
    HapticService().selection();
    _dir = -1;
    setState(() => _index--);
    _switchToCurrentTab();
  }

  void _skip() {
    HapticService().light();
    widget.onSkip();
  }

  /// Spotlight rect for the current step. Prefers the step's
  /// [TutorialTargets] GlobalKey when its widget is mounted AND on-screen.
  /// Otherwise anchors on the LIVE bottom-nav tab button (read from its
  /// GlobalKey), and only if that isn't mounted yet falls back to computed
  /// nav geometry as a last resort.
  Rect _spotlightRectFor(BuildContext context, _TutorialStep step) {
    final keyed = _rectForKey(step.targetKey);
    if (keyed != null && _isRectVisible(keyed)) return keyed;
    final navKey = (step.tabIndex >= 0 && step.tabIndex < kNavTabKeys.length)
        ? kNavTabKeys[step.tabIndex]
        : null;
    final navRect = _rectForKey(navKey);
    if (navRect != null) return navRect;
    return _navTabRect(context, step.tabIndex);
  }

  /// The usable viewport for judging whether a target is "on screen":
  /// the full size minus the top safe-area (where the tutorial header
  /// sits) and the bottom nav bar (which floats over content).
  Rect _viewport() {
    final media = MediaQuery.of(context);
    const navReserve = 66.0 + 12.0; // nav height + outer bottom padding
    return Rect.fromLTRB(
      0,
      media.padding.top,
      media.size.width,
      media.size.height - navReserve - media.padding.bottom,
    );
  }

  bool _isTargetVisible(_TutorialStep step) {
    final r = _rectForKey(step.targetKey);
    return r != null && _isRectVisible(r);
  }

  /// True when a majority of [r] falls inside the usable viewport. A CTA
  /// scrolled below the fold (only a sliver peeking up behind the nav)
  /// reads as not visible, so its step is skipped rather than anchoring
  /// the spotlight to empty space.
  bool _isRectVisible(Rect r) {
    final fullArea = r.width * r.height;
    if (fullArea <= 0) return false;
    final shown = r.intersect(_viewport());
    if (shown.isEmpty || shown.width <= 0 || shown.height <= 0) return false;
    return (shown.width * shown.height) >= fullArea * 0.6;
  }

  Rect? _rectForKey(GlobalKey? key) {
    if (key == null) return null;
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final render = ctx.findRenderObject();
    if (render is! RenderBox || !render.attached) return null;
    final offset = render.localToGlobal(Offset.zero);
    final size = render.size;
    // Pad the rect a touch so the spotlight reads as breathing room
    // around the target, not skin-tight to its edge.
    return Rect.fromLTWH(
      offset.dx - 6,
      offset.dy - 6,
      size.width + 12,
      size.height + 12,
    );
  }

  /// Fallback geometry: rect of the bottom-nav tab button for [tabIndex].
  /// Bottom nav is a 66px-tall Container with 12px L/R + 12px bottom outer
  /// padding, holding [kNavItems.length] equal-width tabs. Each tab has 2px
  /// horizontal margin so the actual highlight is slightly inset.
  ///
  /// The tab count is read live from [kNavItems] rather than hardcoded:
  /// the Routine tab is currently hidden (5 tabs, not 6), and a stale
  /// constant here shifted every nav-anchored spotlight to the wrong tab.
  Rect _navTabRect(BuildContext context, int tabIndex) {
    final media = MediaQuery.of(context);
    final w = media.size.width;
    final h = media.size.height;
    final bottomInset = media.padding.bottom;
    const navOuterPad = 12.0;
    const navHeight = 66.0;
    final tabCount = kNavItems.length;
    // Clamp so a gated/out-of-range tab index can never point off the bar.
    final idx = tabIndex.clamp(0, tabCount - 1);
    final innerW = w - navOuterPad * 2;
    final tabW = innerW / tabCount;
    final navTop = h - navHeight - navOuterPad - bottomInset;
    return Rect.fromLTWH(
      navOuterPad + idx * tabW + 2,
      navTop + 7,
      tabW - 4,
      navHeight - 14,
    );
  }

  @override
  Widget build(BuildContext context) {
    final step = _kSteps[_index];
    final isLast = _index == _kSteps.length - 1;
    final spotlight = _spotlightRectFor(context, step);
    // Cap the effective text scale for the overlay only. The step card is
    // a fixed-position element with finite room; letting an accessibility
    // font scale of 2× through would push the Next / Back buttons off the
    // bottom. The card body also scrolls (below), so nothing is lost —
    // this just keeps the controls on screen.
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(
        textScaler: mq.textScaler.clamp(maxScaleFactor: 1.3),
      ),
      child: Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Dim layer with the cutout — taps inside the hole pass through
          // (so user could see the live tab interaction); taps outside are
          // captured by the Material so the underlying app is "frozen"
          // visually.
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _SpotlightPainter(
                  hole: spotlight,
                  // Animated value so the cutout slides smoothly between
                  // steps without re-allocating the painter.
                ),
              ),
            ),
          ),
          // A subtle pulsing ring around the spotlight so the eye is drawn.
          Positioned(
            left: spotlight.left - 4,
            top: spotlight.top - 4,
            width: spotlight.width + 8,
            height: spotlight.height + 8,
            child: IgnorePointer(
              child: _SpotlightRing(),
            ),
          ),
          // Step header + Skip — centered within the same max width as the
          // card so on wide web the Skip control sits by the card, not in a
          // far corner.
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Align(
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Row(
                  children: [
                    Text(
                      'TUTORIAL  ·  ${_index + 1} / ${_kSteps.length}',
                      style: TextStyle(
                        color: AppColors.pinkLight,
                        fontSize: 11,
                        letterSpacing: 2.0,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _skip,
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          color: BrandColors.ink(context),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Explanation card. Default position is just above the
          // spotlight; if the spotlight sits high on the screen (above
          // ~35% from the top) we instead place the card BELOW it so we
          // don't try to fit a card in 100px of space.
          _PositionedStepCard(
            spotlight: spotlight,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              transitionBuilder: (child, animation) {
                final offset = Tween<Offset>(
                  begin: const Offset(0.04, 0),
                  end: Offset.zero,
                ).animate(animation);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(position: offset, child: child),
                );
              },
              child: _StepCard(
                key: ValueKey(_index),
                step: step,
                isLast: isLast,
                onBack: _index > 0 ? _back : null,
                onNext: _next,
                stepCount: _kSteps.length,
                activeIndex: _index,
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

/// Places the explanation card on whichever side of the spotlight has
/// more room (below if the spotlight is high, above if it's low), and
/// constrains the card's height to that available space so its Next /
/// Back buttons can never spill off-screen or land under the highlight.
class _PositionedStepCard extends StatelessWidget {
  const _PositionedStepCard({
    required this.spotlight,
    required this.child,
  });
  final Rect spotlight;
  final Widget child;

  // Floor for the card height: enough for the header row, dots, and the
  // button row even when the body is fully scrolled away.
  static const double _minCardHeight = 150.0;
  // Cap the card width so it reads as a card (not a full-bleed banner) on
  // wide web / tablet / desktop. Centered within the 16px side margins.
  static const double _maxCardWidth = 460.0;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final h = media.size.height;
    final topReserve = media.padding.top + 52; // tutorial header + skip row
    final botReserve = media.padding.bottom + 12;
    const gap = 14.0;

    final spaceBelow = h - botReserve - (spotlight.bottom + gap);
    final spaceAbove = (spotlight.top - gap) - topReserve;
    final placeBelow = spaceBelow >= spaceAbove;

    final avail = placeBelow ? spaceBelow : spaceAbove;
    final maxH = avail.clamp(_minCardHeight, h * 0.72);
    final constrained = Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH, maxWidth: _maxCardWidth),
        child: child,
      ),
    );

    if (placeBelow) {
      final top = (spotlight.bottom + gap)
          .clamp(topReserve, h - botReserve - _minCardHeight);
      return Positioned(left: 16, right: 16, top: top, child: constrained);
    }
    final bottom = (h - (spotlight.top - gap))
        .clamp(botReserve, h - topReserve - _minCardHeight);
    return Positioned(left: 16, right: 16, bottom: bottom, child: constrained);
  }
}

/// Paints the full-screen dim layer with a rounded-rect cutout. The cutout
/// is the bottom-nav tab being spotlit; everything outside it darkens to
/// 85% opacity black.
class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({required this.hole});
  final Rect hole;

  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Path()..addRect(Offset.zero & size);
    final cutout = Path()
      ..addRRect(RRect.fromRectAndRadius(
        hole.inflate(2),
        const Radius.circular(20),
      ));
    final cut = Path.combine(PathOperation.difference, overlay, cutout);
    canvas.drawPath(
      cut,
      Paint()..color = Colors.black.withValues(alpha: 0.78),
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      oldDelegate.hole != hole;
}

class _SpotlightRing extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.pinkLight.withValues(alpha: 0.85),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.pink.withValues(alpha: 0.55),
            blurRadius: 22,
            spreadRadius: -2,
          ),
        ],
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(
          begin: 1.0,
          end: 1.06,
          duration: 1200.ms,
          curve: Curves.easeInOut,
        );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    super.key,
    required this.step,
    required this.isLast,
    required this.onBack,
    required this.onNext,
    required this.stepCount,
    required this.activeIndex,
  });

  final _TutorialStep step;
  final bool isLast;
  final VoidCallback? onBack;
  final VoidCallback onNext;
  final int stepCount;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            BrandColors.bgCard(context),
            BrandColors.bg(context),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.purpleLight.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.purple.withValues(alpha: 0.30),
            blurRadius: 36,
            spreadRadius: -8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.pinkLight.withValues(alpha: 0.85),
                      AppColors.purple.withValues(alpha: 0.25),
                      Colors.transparent,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.pink.withValues(alpha: 0.40),
                      blurRadius: 14,
                    ),
                  ],
                ),
                child: Icon(step.icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                step.label,
                style: TextStyle(
                  color: BrandColors.inkDim(context),
                  fontSize: 11,
                  letterSpacing: 2.2,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Title + body scroll if the card is height-constrained (short
          // screens, large fonts) so the pinned dots + buttons below never
          // get pushed off-screen.
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    step.title,
                    style: GoogleFonts.bricolageGrotesque(
                      color: BrandColors.ink(context),
                      fontSize: 28,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    step.body,
                    style: TextStyle(
                      color: BrandColors.inkSoft(context),
                      fontSize: 14.5,
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _StepDots(count: stepCount, active: activeIndex),
          const SizedBox(height: 14),
          Row(
            children: [
              if (onBack != null) ...[
                Expanded(
                  child: _SecondaryButton(label: 'Back', onTap: onBack!),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                flex: onBack == null ? 2 : 1,
                child: _PrimaryButton(
                  label: isLast ? 'Get started' : 'Next',
                  onTap: onNext,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.count, required this.active});
  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == active ? 22 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: i == active
                  ? AppColors.pinkLight
                  : BrandColors.inkFaint(context).withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: AppColors.buttonGradient,
          borderRadius: BorderRadius.circular(23),
          boxShadow: [
            BoxShadow(
              color: AppColors.pink.withValues(alpha: 0.40),
              blurRadius: 18,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 14,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: BrandColors.bgCard(context).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(23),
          border: Border.all(
            color: AppColors.purple.withValues(alpha: 0.35),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: BrandColors.ink(context),
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
