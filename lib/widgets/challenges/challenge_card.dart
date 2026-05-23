import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/challenge.dart';
import '../../theme/app_theme.dart';
import 'user_badge_chip.dart';

/// Single challenge tile used in the list + my-challenges views.
class ChallengeCard extends StatelessWidget {
  const ChallengeCard({
    super.key,
    required this.challenge,
    required this.onTap,
  });

  final ChallengeSummary challenge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
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
              color: AppColors.purple.withValues(alpha: 0.32),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.purple.withValues(alpha: 0.16),
                blurRadius: 22,
                spreadRadius: -8,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Creator row
              Row(
                children: [
                  _Avatar(name: challenge.creator.name, size: 30),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          challenge.creator.name,
                          style: TextStyle(
                            color: BrandColors.ink(context),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        UserBadgeChip(
                          badge: challenge.creator.profileBadge,
                          creatorScore: challenge.creator.creatorScore,
                          compact: true,
                        ),
                      ],
                    ),
                  ),
                  _CategoryPill(label: challenge.category),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                challenge.title,
                style: GoogleFonts.bricolageGrotesque(
                  color: BrandColors.ink(context),
                  fontSize: 24,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.schedule_rounded,
                      size: 14, color: BrandColors.inkDim(context)),
                  const SizedBox(width: 6),
                  Text(
                    '${challenge.durationDays}-day · ${challenge.daysRemaining} left',
                    style: TextStyle(
                      color: BrandColors.inkSoft(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.group_rounded,
                      size: 14, color: BrandColors.inkDim(context)),
                  const SizedBox(width: 6),
                  Text(
                    '${challenge.participantCount} in',
                    style: TextStyle(
                      color: BrandColors.inkSoft(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _StatsBar(
                activePct: challenge.activePct,
                gaveUpPct: challenge.gaveUpPct,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.size});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = name.isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.orbGradient,
      ),
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.45,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.pink.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.pinkLight.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        prettyCategory(label),
        style: TextStyle(
          color: AppColors.pinkLight,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _StatsBar extends StatelessWidget {
  const _StatsBar({required this.activePct, required this.gaveUpPct});
  final double activePct;
  final double gaveUpPct;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                Container(
                  height: 6,
                  color: BrandColors.inkFaint(context)
                      .withValues(alpha: 0.25),
                ),
                Row(
                  children: [
                    Expanded(
                      flex: activePct.round().clamp(0, 100),
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          gradient: AppColors.buttonGradient,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: gaveUpPct.round().clamp(0, 100),
                      child: Container(
                        height: 6,
                        color: AppColors.pink.withValues(alpha: 0.55),
                      ),
                    ),
                    Expanded(
                      flex:
                          (100 - activePct - gaveUpPct).round().clamp(0, 100),
                      child: const SizedBox.shrink(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '${activePct.toStringAsFixed(0)}% active',
          style: TextStyle(
            color: BrandColors.inkSoft(context),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}
