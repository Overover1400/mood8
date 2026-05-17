import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/glow_slider.dart';
import '../../../widgets/mood_orb.dart';
import '../onboarding_flow.dart';

class FirstCheckinStep extends StatefulWidget {
  const FirstCheckinStep({
    super.key,
    required this.initialMood,
    required this.initialEnergy,
    required this.initialFocus,
    required this.onSubmit,
  });

  final double initialMood;
  final double initialEnergy;
  final double initialFocus;
  final void Function(double mood, double energy, double focus) onSubmit;

  @override
  State<FirstCheckinStep> createState() => _FirstCheckinStepState();
}

class _FirstCheckinStepState extends State<FirstCheckinStep> {
  late double _mood = widget.initialMood;
  late double _energy = widget.initialEnergy;
  late double _focus = widget.initialFocus;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Let's do your\nfirst check-in.",
            style: Theme.of(context).textTheme.headlineLarge,
          )
              .animate()
              .fadeIn(duration: 500.ms)
              .slideY(begin: 0.08, end: 0, curve: Curves.easeOut),
          const SizedBox(height: 8),
          Text(
            'Just 10 seconds — how are you feeling now?',
            style: TextStyle(color: AppColors.inkDim, fontSize: 14),
          ).animate().fadeIn(delay: 120.ms, duration: 500.ms),
          const SizedBox(height: 24),
          Center(
            child: const MoodOrb(size: 100)
                .animate()
                .fadeIn(delay: 200.ms, duration: 500.ms),
          ),
          const SizedBox(height: 28),
          GlowSlider(
            label: 'Mood',
            icon: Icons.favorite_rounded,
            value: _mood,
            onChanged: (v) => setState(() => _mood = v),
          ),
          const SizedBox(height: 14),
          GlowSlider(
            label: 'Energy',
            icon: Icons.bolt_rounded,
            value: _energy,
            onChanged: (v) => setState(() => _energy = v),
          ),
          const SizedBox(height: 14),
          GlowSlider(
            label: 'Focus',
            icon: Icons.center_focus_strong_rounded,
            value: _focus,
            onChanged: (v) => setState(() => _focus = v),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              _encouragement(_mood, _energy, _focus),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.purpleLight,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
              .animate(key: ValueKey(_band))
              .fadeIn(duration: 350.ms),
          const SizedBox(height: 28),
          OnboardingPrimaryButton(
            label: 'Save & continue',
            icon: Icons.arrow_forward_rounded,
            onTap: () => widget.onSubmit(_mood, _energy, _focus),
          ),
        ],
      ),
    );
  }

  String get _band {
    final avg = (_mood + _energy + _focus) / 3.0;
    if (avg < 0.34) return 'low';
    if (avg < 0.67) return 'mid';
    return 'high';
  }

  String _encouragement(double m, double e, double f) {
    switch (_band) {
      case 'low':
        return "That's real. Naming it is the first step.";
      case 'high':
        return "You're flying — let's protect this state.";
      default:
        return "Solid baseline. Small adjustments compound.";
    }
  }
}
