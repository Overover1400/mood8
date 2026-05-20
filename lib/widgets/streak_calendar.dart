import 'package:flutter/material.dart';

import '../models/habit_log.dart';
import '../theme/app_theme.dart';

class StreakCalendar extends StatelessWidget {
  const StreakCalendar({
    super.key,
    required this.logs,
    required this.color,
    this.days = 30,
    this.frozenDates = const <DateTime>[],
  });

  final List<HabitLog> logs;
  final Color color;
  final int days;
  final List<DateTime> frozenDates;

  @override
  Widget build(BuildContext context) {
    final today = DateTime(DateTime.now().year, DateTime.now().month,
        DateTime.now().day);
    final byDay = <DateTime, HabitLog>{
      for (final l in logs)
        DateTime(l.date.year, l.date.month, l.date.day): l,
    };
    final frozenSet = <DateTime>{
      for (final d in frozenDates) DateTime(d.year, d.month, d.day),
    };

    final dates = <DateTime>[
      for (var i = days - 1; i >= 0; i--)
        today.subtract(Duration(days: i)),
    ];

    return LayoutBuilder(builder: (context, c) {
      const cols = 7;
      const spacing = 6.0;
      final side = (c.maxWidth - spacing * (cols - 1)) / cols;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (var i = 0; i < dates.length; i++)
            _Cell(
              size: side,
              ratio: byDay[dates[i]]?.completionPercentage ?? 0,
              color: color,
              isToday: dates[i] == today,
              isFrozen: frozenSet.contains(dates[i]),
              dayNumber: i + 1,
            ),
        ],
      );
    });
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.size,
    required this.ratio,
    required this.color,
    required this.isToday,
    required this.isFrozen,
    required this.dayNumber,
  });

  final double size;
  final double ratio;
  final Color color;
  final bool isToday;
  final bool isFrozen;
  final int dayNumber;

  @override
  Widget build(BuildContext context) {
    // Stronger floor so partial completions remain visible. 0.30 base
    // ramps to ~0.90 at full completion, vs the old 0.12 → 0.90 which
    // looked nearly empty for half-target days.
    final alpha = 0.30 + 0.60 * ratio.clamp(0.0, 1.0);
    final filled = ratio > 0;
    final bgColor = isFrozen
        ? AppColors.blueAccent.withValues(alpha: 0.40)
        : filled
            ? color.withValues(alpha: alpha)
            : BrandColors.bg(context).withValues(alpha: 0.55);
    final showFreezeIcon = isFrozen && size >= 18;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isToday
              ? AppColors.pinkLight.withValues(alpha: 0.8)
              : isFrozen
                  ? AppColors.blueAccent.withValues(alpha: 0.65)
                  : AppColors.purple.withValues(alpha: 0.10),
          width: isToday ? 1.5 : 1,
        ),
        boxShadow: isFrozen
            ? [
                BoxShadow(
                  color: AppColors.blueAccent.withValues(alpha: 0.45),
                  blurRadius: 6,
                ),
              ]
            : filled && ratio >= 1
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.30),
                      blurRadius: 6,
                    ),
                  ]
                : null,
      ),
      child: showFreezeIcon
          ? Icon(
              Icons.ac_unit_rounded,
              size: size * 0.55,
              color: Colors.white.withValues(alpha: 0.92),
            )
          : Text(
              '$dayNumber',
              style: TextStyle(
                color: filled
                    ? Colors.white.withValues(alpha: 0.85)
                    : BrandColors.inkDim(context).withValues(alpha: 0.65),
                fontSize: size < 22 ? 9 : 10,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}
