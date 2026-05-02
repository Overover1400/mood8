import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class GlowSlider extends StatelessWidget {
  const GlowSlider({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.icon,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final score = (value * 10).toStringAsFixed(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: AppColors.inkSoft),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: const TextStyle(
                color: AppColors.inkSoft,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: score,
                    style: GoogleFonts.instrumentSerif(
                      color: AppColors.ink,
                      fontStyle: FontStyle.italic,
                      fontSize: 22,
                      height: 1.0,
                    ),
                  ),
                  TextSpan(
                    text: ' /10',
                    style: TextStyle(
                      color: AppColors.inkDim,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 8,
            trackShape: const _GradientTrackShape(),
            thumbShape: const _GlowThumbShape(),
            overlayShape: SliderComponentShape.noOverlay,
            activeTrackColor: AppColors.pink,
            inactiveTrackColor: AppColors.bgCard,
            thumbColor: Colors.white,
          ),
          child: Slider(
            value: value,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _GradientTrackShape extends SliderTrackShape {
  const _GradientTrackShape();

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 8.0;
    final trackTop =
        offset.dy + (parentBox.size.height - trackHeight) / 2;
    return Rect.fromLTWH(
      offset.dx,
      trackTop,
      parentBox.size.width,
      trackHeight,
    );
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 0,
  }) {
    final canvas = context.canvas;
    final trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
    );

    final inactiveRRect = RRect.fromRectAndRadius(
      trackRect,
      const Radius.circular(20),
    );
    final inactivePaint = Paint()
      ..color = AppColors.bgCard.withValues(alpha: 0.9);
    canvas.drawRRect(inactiveRRect, inactivePaint);

    final activeRect = Rect.fromLTRB(
      trackRect.left,
      trackRect.top,
      thumbCenter.dx,
      trackRect.bottom,
    );
    if (activeRect.width > 1) {
      final activePaint = Paint()
        ..shader = AppColors.buttonGradient.createShader(activeRect);
      canvas.drawRRect(
        RRect.fromRectAndRadius(activeRect, const Radius.circular(20)),
        activePaint,
      );

      // soft glow above active track
      final glowPaint = Paint()
        ..shader = AppColors.buttonGradient.createShader(activeRect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(activeRect, const Radius.circular(20)),
        glowPaint,
      );
    }
  }
}

class _GlowThumbShape extends SliderComponentShape {
  const _GlowThumbShape();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size(22, 22);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;

    final glow = Paint()
      ..color = AppColors.pinkLight.withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(center, 14, glow);

    final ring = Paint()
      ..shader = AppColors.buttonGradient.createShader(
        Rect.fromCircle(center: center, radius: 12),
      );
    canvas.drawCircle(center, 12, ring);

    final inner = Paint()..color = Colors.white;
    canvas.drawCircle(center, 7, inner);
  }
}
