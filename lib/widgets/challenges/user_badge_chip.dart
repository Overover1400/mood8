import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';

/// Small pill showing a user's profile_badge (and optional creator_score).
/// Build 3 will replace this with proper insignia art — the data
/// pipeline (badge name + score) is the load-bearing piece for now.
class UserBadgeChip extends StatelessWidget {
  const UserBadgeChip({
    super.key,
    required this.badge,
    this.creatorScore,
    this.compact = false,
  });

  final String? badge;
  final int? creatorScore;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final hasBadge = badge != null && badge!.isNotEmpty;
    final hasScore = creatorScore != null && creatorScore! > 0;
    if (!hasBadge && !hasScore) return const SizedBox.shrink();
    final accent = _accentFor(badge);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.28),
            accent.withValues(alpha: 0.14),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accent.withValues(alpha: 0.55),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_rounded,
              color: accent, size: compact ? 11 : 13),
          if (hasBadge) ...[
            const SizedBox(width: 4),
            Text(
              badge!,
              style: GoogleFonts.instrumentSerif(
                color: BrandColors.ink(context),
                fontStyle: FontStyle.italic,
                fontSize: compact ? 12 : 14,
                height: 1.0,
              ),
            ),
          ],
          if (hasScore) ...[
            SizedBox(width: hasBadge ? 6 : 4),
            Text(
              '· ${creatorScore!}',
              style: TextStyle(
                color: BrandColors.inkSoft(context),
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Tier-specific accent so higher prestige reads brighter. Build 3
  /// will replace this with proper insignia colors per tier.
  Color _accentFor(String? badge) {
    switch (badge) {
      case 'Immortal':
        return AppColors.pinkLight;
      case 'Mythic':
        return AppColors.pink;
      case 'Warlord':
        return AppColors.purpleLight;
      case 'Champion':
        return AppColors.purple;
      case 'Veteran':
      case 'Challenger':
        return AppColors.blueAccent;
      case 'Initiate':
      default:
        return AppColors.inkDim;
    }
  }
}
