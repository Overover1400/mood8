import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class TimePill extends StatelessWidget {
  const TimePill({
    super.key,
    required this.minutes,
    this.color,
  });

  final int minutes;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.purpleLight;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_rounded, size: 11, color: accent),
          const SizedBox(width: 4),
          Text(
            _label(minutes),
            style: TextStyle(
              color: AppColors.inkSoft,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  static String _label(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final hours = minutes / 60.0;
    if (hours == hours.roundToDouble()) return '${hours.toInt()}h';
    return '${hours.toStringAsFixed(1)}h';
  }
}
