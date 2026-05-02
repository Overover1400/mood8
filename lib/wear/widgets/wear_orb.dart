import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class WearOrb extends StatefulWidget {
  const WearOrb({super.key, this.size = 50});

  final double size;

  @override
  State<WearOrb> createState() => _WearOrbState();
}

class _WearOrbState extends State<WearOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
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
        final pulse = 1.0 + math.sin(t) * 0.05;

        return Transform.scale(
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
                    gradient: AppColors.orbGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.pink.withValues(alpha: 0.5),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                      BoxShadow(
                        color: AppColors.purple.withValues(alpha: 0.4),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: widget.size * 0.18,
                  left: widget.size * 0.22,
                  child: Container(
                    width: widget.size * 0.22,
                    height: widget.size * 0.14,
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
        );
      },
    );
  }
}
