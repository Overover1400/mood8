import 'package:flutter/material.dart';

import '../../models/analytics_models.dart';
import '../../theme/app_theme.dart';

class TimeOfDayChart extends StatelessWidget {
  const TimeOfDayChart({super.key, required this.values});
  final Map<TimeOfDayBlock, double> values;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'Log check-ins through the day to find your peak window.',
          style: TextStyle(color: AppColors.inkDim, fontSize: 13),
        ),
      );
    }

    final maxVal =
        values.values.fold<double>(0, (m, v) => v > m ? v : m).clamp(0.1, 10.0);
    final bestBlock =
        values.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    final ordered = <TimeOfDayBlock>[
      TimeOfDayBlock.morning,
      TimeOfDayBlock.afternoon,
      TimeOfDayBlock.evening,
      TimeOfDayBlock.night,
    ];

    return Column(
      children: [
        for (final b in ordered)
          if (values.containsKey(b))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: _Bar(
                label: b.label,
                hours: b.hourRange,
                value: values[b]!,
                max: maxVal,
                highlight: b == bestBlock,
              ),
            ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.label,
    required this.hours,
    required this.value,
    required this.max,
    required this.highlight,
  });

  final String label;
  final String hours;
  final double value;
  final double max;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 92,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: highlight ? AppColors.pinkLight : AppColors.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                hours,
                style: TextStyle(
                  color: AppColors.inkDim,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.bg.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: (value / max).clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) {
                  return FractionallySizedBox(
                    widthFactor: v,
                    child: Container(
                      height: 14,
                      decoration: BoxDecoration(
                        gradient: highlight
                            ? AppColors.buttonGradient
                            : LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  AppColors.purple.withValues(alpha: 0.75),
                                  AppColors.pink.withValues(alpha: 0.65),
                                ],
                              ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: highlight
                            ? [
                                BoxShadow(
                                  color:
                                      AppColors.pink.withValues(alpha: 0.45),
                                  blurRadius: 10,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 42,
          child: Text(
            value.toStringAsFixed(1),
            textAlign: TextAlign.right,
            style: TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
