import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/effects_intensity.dart';
import '../../theme/app_theme.dart';
import '../../utils/easing.dart';
import '../../utils/particles.dart';

/// Ethereal identity-level-up celebration. ≈3 s.
///
/// A constellation of glowing nodes appears, edges connect them, the
/// progress percentage shimmers, then everything fades.
class IdentityConstellation extends StatefulWidget {
  const IdentityConstellation({
    super.key,
    required this.identity,
    required this.progress,
    required this.intensity,
    this.onComplete,
  });

  final String identity;
  final double progress; // 0..1
  final EffectsIntensity intensity;
  final VoidCallback? onComplete;

  @override
  State<IdentityConstellation> createState() => _IdentityConstellationState();
}

class _IdentityConstellationState extends State<IdentityConstellation>
    with SingleTickerProviderStateMixin {
  static const Duration _baseDuration = Duration(milliseconds: 3000);

  late final AnimationController _controller;
  late final List<_Star> _stars;
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
    final count = (12 * widget.intensity.particleScale).round().clamp(4, 24);
    _stars = List.generate(count, (i) {
      final angle = (i / count) * math.pi * 2 + rng.nextDouble() * 0.5;
      final r = 60 + rng.nextDouble() * 110;
      return _Star(
        offset: Offset(math.cos(angle) * r, math.sin(angle) * r),
        size: 3 + rng.nextDouble() * 4,
        twinkleSpeed: 0.8 + rng.nextDouble() * 1.4,
        twinklePhase: rng.nextDouble() * math.pi * 2,
        color: rng.nextBool()
            ? ParticlePalette.purpleLight
            : ParticlePalette.pinkLight,
      );
    });

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
    final center = Offset(size.width / 2, size.height * 0.38);
    return IgnorePointer(
      child: RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  painter: _ConstellationPainter(
                    center: center,
                    stars: _stars,
                    t: _controller.value,
                    durationSec:
                        _controller.duration!.inMilliseconds / 1000.0,
                  ),
                );
              },
            ),
            _Toast(
              controller: _controller,
              identity: widget.identity,
              progress: widget.progress,
            ),
          ],
        ),
      ),
    );
  }
}

class _Star {
  const _Star({
    required this.offset,
    required this.size,
    required this.twinkleSpeed,
    required this.twinklePhase,
    required this.color,
  });
  final Offset offset; // relative to constellation centre
  final double size;
  final double twinkleSpeed;
  final double twinklePhase;
  final Color color;
}

class _ConstellationPainter extends CustomPainter {
  _ConstellationPainter({
    required this.center,
    required this.stars,
    required this.t,
    required this.durationSec,
  });

  final Offset center;
  final List<_Star> stars;
  final double t;
  final double durationSec;

  @override
  void paint(Canvas canvas, Size size) {
    _paintCoreGlow(canvas);
    _paintEdges(canvas);
    _paintStars(canvas);
  }

  // Soft purple glow at the constellation's heart.
  void _paintCoreGlow(Canvas canvas) {
    final phase = (t / 0.30).clamp(0.0, 1.0);
    final eased = PremiumEasing.luxe.transform(phase);
    final tail = t < 0.85 ? 1.0 : 1.0 - (t - 0.85) / 0.15;
    final radius = 20 + 60 * eased;
    final alpha = (0.55 * tail).clamp(0.0, 1.0);
    if (alpha <= 0) return;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          ParticlePalette.purpleLight.withValues(alpha: alpha),
          ParticlePalette.pink.withValues(alpha: alpha * 0.4),
          ParticlePalette.purple.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(center, radius, paint);
  }

  // Faint lines connecting nearby stars.
  void _paintEdges(Canvas canvas) {
    if (t < 0.30 || t > 0.92) return;
    final phase = ((t - 0.30) / 0.55).clamp(0.0, 1.0);
    final fade = ParticlePhysics.fadeBell(phase,
        fadeIn: 0.18, fadeOut: 0.35);
    if (fade <= 0) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    for (var i = 0; i < stars.length; i++) {
      for (var j = i + 1; j < stars.length; j++) {
        final a = stars[i].offset + center;
        final b = stars[j].offset + center;
        final d = (a - b).distance;
        if (d > 130) continue;
        final alpha = fade * (1.0 - (d / 130)) * 0.45;
        paint.color = ParticlePalette.purpleLight.withValues(alpha: alpha);
        canvas.drawLine(a, b, paint);
      }
    }
  }

  // Each star: fade-in by index, then twinkle.
  void _paintStars(Canvas canvas) {
    for (var i = 0; i < stars.length; i++) {
      final s = stars[i];
      final delay = 0.10 + (i / stars.length) * 0.25;
      final phase = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (phase <= 0) continue;
      final fade = ParticlePhysics.fadeBell(phase,
          fadeIn: 0.12, fadeOut: 0.25);
      final twinkle =
          0.55 + 0.45 * math.sin(t * durationSec * s.twinkleSpeed + s.twinklePhase);
      final alpha = (fade * twinkle).clamp(0.0, 1.0);
      if (alpha <= 0) continue;
      final pos = center + s.offset;
      canvas.drawCircle(
        pos,
        s.size * 2.4,
        Paint()
          ..color = s.color.withValues(alpha: alpha * 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(
        pos,
        s.size,
        Paint()..color = s.color.withValues(alpha: alpha),
      );
      canvas.drawCircle(
        pos,
        s.size * 0.45,
        Paint()..color = Colors.white.withValues(alpha: alpha * 0.85),
      );
    }
  }

  @override
  bool shouldRepaint(_ConstellationPainter old) => old.t != t;
}

class _Toast extends StatelessWidget {
  const _Toast({
    required this.controller,
    required this.identity,
    required this.progress,
  });
  final AnimationController controller;
  final String identity;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        if (t < 0.42 || t > 0.95) return const SizedBox.shrink();
        final phase = ((t - 0.42) / 0.53).clamp(0.0, 1.0);
        final entry = (phase / 0.25).clamp(0.0, 1.0);
        final exit = phase < 0.85 ? 0.0 : (phase - 0.85) / 0.15;
        final eased = PremiumEasing.luxe.transform(entry);
        final dy = (1 - eased) * 24;
        final alpha = (entry * (1 - exit)).clamp(0.0, 1.0);
        final pct = (progress * 100).round();
        return Positioned(
          left: 0,
          right: 0,
          bottom: 110,
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
                      child: Text(
                        "You're $pct% $identity.",
                        style: GoogleFonts.instrumentSerif(
                          color: BrandColors.ink(context),
                          fontStyle: FontStyle.italic,
                          fontSize: 22,
                          height: 1.0,
                        ),
                      ),
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
