import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ConfidenceIndicator extends StatelessWidget {
  const ConfidenceIndicator({
    super.key,
    required this.confidence,
    this.compact = false,
  });

  final double confidence;
  final bool compact;

  String get _label {
    final c = confidence.abs();
    if (c >= 0.7) return 'very strong';
    if (c >= 0.5) return 'strong';
    if (c >= 0.3) return 'moderate';
    return 'weak';
  }

  Color get _tone {
    final c = confidence.abs();
    if (c >= 0.7) return AppColors.pinkLight;
    if (c >= 0.5) return AppColors.pink;
    if (c >= 0.3) return AppColors.purple;
    return AppColors.inkDim;
  }

  @override
  Widget build(BuildContext context) {
    final width = confidence.abs().clamp(0.1, 1.0);
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Container(
                  height: compact ? 5 : 6,
                  color: BrandColors.bg(context).withValues(alpha: 0.7),
                ),
                FractionallySizedBox(
                  widthFactor: width,
                  child: Container(
                    height: compact ? 5 : 6,
                    decoration: BoxDecoration(
                      gradient: AppColors.buttonGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.pink.withValues(alpha: 0.45),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          _label.toUpperCase(),
          style: TextStyle(
            color: _tone,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
          ),
        ),
      ],
    );
  }
}
