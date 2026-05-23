import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/effects_intensity.dart';
import '../../theme/app_theme.dart';
import '../../utils/easing.dart';
import '../../utils/particles.dart';

/// Full-screen cinematic celebration for "everything done today". ≈3 s.
///
/// Layers (single AnimationController drives all of them):
///   0.00–0.03  scene-dim overlay
///   0.03–0.40  concentric rings (3, staggered)
///   0.10–0.65  mixed-shape burst (petals, stars, hexagons, light flares)
///   0.30–0.85  soft confetti rain
///   0.50–0.85  "Beautiful day" toast slide-in
///   0.65–0.95  light-beam sweep across the scene
///   0.85–1.00  unified fade-out
class CosmicBloom extends StatefulWidget {
  const CosmicBloom({
    super.key,
    required this.intensity,
    this.userName,
    this.onComplete,
  });

  final EffectsIntensity intensity;
  final String? userName;
  final VoidCallback? onComplete;

  @override
  State<CosmicBloom> createState() => _CosmicBloomState();
}

class _CosmicBloomState extends State<CosmicBloom>
    with SingleTickerProviderStateMixin {
  static const Duration _baseDuration = Duration(milliseconds: 3000);

  late final AnimationController _controller;
  late final List<_BurstParticle> _burst;
  late final List<_ConfettiPiece> _confetti;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    final scaledMs =
        (_baseDuration.inMilliseconds * widget.intensity.durationScale)
            .round()
            .clamp(800, 6000);
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: scaledMs),
    );

    final rng = math.Random();
    final burstCount = (28 * widget.intensity.particleScale).round().clamp(8, 48);
    _burst = List.generate(burstCount, (i) => _BurstParticle.random(i, rng));
    final confettiCount =
        (22 * widget.intensity.particleScale).round().clamp(6, 36);
    _confetti = List.generate(confettiCount, (i) => _ConfettiPiece.random(rng));

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
    final size = MediaQuery.sizeOf(context);
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            return Stack(
              fit: StackFit.expand,
              children: [
                // Painted layers
                CustomPaint(
                  painter: _CosmicPainter(
                    canvasSize: size,
                    burst: _burst,
                    confetti: _confetti,
                    t: t,
                    durationSec: _controller.duration!.inMilliseconds / 1000.0,
                  ),
                ),
                // Floating glass toast
                _Toast(progress: t, userName: widget.userName),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── particles ────────────────────────────────────────────────────────

enum _ShapeKind { petal, star, hexagon, flare }

class _BurstParticle {
  _BurstParticle({
    required this.kind,
    required this.angle,
    required this.speed,
    required this.size,
    required this.rotation,
    required this.rotationSpeed,
    required this.depth,
    required this.gradient,
    required this.delay,
    required this.blur,
  });

  final _ShapeKind kind;
  final double angle;
  final double speed;
  final double size;
  final double rotation;
  final double rotationSpeed;
  final double depth; // 0..1, 0 = back, 1 = front (parallax + scale)
  final List<Color> gradient;
  final double delay;
  final double blur;

  factory _BurstParticle.random(int index, math.Random rng) {
    // Distribute kinds by spec ratios: 40/30/20/10
    final r = rng.nextDouble();
    final kind = r < 0.40
        ? _ShapeKind.petal
        : r < 0.70
            ? _ShapeKind.star
            : r < 0.90
                ? _ShapeKind.hexagon
                : _ShapeKind.flare;
    final angle = rng.nextDouble() * math.pi * 2;
    final depth = rng.nextDouble();
    final size = 8.0 + depth * 22.0; // 8–30 px
    final speed = 150 + depth * 220;
    final rotation = rng.nextDouble() * math.pi * 2;
    final rotSpeed =
        (rng.nextBool() ? 1 : -1) * (0.6 + rng.nextDouble() * 1.6);
    final gradient = ParticlePalette
        .petalGradients[index % ParticlePalette.petalGradients.length];
    return _BurstParticle(
      kind: kind,
      angle: angle,
      speed: speed,
      size: size,
      rotation: rotation,
      rotationSpeed: rotSpeed,
      depth: depth,
      gradient: gradient,
      delay: rng.nextDouble() * 0.20,
      blur: (1.0 - depth) * 1.8, // background particles blurred for parallax
    );
  }
}

class _ConfettiPiece {
  _ConfettiPiece({
    required this.startX,
    required this.swayAmp,
    required this.swayFreq,
    required this.size,
    required this.fallSpeed,
    required this.color,
    required this.delay,
    required this.rotationSpeed,
    required this.initialRotation,
  });

  final double startX; // 0..1 across screen
  final double swayAmp; // px
  final double swayFreq; // hz
  final double size; // px
  final double fallSpeed; // px/sec
  final Color color;
  final double delay;
  final double rotationSpeed;
  final double initialRotation;

  factory _ConfettiPiece.random(math.Random rng) {
    final palette = [
      ParticlePalette.purpleLight,
      ParticlePalette.pinkLight,
      ParticlePalette.pink,
      ParticlePalette.blueAccent,
      ParticlePalette.purple,
    ];
    return _ConfettiPiece(
      startX: rng.nextDouble(),
      swayAmp: 14 + rng.nextDouble() * 26,
      swayFreq: 0.4 + rng.nextDouble() * 0.7,
      size: 6 + rng.nextDouble() * 8,
      fallSpeed: 110 + rng.nextDouble() * 90,
      color: palette[rng.nextInt(palette.length)],
      delay: rng.nextDouble() * 0.25,
      rotationSpeed: (rng.nextBool() ? 1 : -1) * (1.0 + rng.nextDouble() * 1.8),
      initialRotation: rng.nextDouble() * math.pi * 2,
    );
  }
}

// ─── painter ──────────────────────────────────────────────────────────

class _CosmicPainter extends CustomPainter {
  _CosmicPainter({
    required this.canvasSize,
    required this.burst,
    required this.confetti,
    required this.t,
    required this.durationSec,
  });

  final Size canvasSize;
  final List<_BurstParticle> burst;
  final List<_ConfettiPiece> confetti;
  final double t;
  final double durationSec;

  static final Paint _dimPaint = Paint();
  static final Paint _ringStroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    _paintDim(canvas, size);
    _paintRings(canvas, size);
    _paintBurst(canvas, size);
    _paintConfetti(canvas, size);
    _paintLightSweep(canvas, size);
  }

  // 0.00–0.03 scene dim
  void _paintDim(Canvas canvas, Size size) {
    if (t > 0.92) return;
    final fadeIn = (t / 0.05).clamp(0.0, 1.0);
    final fadeOut = t < 0.85 ? 1.0 : 1.0 - (t - 0.85) / 0.15;
    final alpha = (0.06 * fadeIn * fadeOut).clamp(0.0, 1.0);
    if (alpha <= 0) return;
    _dimPaint.color = Colors.black.withValues(alpha: alpha);
    canvas.drawRect(Offset.zero & size, _dimPaint);
  }

  // 0.03–0.40 three expanding rings, staggered by 0.05
  void _paintRings(Canvas canvas, Size size) {
    if (t < 0.03 || t > 0.5) return;
    final center = size.center(Offset.zero);
    final maxRadius = size.shortestSide * 1.1;
    for (var i = 0; i < 3; i++) {
      final delay = 0.03 + i * 0.07;
      final span = 0.40 - delay;
      if (t < delay || t > delay + span) continue;
      final local = ((t - delay) / span).clamp(0.0, 1.0);
      final eased = PremiumEasing.luxe.transform(local);
      final radius = 12 + eased * maxRadius;
      final alpha = (0.55 * (1 - local)).clamp(0.0, 1.0);
      _ringStroke
        ..color = ParticlePalette.purpleLight.withValues(alpha: alpha)
        ..shader = LinearGradient(
          colors: [
            ParticlePalette.purple.withValues(alpha: alpha),
            ParticlePalette.pink.withValues(alpha: alpha * 0.6),
            ParticlePalette.pinkLight.withValues(alpha: 0),
          ],
        ).createShader(
            Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, _ringStroke);
    }
  }

  // 0.10–0.65 mixed-shape burst from screen center
  void _paintBurst(Canvas canvas, Size size) {
    if (t < 0.10 || t > 0.72) return;
    final center = size.center(Offset.zero);
    for (final p in burst) {
      final window = 0.55;
      final local = ((t - 0.10 - p.delay * 0.15) / window).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final seconds = local * window * durationSec;

      final velocity = Offset(
        math.cos(p.angle) * p.speed,
        math.sin(p.angle) * p.speed,
      );
      final pos = ParticlePhysics.positionAt(
        velocity: velocity,
        t: seconds,
        gravityScale: 0.25,
      );

      final fade = ParticlePhysics.fadeBell(local,
          fadeIn: 0.15, fadeOut: 0.35);
      final scale = 0.6 + 0.5 * PremiumEasing.luxe.transform(local);
      if (fade <= 0) continue;

      // Parallax: deeper particles scale less, drawn first.
      final depthScale = 0.7 + p.depth * 0.6;
      final renderSize = p.size * scale * depthScale;
      final rotation = p.rotation + p.rotationSpeed * seconds;

      canvas.save();
      canvas.translate(center.dx + pos.dx, center.dy + pos.dy);
      canvas.rotate(rotation);
      _drawShape(canvas, p, renderSize, fade);
      canvas.restore();
    }
  }

  void _drawShape(
      Canvas canvas, _BurstParticle p, double size, double fade) {
    final bounds = Rect.fromCircle(center: Offset.zero, radius: size);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          p.gradient[0].withValues(alpha: fade),
          p.gradient[1].withValues(alpha: fade * 0.8),
        ],
      ).createShader(bounds);
    if (p.blur > 0.05) {
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, p.blur);
    }
    switch (p.kind) {
      case _ShapeKind.petal:
        canvas.drawPath(_petalPath(size), paint);
        break;
      case _ShapeKind.star:
        canvas.drawPath(_starPath(size), paint);
        // Bright center pop.
        canvas.drawCircle(
          Offset.zero,
          size * 0.22,
          Paint()
            ..color = Colors.white.withValues(alpha: fade * 0.55)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4),
        );
        break;
      case _ShapeKind.hexagon:
        canvas.drawPath(_hexagonPath(size), paint);
        break;
      case _ShapeKind.flare:
        final flarePaint = Paint()
          ..shader = RadialGradient(
            colors: [
              p.gradient[0].withValues(alpha: fade),
              p.gradient[1].withValues(alpha: fade * 0.4),
              p.gradient[1].withValues(alpha: 0),
            ],
            stops: const [0.0, 0.55, 1.0],
          ).createShader(bounds)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
        canvas.drawCircle(Offset.zero, size * 1.2, flarePaint);
        break;
    }
  }

  Path _petalPath(double size) {
    final s = size;
    return Path()
      ..moveTo(0, -s)
      ..quadraticBezierTo(s * 0.78, -s * 0.28, s * 0.42, s * 0.34)
      ..quadraticBezierTo(0, s * 0.88, -s * 0.42, s * 0.34)
      ..quadraticBezierTo(-s * 0.78, -s * 0.28, 0, -s)
      ..close();
  }

  Path _starPath(double size) {
    final path = Path();
    const points = 5;
    for (var i = 0; i < points * 2; i++) {
      final isOuter = i.isEven;
      final r = isOuter ? size : size * 0.45;
      final angle = -math.pi / 2 + i * math.pi / points;
      final x = math.cos(angle) * r;
      final y = math.sin(angle) * r;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  Path _hexagonPath(double size) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = math.pi / 3 * i;
      final x = math.cos(angle) * size;
      final y = math.sin(angle) * size;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  // 0.30–0.85 confetti drift down
  void _paintConfetti(Canvas canvas, Size size) {
    if (t < 0.28 || t > 0.95) return;
    for (final c in confetti) {
      final window = 0.65;
      final local = ((t - 0.28 - c.delay * 0.10) / window).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final seconds = local * window * durationSec;
      final fall = c.fallSpeed * seconds;
      final sway = math.sin(seconds * c.swayFreq * math.pi * 2) * c.swayAmp;
      final x = c.startX * size.width + sway;
      final y = -20.0 + fall;
      if (y > size.height + 30) continue;
      final fade = ParticlePhysics.fadeBell(local,
          fadeIn: 0.10, fadeOut: 0.30);
      if (fade <= 0) continue;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(c.initialRotation + c.rotationSpeed * seconds);
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: c.size,
        height: c.size * 0.45,
      );
      final paint = Paint()
        ..color = c.color.withValues(alpha: fade);
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)), paint);
      canvas.restore();
    }
  }

  // 0.65–0.95 sky-light sweep across the scene
  void _paintLightSweep(Canvas canvas, Size size) {
    if (t < 0.62 || t > 0.98) return;
    final phase = ((t - 0.62) / 0.34).clamp(0.0, 1.0);
    final eased = PremiumEasing.cinematic.transform(phase);
    final centerX = -size.width * 0.4 + (size.width * 1.8) * eased;
    final width = size.width * 0.4;
    final rect = Rect.fromLTWH(
      centerX - width / 2,
      0,
      width,
      size.height,
    );
    final fade = ParticlePhysics.fadeBell(phase,
        fadeIn: 0.20, fadeOut: 0.30);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: 0.06 * fade),
          Colors.white.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(_CosmicPainter old) => old.t != t;
}

// ─── glass toast ──────────────────────────────────────────────────────

class _Toast extends StatelessWidget {
  const _Toast({required this.progress, required this.userName});
  final double progress;
  final String? userName;

  @override
  Widget build(BuildContext context) {
    // Visible window 0.50 → 0.92, slide up + fade.
    if (progress < 0.48 || progress > 0.95) return const SizedBox.shrink();
    final phase = ((progress - 0.48) / 0.47).clamp(0.0, 1.0);
    final slideEnter = (phase / 0.25).clamp(0.0, 1.0);
    final slideExit = phase < 0.78
        ? 0.0
        : ((phase - 0.78) / 0.22).clamp(0.0, 1.0);
    final easedEnter = PremiumEasing.luxe.transform(slideEnter);
    final dy = (1 - easedEnter) * 36;
    final alpha = ((slideEnter) * (1 - slideExit)).clamp(0.0, 1.0);
    final name = (userName == null || userName!.isEmpty) ? 'friend' : userName!;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 80,
      child: Center(
        child: Opacity(
          opacity: alpha,
          child: Transform.translate(
            offset: Offset(0, dy),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 22, vertical: 14),
                  decoration: BoxDecoration(
                    color: BrandColors.bgCard(context).withValues(alpha: 0.65),
                    border: Border.all(
                      color: AppColors.pinkLight.withValues(alpha: 0.45),
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('✨', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      Text(
                        'Beautiful day, $name.',
                        style: GoogleFonts.bricolageGrotesque(
                          color: BrandColors.ink(context),
                          fontSize: 22,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
