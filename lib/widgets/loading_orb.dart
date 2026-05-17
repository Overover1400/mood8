import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class LoadingOrb extends StatefulWidget {
  const LoadingOrb({super.key, this.size = 140, this.label});

  final double size;
  final String? label;

  @override
  State<LoadingOrb> createState() => _LoadingOrbState();
}

class _LoadingOrbState extends State<LoadingOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value * 2 * math.pi;
              final pulse = 1.0 + math.sin(t) * 0.05;
              return Transform.rotate(
                angle: _controller.value * 2 * math.pi,
                child: Transform.scale(
                  scale: pulse,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const SweepGradient(
                        colors: [
                          AppColors.purple,
                          AppColors.pink,
                          AppColors.pinkLight,
                          AppColors.purpleLight,
                          AppColors.purple,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.pink.withValues(alpha: 0.45),
                          blurRadius: 28,
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: AppColors.purple.withValues(alpha: 0.45),
                          blurRadius: 38,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: widget.size * 0.55,
                        height: widget.size * 0.55,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.bgDeep.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.label != null) ...[
          const SizedBox(height: 18),
          Text(
            widget.label!,
            style: TextStyle(
              color: AppColors.inkSoft,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ],
    );
  }
}
