import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/focus_area.dart';
import '../../models/user_profile.dart';
import '../../services/onboarding_service.dart';
import '../../theme/app_theme.dart';
import 'steps/chronotype_step.dart';
import 'steps/completion_step.dart';
import 'steps/first_checkin_step.dart';
import 'steps/focus_areas_step.dart';
import 'steps/identity_step.dart';
import 'steps/name_step.dart';
import 'steps/welcome_step.dart';

class OnboardingData {
  String name = '';
  List<String> identities = [];
  List<FocusArea> focusAreas = [];
  Chronotype chronotype = Chronotype.balanced;
  double mood = 0.65;
  double energy = 0.6;
  double focus = 0.6;
}

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final PageController _controller = PageController();
  final OnboardingData _data = OnboardingData();
  final OnboardingService _service = OnboardingService();
  int _page = 0;
  bool _completing = false;

  static const int _totalSteps = 7;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int page) {
    HapticFeedback.selectionClick();
    _controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  void _next() => _go((_page + 1).clamp(0, _totalSteps - 1));
  void _back() => _go((_page - 1).clamp(0, _totalSteps - 1));

  Future<void> _skip() async {
    HapticFeedback.lightImpact();
    await _finish(skipCheckin: true);
  }

  Future<void> _finish({bool skipCheckin = false}) async {
    if (_completing) return;
    setState(() => _completing = true);
    try {
      await _service.complete(
        name: _data.name,
        identities: _data.identities,
        focusAreas: _data.focusAreas,
        chronotype: _data.chronotype,
        mood: skipCheckin ? null : _data.mood,
        energy: skipCheckin ? null : _data.energy,
        focus: skipCheckin ? null : _data.focus,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _completing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not finish onboarding: $e'),
            backgroundColor: AppColors.bgCard,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: Stack(
        children: [
          const _BackgroundGlow(),
          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  page: _page,
                  total: _totalSteps,
                  onBack: _page > 0 && _page < _totalSteps - 1 ? _back : null,
                  onSkip: _page < _totalSteps - 1 ? _skip : null,
                ),
                Expanded(
                  child: PageView(
                    controller: _controller,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (i) => setState(() => _page = i),
                    children: [
                      WelcomeStep(onNext: _next),
                      NameStep(
                        initial: _data.name,
                        onSubmit: (n) {
                          _data.name = n;
                          _next();
                        },
                      ),
                      IdentityStep(
                        initial: _data.identities,
                        onSubmit: (ids) {
                          _data.identities = ids;
                          _next();
                        },
                      ),
                      FocusAreasStep(
                        initial: _data.focusAreas,
                        onSubmit: (areas) {
                          _data.focusAreas = areas;
                          _next();
                        },
                      ),
                      ChronotypeStep(
                        initial: _data.chronotype,
                        onSubmit: (c) {
                          _data.chronotype = c;
                          _next();
                        },
                      ),
                      FirstCheckinStep(
                        initialMood: _data.mood,
                        initialEnergy: _data.energy,
                        initialFocus: _data.focus,
                        onSubmit: (m, e, f) {
                          _data.mood = m;
                          _data.energy = e;
                          _data.focus = f;
                          _next();
                        },
                      ),
                      CompletionStep(
                        data: _data,
                        completing: _completing,
                        onStart: () => _finish(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.page,
    required this.total,
    required this.onBack,
    required this.onSkip,
  });

  final int page;
  final int total;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: onBack == null
                ? const SizedBox.shrink()
                : IconButton(
                    onPressed: onBack,
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: AppColors.inkSoft,
                      size: 18,
                    ),
                  ),
          ),
          Expanded(child: _ProgressDots(page: page, total: total)),
          SizedBox(
            width: 56,
            child: onSkip == null
                ? const SizedBox.shrink()
                : TextButton(
                    onPressed: onSkip,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.inkDim,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.page, required this.total});
  final int page;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < total; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == page ? 22 : 6,
            height: 6,
            decoration: BoxDecoration(
              gradient: i == page ? AppColors.buttonGradient : null,
              color: i == page
                  ? null
                  : AppColors.inkFaint.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(6),
            ),
          )
              .animate()
              .fadeIn(delay: (i * 30).ms),
      ],
    );
  }
}

class _BackgroundGlow extends StatelessWidget {
  const _BackgroundGlow();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              top: -120,
              left: -100,
              child: Container(
                width: 340,
                height: 340,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.purple.withValues(alpha: 0.28),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -120,
              right: -100,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.pink.withValues(alpha: 0.22),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingPrimaryButton extends StatelessWidget {
  const OnboardingPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: enabled ? 1.0 : 0.45,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            gradient: AppColors.buttonGradient,
            borderRadius: BorderRadius.circular(28),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: AppColors.pink.withValues(alpha: 0.45),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: AppColors.purple.withValues(alpha: 0.40),
                      blurRadius: 30,
                      spreadRadius: -4,
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 8),
                Icon(icon, color: Colors.white, size: 18),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
