import 'package:flutter/material.dart';

class AnimatedNumber extends StatelessWidget {
  const AnimatedNumber({
    super.key,
    required this.value,
    required this.builder,
    this.duration = const Duration(milliseconds: 800),
    this.curve = Curves.easeOutCubic,
    this.fractionDigits = 0,
  });

  final double value;
  final Duration duration;
  final Curve curve;
  final int fractionDigits;
  final Widget Function(BuildContext, String) builder;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: duration,
      curve: curve,
      builder: (context, v, _) {
        final text = v.toStringAsFixed(fractionDigits);
        return builder(context, text);
      },
    );
  }
}
