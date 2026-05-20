import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.orbGradient,
            boxShadow: [
              BoxShadow(
                color: AppColors.pink.withValues(alpha: 0.40),
                blurRadius: 10,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: BrandColors.bgCard(context).withValues(alpha: 0.85),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(18),
            ),
            border: Border.all(
              color: AppColors.purple.withValues(alpha: 0.18),
            ),
          ),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    _dot(_alpha(t, i)),
                    if (i < 2) const SizedBox(width: 5),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  static double _alpha(double t, int i) {
    final shift = (t - i * 0.18) % 1.0;
    final norm = shift < 0 ? shift + 1.0 : shift;
    final pulse = 0.5 - 0.5 * (1 - 2 * (norm - 0.5).abs());
    return 0.35 + 0.65 * pulse;
  }

  Widget _dot(double alpha) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.pinkLight.withValues(alpha: alpha),
      ),
    );
  }
}
