import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';

/// Compact in-challenge rank pill (Recruit … Legend). Wired now so the
/// data is hooked up; Build 3 swaps the placeholder gradient + chevron
/// for proper military-style insignia art per tier.
class RankInsignia extends StatelessWidget {
  const RankInsignia({
    super.key,
    required this.rankIndex,
    required this.rankName,
    this.size = 18,
  });

  /// 0-based index into the rank ladder (Recruit=0 .. Legend=10).
  final int rankIndex;
  final String rankName;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tier = _tierFor(rankIndex);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: tier.colors,
            ),
            border: Border.all(
              color: tier.border,
              width: 1,
            ),
            boxShadow: rankIndex >= 8
                ? [
                    BoxShadow(
                      color: tier.colors.last.withValues(alpha: 0.55),
                      blurRadius: 6,
                    ),
                  ]
                : null,
          ),
          child: Text(
            _chevronFor(rankIndex),
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.55,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          rankName,
          style: GoogleFonts.instrumentSerif(
            color: BrandColors.ink(context),
            fontStyle: FontStyle.italic,
            fontSize: size * 0.78,
          ),
        ),
      ],
    );
  }

  String _chevronFor(int i) {
    // ASCII placeholder until Build 3's art lands. Higher tiers get
    // more visual weight via more chevrons.
    if (i >= 10) return '★';
    if (i >= 8) return '★';
    if (i >= 5) return '★';
    if (i >= 3) return '▲';
    if (i >= 1) return '▲';
    return '·';
  }

  _Tier _tierFor(int i) {
    if (i >= 10) {
      // Legend
      return const _Tier(
        colors: [Color(0xFFFCD34D), Color(0xFFF59E0B)],
        border: Color(0xFFFCD34D),
      );
    }
    if (i >= 9) {
      // King/Queen
      return _Tier(
        colors: const [Color(0xFFEC4899), Color(0xFFC084FC)],
        border: AppColors.pinkLight,
      );
    }
    if (i >= 8) {
      // General
      return _Tier(
        colors: const [Color(0xFFA855F7), Color(0xFFEC4899)],
        border: AppColors.purpleLight,
      );
    }
    if (i >= 5) {
      // Captain → Colonel
      return _Tier(
        colors: const [Color(0xFFA855F7), Color(0xFF818CF8)],
        border: AppColors.purple,
      );
    }
    if (i >= 3) {
      // Sergeant → Lieutenant
      return const _Tier(
        colors: [Color(0xFF818CF8), Color(0xFF6366F1)],
        border: Color(0xFF818CF8),
      );
    }
    // Recruit, Private, Corporal
    return _Tier(
      colors: [
        AppColors.inkFaint.withValues(alpha: 0.8),
        AppColors.inkDim.withValues(alpha: 0.8),
      ],
      border: AppColors.inkDim,
    );
  }
}

class _Tier {
  const _Tier({required this.colors, required this.border});
  final List<Color> colors;
  final Color border;
}
