import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/mood_orb.dart';
import '../onboarding_flow.dart';

class WelcomeStep extends StatelessWidget {
  const WelcomeStep({super.key, required this.onNext});
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Center(
            child: const MoodOrb(size: 200)
                .animate()
                .fadeIn(duration: 800.ms)
                .scaleXY(
                    begin: 0.85, end: 1.0, curve: Curves.easeOutCubic),
          ),
          const SizedBox(height: 36),
          Text(
            'Become more\nof yourself.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontSize: 48,
                  height: 1.05,
                ),
          )
              .animate()
              .fadeIn(delay: 200.ms, duration: 700.ms)
              .slideY(begin: 0.06, end: 0, curve: Curves.easeOut),
          const SizedBox(height: 18),
          Text(
            'Mood8 is your personal operating system. '
            "Built to help you understand what actually makes you better.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.inkDim,
              fontSize: 15,
              height: 1.5,
            ),
          )
              .animate()
              .fadeIn(delay: 450.ms, duration: 600.ms),
          const Spacer(),
          OnboardingPrimaryButton(
            label: 'Get started',
            icon: Icons.arrow_forward_rounded,
            onTap: onNext,
          )
              .animate()
              .fadeIn(delay: 700.ms, duration: 500.ms)
              .slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
        ],
      ),
    );
  }
}
