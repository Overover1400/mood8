import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/effects_intensity.dart';
import '../../theme/app_theme.dart';
import '../../utils/easing.dart';
import '../../utils/particles.dart';

/// Streak-milestone celebration. ≈2.5 s.
///
/// Phases (driven by one [AnimationController]):
///   0.00–0.08  flame icon overshoots from origin
///   0.08–0.24  number scrolls up with parallax trail
///   0.16–0.40  five light beams rise from origin
///   0.32–0.72  particle cascade falls from beam tops
///   0.48–0.80  glass-morphism badge slides in
///   0.80–1.00  unified fade-out
class PhoenixRise extends StatefulWidget {
  const PhoenixRise({
    super.key,
    required this.days,
    required this.intensity,
    this.flameOrigin,
    this.onComplete,
  });

  final int days;
  final EffectsIntensity intensity;
  final Offset? flameOrigin;
  final VoidCallback? onComplete;

  @override
  State<PhoenixRise> createState() => _PhoenixRiseState();
}

class _PhoenixRiseState extends State<PhoenixRise>
    with SingleTickerProviderStateMixin {
  static const Duration _baseDuration = Duration(milliseconds: 2500);

  late final AnimationController _controller;
  late final List<_Cascade> _cascade;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    final scaledMs =
        (_baseDuration.inMilliseconds * widget.intensity.durationScale)
            .round()
            .clamp(800, 5000);
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: scaledMs),
    );

    final rng = math.Random();
    final count = (32 * widget.intensity.particleScale).round().clamp(8, 60);
    _cascade = List.generate(count, (i) => _Cascade.random(rng));

    _controller.addStatusListener((s) {
      if (s == AnimationStatus.completed && !_disposed) {
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
    final origin = widget.flameOrigin ??
        Offset(size.width / 2, size.height * 0.34);
    return IgnorePointer(
      child: RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  painter: _PhoenixPainter(
                    canvasSize: size,
                    origin: origin,
                    cascade: _cascade,
                    t: _controller.value,
                    durationSec:
                        _controller.duration!.inMilliseconds / 1000.0,
                  ),
                );
              },
            ),
            _Badge(
              controller: _controller,
              days: widget.days,
              origin: origin,
            ),
          ],
        ),
      ),
    );
  }
}

class _Cascade {
  _Cascade({
    required this.beamIndex,
    required this.startOffsetX,
    required this.swayAmp,
    required this.swayFreq,
    required this.fallSpeed,
    required this.size,
    required this.color,
    required this.delay,
  });

  final int beamIndex; // 0..4
  final double startOffsetX; // jitter from beam centre
  final double swayAmp;
  final double swayFreq;
  final double fallSpeed;
  final double size;
  final Color color;
  final double delay; // 0..0.3 stagger

  factory _Cascade.random(math.Random rng) {
    final palette = [
      const Color(0xFFFFB451), // warm orange
      const Color(0xFFFF6B81), // hot pink
      ParticlePalette.pinkLight,
      ParticlePalette.purpleLight,
      const Color(0xFFFFE38B), // soft yellow
    ];
    return _Cascade(
      beamIndex: rng.nextInt(5),
      startOffsetX: (rng.nextDouble() - 0.5) * 16,
      swayAmp: 12 + rng.nextDouble() * 22,
      swayFreq: 0.7 + rng.nextDouble() * 0.9,
      fallSpeed: 120 + rng.nextDouble() * 140,
      size: 3 + rng.nextDouble() * 4,
      color: palette[rng.nextInt(palette.length)],
      delay: rng.nextDouble() * 0.3,
    );
  }
}

class _PhoenixPainter extends CustomPainter {
  _PhoenixPainter({
    required this.canvasSize,
    required this.origin,
    required this.cascade,
    required this.t,
    required this.durationSec,
  });

  final Size canvasSize;
  final Offset origin;
  final List<_Cascade> cascade;
  final double t;
  final double durationSec;

  @override
  void paint(Canvas canvas, Size size) {
    _paintBeams(canvas, size);
    _paintCascade(canvas, size);
    _paintFlameGlow(canvas);
  }

  // Five vertical light beams shooting up from origin.
  void _paintBeams(Canvas canvas, Size size) {
    if (t < 0.16 || t > 0.85) return;
    final local = ((t - 0.16) / 0.50).clamp(0.0, 1.0);
    final eased = PremiumEasing.luxe.transform(local);
    final fadeOut = t < 0.55 ? 1.0 : 1.0 - (t - 0.55) / 0.30;
    final alpha = (0.32 * fadeOut).clamp(0.0, 1.0);
    if (alpha <= 0) return;

    for (var i = 0; i < 5; i++) {
      // Beam spread: ±60px from centre, with subtle sway via i.
      final spread = (i - 2) * 22.0;
      final sway = math.sin(t * math.pi * 2 + i) * 4;
      final x = origin.dx + spread + sway;
      final beamWidth = 4.5 + (i.isEven ? 1.5 : 0);
      final beamHeight = origin.dy * eased * 1.05;
      final rect = Rect.fromLTWH(
        x - beamWidth / 2,
        origin.dy - beamHeight,
        beamWidth,
        beamHeight,
      );
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            const Color(0xFFFFB451).withValues(alpha: alpha),
            const Color(0xFFFF6B81).withValues(alpha: alpha * 0.55),
            ParticlePalette.pinkLight.withValues(alpha: 0),
          ],
        ).createShader(rect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        paint,
      );
    }
  }

  // Cascade of particles falling from beam tops.
  void _paintCascade(Canvas canvas, Size size) {
    if (t < 0.30 || t > 0.95) return;
    for (final c in cascade) {
      final window = 0.55;
      final local = ((t - 0.30 - c.delay * 0.15) / window).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final seconds = local * window * durationSec;
      final beamX = origin.dx + (c.beamIndex - 2) * 22.0 + c.startOffsetX;
      final beamTopY = origin.dy * 0.10; // top of the beams
      final fall = c.fallSpeed * seconds;
      final sway = math.sin(seconds * c.swayFreq * math.pi * 2) * c.swayAmp;
      final y = beamTopY + fall;
      if (y > size.height) continue;
      final fade = ParticlePhysics.fadeBell(local,
          fadeIn: 0.15, fadeOut: 0.35);
      if (fade <= 0) continue;

      final paint = Paint()
        ..color = c.color.withValues(alpha: fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8);
      canvas.drawCircle(Offset(beamX + sway, y), c.size, paint);
      // Bright core.
      canvas.drawCircle(
        Offset(beamX + sway, y),
        c.size * 0.4,
        Paint()..color = Colors.white.withValues(alpha: fade * 0.7),
      );
    }
  }

  // Warm flame glow at origin, intense first then settling.
  void _paintFlameGlow(Canvas canvas) {
    final phase = (t / 0.18).clamp(0.0, 1.0);
    final eased = PremiumEasing.subtleBounce.transform(phase);
    final pulse = t < 0.95 ? 1.0 : 1.0 - (t - 0.95) / 0.05;
    final radius = 28 + 48 * eased;
    final alpha = (0.80 * pulse).clamp(0.0, 1.0);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFB451).withValues(alpha: alpha),
          const Color(0xFFFF6B81).withValues(alpha: alpha * 0.6),
          ParticlePalette.pinkLight.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: origin, radius: radius))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(origin, radius, paint);
  }

  @override
  bool shouldRepaint(_PhoenixPainter old) => old.t != t;
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.controller,
    required this.days,
    required this.origin,
  });
  final AnimationController controller;
  final int days;
  final Offset origin;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        if (t < 0.46) return const SizedBox.shrink();
        final phase = ((t - 0.46) / 0.40).clamp(0.0, 1.0);
        final entry = (phase / 0.25).clamp(0.0, 1.0);
        final exit = phase < 0.85 ? 0.0 : (phase - 0.85) / 0.15;
        final eased = PremiumEasing.subtleBounce.transform(entry);
        final dx = (1 - eased) * 80;
        final alpha = (entry * (1 - exit)).clamp(0.0, 1.0);
        return Positioned(
          right: 24,
          top: origin.dy + 12,
          child: Opacity(
            opacity: alpha,
            child: Transform.translate(
              offset: Offset(dx, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFFFFB451).withValues(alpha: 0.55),
                          const Color(0xFFFF6B81).withValues(alpha: 0.45),
                        ],
                      ),
                      border: Border.all(
                        color: const Color(0xFFFFE38B).withValues(alpha: 0.45),
                      ),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🔥', style: TextStyle(fontSize: 22)),
                        const SizedBox(width: 8),
                        Text(
                          '$days day streak',
                          style: GoogleFonts.instrumentSerif(
                            color: AppColors.ink,
                            fontStyle: FontStyle.italic,
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
        );
      },
    );
  }
}
