import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Single-shot particle burst. Spawns [sparkleCount] small glowing dots from
/// the centre of its bounds, each with a random angle (favouring upward),
/// random size, random color from the Mood8 palette, and an ease-out fade.
///
/// Designed to be inserted via [OverlayEntry] and disposed after [duration].
/// One [AnimationController], one [CustomPainter] — cheap to repaint.
class SparkleOverlay extends StatefulWidget {
  const SparkleOverlay({
    super.key,
    required this.sparkleCount,
    required this.spread,
    required this.duration,
    this.onComplete,
  });

  final int sparkleCount;
  final double spread;
  final Duration duration;
  final VoidCallback? onComplete;

  @override
  State<SparkleOverlay> createState() => _SparkleOverlayState();
}

class _SparkleOverlayState extends State<SparkleOverlay>
    with SingleTickerProviderStateMixin {
  static const List<Color> _palette = [
    Color(0xFFC084FC),
    Color(0xFFEC4899),
    Color(0xFFF472B6),
    Color(0xFF818CF8),
    Color(0xFFA855F7),
    Color(0xFFFAF5FF),
  ];

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final List<_Particle> _particles;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    final rng = math.Random();
    _particles = List.generate(widget.sparkleCount, (_) {
      // Angle: favour the upper hemisphere — sparkles "rise".
      final angle = -math.pi / 2 + (rng.nextDouble() - 0.5) * math.pi;
      final distance = widget.spread * (0.45 + rng.nextDouble() * 0.55);
      final size = 2.0 + rng.nextDouble() * 4.0;
      final delay = rng.nextDouble() * 0.25;
      final color = _palette[rng.nextInt(_palette.length)];
      return _Particle(
        angle: angle,
        distance: distance,
        size: size,
        delay: delay,
        color: color,
      );
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_completed) {
        _completed = true;
        widget.onComplete?.call();
      }
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: SizedBox.expand(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: _SparklePainter(
                  particles: _particles,
                  t: _controller.value,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Particle {
  const _Particle({
    required this.angle,
    required this.distance,
    required this.size,
    required this.delay,
    required this.color,
  });

  final double angle;
  final double distance;
  final double size;
  final double delay;
  final Color color;
}

class _SparklePainter extends CustomPainter {
  _SparklePainter({required this.particles, required this.t});

  final List<_Particle> particles;
  final double t;

  static final Paint _bodyPaint = Paint();
  static final Paint _glowPaint = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (final p in particles) {
      final localT = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (localT <= 0) continue;
      // Ease-out cubic for travel.
      final eased = 1 - math.pow(1 - localT, 3).toDouble();
      // Add a tiny gravity drift downward as time advances.
      final dx = math.cos(p.angle) * p.distance * eased;
      final dy = math.sin(p.angle) * p.distance * eased + eased * eased * 6;
      // Fade in fast, then out.
      final fadeIn = (localT * 4).clamp(0.0, 1.0);
      final fadeOut = 1.0 - localT;
      final opacity = (fadeIn * fadeOut).clamp(0.0, 1.0);
      if (opacity <= 0) continue;
      final pos = center + Offset(dx, dy);
      _glowPaint.color = p.color.withValues(alpha: opacity * 0.45);
      canvas.drawCircle(pos, p.size * 1.8, _glowPaint);
      _bodyPaint.color = p.color.withValues(alpha: opacity);
      canvas.drawCircle(pos, p.size, _bodyPaint);
    }
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.t != t;
}

/// Lightweight image-precaching helper kept here so we don't pull `dart:ui`
/// into every consumer. Currently unused but reserved for future custom
/// sparkle bitmaps.
// ignore: unused_element
class _NoopImage {
  // ignore: unused_field
  final ui.Image? image = null;
}
