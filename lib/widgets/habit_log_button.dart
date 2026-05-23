import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/habit.dart';
import '../models/habit_type.dart';
import '../theme/app_theme.dart';

class HabitLogButton extends StatelessWidget {
  const HabitLogButton({
    super.key,
    required this.habit,
    required this.value,
    required this.onIncrement,
    required this.onDecrement,
    required this.onToggle,
    this.compact = false,
  });

  final Habit habit;
  final int value;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onToggle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cardColor =
        habit.isAvoid ? AppColors.pinkLight : Color(habit.color);
    switch (habit.habitType) {
      case HabitType.yesNo:
        return _YesNoButton(
          done: value > 0,
          color: cardColor,
          // Quit-mode habits use a heart/check ("stayed clean") instead
          // of a plain check — same widget, friendlier semantic.
          icon: habit.isQuit ? Icons.spa_rounded : Icons.check_rounded,
          onTap: () {
            HapticFeedback.mediumImpact();
            onToggle();
          },
        );
      case HabitType.counter:
      case HabitType.duration:
        return _StepperPill(
          value: value,
          // Reduce-mode habits have no upper bound — pass 0 so the pill
          // renders "5 today" instead of "5 / 1048576" and never locks.
          target: habit.isReduce ? 0 : habit.effectiveTarget,
          unit: habit.targetUnit ?? habit.habitType.defaultUnit,
          color: cardColor,
          isDuration: habit.habitType == HabitType.duration,
          isReduce: habit.isReduce,
          onPlus: () {
            HapticFeedback.selectionClick();
            onIncrement();
          },
          onMinus: () {
            HapticFeedback.selectionClick();
            onDecrement();
          },
          compact: compact,
        );
    }
  }
}

class _YesNoButton extends StatelessWidget {
  const _YesNoButton({
    required this.done,
    required this.color,
    required this.onTap,
    this.icon = Icons.check_rounded,
  });

  final bool done;
  final Color color;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: done ? AppColors.buttonGradient : null,
        color: done ? null : BrandColors.bgCard(context).withValues(alpha: 0.9),
        border: Border.all(
          color: done
              ? Colors.transparent
              : color.withValues(alpha: 0.55),
          width: 1.5,
        ),
        boxShadow: done
            ? [
                BoxShadow(
                  color: AppColors.pink.withValues(alpha: 0.45),
                  blurRadius: 16,
                ),
              ]
            : null,
      ),
      child: done
          ? Icon(icon, color: Colors.white, size: 22)
              .animate(key: const ValueKey('check'))
              .scaleXY(
                begin: 0.6,
                end: 1.0,
                duration: 240.ms,
                curve: Curves.easeOutBack,
              )
          : Icon(
              icon,
              color: color.withValues(alpha: 0.45),
              size: 18,
            ),
    );

    return GestureDetector(onTap: onTap, child: body);
  }
}

class _StepperPill extends StatelessWidget {
  const _StepperPill({
    required this.value,
    required this.target,
    required this.unit,
    required this.color,
    required this.isDuration,
    required this.onPlus,
    required this.onMinus,
    required this.compact,
    this.isReduce = false,
  });

  final int value;
  final int target;
  final String unit;
  final Color color;
  final bool isDuration;
  final bool isReduce;
  final VoidCallback onPlus;
  final VoidCallback onMinus;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // Reduce-mode never "completes" — every count is data. Build /
    // counter / duration habits glow + lock when value hits target.
    final done = !isReduce && target > 0 && value >= target;
    final label = isReduce
        ? '$value'
        : isDuration
            ? '$value/${target}m'
            : '$value / $target';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        gradient: done
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.55),
                  color.withValues(alpha: 0.35),
                ],
              )
            : null,
        color: done ? null : BrandColors.bg(context).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: done
              ? color.withValues(alpha: 0.65)
              : color.withValues(alpha: 0.30),
        ),
        boxShadow: done
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 14,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _round(Icons.remove_rounded, onMinus,
              enabled: value > 0 && !done, context: context),
          SizedBox(
            width: compact ? 56 : 70,
            child: Center(
              child: Text(
                label,
                style: GoogleFonts.bricolageGrotesque(
                  color: BrandColors.ink(context),
                  fontSize: compact ? 16 : 18,
                  height: 1.0,
                ),
              ),
            ),
          ),
          _round(Icons.add_rounded, onPlus,
              enabled: isReduce || !done, context: context),
        ],
      ),
    );
  }

  Widget _round(
    IconData icon,
    VoidCallback onTap, {
    bool enabled = true,
    required BuildContext context,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: BrandColors.bgCard(context).withValues(alpha: 0.85),
          ),
          child: Icon(icon, size: 16, color: BrandColors.inkSoft(context)),
        ),
      ),
    );
  }
}
