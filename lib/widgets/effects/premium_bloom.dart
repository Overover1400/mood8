import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/effects_intensity.dart';
import '../../utils/easing.dart';
import '../../utils/particles.dart';

/// Cinematic habit-complete celebration. ≈1.8 s total.
///
/// Phases (single AnimationController drives all of them):
///   0.00–0.20  radial glow expands from [origin]
///   0.05–0.55  expanding ring wave (origin highlight)
///   0.11–0.78  12–15 petal physics, gradient-filled, rotating
///   0.65–1.00  everything fades out together
///
/// Pure [CustomPainter] under one [RepaintBoundary] — keeps frames cheap
/// even when the host screen is rebuilding.
class PremiumBloom extends StatefulWidget {
  const PremiumBloom({
    super.key,
    required this.origin,
    required this.intensity,
    this.onComplete,
  });

  final Offset origin;
  final EffectsIntensity intensity;
  final VoidCallback? onComplete;

  @override
  State<PremiumBloom> createState() => _PremiumBloomState();
}

class _PremiumBloomState extends State<PremiumBloom>
    with SingleTickerProviderStateMixin {
  static const Duration _baseDuration = Duration(milliseconds: 1800);
  static const int _basePetalCount = 14;

  late final AnimationController _controller;
  late final List<_Petal> _petals;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    final scaledMs =
        (_baseDuration.inMilliseconds * widget.intensity.durationScale)
            .round()
            .clamp(300, 4000);
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: scaledMs),
    );

    final rng = math.Random();
    final petalCount =
        (_basePetalCount * widget.intensity.particleScale).round().clamp(4, 24);
    _petals = List.generate(petalCount, (i) => _Petal.random(i, rng));

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_disposed) {
        widget.onComplete?.call();
      }
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _disposed = true;
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
                painter: _BloomPainter(
                  origin: widget.origin,
                  petals: _petals,
                  t: _controller.value,
                  durationSec: _controller.duration!.inMilliseconds / 1000.0,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Petal {
  _Petal({
    required this.gradient,
    required this.baseAngle,
    required this.speed,
    required this.size,
    required this.rotationSpeed,
    required this.initialRotation,
    required this.delay,
    required this.driftAmp,
    required this.driftFreq,
  });

  final List<Color> gradient;
  final double baseAngle; // radians, 0 = right, -π/2 = up
  final double speed; // px/sec initial velocity
  final double size; // px (large: 8-24)
  final double rotationSpeed; // rad/sec
  final double initialRotation; // rad
  final double delay; // 0..1 phase offset (within window)
  final double driftAmp; // horizontal sin amplitude (px)
  final double driftFreq; // hz

  factory _Petal.random(int index, math.Random rng) {
    // Favour upward arc: -3π/4 ~ -π/4
    final angle = -math.pi * 0.75 + rng.nextDouble() * math.pi * 0.5;
    final speed = 120.0 + rng.nextDouble() * 180.0;
    // Discrete-ish sizes for variety: 8/12/16/20/24.
    const sizes = [8.0, 12.0, 16.0, 20.0, 24.0];
    final size = sizes[rng.nextInt(sizes.length)];
    final rotation = rng.nextDouble() * math.pi * 2;
    final rotSpeed =
        (rng.nextBool() ? 1 : -1) * (0.8 + rng.nextDouble() * 1.5);
    final gradient =
        ParticlePalette.petalGradients[index % ParticlePalette.petalGradients.length];
    final delay = rng.nextDouble() * 0.18;
    final driftAmp = 6.0 + rng.nextDouble() * 14.0;
    final driftFreq = 0.6 + rng.nextDouble() * 0.9;
    return _Petal(
      gradient: gradient,
      baseAngle: angle,
      speed: speed,
      size: size,
      rotationSpeed: rotSpeed,
      initialRotation: rotation,
      delay: delay,
      driftAmp: driftAmp,
      driftFreq: driftFreq,
    );
  }
}

class _BloomPainter extends CustomPainter {
  _BloomPainter({
    required this.origin,
    required this.petals,
    required this.t,
    required this.durationSec,
  });

  final Offset origin;
  final List<_Petal> petals;
  final double t; // 0..1
  final double durationSec;

  // Cached static paints to avoid allocations in paint().
  static final Paint _glowPaint = Paint();
  static final Paint _ringStroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6;

  @override
  void paint(Canvas canvas, Size size) {
    _paintGlow(canvas);
    _paintRing(canvas);
    _paintPetals(canvas);
  }

  // ── Phase 1: radial glow halo (0–0.20) ──────────────────────────────

  void _paintGlow(Canvas canvas) {
    if (t > 0.45) return;
    final phase = (t / 0.20).clamp(0.0, 1.0);
    final easedScale = PremiumEasing.luxe.transform(phase);
    // Tail-off so glow fades after peak.
    final tail = t < 0.20 ? 1.0 : 1.0 - ((t - 0.20) / 0.25).clamp(0.0, 1.0);
    final radius = 30 + 96 * easedScale;
    final alpha = (0.55 * tail).clamp(0.0, 1.0);
    _glowPaint.shader = RadialGradient(
      colors: [
        ParticlePalette.purple.withValues(alpha: alpha),
        ParticlePalette.pinkLight.withValues(alpha: alpha * 0.55),
        ParticlePalette.purpleLight.withValues(alpha: 0),
      ],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(Rect.fromCircle(center: origin, radius: radius));
    _glowPaint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(origin, radius, _glowPaint);
  }

  // ── Phase 2: ring wave (0.05–0.55) ──────────────────────────────────

  void _paintRing(Canvas canvas) {
    if (t < 0.05 || t > 0.6) return;
    final phase = ((t - 0.05) / 0.5).clamp(0.0, 1.0);
    final eased = PremiumEasing.luxe.transform(phase);
    final radius = 12 + 220 * eased;
    final alpha = (0.55 * (1 - phase)).clamp(0.0, 1.0);
    _ringStroke.color = ParticlePalette.pinkLight.withValues(alpha: alpha);
    _ringStroke.maskFilter =
        const MaskFilter.blur(BlurStyle.normal, 1.2);
    canvas.drawCircle(origin, radius, _ringStroke);
  }

  // ── Phase 3: gradient petal physics (0.11–0.78) ────────────────────

  void _paintPetals(Canvas canvas) {
    // Each petal lives in its own [delay..1] slice, so an early petal
    // launches first and a delayed one finishes later. Lifespan ≈ 0.85s.
    for (final p in petals) {
      final local = ((t - p.delay) / (1.0 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final seconds = local * durationSec * (1.0 - p.delay);

      // Velocity vector
      final velocity = Offset(
        math.cos(p.baseAngle) * p.speed,
        math.sin(p.baseAngle) * p.speed,
      );
      var pos = ParticlePhysics.positionAt(
        velocity: velocity,
        t: seconds,
        gravityScale: 0.55,
      );
      // Sideways drift — sin wave for organic motion.
      final drift = math.sin(seconds * p.driftFreq * math.pi * 2) * p.driftAmp;
      pos = pos + Offset(drift, 0);

      final rotation = p.initialRotation + p.rotationSpeed * seconds;

      final fade = ParticlePhysics.fadeBell(local,
          fadeIn: 0.12, fadeOut: 0.35);
      final scale = ParticlePhysics.scaleBell(local,
          grow: 0.18, hold: 0.45);
      if (fade <= 0 || scale <= 0) continue;

      canvas.save();
      canvas.translate(origin.dx + pos.dx, origin.dy + pos.dy);
      canvas.rotate(rotation);

      final renderSize = p.size * scale;
      final bounds = Rect.fromCenter(
        center: Offset.zero,
        width: renderSize * 1.1,
        height: renderSize * 1.6,
      );

      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            p.gradient[0].withValues(alpha: fade),
            p.gradient[1].withValues(alpha: fade * 0.85),
          ],
        ).createShader(bounds)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.6);

      canvas.drawPath(_petalPath(renderSize), paint);

      // Inner highlight: smaller, brighter to give depth.
      final highlight = Paint()
        ..color = Colors.white.withValues(alpha: fade * 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4);
      canvas.drawPath(_petalPath(renderSize * 0.65), highlight);

      canvas.restore();
    }
  }

  Path _petalPath(double size) {
    // Teardrop / leaf — pointy at the top, rounded bottom.
    final s = size;
    return Path()
      ..moveTo(0, -s)
      ..quadraticBezierTo(s * 0.78, -s * 0.28, s * 0.42, s * 0.34)
      ..quadraticBezierTo(0, s * 0.88, -s * 0.42, s * 0.34)
      ..quadraticBezierTo(-s * 0.78, -s * 0.28, 0, -s)
      ..close();
  }

  @override
  bool shouldRepaint(_BloomPainter old) => old.t != t;
}
