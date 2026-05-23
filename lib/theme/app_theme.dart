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

/// Theme-aware surface + text colors. Pass a [BuildContext] — the helper
/// reads `Theme.of(context).brightness` and returns the dark or light
/// token. Use for scaffold backgrounds, primary on-surface text, and any
/// element that should invert with the user's theme preference.
///
/// Brand accents (purple/pink/blue/gradients) stay the same across themes
/// and live on [AppColors] as before.
class BrandColors {
  BrandColors._();

  static const _lightBgDeep = Color(0xFFFAF5FF);
  static const _lightBg = Color(0xFFF3E8FF);
  static const _lightBgCard = Color(0xFFFFFFFF);
  static const _lightInk = Color(0xFF1F1338);
  static const _lightInkSoft = Color(0xFF4C1D95);
  static const _lightInkDim = Color(0xFF6B5680);
  static const _lightInkFaint = Color(0xFFA78BB8);

  static bool _isLight(BuildContext c) =>
      Theme.of(c).brightness == Brightness.light;

  static Color bgDeep(BuildContext c) =>
      _isLight(c) ? _lightBgDeep : AppColors.bgDeep;
  static Color bg(BuildContext c) =>
      _isLight(c) ? _lightBg : AppColors.bg;
  static Color bgCard(BuildContext c) =>
      _isLight(c) ? _lightBgCard : AppColors.bgCard;
  static Color ink(BuildContext c) =>
      _isLight(c) ? _lightInk : AppColors.ink;
  static Color inkSoft(BuildContext c) =>
      _isLight(c) ? _lightInkSoft : AppColors.inkSoft;
  static Color inkDim(BuildContext c) =>
      _isLight(c) ? _lightInkDim : AppColors.inkDim;
  static Color inkFaint(BuildContext c) =>
      _isLight(c) ? _lightInkFaint : AppColors.inkFaint;
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
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.bgCard,
        contentTextStyle: const TextStyle(
          color: AppColors.ink,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
        actionTextColor: AppColors.pinkLight,
        behavior: SnackBarBehavior.floating,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  // App-wide font: Bricolage Grotesque. Single typeface for the whole
  // app — display + body — with hierarchy expressed through weight and
  // size only. Picked for its slight humanist warmth + characterful
  // modern proportions; tracks well at both giant display sizes and
  // small captions, holds identity without leaning literary.
  static TextTheme _buildTextTheme(TextTheme base) {
    final t = GoogleFonts.bricolageGrotesqueTextTheme(base);
    return base.copyWith(
      displayLarge: t.displayLarge?.copyWith(
        color: AppColors.ink,
        fontWeight: FontWeight.w800,
        fontSize: 56,
        height: 1.0,
        letterSpacing: -1.0,
      ),
      displayMedium: t.displayMedium?.copyWith(
        color: AppColors.ink,
        fontWeight: FontWeight.w800,
        fontSize: 44,
        height: 1.0,
        letterSpacing: -0.6,
      ),
      displaySmall: t.displaySmall?.copyWith(
        color: AppColors.ink,
        fontWeight: FontWeight.w800,
        fontSize: 32,
        height: 1.05,
        letterSpacing: -0.4,
      ),
      headlineLarge: t.headlineLarge?.copyWith(
        color: AppColors.ink,
        fontWeight: FontWeight.w800,
        fontSize: 28,
        height: 1.1,
        letterSpacing: -0.3,
      ),
      headlineMedium: t.headlineMedium?.copyWith(
        color: AppColors.ink,
        fontWeight: FontWeight.w700,
        fontSize: 24,
        letterSpacing: -0.2,
      ),
      headlineSmall: t.headlineSmall?.copyWith(
        color: AppColors.ink,
        fontWeight: FontWeight.w700,
        fontSize: 20,
        letterSpacing: -0.1,
      ),
      titleLarge: t.titleLarge?.copyWith(
        color: AppColors.ink,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: t.titleMedium?.copyWith(
        color: AppColors.ink,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: t.titleSmall?.copyWith(
        color: AppColors.inkSoft,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
      bodyLarge: t.bodyLarge?.copyWith(
        color: AppColors.ink,
        fontWeight: FontWeight.w500,
      ),
      bodyMedium: t.bodyMedium?.copyWith(
        color: AppColors.inkSoft,
        fontWeight: FontWeight.w500,
      ),
      bodySmall: t.bodySmall?.copyWith(
        color: AppColors.inkDim,
        fontWeight: FontWeight.w500,
      ),
      labelLarge: t.labelLarge?.copyWith(
        color: AppColors.ink,
        fontWeight: FontWeight.w700,
      ),
      labelMedium: t.labelMedium?.copyWith(
        color: AppColors.inkSoft,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: t.labelSmall?.copyWith(
        color: AppColors.inkDim,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}

/// Centralised Bricolage TextStyle factory for inline use. Replaces
/// the scattered `GoogleFonts.bricolageGrotesque(...)` call sites — call
/// `brandFont(...)` and tweak weight/size to taste. Default is heavy
/// because the majority of inline uses were big headlines.
TextStyle brandFont({
  Color? color,
  double? fontSize,
  FontWeight weight = FontWeight.w800,
  double height = 1.05,
  double letterSpacing = -0.2,
  List<Shadow>? shadows,
  Paint? foreground,
}) {
  return GoogleFonts.bricolageGrotesque(
    color: foreground == null ? color : null,
    fontSize: fontSize,
    fontWeight: weight,
    height: height,
    letterSpacing: letterSpacing,
    shadows: shadows,
    foreground: foreground,
  );
}
