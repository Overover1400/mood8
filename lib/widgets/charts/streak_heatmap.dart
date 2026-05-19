import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../models/analytics_models.dart';
import '../../theme/app_theme.dart';

class StreakHeatmap extends StatelessWidget {
  const StreakHeatmap({super.key, required this.days});
  final List<HeatmapDay> days;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text(
          'Track for a few days to see your streak come alive.',
          style: TextStyle(color: AppColors.inkDim, fontSize: 13),
        ),
      );
    }

    return LayoutBuilder(builder: (context, c) {
      const cols = 7;
      const spacing = 6.0;
      final side = (c.maxWidth - spacing * (cols - 1)) / cols;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (final l in const ['M', 'T', 'W', 'T', 'F', 'S', 'S']) ...[
                SizedBox(
                  width: side,
                  child: Text(
                    l,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.inkDim,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                if (l != 'S') const SizedBox(width: spacing),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (var i = 0; i < days.length; i++)
                _Cell(
                  day: days[i],
                  size: side,
                ).animate(delay: (12 * i).ms).fadeIn(duration: 250.ms),
            ],
          ),
        ],
      );
    });
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.day, required this.size});
  final HeatmapDay day;
  final double size;

  bool get _isToday {
    final n = DateTime.now();
    return day.date.year == n.year &&
        day.date.month == n.month &&
        day.date.day == n.day;
  }

  Color get _bg {
    if (day.isFrozen) return AppColors.blueAccent.withValues(alpha: 0.40);
    if (!day.hasData) return AppColors.bg.withValues(alpha: 0.55);
    final s = day.completionScore;
    if (s < 0.34) {
      return AppColors.purple.withValues(alpha: 0.30);
    }
    if (s < 0.67) {
      return AppColors.purple.withValues(alpha: 0.65);
    }
    return AppColors.pink.withValues(alpha: 0.85);
  }

  @override
  Widget build(BuildContext context) {
    final glow = day.hasData && day.completionScore >= 0.67;
    return GestureDetector(
      onTap: () => _showPopup(context),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: _isToday
                ? AppColors.pinkLight.withValues(alpha: 0.85)
                : day.isFrozen
                    ? AppColors.blueAccent.withValues(alpha: 0.65)
                    : AppColors.purple.withValues(alpha: 0.10),
            width: _isToday ? 1.5 : 1,
          ),
          boxShadow: day.isFrozen
              ? [
                  BoxShadow(
                    color: AppColors.blueAccent.withValues(alpha: 0.55),
                    blurRadius: 8,
                  ),
                ]
              : glow
                  ? [
                      BoxShadow(
                        color: AppColors.pink.withValues(alpha: 0.45),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
        ),
        child: day.isFrozen && size >= 18
            ? Icon(
                Icons.ac_unit_rounded,
                size: size * 0.55,
                color: Colors.white.withValues(alpha: 0.92),
              )
            : null,
      ),
    );
  }

  void _showPopup(BuildContext context) {
    final label = DateFormat('EEE, MMM d').format(day.date);
    final value = day.isFrozen
        ? 'frozen ❄'
        : day.hasData
            ? '${(day.completionScore * 10).toStringAsFixed(1)}/10'
            : 'no data';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label · $value'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.bgCard,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
