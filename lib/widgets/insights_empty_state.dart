import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_theme.dart';
import 'mood_orb.dart';

class InsightsEmptyState extends StatelessWidget {
  const InsightsEmptyState({
    super.key,
    required this.daysTracked,
    required this.daysRequired,
  });

  final int daysTracked;
  final int daysRequired;

  @override
  Widget build(BuildContext context) {
    final progress = (daysTracked / daysRequired).clamp(0.0, 1.0);
    final remaining = (daysRequired - daysTracked).clamp(0, daysRequired);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 24, 8, 24),
      child: Column(
        children: [
          const MoodOrb(size: 120),
          const SizedBox(height: 20),
          Text(
            'We need a few more days…',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 22,
                ),
          )
              .animate()
              .fadeIn(duration: 500.ms)
              .slideY(begin: 0.06, end: 0, curve: Curves.easeOut),
          const SizedBox(height: 8),
          Text(
            'Mood8 needs at least $daysRequired days of check-ins '
            'to find patterns worth surfacing.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.inkDim,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      Container(
                        height: 10,
                        color: AppColors.bg.withValues(alpha: 0.7),
                      ),
                      AnimatedFractionallySizedBox(
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        widthFactor: progress,
                        child: Container(
                          height: 10,
                          decoration: BoxDecoration(
                            gradient: AppColors.buttonGradient,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.pink.withValues(alpha: 0.45),
                                blurRadius: 14,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$daysTracked of $daysRequired days · '
                  '${remaining == 0 ? 'ready' : '$remaining to go'}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.inkSoft,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
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
