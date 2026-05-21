import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';

/// Small pill showing a user's profile_badge (and optional creator_score).
/// Public API kept stable from Build 2; Build 3 replaces the inline shield
/// icon with a proper [PrestigeBadgeArt] painter so each tier has its own
/// emblem.
class UserBadgeChip extends StatelessWidget {
  const UserBadgeChip({
    super.key,
    required this.badge,
    this.creatorScore,
    this.compact = false,
  });

  final String? badge;
  final int? creatorScore;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final hasBadge = badge != null && badge!.isNotEmpty;
    final hasScore = creatorScore != null && creatorScore! > 0;
    if (!hasBadge && !hasScore) return const SizedBox.shrink();
    final accent = prestigeAccentFor(badge);
    final emblemSize = compact ? 16.0 : 20.0;
    return Container(
      padding: EdgeInsets.fromLTRB(
        compact ? 6 : 8,
        compact ? 2 : 3,
        compact ? 10 : 12,
        compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.30),
            accent.withValues(alpha: 0.14),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: accent.withValues(alpha: 0.60),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasBadge)
            PrestigeBadgeArt(badge: badge!, size: emblemSize),
          if (hasBadge) SizedBox(width: compact ? 5 : 7),
          if (hasBadge)
            Text(
              badge!,
              style: GoogleFonts.instrumentSerif(
                color: BrandColors.ink(context),
                fontStyle: FontStyle.italic,
                fontSize: compact ? 12 : 14,
                height: 1.0,
              ),
            ),
          if (hasScore) ...[
            SizedBox(width: hasBadge ? 6 : 4),
            Text(
              '· ${creatorScore!}',
              style: TextStyle(
                color: BrandColors.inkSoft(context),
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Just the emblem, no chip frame. Used in the legend screen and the
/// prestige-unlock celebration.
class PrestigeBadgeArt extends StatelessWidget {
  const PrestigeBadgeArt({
    super.key,
    required this.badge,
    required this.size,
  });
  final String badge;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PrestigePainter(tier: _tierFromName(badge)),
        isComplex: true,
        willChange: false,
      ),
    );
  }
}

/// Tier-specific accent color. Used to tint the chip frame even when
/// no badge art is shown (legacy callers that pass just a score).
Color prestigeAccentFor(String? badge) {
  switch (_tierFromName(badge ?? '')) {
    case 0:
      return const Color(0xFF9CA3AF); // silver-cool — Initiate
    case 1:
      return AppColors.blueAccent; // Challenger
    case 2:
      return AppColors.purple; // Veteran
    case 3:
      return AppColors.purpleLight; // Champion
    case 4:
      return AppColors.pink; // Warlord
    case 5:
      return AppColors.pinkLight; // Mythic
    case 6:
      return const Color(0xFFFFE08A); // Immortal — radiant gold
    default:
      return AppColors.inkDim;
  }
}

const List<String> prestigeBadgeNames = [
  'Initiate',
  'Challenger',
  'Veteran',
  'Champion',
  'Warlord',
  'Mythic',
  'Immortal',
];

/// Thresholds — completed-challenge count required for each badge.
const List<int> prestigeBadgeThresholds = [1, 3, 5, 10, 20, 35, 50];

int _tierFromName(String name) {
  switch (name) {
    case 'Initiate':
      return 0;
    case 'Challenger':
      return 1;
    case 'Veteran':
      return 2;
    case 'Champion':
      return 3;
    case 'Warlord':
      return 4;
    case 'Mythic':
      return 5;
    case 'Immortal':
      return 6;
    default:
      return -1;
  }
}

// ──────────────────────────────────────────────────────────────────
// Painter
// ──────────────────────────────────────────────────────────────────

class _PrestigePainter extends CustomPainter {
  _PrestigePainter({required this.tier});
  final int tier;

  @override
  void paint(Canvas canvas, Size size) {
    if (tier < 0) return;
    switch (tier) {
      case 0:
        _paintInitiate(canvas, size);
        break;
      case 1:
        _paintChallenger(canvas, size);
        break;
      case 2:
        _paintVeteran(canvas, size);
        break;
      case 3:
        _paintChampion(canvas, size);
        break;
      case 4:
        _paintWarlord(canvas, size);
        break;
      case 5:
        _paintMythic(canvas, size);
        break;
      case 6:
        _paintImmortal(canvas, size);
        break;
    }
  }

  // 0 — Initiate: simple hexagonal badge with a center dot. Modest.
  void _paintInitiate(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = size.center(Offset.zero);
    final hex = _hexagonPath(c, s * 0.42);
    canvas.drawPath(
      hex,
      Paint()
        ..shader = LinearGradient(
          colors: const [Color(0xFFD1D5DB), Color(0xFF6B7280)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromCircle(center: c, radius: s / 2)),
    );
    canvas.drawPath(
      hex,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.04,
    );
    canvas.drawCircle(c, s * 0.07, Paint()..color = Colors.white);
  }

  // 1 — Challenger: crossed swords on a small shield. Sharp + active.
  void _paintChallenger(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = size.center(Offset.zero);
    final shield = _shieldPath(c, s * 0.36, s * 0.46);
    canvas.drawPath(
      shield,
      Paint()
        ..shader = LinearGradient(
          colors: [AppColors.blueAccent, AppColors.purple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromCircle(center: c, radius: s / 2)),
    );
    canvas.drawPath(
      shield,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.035,
    );
    // Two crossed swords — diagonal lines + small guard rectangles.
    final swordPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = s * 0.05
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(c.dx - s * 0.16, c.dy - s * 0.16),
      Offset(c.dx + s * 0.16, c.dy + s * 0.16),
      swordPaint,
    );
    canvas.drawLine(
      Offset(c.dx + s * 0.16, c.dy - s * 0.16),
      Offset(c.dx - s * 0.16, c.dy + s * 0.16),
      swordPaint,
    );
  }

  // 2 — Veteran: shield with laurel border + single chevron inside.
  void _paintVeteran(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = size.center(Offset.zero);
    final shield = _shieldPath(c, s * 0.40, s * 0.50);
    canvas.drawPath(
      shield,
      Paint()
        ..shader = LinearGradient(
          colors: [AppColors.purple, const Color(0xFF6B21A8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromCircle(center: c, radius: s / 2)),
    );
    canvas.drawPath(
      shield,
      Paint()
        ..color = const Color(0xFFFFE08A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.045,
    );
    // Inner chevron — single
    final p = Paint()
      ..color = const Color(0xFFFFE08A)
      ..strokeWidth = s * 0.08
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final w = s * 0.34;
    final h = s * 0.12;
    final cy = c.dy + s * 0.08;
    final path = Path()
      ..moveTo(c.dx - w / 2, cy)
      ..lineTo(c.dx, cy - h)
      ..lineTo(c.dx + w / 2, cy);
    canvas.drawPath(path, p);
  }

  // 3 — Champion: laurel wreath with a star center. Classic victory.
  void _paintChampion(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = size.center(Offset.zero);
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [AppColors.purpleLight, AppColors.pink],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: c, radius: s / 2));
    _drawLaurel(canvas, c, s * 0.40, paint, side: -1, leaves: 6);
    _drawLaurel(canvas, c, s * 0.40, paint, side: 1, leaves: 6);
    _drawStar(canvas, c, s * 0.22, paint);
  }

  // 4 — Warlord: angular hex crest with crossed axes/sceptres.
  void _paintWarlord(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = size.center(Offset.zero);
    final crest = _diamondPath(c, s * 0.40);
    canvas.drawPath(
      crest,
      Paint()
        ..shader = LinearGradient(
          colors: [AppColors.pink, const Color(0xFF8B1538)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromCircle(center: c, radius: s / 2)),
    );
    canvas.drawPath(
      crest,
      Paint()
        ..color = const Color(0xFFFFD9A6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.04,
    );
    // Crossed angular sceptres — heavy lines with small disks at ends.
    final p = Paint()
      ..color = const Color(0xFFFFD9A6)
      ..strokeWidth = s * 0.05
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(c.dx - s * 0.18, c.dy - s * 0.04),
      Offset(c.dx + s * 0.18, c.dy + s * 0.04),
      p,
    );
    canvas.drawLine(
      Offset(c.dx + s * 0.18, c.dy - s * 0.04),
      Offset(c.dx - s * 0.18, c.dy + s * 0.04),
      p,
    );
    final disk = Paint()..color = const Color(0xFFFFE08A);
    for (final dx in [-0.18, 0.18]) {
      canvas.drawCircle(
          Offset(c.dx + s * dx, c.dy - s * 0.04), s * 0.05, disk);
      canvas.drawCircle(
          Offset(c.dx + s * dx, c.dy + s * 0.04), s * 0.05, disk);
    }
  }

  // 5 — Mythic: phoenix/flame shape with motion-implying glow.
  void _paintMythic(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = size.center(Offset.zero);
    // Glow
    canvas.drawCircle(
      c,
      s * 0.45,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.pinkLight.withValues(alpha: 0.55),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: c, radius: s * 0.45)),
    );
    // Flame path
    final flame = Path()
      ..moveTo(c.dx, c.dy - s * 0.30)
      ..cubicTo(
        c.dx + s * 0.22, c.dy - s * 0.12,
        c.dx + s * 0.18, c.dy + s * 0.10,
        c.dx + s * 0.06, c.dy + s * 0.28,
      )
      ..cubicTo(
        c.dx + s * 0.16, c.dy + s * 0.12,
        c.dx + s * 0.04, c.dy + s * 0.04,
        c.dx, c.dy - s * 0.04,
      )
      ..cubicTo(
        c.dx - s * 0.04, c.dy + s * 0.04,
        c.dx - s * 0.16, c.dy + s * 0.12,
        c.dx - s * 0.06, c.dy + s * 0.28,
      )
      ..cubicTo(
        c.dx - s * 0.18, c.dy + s * 0.10,
        c.dx - s * 0.22, c.dy - s * 0.12,
        c.dx, c.dy - s * 0.30,
      )
      ..close();
    canvas.drawPath(
      flame,
      Paint()
        ..shader = LinearGradient(
          colors: [Colors.white, AppColors.pinkLight, AppColors.pink],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromCircle(center: c, radius: s / 2)),
    );
  }

  // 6 — Immortal: radiant sun with crown — spectacular.
  void _paintImmortal(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = size.center(Offset.zero);
    // Outer rays
    final rayPaint = Paint()
      ..color = const Color(0xFFFFE08A)
      ..strokeWidth = s * 0.05
      ..strokeCap = StrokeCap.round;
    const rayCount = 12;
    for (var i = 0; i < rayCount; i++) {
      final a = -math.pi / 2 + i * (2 * math.pi / rayCount);
      final inner = s * 0.30;
      final outer = s * 0.46;
      canvas.drawLine(
        Offset(c.dx + math.cos(a) * inner, c.dy + math.sin(a) * inner),
        Offset(c.dx + math.cos(a) * outer, c.dy + math.sin(a) * outer),
        rayPaint,
      );
    }
    // Sun disk
    canvas.drawCircle(
      c,
      s * 0.26,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white,
            const Color(0xFFFFE08A),
            const Color(0xFFE0A82E),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: s * 0.26)),
    );
    // Crown atop
    final crownPaint = Paint()..color = const Color(0xFFFFE08A);
    final crownPath = Path()
      ..moveTo(c.dx - s * 0.18, c.dy - s * 0.12)
      ..lineTo(c.dx - s * 0.10, c.dy - s * 0.22)
      ..lineTo(c.dx, c.dy - s * 0.16)
      ..lineTo(c.dx + s * 0.10, c.dy - s * 0.22)
      ..lineTo(c.dx + s * 0.18, c.dy - s * 0.12)
      ..lineTo(c.dx + s * 0.18, c.dy - s * 0.06)
      ..lineTo(c.dx - s * 0.18, c.dy - s * 0.06)
      ..close();
    canvas.drawPath(crownPath, crownPaint);
  }

  // ─── Shared shape helpers ─────────────────────────────────────────

  Path _hexagonPath(Offset c, double radius) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final a = -math.pi / 2 + i * (math.pi / 3);
      final x = c.dx + radius * math.cos(a);
      final y = c.dy + radius * math.sin(a);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  Path _shieldPath(Offset c, double halfWidth, double halfHeight) {
    final left = c.dx - halfWidth;
    final right = c.dx + halfWidth;
    final top = c.dy - halfHeight;
    final bottom = c.dy + halfHeight;
    final mid = c.dy + halfHeight * 0.45;
    return Path()
      ..moveTo(left, top + halfHeight * 0.15)
      ..lineTo(left, mid)
      ..quadraticBezierTo(c.dx, bottom, right, mid)
      ..lineTo(right, top + halfHeight * 0.15)
      ..quadraticBezierTo(
          c.dx, top - halfHeight * 0.08, left, top + halfHeight * 0.15)
      ..close();
  }

  Path _diamondPath(Offset c, double r) {
    return Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + r * 0.85, c.dy)
      ..lineTo(c.dx, c.dy + r)
      ..lineTo(c.dx - r * 0.85, c.dy)
      ..close();
  }

  void _drawLaurel(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint, {
    required int side,
    int leaves = 6,
  }) {
    for (var i = 0; i < leaves; i++) {
      final t = i / (leaves - 1);
      final baseAngle = math.pi * (1 - 0.55 * t);
      final angle = side > 0 ? -baseAngle + math.pi : baseAngle;
      final cx = center.dx + radius * math.cos(angle);
      final cy = center.dy - radius * math.sin(angle);
      _drawLeaf(canvas, Offset(cx, cy), radius * 0.35, angle, paint, side: side);
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
    canvas.save();
    canvas.translate(c.dx, c.dy);
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
    Offset c,
    double outerRadius,
    Paint paint,
  ) {
    final path = Path();
    const points = 5;
    final inner = outerRadius * 0.42;
    for (var i = 0; i < points * 2; i++) {
      final r = i.isEven ? outerRadius : inner;
      final a = -math.pi / 2 + i * math.pi / points;
      final x = c.dx + r * math.cos(a);
      final y = c.dy + r * math.sin(a);
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
  bool shouldRepaint(covariant _PrestigePainter old) => old.tier != tier;
}
