import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_theme.dart';

/// Light-mode palette + ThemeData. The brand colors (purple/pink/blue) stay
/// the same — only surfaces and text colors invert. Most existing widgets
/// still reference `AppColors.*` static colors directly, so they keep the
/// dark look in light mode for now; the scaffold/AppBar/Material surfaces
/// adapt automatically via Theme.of(context).
///
/// To fully theme an existing widget, swap `AppColors.bgDeep` →
/// `AppLightColors.bgDeep(context)` etc.
class AppLightColors {
  static const bgDeep = Color(0xFFFAF5FF);
  static const bg = Color(0xFFF3E8FF);
  static const bgCard = Color(0xFFFFFFFF);
  static const ink = Color(0xFF1F1338);
  static const inkSoft = Color(0xFF4C1D95);
  static const inkDim = Color(0xFF6B5680);
  static const inkFaint = Color(0xFFA78BB8);
}

class AppLightTheme {
  static ThemeData get theme {
    final base = ThemeData.light(useMaterial3: true);
    final textTheme = _buildTextTheme(base.textTheme);

    return base.copyWith(
      scaffoldBackgroundColor: AppLightColors.bgDeep,
      colorScheme: const ColorScheme.light(
        surface: AppLightColors.bgDeep,
        primary: AppColors.purple,
        secondary: AppColors.pink,
        tertiary: AppColors.blueAccent,
        onSurface: AppLightColors.ink,
      ),
      cardColor: AppLightColors.bgCard,
      dividerColor: AppLightColors.inkFaint.withValues(alpha: 0.2),
      textTheme: textTheme,
      iconTheme: const IconThemeData(color: AppLightColors.inkSoft),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppLightColors.ink,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppLightColors.bgCard,
        contentTextStyle: const TextStyle(
          color: AppLightColors.ink,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
        actionTextColor: AppColors.purple,
        behavior: SnackBarBehavior.floating,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  static TextTheme _buildTextTheme(TextTheme base) {
    final t = GoogleFonts.bricolageGrotesqueTextTheme(base);
    return base.copyWith(
      displayLarge: t.displayLarge?.copyWith(
        color: AppLightColors.ink,
        fontWeight: FontWeight.w800,
        fontSize: 56,
        height: 1.0,
        letterSpacing: -1.0,
      ),
      displayMedium: t.displayMedium?.copyWith(
        color: AppLightColors.ink,
        fontWeight: FontWeight.w800,
        fontSize: 44,
        height: 1.0,
        letterSpacing: -0.6,
      ),
      displaySmall: t.displaySmall?.copyWith(
        color: AppLightColors.ink,
        fontWeight: FontWeight.w800,
        fontSize: 32,
        height: 1.05,
        letterSpacing: -0.4,
      ),
      headlineLarge: t.headlineLarge?.copyWith(
        color: AppLightColors.ink,
        fontWeight: FontWeight.w800,
        fontSize: 28,
        height: 1.1,
        letterSpacing: -0.3,
      ),
      headlineMedium: t.headlineMedium?.copyWith(
        color: AppLightColors.ink,
        fontWeight: FontWeight.w700,
        fontSize: 24,
        letterSpacing: -0.2,
      ),
      headlineSmall: t.headlineSmall?.copyWith(
        color: AppLightColors.ink,
        fontWeight: FontWeight.w700,
        fontSize: 20,
        letterSpacing: -0.1,
      ),
      titleLarge: t.titleLarge?.copyWith(
        color: AppLightColors.ink,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: t.titleMedium?.copyWith(
        color: AppLightColors.ink,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: t.titleSmall?.copyWith(
        color: AppLightColors.inkSoft,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
      bodyLarge: t.bodyLarge?.copyWith(
        color: AppLightColors.ink,
        fontWeight: FontWeight.w500,
      ),
      bodyMedium: t.bodyMedium?.copyWith(
        color: AppLightColors.inkSoft,
        fontWeight: FontWeight.w500,
      ),
      bodySmall: t.bodySmall?.copyWith(
        color: AppLightColors.inkDim,
        fontWeight: FontWeight.w500,
      ),
      labelLarge: t.labelLarge?.copyWith(
        color: AppLightColors.ink,
        fontWeight: FontWeight.w700,
      ),
      labelMedium: t.labelMedium?.copyWith(
        color: AppLightColors.inkSoft,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: t.labelSmall?.copyWith(
        color: AppLightColors.inkDim,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}
