import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class WearSlider extends StatelessWidget {
  const WearSlider({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 6,
        trackShape: const _CompactTrackShape(),
        thumbShape: const _CompactThumbShape(),
        overlayShape: SliderComponentShape.noOverlay,
        activeTrackColor: AppColors.pink,
        inactiveTrackColor: AppColors.bgCard,
        thumbColor: Colors.white,
      ),
      child: Slider(
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

class _CompactTrackShape extends SliderTrackShape {
  const _CompactTrackShape();

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 6.0;
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

    final inactivePaint = Paint()
      ..color = AppColors.bgCard.withValues(alpha: 0.9);
    canvas.drawRRect(
      RRect.fromRectAndRadius(trackRect, const Radius.circular(20)),
      inactivePaint,
    );

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
    }
  }
}

class _CompactThumbShape extends SliderComponentShape {
  const _CompactThumbShape();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size(18, 18);

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
      ..color = AppColors.pinkLight.withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(center, 10, glow);

    final ring = Paint()
      ..shader = AppColors.buttonGradient.createShader(
        Rect.fromCircle(center: center, radius: 9),
      );
    canvas.drawCircle(center, 9, ring);

    final inner = Paint()..color = Colors.white;
    canvas.drawCircle(center, 5, inner);
  }
}
