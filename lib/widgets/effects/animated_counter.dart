import 'package:flutter/material.dart';

/// Smoothly tweens between integer values when [value] changes. Adds a tiny
/// scale bump on every change so the user notices the increment.
class AnimatedCounter extends StatefulWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    this.duration = const Duration(milliseconds: 700),
    this.style,
    this.textAlign,
  });

  final int value;
  final Duration duration;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter> {
  late int _displayed = widget.value;

  @override
  void didUpdateWidget(covariant AnimatedCounter old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _animate(old.value, widget.value);
    }
  }

  void _animate(int from, int to) {
    setState(() => _displayed = to);
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(_displayed),
      tween: Tween<double>(begin: 0, end: 1),
      duration: widget.duration,
      curve: Curves.easeOutQuart,
      builder: (context, t, _) {
        // Bell-shaped scale bump that peaks early then settles.
        final bump = t < 0.4 ? (t / 0.4) : (1 - (t - 0.4) / 0.6);
        final scale = 1.0 + 0.15 * bump.clamp(0.0, 1.0);
        return Transform.scale(
          scale: scale,
          alignment: Alignment.center,
          child: Text(
            '$_displayed',
            textAlign: widget.textAlign,
            style: widget.style,
          ),
        );
      },
    );
  }
}
