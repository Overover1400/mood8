import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class GlowSlider extends StatelessWidget {
  const GlowSlider({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
    this.icon,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  /// Fires when the user lifts their finger. Home uses this to start
  /// the 2-second auto-save countdown — `onChanged` just paints live.
  final ValueChanged<double>? onChangeEnd;
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
              Icon(icon, size: 16, color: BrandColors.inkSoft(context)),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                color: BrandColors.inkSoft(context),
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
                    style: GoogleFonts.bricolageGrotesque(
                      color: BrandColors.ink(context),
                      fontSize: 22,
                      height: 1.0,
                    ),
                  ),
                  TextSpan(
                    text: ' /10',
                    style: TextStyle(
                      color: BrandColors.inkDim(context),
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
            inactiveTrackColor: BrandColors.bgCard(context),
            thumbColor: Colors.white,
          ),
          child: Slider(
            value: value,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
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

/// Compact variant — single horizontal row of `icon · label · slim
/// slider · value`. Used on Home so the "How are you, right now?"
/// section fits three controls into about a third of the vertical
/// space the full [GlowSlider] needs. Same gradient track, same auto-
/// save semantics (onChangeEnd), just thinner.
///
/// **Why this is stateful.** Earlier versions painted `value` straight
/// off the parent prop. During a fast drag, the home screen's other
/// rebuilders (three ValueListenableBuilders watching mood/routines/
/// habits boxes, plus the flutter_animate wrappers) competed with the
/// slider's setState and the displayed number sometimes lagged the
/// thumb position by a frame or two — the user saw the number "jump
/// to a wrong value during drag and snap back on release". Tracking
/// the live drag value internally and only syncing to the parent for
/// persistence decouples the displayed number from any external
/// rebuild cadence: it tracks the slider's onChanged callback at
/// frame rate, period.
class CompactGlowSlider extends StatefulWidget {
  const CompactGlowSlider({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
  });

  final String label;
  final IconData icon;
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  @override
  State<CompactGlowSlider> createState() => _CompactGlowSliderState();
}

class _CompactGlowSliderState extends State<CompactGlowSlider> {
  /// Live drag value. Null when not dragging — then the displayed
  /// value falls back to the parent-controlled [widget.value].
  double? _liveValue;

  @override
  void didUpdateWidget(covariant CompactGlowSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The parent pushed a new value (e.g. hydration from today's
    // entry, or a reset). If we're not currently dragging, accept it.
    // If we are dragging, ignore — the user's finger is the source
    // of truth until they lift it.
    if (_liveValue != null && widget.value != oldWidget.value) {
      // Parent value changed while we were dragging — could happen
      // from an external sync. Don't snap mid-drag; let the drag
      // finish, then the next rebuild will pick up the new prop.
    }
  }

  double get _displayValue => _liveValue ?? widget.value;

  void _handleChanged(double v) {
    setState(() => _liveValue = v);
    widget.onChanged(v);
  }

  void _handleChangeEnd(double v) {
    setState(() => _liveValue = null);
    widget.onChangeEnd?.call(v);
  }

  @override
  Widget build(BuildContext context) {
    final v = _displayValue;
    final score = (v * 10).toStringAsFixed(1);
    return SizedBox(
      height: 38,
      child: Row(
        children: [
          Icon(widget.icon, size: 17, color: BrandColors.inkSoft(context)),
          const SizedBox(width: 8),
          SizedBox(
            width: 58,
            child: Text(
              widget.label,
              style: TextStyle(
                color: BrandColors.inkSoft(context),
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 7,
                trackShape: const _GradientTrackShape(),
                thumbShape: const _CompactThumbShape(),
                overlayShape: SliderComponentShape.noOverlay,
                activeTrackColor: AppColors.pink,
                inactiveTrackColor: BrandColors.bgCard(context),
                thumbColor: Colors.white,
              ),
              child: Slider(
                // IMPORTANT: paint the thumb from the live drag value
                // too, not the parent prop. Otherwise the thumb lags
                // the displayed score during fast drags on slower
                // devices — same root cause as the value-text bug.
                value: v,
                onChanged: _handleChanged,
                onChangeEnd: _handleChangeEnd,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Bumped from 42 → 54 px. "10.0 /10" needs ~52 px at this
          // font size; the old 42 was just under the threshold and
          // clipped the " /10" suffix at high values, which
          // contributed to the "wrong value" misread.
          SizedBox(
            width: 54,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: score,
                    style: GoogleFonts.bricolageGrotesque(
                      color: BrandColors.ink(context),
                      fontSize: 17,
                      height: 1.0,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(
                    text: ' /10',
                    style: TextStyle(
                      color: BrandColors.inkDim(context),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.right,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactThumbShape extends SliderComponentShape {
  const _CompactThumbShape();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size(20, 20);

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
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(center, 11, glow);
    final ring = Paint()
      ..shader = AppColors.buttonGradient.createShader(
        Rect.fromCircle(center: center, radius: 10),
      );
    canvas.drawCircle(center, 10, ring);
    final inner = Paint()..color = Colors.white;
    canvas.drawCircle(center, 5.5, inner);
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
