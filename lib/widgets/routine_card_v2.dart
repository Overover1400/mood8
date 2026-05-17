import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/routine_item.dart';
import '../theme/app_theme.dart';
import 'time_pill.dart';

class RoutineCardV2 extends StatelessWidget {
  const RoutineCardV2({
    super.key,
    required this.item,
    required this.isCurrent,
    required this.onTap,
    required this.onToggleComplete,
    this.completable = true,
  });

  final RoutineItem item;
  final bool isCurrent;
  final VoidCallback onTap;
  final VoidCallback onToggleComplete;
  final bool completable;

  @override
  Widget build(BuildContext context) {
    final accent = item.category.color;
    final completed = item.isCompleted;
    final period = isCurrent
        ? 'NOW'
        : (item.time.hour < 12 ? 'AM' : 'PM');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Opacity(
          opacity: completed ? 0.55 : 1.0,
          child: Container(
            decoration: BoxDecoration(
              gradient: isCurrent
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.purple.withValues(alpha: 0.28),
                        AppColors.pink.withValues(alpha: 0.18),
                      ],
                    )
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.bgCard.withValues(alpha: 0.95),
                        AppColors.bg.withValues(alpha: 0.85),
                      ],
                    ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isCurrent
                    ? AppColors.pinkLight.withValues(alpha: 0.55)
                    : AppColors.purple.withValues(alpha: 0.16),
              ),
              boxShadow: isCurrent
                  ? [
                      BoxShadow(
                        color: AppColors.pink.withValues(alpha: 0.30),
                        blurRadius: 22,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 3,
                    margin: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.6),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 50,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('HH:mm').format(item.time),
                          style: GoogleFonts.instrumentSerif(
                            color: AppColors.ink,
                            fontStyle: FontStyle.italic,
                            fontSize: 16,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          period,
                          style: TextStyle(
                            color: isCurrent
                                ? AppColors.pinkLight
                                : AppColors.inkDim,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 14, 12, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.ink,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              decoration: completed
                                  ? TextDecoration.lineThrough
                                  : null,
                              decorationColor:
                                  AppColors.inkDim.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.inkDim,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              TimePill(
                                minutes: item.durationMinutes,
                                color: accent,
                              ),
                              const SizedBox(width: 6),
                              _CategoryBadge(category: item.category),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 14, left: 4),
                    child: Center(
                      child: _CompleteButton(
                        completed: completed,
                        accent: accent,
                        isCurrent: isCurrent,
                        enabled: completable,
                        onTap: () {
                          if (!completable) return;
                          HapticFeedback.mediumImpact();
                          onToggleComplete();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category});

  final dynamic category;

  @override
  Widget build(BuildContext context) {
    final color = category.color as Color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(category.icon as IconData, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            (category.label as String).toUpperCase(),
            style: TextStyle(
              color: AppColors.inkSoft,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompleteButton extends StatelessWidget {
  const _CompleteButton({
    required this.completed,
    required this.accent,
    required this.isCurrent,
    required this.enabled,
    required this.onTap,
  });

  final bool completed;
  final Color accent;
  final bool isCurrent;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = !enabled;
    final body = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: completed
            ? AppColors.buttonGradient
            : null,
        color: completed
            ? null
            : (disabled
                ? AppColors.bgCard.withValues(alpha: 0.4)
                : AppColors.bgCard.withValues(alpha: 0.9)),
        border: Border.all(
          color: completed
              ? Colors.transparent
              : (disabled
                  ? AppColors.inkFaint.withValues(alpha: 0.4)
                  : accent.withValues(alpha: 0.55)),
          width: 1.5,
        ),
        boxShadow: completed
            ? [
                BoxShadow(
                  color: AppColors.pink.withValues(alpha: 0.45),
                  blurRadius: 14,
                ),
              ]
            : null,
      ),
      child: completed
          ? const Icon(Icons.check_rounded, size: 20, color: Colors.white)
          : Icon(
              Icons.check_rounded,
              size: 18,
              color: disabled
                  ? AppColors.inkFaint
                  : accent.withValues(alpha: 0.55),
            ),
    );

    Widget result = GestureDetector(
      onTap: enabled ? onTap : null,
      child: body,
    );

    if (isCurrent && !completed && enabled) {
      result = result
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(end: 1.08, duration: 900.ms, curve: Curves.easeInOut);
    }

    return result;
  }
}
