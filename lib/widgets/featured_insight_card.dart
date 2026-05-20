import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/insight.dart';
import '../theme/app_theme.dart';
import 'confidence_indicator.dart';

class FeaturedInsightCard extends StatelessWidget {
  const FeaturedInsightCard({
    super.key,
    required this.insight,
    required this.onTap,
    required this.onAction,
  });

  final Insight insight;
  final VoidCallback onTap;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final tone = insight.color;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.purple.withValues(alpha: 0.35),
                AppColors.pink.withValues(alpha: 0.22),
              ],
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: AppColors.pinkLight.withValues(alpha: 0.55),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.purple.withValues(alpha: 0.30),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: AppColors.buttonGradient,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.pink.withValues(alpha: 0.40),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                    child: const Text(
                      '★ STRONGEST PATTERN',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6,
                      ),
                    ),
                  )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .shimmer(
                        duration: 2400.ms,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                  const Spacer(),
                  Text(
                    insight.type.emoji,
                    style: const TextStyle(fontSize: 18),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                insight.title,
                style: GoogleFonts.instrumentSerif(
                  color: BrandColors.ink(context),
                  fontStyle: FontStyle.italic,
                  fontSize: 26,
                  height: 1.1,
                ),
              ),
              if (insight.description != null) ...[
                const SizedBox(height: 10),
                Text(
                  insight.description!,
                  style: TextStyle(
                    color: BrandColors.inkSoft(context),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ConfidenceIndicator(confidence: insight.confidence),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Based on ${insight.sampleSize} day${insight.sampleSize == 1 ? '' : 's'}',
                    style: TextStyle(
                      color: BrandColors.inkSoft(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const Spacer(),
                  if (insight.actionable && insight.actionText != null)
                    GestureDetector(
                      onTap: onAction,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: AppColors.buttonGradient,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.pink.withValues(alpha: 0.45),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Text(
                          insight.actionText!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    )
                  else
                    Icon(Icons.arrow_forward_rounded,
                        color: tone.withValues(alpha: 0.85), size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
