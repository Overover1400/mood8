import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';

class IdentityProgressBar extends StatelessWidget {
  const IdentityProgressBar({
    super.key,
    required this.identity,
    required this.value,
    required this.subtitle,
  });

  final String identity;
  final double value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                identity,
                style: GoogleFonts.bricolageGrotesque(
                  color: BrandColors.ink(context),
                  fontSize: 19,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  subtitle,
                  style: TextStyle(
                    color: BrandColors.inkDim(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${(value * 100).round()}%',
                style: TextStyle(
                  color: AppColors.pinkLight,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Container(
                  height: 8,
                  color: BrandColors.bg(context).withValues(alpha: 0.7),
                ),
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  widthFactor: value.clamp(0.0, 1.0),
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: AppColors.buttonGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.pink.withValues(alpha: 0.50),
                          blurRadius: 10,
                          offset: const Offset(2, 0),
                        ),
                      ],
                    ),
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
