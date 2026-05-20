import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class HabitRing extends StatelessWidget {
  const HabitRing({
    super.key,
    required this.value,
    required this.size,
    required this.color,
    this.strokeWidth = 6,
  });

  final double value;
  final double size;
  final Color color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RingPainter(
              progress: v,
              color: color,
              strokeWidth: strokeWidth,
            ),
            child: Center(
              child: Text(
                '${(v * 100).round()}%',
                style: TextStyle(
                  color: BrandColors.ink(context),
                  fontSize: size * 0.22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final bg = Paint()
      ..color = AppColors.bg.withValues(alpha: 0.7)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bg);

    if (progress <= 0) return;

    final fg = Paint()
      ..shader = SweepGradient(
        colors: [
          color,
          AppColors.pinkLight,
          AppColors.purpleLight,
          color,
        ],
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
      ).createShader(rect)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}
