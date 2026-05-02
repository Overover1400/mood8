import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const bgDeep = Color(0xFF0A0612);
  static const bg = Color(0xFF110821);
  static const bgCard = Color(0xFF1F1338);

  static const purple = Color(0xFFA855F7);
  static const purpleLight = Color(0xFFC084FC);
  static const pink = Color(0xFFEC4899);
  static const pinkLight = Color(0xFFF472B6);
  static const blueAccent = Color(0xFF818CF8);

  static const ink = Color(0xFFFAF5FF);
  static const inkSoft = Color(0xFFE9D5FF);
  static const inkDim = Color(0xFFA78BB8);
  static const inkFaint = Color(0xFF6B5680);

  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [purple, pink, pinkLight],
  );

  static const buttonGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [purpleLight, pinkLight, blueAccent],
  );

  static LinearGradient softGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [purple.withValues(alpha: 0.15), pink.withValues(alpha: 0.15)],
  );

  static RadialGradient orbGradient = const RadialGradient(
    center: Alignment(-0.2, -0.3),
    radius: 0.95,
    colors: [
      Color(0xFFF472B6),
      Color(0xFFC084FC),
      Color(0xFFA855F7),
      Color(0xFF6B21A8),
    ],
    stops: [0.0, 0.4, 0.75, 1.0],
  );
}

class AppTheme {
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = _buildTextTheme(base.textTheme);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bgDeep,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.bgDeep,
        primary: AppColors.purple,
        secondary: AppColors.pink,
        tertiary: AppColors.blueAccent,
        onSurface: AppColors.ink,
      ),
      textTheme: textTheme,
      iconTheme: const IconThemeData(color: AppColors.inkSoft),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );
  }

  static TextTheme _buildTextTheme(TextTheme base) {
    final display = GoogleFonts.instrumentSerifTextTheme(base);
    final body = GoogleFonts.plusJakartaSansTextTheme(base);

    return base.copyWith(
      displayLarge: display.displayLarge?.copyWith(
        color: AppColors.ink,
        fontStyle: FontStyle.italic,
        fontSize: 56,
        height: 1.05,
      ),
      displayMedium: display.displayMedium?.copyWith(
        color: AppColors.ink,
        fontStyle: FontStyle.italic,
        fontSize: 44,
        height: 1.05,
      ),
      displaySmall: display.displaySmall?.copyWith(
        color: AppColors.ink,
        fontStyle: FontStyle.italic,
        fontSize: 32,
        height: 1.1,
      ),
      headlineLarge: display.headlineLarge?.copyWith(
        color: AppColors.ink,
        fontStyle: FontStyle.italic,
        fontSize: 28,
        height: 1.15,
      ),
      headlineMedium: display.headlineMedium?.copyWith(
        color: AppColors.ink,
        fontStyle: FontStyle.italic,
        fontSize: 24,
      ),
      headlineSmall: display.headlineSmall?.copyWith(
        color: AppColors.ink,
        fontStyle: FontStyle.italic,
        fontSize: 20,
      ),
      titleLarge: body.titleLarge?.copyWith(
        color: AppColors.ink,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: body.titleMedium?.copyWith(
        color: AppColors.ink,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: body.titleSmall?.copyWith(
        color: AppColors.inkSoft,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
      bodyLarge: body.bodyLarge?.copyWith(color: AppColors.ink),
      bodyMedium: body.bodyMedium?.copyWith(color: AppColors.inkSoft),
      bodySmall: body.bodySmall?.copyWith(color: AppColors.inkDim),
      labelLarge: body.labelLarge?.copyWith(
        color: AppColors.ink,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: body.labelMedium?.copyWith(color: AppColors.inkSoft),
      labelSmall: body.labelSmall?.copyWith(
        color: AppColors.inkDim,
        letterSpacing: 1.2,
      ),
    );
  }
}
