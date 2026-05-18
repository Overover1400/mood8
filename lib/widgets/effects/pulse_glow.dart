import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Wraps [child] in a single-shot scale + glow animation triggered by
/// [trigger] flipping from `false` → `true`. Used to celebrate a card's
/// completion without inserting an overlay.
class PulseGlow extends StatefulWidget {
  const PulseGlow({
    super.key,
    required this.child,
    required this.trigger,
    this.glowColor,
    this.duration = const Duration(milliseconds: 600),
    this.borderRadius = 20,
  });

  final Widget child;
  final bool trigger;
  final Color? glowColor;
  final Duration duration;
  final double borderRadius;

  @override
  State<PulseGlow> createState() => _PulseGlowState();
}

class _PulseGlowState extends State<PulseGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void didUpdateWidget(covariant PulseGlow old) {
    super.didUpdateWidget(old);
    if (widget.trigger && !old.trigger) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          // 0 → 1 → 0 bell using sin curve.
          final bell = _bell(t);
          final scale = 1.0 + bell * 0.03;
          final glow = bell * 24.0;
          final color = widget.glowColor ?? AppColors.purpleLight;
          return Transform.scale(
            scale: scale,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                boxShadow: glow <= 0
                    ? const []
                    : [
                        BoxShadow(
                          color: color.withValues(alpha: 0.45 * bell),
                          blurRadius: glow,
                        ),
                      ],
              ),
              child: child,
            ),
          );
        },
        child: widget.child,
      ),
    );
  }

  static double _bell(double t) {
    if (t <= 0 || t >= 1) return 0;
    // Smooth ease-in/out bell that peaks at t=0.5.
    final x = (t - 0.5) * 2;
    return 1 - x * x;
  }
}
