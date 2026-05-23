import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/analytics_models.dart';
import '../theme/app_theme.dart';

class PeriodComparisonRow extends StatelessWidget {
  const PeriodComparisonRow({super.key, required this.comparison});
  final Comparison comparison;

  @override
  Widget build(BuildContext context) {
    final neutral = comparison.previous == 0 && comparison.current == 0;
    final upColor = const Color(0xFF7CE5B0);
    final downColor = const Color(0xFFFF6B81);
    final tone = neutral
        ? BrandColors.inkDim(context)
        : (comparison.isUp ? upColor : downColor);
    final pct = (comparison.changePercent * 100).round();
    final sign = comparison.isUp ? '+' : '';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: BrandColors.bgCard(context).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comparison.metric.toUpperCase(),
                  style: TextStyle(
                    color: BrandColors.inkDim(context),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: comparison.previous.toStringAsFixed(1),
                        style: TextStyle(
                          color: BrandColors.inkDim(context),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(
                        text: '  →  ',
                        style: TextStyle(
                          color: BrandColors.inkDim(context).withValues(alpha: 0.6),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(
                        text:
                            '${comparison.current.toStringAsFixed(1)}${comparison.unit}',
                        style: GoogleFonts.bricolageGrotesque(
                          color: BrandColors.ink(context),
                          fontSize: 22,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: tone.withValues(alpha: 0.40)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  neutral
                      ? Icons.remove_rounded
                      : (comparison.isUp
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded),
                  color: tone,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  neutral ? '—' : '$sign$pct%',
                  style: TextStyle(
                    color: tone,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
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
