import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/user_profile.dart';
import '../../../services/onboarding_service.dart';
import '../../../theme/app_theme.dart';
import '../onboarding_flow.dart';

class CompletionStep extends StatefulWidget {
  const CompletionStep({
    super.key,
    required this.data,
    required this.completing,
    required this.onStart,
  });

  final OnboardingData data;
  final bool completing;
  final VoidCallback onStart;

  @override
  State<CompletionStep> createState() => _CompletionStepState();
}

class _CompletionStepState extends State<CompletionStep> {
  late final ConfettiController _confetti =
      ConfettiController(duration: const Duration(seconds: 2));
  late final OnboardingService _preview = OnboardingService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _confetti.play());
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.data.name.trim().isEmpty
        ? 'friend'
        : widget.data.name.trim();
    final topIdentity = widget.data.identities.isNotEmpty
        ? widget.data.identities.first
        : 'better self';

    final previewProfile = UserProfile(
      name: name,
      identities: widget.data.identities,
      focusAreas: widget.data.focusAreas,
      hasCompletedOnboarding: false,
      createdAt: DateTime.now(),
      chronotype: widget.data.chronotype,
    );
    final starters = _preview.generateStarterRoutines(previewProfile);

    return Stack(
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confetti,
            blastDirection: math.pi / 2,
            blastDirectionality: BlastDirectionality.explosive,
            emissionFrequency: 0.06,
            numberOfParticles: 16,
            maxBlastForce: 18,
            minBlastForce: 6,
            gravity: 0.2,
            colors: const [
              AppColors.purple,
              AppColors.purpleLight,
              AppColors.pink,
              AppColors.pinkLight,
              AppColors.blueAccent,
            ],
          ),
        ),
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Text(
                'Welcome,',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.inkSoft,
                    ),
              )
                  .animate()
                  .fadeIn(delay: 150.ms, duration: 500.ms),
              Text(
                name,
                style: GoogleFonts.instrumentSerif(
                  color: AppColors.ink,
                  fontStyle: FontStyle.italic,
                  fontSize: 48,
                  height: 1.0,
                  foreground: Paint()
                    ..shader = AppColors.primaryGradient
                        .createShader(const Rect.fromLTWH(0, 0, 280, 60)),
                ),
              )
                  .animate()
                  .fadeIn(delay: 250.ms, duration: 600.ms)
                  .slideY(begin: 0.08, end: 0, curve: Curves.easeOut),
              const SizedBox(height: 18),
              Text(
                "You're on day 1 of becoming a $topIdentity.",
                style: TextStyle(
                  color: AppColors.inkDim,
                  fontSize: 14,
                  height: 1.5,
                ),
              ).animate().fadeIn(delay: 400.ms, duration: 500.ms),
              if (widget.data.identities.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final id in widget.data.identities)
                      _IdentityPill(label: id),
                  ],
                ).animate().fadeIn(delay: 500.ms, duration: 500.ms),
              ],
              const SizedBox(height: 28),
              Text(
                "HERE'S YOUR STARTER PACK",
                style: TextStyle(
                  color: AppColors.inkDim,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 10),
              for (var i = 0; i < starters.length; i++) ...[
                _StarterRow(
                  routine: starters[i],
                  chronotype: widget.data.chronotype,
                )
                    .animate(delay: (600 + i * 80).ms)
                    .fadeIn(duration: 400.ms)
                    .slideX(begin: -0.04, end: 0, curve: Curves.easeOut),
                if (i < starters.length - 1) const SizedBox(height: 8),
              ],
              const SizedBox(height: 28),
              OnboardingPrimaryButton(
                label: widget.completing ? 'Setting up…' : "Let's begin",
                icon: widget.completing
                    ? null
                    : Icons.arrow_forward_rounded,
                onTap: widget.completing ? null : widget.onStart,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IdentityPill extends StatelessWidget {
  const _IdentityPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.purple.withValues(alpha: 0.30),
            AppColors.pink.withValues(alpha: 0.20),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.45),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.instrumentSerif(
          color: AppColors.ink,
          fontStyle: FontStyle.italic,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _StarterRow extends StatelessWidget {
  const _StarterRow({required this.routine, required this.chronotype});

  final StarterRoutine routine;
  final Chronotype chronotype;

  @override
  Widget build(BuildContext context) {
    final color = routine.category.color;
    final hour = routine.hourFor(chronotype);
    final time =
        '${hour.toString().padLeft(2, '0')}:${routine.minute.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.22),
            ),
            child: Icon(routine.category.icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  routine.title,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  routine.meta,
                  style: const TextStyle(
                    color: AppColors.inkDim,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: GoogleFonts.instrumentSerif(
              color: AppColors.inkSoft,
              fontStyle: FontStyle.italic,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
