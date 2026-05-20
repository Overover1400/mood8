import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/subscription.dart';
import '../theme/app_theme.dart';

class PremiumBadge extends StatelessWidget {
  const PremiumBadge({super.key, required this.tier, this.compact = false});

  final SubscriptionTier tier;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final paid = tier.isPaid;
    final padding = compact
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 3)
        : const EdgeInsets.symmetric(horizontal: 10, vertical: 4);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: paid ? AppColors.buttonGradient : null,
        color: paid ? null : BrandColors.bgCard(context).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: paid
              ? Colors.transparent
              : AppColors.purple.withValues(alpha: 0.25),
        ),
        boxShadow: paid
            ? [
                BoxShadow(
                  color: AppColors.pink.withValues(alpha: 0.35),
                  blurRadius: 12,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            paid
                ? Icons.workspace_premium_rounded
                : Icons.lock_outline_rounded,
            color: paid ? Colors.white : BrandColors.inkDim(context),
            size: compact ? 11 : 13,
          ),
          const SizedBox(width: 6),
          Text(
            tier.label.toUpperCase(),
            style: paid
                ? const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  )
                : GoogleFonts.plusJakartaSans(
                    color: BrandColors.inkDim(context),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
          ),
        ],
      ),
    );
  }
}
