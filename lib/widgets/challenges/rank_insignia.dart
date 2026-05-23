import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';

/// Public API kept stable from Build 2 — same constructor, same fields,
/// same uses sites. Build 3 swaps the placeholder gradient + chevron
/// for a proper military insignia per tier (0–10) painted directly to
/// canvas so it stays crisp at any [size].
class RankInsignia extends StatelessWidget {
  const RankInsignia({
    super.key,
    required this.rankIndex,
    required this.rankName,
    this.size = 18,
    this.showLabel = true,
  });

  /// 0-based index into the rank ladder. Out-of-range values are
  /// clamped — the painter falls back to the closest tier.
  final int rankIndex;
  final String rankName;
  final double size;

  /// When false, only the medallion is drawn — useful for the
  /// participant grid where the name is shown elsewhere.
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final medallion = RankInsigniaArt(
      rankIndex: rankIndex,
      size: size,
    );
    if (!showLabel) return medallion;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        medallion,
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            rankName,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.bricolageGrotesque(
              color: BrandColors.ink(context),
              fontSize: size * 0.78,
            ),
          ),
        ),
      ],
    );
  }
}

/// Just the medallion — no name. Use this when you only want the art
/// (e.g. legend tiles, the rank-up dialog hero).
class RankInsigniaArt extends StatelessWidget {
  const RankInsigniaArt({
    super.key,
    required this.rankIndex,
    required this.size,
  });

  final int rankIndex;
  final double size;

  @override
  Widget build(BuildContext context) {
    final clamped = rankIndex.clamp(0, _kRankPaletteCount - 1);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RankInsigniaPainter(rankIndex: clamped),
        isComplex: true,
        willChange: false,
      ),
    );
  }
}

const int _kRankPaletteCount = 11;

class _RankInsigniaPainter extends CustomPainter {
  _RankInsigniaPainter({required this.rankIndex});
  final int rankIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final palette = _paletteFor(rankIndex);
    _paintMedallion(canvas, size, palette);
    switch (rankIndex) {
      case 0:
        _paintRecruit(canvas, size, palette);
        break;
      case 1:
        _paintChevrons(canvas, size, palette, count: 1);
        break;
      case 2:
        _paintChevrons(canvas, size, palette, count: 2);
        break;
      case 3:
        _paintChevrons(canvas, size, palette, count: 3);
        break;
      case 4:
        _paintBars(canvas, size, palette, count: 1);
        break;
      case 5:
        _paintBars(canvas, size, palette, count: 2);
        break;
      case 6:
        _paintStars(canvas, size, palette, count: 1);
        break;
      case 7:
        _paintColonelEagle(canvas, size, palette);
        break;
      case 8:
        _paintGeneralStars(canvas, size, palette);
        break;
      case 9:
        _paintCrown(canvas, size, palette);
        break;
      case 10:
        _paintLegendLaurel(canvas, size, palette);
        break;
    }
  }

  // ─── Medallion background ────────────────────────────────────────

  void _paintMedallion(Canvas canvas, Size size, _Palette p) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final rect = Rect.fromCircle(center: center, radius: r);

    // Outer glow for high tiers.
    if (rankIndex >= 9) {
      final glowR = r * 1.2;
      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [p.glow.withValues(alpha: 0.55), Colors.transparent],
        ).createShader(Rect.fromCircle(center: center, radius: glowR))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.18);
      canvas.drawCircle(center, glowR, glowPaint);
    }

    // Body — radial highlight so it reads like brushed metal.
    final bodyPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        radius: 1.1,
        colors: p.body,
        stops: const [0.0, 0.55, 1.0],
      ).createShader(rect);
    canvas.drawCircle(center, r * 0.95, bodyPaint);

    // Inner rim
    final rimPaint = Paint()
      ..color = p.rim
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.06;
    canvas.drawCircle(center, r * 0.92, rimPaint);

    // Top sheen — small white arc highlight for the metallic gleam.
    final sheen = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.40),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5],
      ).createShader(rect)
      ..blendMode = BlendMode.screen;
    canvas.drawCircle(center, r * 0.92, sheen);
  }

  // ─── Glyphs ──────────────────────────────────────────────────────

  void _paintRecruit(Canvas canvas, Size size, _Palette p) {
    // A single small dot — humble starting point.
    final center = size.center(Offset.zero);
    final dot = Paint()..color = p.glyph.withValues(alpha: 0.65);
    canvas.drawCircle(center, size.shortestSide * 0.07, dot);
  }

  void _paintChevrons(
    Canvas canvas,
    Size size,
    _Palette p, {
    required int count,
  }) {
    final s = size.shortestSide;
    final center = size.center(Offset.zero);
    final stroke = s * 0.09;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [p.glyphHighlight, p.glyph],
      ).createShader(Rect.fromCircle(center: center, radius: s / 2))
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final chevronW = s * 0.50;
    final chevronH = s * 0.16;
    final gap = s * 0.13;
    // Vertically center the stack of chevrons.
    final totalH = count * chevronH + (count - 1) * (gap - chevronH);
    final startY = center.dy + totalH / 2;
    for (var i = 0; i < count; i++) {
      final cy = startY - i * gap;
      final path = Path()
        ..moveTo(center.dx - chevronW / 2, cy)
        ..lineTo(center.dx, cy - chevronH)
        ..lineTo(center.dx + chevronW / 2, cy);
      canvas.drawPath(path, paint);
    }
  }

  void _paintBars(
    Canvas canvas,
    Size size,
    _Palette p, {
    required int count,
  }) {
    final s = size.shortestSide;
    final center = size.center(Offset.zero);
    final barH = s * 0.42;
    final barW = s * 0.12;
    final gap = s * 0.06;
    final totalW = count * barW + (count - 1) * gap;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [p.glyphHighlight, p.glyph],
      ).createShader(Rect.fromCenter(
          center: center, width: totalW, height: barH));
    for (var i = 0; i < count; i++) {
      final x = center.dx - totalW / 2 + i * (barW + gap);
      final rect = Rect.fromLTWH(x, center.dy - barH / 2, barW, barH);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(s * 0.025)),
        paint,
      );
    }
  }

  void _paintStars(
    Canvas canvas,
    Size size,
    _Palette p, {
    required int count,
  }) {
    final s = size.shortestSide;
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [p.glyphHighlight, p.glyph],
      ).createShader(Rect.fromCircle(center: center, radius: s / 2));
    if (count == 1) {
      _drawStar(canvas, center, s * 0.24, paint);
      return;
    }
    // Multi-star — horizontal row.
    final starR = s * 0.16;
    final gap = s * 0.06;
    final totalW = count * starR * 2 + (count - 1) * gap;
    for (var i = 0; i < count; i++) {
      final cx = center.dx - totalW / 2 + starR + i * (starR * 2 + gap);
      _drawStar(canvas, Offset(cx, center.dy), starR, paint);
    }
  }

  void _paintColonelEagle(Canvas canvas, Size size, _Palette p) {
    // Two stars stacked over a horizontal bar — a "promoted" feel.
    final s = size.shortestSide;
    final center = size.center(Offset.zero);
    final starR = s * 0.13;
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [p.glyphHighlight, p.glyph],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: center, radius: s / 2));
    _drawStar(canvas,
        Offset(center.dx - s * 0.16, center.dy - s * 0.06), starR, paint);
    _drawStar(canvas,
        Offset(center.dx + s * 0.16, center.dy - s * 0.06), starR, paint);
    // Bar beneath
    final barW = s * 0.46;
    final barH = s * 0.07;
    final barRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy + s * 0.18),
      width: barW,
      height: barH,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(barRect, Radius.circular(s * 0.02)),
      paint,
    );
  }

  void _paintGeneralStars(Canvas canvas, Size size, _Palette p) {
    // Four stars in a diamond pattern — visually richer than colonel.
    final s = size.shortestSide;
    final center = size.center(Offset.zero);
    final starR = s * 0.11;
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [p.glyphHighlight, p.glyph],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: center, radius: s / 2));
    final offset = s * 0.20;
    _drawStar(canvas, Offset(center.dx, center.dy - offset), starR, paint);
    _drawStar(canvas, Offset(center.dx, center.dy + offset), starR, paint);
    _drawStar(canvas, Offset(center.dx - offset, center.dy), starR, paint);
    _drawStar(canvas, Offset(center.dx + offset, center.dy), starR, paint);
    // Center smaller star
    _drawStar(canvas, center, starR * 0.6, paint);
  }

  void _paintCrown(Canvas canvas, Size size, _Palette p) {
    final s = size.shortestSide;
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [p.glyphHighlight, p.glyph],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromCircle(center: center, radius: s / 2));

    // Crown base (trapezoid-ish)
    final baseY = center.dy + s * 0.18;
    final baseLeft = center.dx - s * 0.30;
    final baseRight = center.dx + s * 0.30;
    final peakY = center.dy - s * 0.16;
    final dipY = center.dy - s * 0.02;

    final path = Path()
      ..moveTo(baseLeft, baseY)
      ..lineTo(baseLeft + s * 0.04, dipY + s * 0.04)
      ..lineTo(center.dx - s * 0.18, peakY)
      ..lineTo(center.dx - s * 0.10, dipY)
      ..lineTo(center.dx, peakY - s * 0.04) // tallest center spike
      ..lineTo(center.dx + s * 0.10, dipY)
      ..lineTo(center.dx + s * 0.18, peakY)
      ..lineTo(baseRight - s * 0.04, dipY + s * 0.04)
      ..lineTo(baseRight, baseY)
      ..close();
    canvas.drawPath(path, paint);

    // Center jewel — a small star atop the highest spike.
    _drawStar(
        canvas,
        Offset(center.dx, peakY - s * 0.04),
        s * 0.06,
        Paint()..color = AppColors.pinkLight);
    // Side jewels (dots) atop the outer spikes
    final jewelPaint = Paint()..color = AppColors.pinkLight;
    canvas.drawCircle(
        Offset(center.dx - s * 0.18, peakY), s * 0.035, jewelPaint);
    canvas.drawCircle(
        Offset(center.dx + s * 0.18, peakY), s * 0.035, jewelPaint);

    // Base band
    final bandRect = Rect.fromLTWH(
      baseLeft,
      baseY,
      baseRight - baseLeft,
      s * 0.10,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bandRect, Radius.circular(s * 0.02)),
      paint,
    );
  }

  void _paintLegendLaurel(Canvas canvas, Size size, _Palette p) {
    // Glowing center star surrounded by a laurel wreath.
    final s = size.shortestSide;
    final center = size.center(Offset.zero);

    // Inner soft glow
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.pinkLight.withValues(alpha: 0.55),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: s * 0.40));
    canvas.drawCircle(center, s * 0.32, glow);

    // Laurel wreath — pairs of stylized leaf shapes on each side
    final leafPaint = Paint()
      ..shader = LinearGradient(
        colors: [p.glyphHighlight, p.glyph],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: center, radius: s / 2));
    _drawLaurel(canvas, center, s * 0.34, leafPaint, side: -1);
    _drawLaurel(canvas, center, s * 0.34, leafPaint, side: 1);

    // Center star, large
    final starPaint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.white, AppColors.pinkLight],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: center, radius: s * 0.20));
    _drawStar(canvas, center, s * 0.20, starPaint);
  }

  void _drawLaurel(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint, {
    required int side, // -1 left, +1 right
  }) {
    // 5 small leaves arching from bottom-side up over the top.
    const leafCount = 5;
    for (var i = 0; i < leafCount; i++) {
      // Sweep from ~120deg (bottom side) to ~60deg above (top side).
      final t = i / (leafCount - 1);
      final baseAngle = math.pi * (1 - 0.55 * t); // 180° → ~80°
      final angle = side > 0 ? -baseAngle + math.pi : baseAngle;
      final cx = center.dx + radius * math.cos(angle);
      final cy = center.dy - radius * math.sin(angle);
      _drawLeaf(canvas, Offset(cx, cy), radius * 0.40, angle, paint, side: side);
    }
  }

  void _drawLeaf(
    Canvas canvas,
    Offset c,
    double len,
    double angle,
    Paint paint, {
    required int side,
  }) {
    final path = Path();
    // A simple elongated oval leaf, drawn relative to (0,0) then rotated.
    canvas.save();
    canvas.translate(c.dx, c.dy);
    // Rotate so the leaf "points" away from the center along the ring tangent.
    canvas.rotate(angle + (side > 0 ? -math.pi / 2 : math.pi / 2));
    path.moveTo(0, -len / 2);
    path.quadraticBezierTo(len / 3, -len / 6, 0, len / 2);
    path.quadraticBezierTo(-len / 3, -len / 6, 0, -len / 2);
    path.close();
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  void _drawStar(
    Canvas canvas,
    Offset center,
    double outerRadius,
    Paint paint,
  ) {
    final path = Path();
    const points = 5;
    final innerRadius = outerRadius * 0.42;
    for (var i = 0; i < points * 2; i++) {
      final r = i.isEven ? outerRadius : innerRadius;
      final angle = -math.pi / 2 + i * math.pi / points;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _RankInsigniaPainter oldDelegate) =>
      oldDelegate.rankIndex != rankIndex;
}

// ─── Palette per tier ─────────────────────────────────────────────

class _Palette {
  const _Palette({
    required this.body,
    required this.rim,
    required this.glyph,
    required this.glyphHighlight,
    required this.glow,
  });
  final List<Color> body;
  final Color rim;
  final Color glyph;
  final Color glyphHighlight;
  final Color glow;
}

const _bronze = Color(0xFFB87333);
const _bronzeBright = Color(0xFFE8A063);
const _silver = Color(0xFF9CA3AF);
const _silverBright = Color(0xFFE5E7EB);
const _gold = Color(0xFFE0A82E);
const _goldBright = Color(0xFFFFE08A);

_Palette _paletteFor(int rank) {
  // Lower (0–3): muted/bronze
  // Mid (4–6): silver
  // High (7–8): gold
  // Royal (9–10): gold + pink/white glow
  if (rank <= 0) {
    return const _Palette(
      body: [Color(0xFF4B4458), Color(0xFF2F2A40), Color(0xFF221C30)],
      rim: Color(0xFF6B5680),
      glyph: Color(0xFFC9C2D6),
      glyphHighlight: Color(0xFFE9D5FF),
      glow: Color(0x00000000),
    );
  }
  if (rank <= 3) {
    return _Palette(
      body: const [Color(0xFF8C5A2E), _bronze, Color(0xFF6A4220)],
      rim: _bronzeBright,
      glyph: _bronzeBright,
      glyphHighlight: const Color(0xFFFFD9A6),
      glow: const Color(0x00000000),
    );
  }
  if (rank <= 6) {
    return _Palette(
      body: const [Color(0xFFC9CED6), _silver, Color(0xFF6B7280)],
      rim: _silverBright,
      glyph: _silverBright,
      glyphHighlight: Colors.white,
      glow: const Color(0x00000000),
    );
  }
  if (rank <= 8) {
    return _Palette(
      body: const [_goldBright, _gold, Color(0xFFA67520)],
      rim: _goldBright,
      glyph: _goldBright,
      glyphHighlight: Colors.white,
      glow: _gold,
    );
  }
  if (rank == 9) {
    // King/Queen — gold + pink jewels
    return _Palette(
      body: const [_goldBright, _gold, Color(0xFFA67520)],
      rim: _goldBright,
      glyph: _goldBright,
      glyphHighlight: Colors.white,
      glow: AppColors.pinkLight,
    );
  }
  // Legend
  return _Palette(
    body: const [Color(0xFFFFF1B8), _goldBright, _gold],
    rim: Colors.white,
    glyph: const Color(0xFFFFE08A),
    glyphHighlight: Colors.white,
    glow: AppColors.pinkLight,
  );
}
