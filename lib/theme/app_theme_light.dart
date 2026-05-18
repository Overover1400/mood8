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
    );
  }

  static TextTheme _buildTextTheme(TextTheme base) {
    final display = GoogleFonts.instrumentSerifTextTheme(base);
    final body = GoogleFonts.plusJakartaSansTextTheme(base);

    return base.copyWith(
      displayLarge: display.displayLarge?.copyWith(
        color: AppLightColors.ink,
        fontStyle: FontStyle.italic,
        fontSize: 56,
        height: 1.05,
      ),
      displayMedium: display.displayMedium?.copyWith(
        color: AppLightColors.ink,
        fontStyle: FontStyle.italic,
        fontSize: 44,
        height: 1.05,
      ),
      displaySmall: display.displaySmall?.copyWith(
        color: AppLightColors.ink,
        fontStyle: FontStyle.italic,
        fontSize: 32,
        height: 1.1,
      ),
      headlineLarge: display.headlineLarge?.copyWith(
        color: AppLightColors.ink,
        fontStyle: FontStyle.italic,
        fontSize: 28,
        height: 1.15,
      ),
      headlineMedium: display.headlineMedium?.copyWith(
        color: AppLightColors.ink,
        fontStyle: FontStyle.italic,
        fontSize: 24,
      ),
      headlineSmall: display.headlineSmall?.copyWith(
        color: AppLightColors.ink,
        fontStyle: FontStyle.italic,
        fontSize: 20,
      ),
      titleLarge: body.titleLarge?.copyWith(
        color: AppLightColors.ink,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: body.titleMedium?.copyWith(
        color: AppLightColors.ink,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: body.titleSmall?.copyWith(
        color: AppLightColors.inkSoft,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
      bodyLarge: body.bodyLarge?.copyWith(color: AppLightColors.ink),
      bodyMedium: body.bodyMedium?.copyWith(color: AppLightColors.inkSoft),
      bodySmall: body.bodySmall?.copyWith(color: AppLightColors.inkDim),
      labelLarge: body.labelLarge?.copyWith(
        color: AppLightColors.ink,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: body.labelMedium?.copyWith(color: AppLightColors.inkSoft),
      labelSmall: body.labelSmall?.copyWith(
        color: AppLightColors.inkDim,
        letterSpacing: 1.2,
      ),
    );
  }
}
