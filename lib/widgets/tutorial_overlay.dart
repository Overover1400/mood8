import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/main_navigation.dart';
import '../services/haptic_service.dart';
import '../theme/app_theme.dart';
import 'bottom_nav.dart';

const String _kTutorialCompletedPrefKey = 'tutorial_completed';

/// Returns true if the user has already seen (or skipped) the tutorial.
Future<bool> isTutorialCompleted() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kTutorialCompletedPrefKey) ?? false;
  } catch (_) {
    return false;
  }
}

Future<void> markTutorialCompleted() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kTutorialCompletedPrefKey, true);
  } catch (_) {/* best effort */}
}

Future<void> resetTutorial() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kTutorialCompletedPrefKey, false);
  } catch (_) {}
}

class _TutorialStep {
  const _TutorialStep({
    required this.tabIndex,
    required this.icon,
    required this.label,
    required this.title,
    required this.body,
  });
  final int tabIndex; // 0..5 — also the spotlight target inside bottom nav
  final IconData icon;
  final String label;
  final String title;
  final String body;
}

const List<_TutorialStep> _kSteps = [
  _TutorialStep(
    tabIndex: 0,
    icon: Icons.today_rounded,
    label: 'TODAY',
    title: 'Your daily moment.',
    body:
        'Check in with your mood and energy, run through your routines, and feel the shape of your day.',
  ),
  _TutorialStep(
    tabIndex: kHabitsTabIndex,
    icon: Icons.check_circle_outline_rounded,
    label: 'HABITS',
    title: 'Small votes, big identity.',
    body:
        'Each habit is a quiet vote for who you are becoming. Tap to complete, hold to edit.',
  ),
  _TutorialStep(
    tabIndex: kRoutineTabIndex,
    icon: Icons.schedule_rounded,
    label: 'ROUTINE',
    title: 'A flow that fits you.',
    body:
        "Lay out the rhythm of your day. We'll surface what's next and celebrate when it's done.",
  ),
  _TutorialStep(
    tabIndex: kCoachTabIndex,
    icon: Icons.chat_bubble_outline_rounded,
    label: 'COACH',
    title: 'Quiet, warm, available.',
    body:
        'Ask the coach anything. Get a nightly reflection that reads your day with care.',
  ),
  _TutorialStep(
    tabIndex: kInsightsTabIndex,
    icon: Icons.auto_awesome_rounded,
    label: 'INSIGHTS',
    title: 'Patterns made visible.',
    body:
        'Mood8 surfaces the patterns behind your mood — what lifts you, what drains you.',
  ),
  _TutorialStep(
    tabIndex: kProgressTabIndex,
    icon: Icons.bar_chart_rounded,
    label: 'PROGRESS',
    title: 'Identity in motion.',
    body:
        'Streaks, completion rates, identity progress — the long view of who you are becoming.',
  ),
];

/// Mounts the tutorial as a floating overlay above MainNavigation so the
/// app's bottom nav + tab body remain interactive (we drive them) while
/// the tutorial dims everything except the highlighted spot. Fire and
/// forget — the entry removes itself on Skip or final Next.
void showTutorial(BuildContext context) {
  HapticService().light();
  final overlay = Overlay.of(context, rootOverlay: true);
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
  }

  void _next() {
    HapticService().selection();
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
    setState(() => _index--);
    _switchToCurrentTab();
  }

  void _skip() {
    HapticService().light();
    widget.onSkip();
  }

  /// Computes the on-screen rect of the currently-spotlit bottom nav tab.
  /// Bottom nav is a 66px-tall Container with 12px L/R + 12px bottom outer
  /// padding, holding 6 equal-width tabs. Each tab has 2px horizontal
  /// margin so the actual highlight is slightly inset.
  Rect _spotlightRectFor(BuildContext context, int tabIndex) {
    final media = MediaQuery.of(context);
    final w = media.size.width;
    final h = media.size.height;
    final bottomInset = media.padding.bottom;
    const navOuterPad = 12.0;
    const navHeight = 66.0;
    const tabCount = 6;
    final innerW = w - navOuterPad * 2;
    final tabW = innerW / tabCount;
    final navTop = h - navHeight - navOuterPad - bottomInset;
    // The _NavButton inside has horizontal margin: 2 and vertical: 7.
    return Rect.fromLTWH(
      navOuterPad + tabIndex * tabW + 2,
      navTop + 7,
      tabW - 4,
      navHeight - 14,
    );
  }

  @override
  Widget build(BuildContext context) {
    final step = _kSteps[_index];
    final isLast = _index == _kSteps.length - 1;
    final spotlight = _spotlightRectFor(context, step.tabIndex);
    return Material(
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
          // Step header + Skip
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 8,
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
                      color: AppColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Explanation card — anchored near the bottom, above the bottom nav
          Positioned(
            left: 16,
            right: 16,
            // Sit just above the spotlight; clamp so it doesn't crowd the
            // top inset on tiny screens.
            bottom: MediaQuery.of(context).size.height - spotlight.top + 16,
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
    );
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
            AppColors.bgCard,
            AppColors.bg,
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
                  color: AppColors.inkDim,
                  fontSize: 11,
                  letterSpacing: 2.2,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            step.title,
            style: GoogleFonts.instrumentSerif(
              color: AppColors.ink,
              fontStyle: FontStyle.italic,
              fontSize: 28,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            step.body,
            style: TextStyle(
              color: AppColors.inkSoft,
              fontSize: 14.5,
              height: 1.55,
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
                  : AppColors.inkFaint.withValues(alpha: 0.55),
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
          color: AppColors.bgCard.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(23),
          border: Border.all(
            color: AppColors.purple.withValues(alpha: 0.35),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: AppColors.ink,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
