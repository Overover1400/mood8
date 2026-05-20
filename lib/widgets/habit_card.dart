import 'package:flutter/material.dart';

import '../models/habit.dart';
import '../models/habit_log.dart';
import '../theme/app_theme.dart';
import 'habit_log_button.dart';

class HabitCard extends StatelessWidget {
  const HabitCard({
    super.key,
    required this.habit,
    required this.todayValue,
    required this.last7,
    required this.onTap,
    required this.onIncrement,
    required this.onDecrement,
    required this.onToggle,
  });

  final Habit habit;
  final int todayValue;
  final List<HabitLog> last7;
  final VoidCallback onTap;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final color = Color(habit.color);
    // Locked when the user has hit (or exceeded) today's target. Card
    // fades to 45% opacity over 600ms so the user can see it's complete
    // but can't accidentally tap a − to undo. Tap-to-detail still works.
    final locked = todayValue >= habit.effectiveTarget;
    return AnimatedOpacity(
      opacity: locked ? 0.45 : 1.0,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.bgCard.withValues(alpha: 0.92),
                  AppColors.bg.withValues(alpha: 0.85),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: color.withValues(alpha: 0.22),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _IconBubble(color: color, emoji: habit.icon),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            habit.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _IdentityChip(
                            identity: habit.identity,
                            color: color,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    IgnorePointer(
                      ignoring: locked,
                      child: HabitLogButton(
                        habit: habit,
                        value: todayValue,
                        onIncrement: onIncrement,
                        onDecrement: onDecrement,
                        onToggle: onToggle,
                        compact: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _WeekStrip(logs: last7, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconBubble extends StatelessWidget {
  const _IconBubble({required this.color, required this.emoji});
  final Color color;
  final String emoji;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.55),
            color.withValues(alpha: 0.12),
          ],
        ),
        border: Border.all(
          color: color.withValues(alpha: 0.4),
        ),
      ),
      child: Text(emoji, style: const TextStyle(fontSize: 20)),
    );
  }
}

class _IdentityChip extends StatelessWidget {
  const _IdentityChip({required this.identity, required this.color});
  final String identity;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(
        identity.toUpperCase(),
        style: TextStyle(
          color: AppColors.inkSoft,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.logs, required this.color});
  final List<HabitLog> logs;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final today = DateTime(DateTime.now().year, DateTime.now().month,
        DateTime.now().day);
    final byDay = <DateTime, HabitLog>{
      for (final l in logs)
        DateTime(l.date.year, l.date.month, l.date.day): l,
    };

    return Row(
      children: [
        for (var i = 6; i >= 0; i--) ...[
          Expanded(
            child: _Dot(
              ratio: byDay[today.subtract(Duration(days: i))]
                      ?.completionPercentage ??
                  0,
              color: color,
              isToday: i == 0,
            ),
          ),
          if (i > 0) const SizedBox(width: 4),
        ],
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({
    required this.ratio,
    required this.color,
    required this.isToday,
  });

  final double ratio;
  final Color color;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final filled = ratio > 0;
    return Container(
      height: 8,
      decoration: BoxDecoration(
        color: filled
            ? color.withValues(alpha: 0.25 + 0.65 * ratio.clamp(0.0, 1.0))
            : AppColors.bg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isToday
              ? AppColors.pinkLight.withValues(alpha: 0.8)
              : AppColors.purple.withValues(alpha: 0.08),
          width: isToday ? 1.4 : 1,
        ),
      ),
    );
  }
}
