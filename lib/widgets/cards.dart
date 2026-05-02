import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 24,
    this.gradient,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: gradient ??
            LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.bgCard.withValues(alpha: 0.95),
                AppColors.bg.withValues(alpha: 0.85),
              ],
            ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.18),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.purple.withValues(alpha: 0.10),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.emoji,
    this.accent,
  });

  final String label;
  final String value;
  final String emoji;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppColors.purpleLight;

    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
      borderRadius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withValues(alpha: 0.45),
                  color.withValues(alpha: 0.05),
                ],
              ),
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: AppColors.inkDim,
              fontSize: 10,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class RoutineCard extends StatelessWidget {
  const RoutineCard({
    super.key,
    required this.time,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.isNow = false,
  });

  final String time;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isNow;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      gradient: isNow
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.purple.withValues(alpha: 0.30),
                AppColors.pink.withValues(alpha: 0.20),
              ],
            )
          : null,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: isNow
                  ? AppColors.buttonGradient
                  : LinearGradient(
                      colors: [
                        AppColors.purple.withValues(alpha: 0.25),
                        AppColors.pink.withValues(alpha: 0.20),
                      ],
                    ),
              boxShadow: isNow
                  ? [
                      BoxShadow(
                        color: AppColors.pink.withValues(alpha: 0.45),
                        blurRadius: 20,
                      ),
                    ]
                  : null,
            ),
            child: Icon(icon,
                color: isNow ? Colors.white : AppColors.inkSoft, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      time,
                      style: TextStyle(
                        color: isNow ? AppColors.pinkLight : AppColors.inkDim,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    if (isNow) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: AppColors.buttonGradient,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'NOW',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.inkDim,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: AppColors.inkDim, size: 22),
        ],
      ),
    );
  }
}
