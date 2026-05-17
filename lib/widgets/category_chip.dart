import 'package:flutter/material.dart';

import '../models/routine_category.dart';
import '../theme/app_theme.dart';

class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.category,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final RoutineCategory category;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = category.color;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: compact ? 7 : 10,
        ),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.85),
                    color.withValues(alpha: 0.55),
                  ],
                )
              : null,
          color: selected ? null : AppColors.bgCard.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.75)
                : AppColors.purple.withValues(alpha: 0.18),
            width: 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              category.icon,
              size: compact ? 14 : 16,
              color: selected ? Colors.white : AppColors.inkSoft,
            ),
            const SizedBox(width: 6),
            Text(
              category.label,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.inkSoft,
                fontWeight: FontWeight.w700,
                fontSize: compact ? 11 : 12,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
