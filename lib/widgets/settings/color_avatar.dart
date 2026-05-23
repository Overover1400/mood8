import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';

class ColorAvatar extends StatelessWidget {
  const ColorAvatar({
    super.key,
    required this.name,
    this.size = 36,
    this.onTap,
  });

  final String name;
  final double size;
  final VoidCallback? onTap;

  String get _initials {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.characters.first.toUpperCase();
    }
    final first = parts.first.characters.first;
    final last = parts.last.characters.first;
    return '$first$last'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.buttonGradient,
        boxShadow: [
          BoxShadow(
            color: AppColors.pink.withValues(alpha: 0.40),
            blurRadius: size * 0.4,
            offset: Offset(0, size * 0.15),
          ),
        ],
      ),
      child: Text(
        _initials,
        style: GoogleFonts.bricolageGrotesque(
          color: Colors.white,
          fontSize: size * 0.45,
          height: 1.0,
        ),
      ),
    );
    if (onTap == null) return avatar;
    return GestureDetector(onTap: onTap, child: avatar);
  }
}
