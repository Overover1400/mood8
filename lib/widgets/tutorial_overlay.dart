import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/haptic_service.dart';
import '../theme/app_theme.dart';

const String _kTutorialCompletedPrefKey = 'tutorial_completed';

class _TutorialStep {
  const _TutorialStep({
    required this.icon,
    required this.label,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String label; // small uppercase eyebrow
  final String title; // italic serif heading
  final String body;
}

const List<_TutorialStep> _kSteps = [
  _TutorialStep(
    icon: Icons.today_rounded,
    label: 'TODAY',
    title: 'Your daily moment.',
    body:
        'Check in with your mood and energy, run through your routines, and feel the shape of your day.',
  ),
  _TutorialStep(
    icon: Icons.check_circle_outline_rounded,
    label: 'HABITS',
    title: 'Small votes, big identity.',
    body:
        'Each habit is a quiet vote for who you are becoming. Tap to complete, hold to edit.',
  ),
  _TutorialStep(
    icon: Icons.event_available_rounded,
    label: 'ROUTINE',
    title: 'A flow that fits you.',
    body:
        "Lay out the rhythm of your day. We'll surface what's next and celebrate when it's done.",
  ),
  _TutorialStep(
    icon: Icons.auto_awesome_rounded,
    label: 'COACH',
    title: 'Quiet, warm, available.',
    body:
        'Ask the coach anything. Get a nightly reflection that reads your day with care.',
  ),
  _TutorialStep(
    icon: Icons.insights_rounded,
    label: 'INSIGHTS',
    title: 'Patterns made visible.',
    body:
        'Mood8 surfaces the patterns behind your mood — what lifts you, what drains you.',
  ),
  _TutorialStep(
    icon: Icons.show_chart_rounded,
    label: 'PROGRESS',
    title: 'Identity in motion.',
    body:
        'Streaks, completion rates, identity progress — the long view of who you are becoming.',
  ),
];

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

/// Pushes the tutorial as a full-screen modal route. Returns when the
/// user finishes or skips.
Future<void> showTutorial(BuildContext context) {
  HapticService().light();
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      transitionDuration: const Duration(milliseconds: 360),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (_, _, _) => const _TutorialFlow(),
      transitionsBuilder: (_, animation, _, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
}

class _TutorialFlow extends StatefulWidget {
  const _TutorialFlow();

  @override
  State<_TutorialFlow> createState() => _TutorialFlowState();
}

class _TutorialFlowState extends State<_TutorialFlow> {
  int _index = 0;

  void _next() {
    HapticService().selection();
    if (_index >= _kSteps.length - 1) {
      _finish();
      return;
    }
    setState(() => _index++);
  }

  void _back() {
    if (_index <= 0) return;
    HapticService().selection();
    setState(() => _index--);
  }

  Future<void> _finish() async {
    HapticService().light();
    await markTutorialCompleted();
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final step = _kSteps[_index];
    final isLast = _index == _kSteps.length - 1;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            children: [
              Row(
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
                    onPressed: _finish,
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        color: AppColors.inkDim,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.06, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: _StepCard(
                  key: ValueKey(_index),
                  step: step,
                ),
              ),
              const SizedBox(height: 18),
              _StepDots(
                count: _kSteps.length,
                active: _index,
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  if (_index > 0)
                    Expanded(
                      child: _SecondaryButton(
                        label: 'Back',
                        onTap: _back,
                      ),
                    ),
                  if (_index > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: _index > 0 ? 1 : 2,
                    child: _PrimaryButton(
                      label: isLast ? 'Got it' : 'Next',
                      onTap: _next,
                    ),
                  ),
                ],
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({super.key, required this.step});
  final _TutorialStep step;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.bgCard,
            AppColors.bg,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.purpleLight.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.purple.withValues(alpha: 0.30),
            blurRadius: 36,
            spreadRadius: -10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
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
                      color: AppColors.pink.withValues(alpha: 0.45),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: Icon(step.icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Text(
                step.label,
                style: TextStyle(
                  color: AppColors.inkDim,
                  fontSize: 11,
                  letterSpacing: 2.4,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            step.title,
            style: GoogleFonts.instrumentSerif(
              color: AppColors.ink,
              fontStyle: FontStyle.italic,
              fontSize: 32,
              height: 1.1,
            ),
          )
              .animate()
              .fadeIn(delay: 80.ms, duration: 400.ms)
              .slideY(begin: 0.06, end: 0, curve: Curves.easeOut),
          const SizedBox(height: 12),
          Text(
            step.body,
            style: TextStyle(
              color: AppColors.inkSoft,
              fontSize: 15,
              height: 1.55,
            ),
          )
              .animate()
              .fadeIn(delay: 140.ms, duration: 400.ms),
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
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: AppColors.buttonGradient,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: AppColors.pink.withValues(alpha: 0.45),
              blurRadius: 20,
              offset: const Offset(0, 6),
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
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.bgCard.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(25),
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
