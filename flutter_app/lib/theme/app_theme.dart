import 'package:flutter/material.dart';

/// Central place for every purple-palette constant used across the app.
///
/// The palette is tuned so that:
///  * the primary is a deep violet that reads well on white,
///  * surfaces/containers are soft lavender rather than pure gray,
///  * borders/accents stay subtle but clearly purple-tinted,
///  * on-color contrast stays WCAG-AA friendly in both modes.
abstract final class AppPalette {
  // --- Brand / primary ---
  /// Deep violet primary used for buttons, active chips, the FAB and
  /// selection highlights.
  static const Color primary = Color(0xFF6D4DC4);

  /// Slightly darker primary for pressed/hover states.
  static const Color primaryDark = Color(0xFF5A3DA8);

  /// Lighter tint for gradients and hover washes.
  static const Color primaryLight = Color(0xFF9B7FE0);

  // --- Light mode ---
  /// App background in light mode: very soft lavender instead of gray.
  static const Color lightScaffold = Color(0xFFF5F2FB);

  /// Card background in light mode (near-white with a purple hint).
  static const Color lightSurface = Color(0xFFFCFAFF);

  /// Filled containers (chips, tag rows) in light mode.
  static const Color lightContainer = Color(0xFFE9E2F7);

  /// Subtle purple-tinted borders in light mode.
  static const Color lightOutline = Color(0xFFD8CCEF);

  /// High-contrast body text on light surfaces.
  static const Color lightOnSurface = Color(0xFF1E1B29);

  /// Muted secondary text (examples, hints) on light surfaces.
  static const Color lightOnSurfaceVariant = Color(0xFF5E5872);

  // --- Dark mode ---
  /// App background in dark mode: deep purple-black.
  static const Color darkScaffold = Color(0xFF16121F);

  /// Card background in dark mode.
  static const Color darkSurface = Color(0xFF1F1929);

  /// Filled containers (chips, tag rows) in dark mode.
  static const Color darkContainer = Color(0xFF2C2340);

  /// Subtle purple-tinted borders in dark mode.
  static const Color darkOutline = Color(0xFF4A3D66);

  /// Primary in dark mode is lifted for contrast on dark surfaces.
  static const Color darkPrimary = Color(0xFFB79CF0);

  /// High-contrast body text on dark surfaces.
  static const Color darkOnSurface = Color(0xFFECE7F6);

  /// Muted secondary text on dark surfaces.
  static const Color darkOnSurfaceVariant = Color(0xFFB0A7C6);
}

/// Builds the custom purple [ThemeData] for light and dark modes.
abstract final class AppTheme {
  /// Light purple theme.
  static ThemeData light() => _base(
        brightness: Brightness.light,
        scaffold: AppPalette.lightScaffold,
        surface: AppPalette.lightSurface,
        container: AppPalette.lightContainer,
        outline: AppPalette.lightOutline,
        primary: AppPalette.primary,
        onPrimary: Colors.white,
        onSurface: AppPalette.lightOnSurface,
        onSurfaceVariant: AppPalette.lightOnSurfaceVariant,
      );

  /// Dark purple theme.
  static ThemeData dark() => _base(
        brightness: Brightness.dark,
        scaffold: AppPalette.darkScaffold,
        surface: AppPalette.darkSurface,
        container: AppPalette.darkContainer,
        outline: AppPalette.darkOutline,
        primary: AppPalette.darkPrimary,
        onPrimary: const Color(0xFF1C1430),
        onSurface: AppPalette.darkOnSurface,
        onSurfaceVariant: AppPalette.darkOnSurfaceVariant,
      );

  /// Shared skeleton so light/dark only differ by the palette values.
  static ThemeData _base({
    required Brightness brightness,
    required Color scaffold,
    required Color surface,
    required Color container,
    required Color outline,
    required Color primary,
    required Color onPrimary,
    required Color onSurface,
    required Color onSurfaceVariant,
  }) {
    final bool isLight = brightness == Brightness.light;

    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: isLight ? AppPalette.primary : AppPalette.darkPrimary,
      brightness: brightness,
    ).copyWith(
      primary: primary,
      onPrimary: onPrimary,
      secondary: isLight ? AppPalette.primaryLight : AppPalette.darkPrimary,
      surface: surface,
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceVariant,
      surfaceContainerHighest: container,
      outline: outline,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      // Persian UI text keeps the Vazirmatn-like feel; falls back cleanly.
      fontFamily: 'Vazirmatn',
      cardTheme: CardThemeData(
        color: surface,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: isLight ? 0.12 : 0.45),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: outline.withValues(alpha: 0.7)),
        ),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: container,
        side: BorderSide(color: outline.withValues(alpha: 0.6)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        labelStyle: TextStyle(color: onSurface, fontSize: 12.5),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          side: WidgetStatePropertyAll(BorderSide(color: outline)),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return primary;
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return onPrimary;
            return onSurfaceVariant;
          }),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isLight ? AppPalette.primaryDark : container,
        contentTextStyle: TextStyle(color: isLight ? Colors.white : onSurface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      dividerTheme: DividerThemeData(color: outline.withValues(alpha: 0.5)),
    );
  }
}
