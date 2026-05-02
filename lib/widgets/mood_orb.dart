import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MoodOrb extends StatefulWidget {
  const MoodOrb({super.key, this.size = 180});

  final double size;

  @override
  State<MoodOrb> createState() => _MoodOrbState();
}

class _MoodOrbState extends State<MoodOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value * 2 * math.pi;
        final float = math.sin(t) * 6;
        final pulse = 1.0 + math.sin(t) * 0.04;

        return Transform.translate(
          offset: Offset(0, float),
          child: Transform.scale(
            scale: pulse,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.pink.withValues(alpha: 0.45),
                          AppColors.purple.withValues(alpha: 0.10),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),
                  Container(
                    width: widget.size * 0.72,
                    height: widget.size * 0.72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.orbGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.pink.withValues(alpha: 0.55),
                          blurRadius: 40,
                          spreadRadius: 4,
                        ),
                        BoxShadow(
                          color: AppColors.purple.withValues(alpha: 0.45),
                          blurRadius: 80,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: widget.size * 0.18,
                    left: widget.size * 0.22,
                    child: Container(
                      width: widget.size * 0.18,
                      height: widget.size * 0.12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.85),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
