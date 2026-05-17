import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/user_profile.dart';
import '../../../theme/app_theme.dart';
import '../onboarding_flow.dart';

class ChronotypeStep extends StatefulWidget {
  const ChronotypeStep({
    super.key,
    required this.initial,
    required this.onSubmit,
  });

  final Chronotype initial;
  final ValueChanged<Chronotype> onSubmit;

  @override
  State<ChronotypeStep> createState() => _ChronotypeStepState();
}

class _ChronotypeStepState extends State<ChronotypeStep> {
  late Chronotype _selected = widget.initial;

  void _pick(Chronotype c) {
    HapticFeedback.selectionClick();
    setState(() => _selected = c);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'When are you\nat your best?',
            style: Theme.of(context).textTheme.headlineLarge,
          )
              .animate()
              .fadeIn(duration: 500.ms)
              .slideY(begin: 0.08, end: 0, curve: Curves.easeOut),
          const SizedBox(height: 8),
          Text(
            "We'll plan around your natural rhythm.",
            style: TextStyle(color: AppColors.inkDim, fontSize: 14),
          ).animate().fadeIn(delay: 120.ms, duration: 500.ms),
          const SizedBox(height: 20),
          for (var i = 0; i < Chronotype.values.length; i++) ...[
            _ChronoCard(
              chrono: Chronotype.values[i],
              selected: _selected == Chronotype.values[i],
              onTap: () => _pick(Chronotype.values[i]),
            )
                .animate(delay: (80 * i).ms)
                .fadeIn(duration: 380.ms)
                .slideY(begin: 0.08, end: 0, curve: Curves.easeOut),
            if (i < Chronotype.values.length - 1) const SizedBox(height: 12),
          ],
          const Spacer(),
          OnboardingPrimaryButton(
            label: 'Continue',
            icon: Icons.arrow_forward_rounded,
            onTap: () => widget.onSubmit(_selected),
          ),
        ],
      ),
    );
  }
}

class _ChronoCard extends StatelessWidget {
  const _ChronoCard({
    required this.chrono,
    required this.selected,
    required this.onTap,
  });

  final Chronotype chrono;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.purple.withValues(alpha: 0.45),
                    AppColors.pink.withValues(alpha: 0.30),
                  ],
                )
              : null,
          color: selected ? null : AppColors.bgCard.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected
                ? AppColors.pinkLight.withValues(alpha: 0.65)
                : AppColors.purple.withValues(alpha: 0.18),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.pink.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.bg.withValues(alpha: 0.6),
              ),
              child: Text(chrono.emoji,
                  style: const TextStyle(fontSize: 28)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chrono.label,
                    style: selected
                        ? GoogleFonts.instrumentSerif(
                            color: Colors.white,
                            fontStyle: FontStyle.italic,
                            fontSize: 22,
                            height: 1.0,
                          )
                        : const TextStyle(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    chrono.tagline,
                    style: TextStyle(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.85)
                          : AppColors.inkSoft,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    chrono.window.toUpperCase(),
                    style: TextStyle(
                      color: selected
                          ? AppColors.pinkLight
                          : AppColors.inkDim,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
