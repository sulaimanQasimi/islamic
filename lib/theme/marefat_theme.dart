import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// معرفت visual system — cool sage mist, deep forest ink, warm brass.
class MarefatColors {
  MarefatColors._();

  static const ink = Color(0xFF0D2A26);
  static const forest = Color(0xFF1A5C4E);
  static const sage = Color(0xFF3D7A6C);
  static const mist = Color(0xFFE6F0EC);
  static const mistDeep = Color(0xFFD0E3DB);
  static const surface = Color(0xFFF5FAF7);
  static const brass = Color(0xFFB8893A);
  static const brassSoft = Color(0xFFD4B06A);
  static const parchment = Color(0xFFF7F2E6);
  static const night = Color(0xFF0A1A18);
  static const nightSurface = Color(0xFF132826);
  static const muted = Color(0xFF5A716B);
  static const onDark = Color(0xFFE6F0EC);
  static const mutedDark = Color(0xFF8AA39B);
  static const mistDark = Color(0xFF1B322E);
  static const mistDeepDark = Color(0xFF243F39);

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color text(BuildContext context) =>
      isDark(context) ? onDark : ink;

  static Color mutedText(BuildContext context) =>
      isDark(context) ? mutedDark : muted;

  static Color card(BuildContext context) =>
      isDark(context) ? nightSurface : Colors.white;

  static Color sheet(BuildContext context) =>
      isDark(context) ? nightSurface : surface;

  static Color softFill(BuildContext context) =>
      isDark(context) ? mistDark : mist;

  static Color softBorder(BuildContext context) =>
      isDark(context) ? mistDeepDark : mistDeep;

  static Color inputFill(BuildContext context) => isDark(context)
      ? Colors.white.withValues(alpha: 0.06)
      : Colors.white.withValues(alpha: 0.88);

  static Color hairline(BuildContext context) =>
      isDark(context) ? Colors.white24 : Colors.black12;

  static Color accent(BuildContext context) =>
      isDark(context) ? sage : forest;

  static Color accentSoft(BuildContext context) =>
      isDark(context) ? brassSoft : brass;
}

class MarefatTheme {
  MarefatTheme._();

  static TextStyle _safeVazirmatn({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
  }) {
    try {
      return GoogleFonts.vazirmatn(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
      );
    } catch (_) {
      return TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
      );
    }
  }

  static TextTheme _textTheme(Color color) {
    TextTheme base;
    try {
      base = GoogleFonts.vazirmatnTextTheme().apply(
        bodyColor: color,
        displayColor: color,
      );
    } catch (_) {
      base = ThemeData(brightness: Brightness.light).textTheme.apply(
        bodyColor: color,
        displayColor: color,
      );
    }
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        height: 1.15,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        height: 1.25,
      ),
      titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      bodyLarge: base.bodyLarge?.copyWith(height: 1.7),
      bodyMedium: base.bodyMedium?.copyWith(height: 1.65),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    );
  }

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: MarefatColors.forest,
      brightness: Brightness.light,
      primary: MarefatColors.forest,
      secondary: MarefatColors.brass,
      surface: MarefatColors.surface,
      onPrimary: Colors.white,
      onSecondary: MarefatColors.ink,
      onSurface: MarefatColors.ink,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: MarefatColors.mist,
      textTheme: _textTheme(MarefatColors.ink),
      dividerColor: MarefatColors.mistDeep,
      cardColor: Colors.white,
      dialogTheme: DialogThemeData(
        backgroundColor: MarefatColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: MarefatColors.ink,
        titleTextStyle: _safeVazirmatn(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: MarefatColors.ink,
        ),
        iconTheme: const IconThemeData(color: MarefatColors.ink),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: MarefatColors.surface.withValues(alpha: 0.94),
        indicatorColor: MarefatColors.forest.withValues(alpha: 0.14),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return _safeVazirmatn(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? MarefatColors.forest : MarefatColors.muted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? MarefatColors.forest : MarefatColors.muted,
            size: 22,
          );
        }),
      ),
      chipTheme: ChipThemeData(
        selectedColor: MarefatColors.forest,
        backgroundColor: Colors.white.withValues(alpha: 0.75),
        disabledColor: MarefatColors.mistDeep,
        side: const BorderSide(color: MarefatColors.mistDeep),
        labelStyle: _safeVazirmatn(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: MarefatColors.ink,
        ),
        secondaryLabelStyle: _safeVazirmatn(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: MarefatColors.forest,
        thumbColor: MarefatColors.forest,
        inactiveTrackColor: MarefatColors.forest.withValues(alpha: 0.15),
        overlayColor: MarefatColors.forest.withValues(alpha: 0.12),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: MarefatColors.forest,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: _safeVazirmatn(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: MarefatColors.forest,
          side: const BorderSide(color: MarefatColors.mistDeep),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: MarefatColors.forest),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: MarefatColors.forest,
        textColor: MarefatColors.ink,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: MarefatColors.ink,
        contentTextStyle: _safeVazirmatn(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: MarefatColors.surface,
        modalBackgroundColor: MarefatColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: MarefatColors.surface,
        textStyle: _safeVazirmatn(color: MarefatColors.ink),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.88),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: MarefatColors.mistDeep),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: MarefatColors.forest, width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: _safeVazirmatn(color: MarefatColors.muted),
        labelStyle: _safeVazirmatn(color: MarefatColors.muted),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: MarefatColors.forest,
        linearTrackColor: MarefatColors.mistDeep,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? MarefatColors.forest
              : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? MarefatColors.forest.withValues(alpha: 0.35)
              : MarefatColors.mistDeep,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: MarefatColors.forest,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: MarefatColors.mistDeep),
        ),
      ),
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: MarefatColors.sage,
      brightness: Brightness.dark,
      primary: MarefatColors.sage,
      secondary: MarefatColors.brassSoft,
      surface: MarefatColors.nightSurface,
      onPrimary: Colors.white,
      onSecondary: MarefatColors.night,
      onSurface: MarefatColors.onDark,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: MarefatColors.night,
      textTheme: _textTheme(MarefatColors.onDark),
      dividerColor: MarefatColors.mistDeepDark,
      cardColor: MarefatColors.nightSurface,
      dialogTheme: DialogThemeData(
        backgroundColor: MarefatColors.nightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: MarefatColors.onDark,
        titleTextStyle: _safeVazirmatn(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: MarefatColors.onDark,
        ),
        iconTheme: const IconThemeData(color: MarefatColors.onDark),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: MarefatColors.nightSurface.withValues(alpha: 0.96),
        indicatorColor: MarefatColors.sage.withValues(alpha: 0.22),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return _safeVazirmatn(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? MarefatColors.brassSoft : MarefatColors.mutedDark,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? MarefatColors.brassSoft : MarefatColors.mutedDark,
            size: 22,
          );
        }),
      ),
      chipTheme: ChipThemeData(
        selectedColor: MarefatColors.sage,
        backgroundColor: Colors.white.withValues(alpha: 0.08),
        disabledColor: MarefatColors.mistDeepDark,
        side: const BorderSide(color: MarefatColors.mistDeepDark),
        labelStyle: _safeVazirmatn(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: MarefatColors.onDark,
        ),
        secondaryLabelStyle: _safeVazirmatn(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: MarefatColors.sage,
        thumbColor: MarefatColors.brassSoft,
        inactiveTrackColor: MarefatColors.sage.withValues(alpha: 0.2),
        overlayColor: MarefatColors.sage.withValues(alpha: 0.14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: MarefatColors.sage,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: _safeVazirmatn(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: MarefatColors.brassSoft,
          side: const BorderSide(color: MarefatColors.mistDeepDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: MarefatColors.brassSoft),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: MarefatColors.brassSoft,
        textColor: MarefatColors.onDark,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: MarefatColors.mistDark,
        contentTextStyle: _safeVazirmatn(color: MarefatColors.onDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: MarefatColors.nightSurface,
        modalBackgroundColor: MarefatColors.nightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: MarefatColors.nightSurface,
        textStyle: _safeVazirmatn(color: MarefatColors.onDark),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: MarefatColors.mistDeepDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: MarefatColors.sage, width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: _safeVazirmatn(color: MarefatColors.mutedDark),
        labelStyle: _safeVazirmatn(color: MarefatColors.mutedDark),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: MarefatColors.sage,
        linearTrackColor: MarefatColors.mistDeepDark,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? MarefatColors.brassSoft
              : MarefatColors.onDark,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? MarefatColors.sage.withValues(alpha: 0.45)
              : MarefatColors.mistDeepDark,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: MarefatColors.sage,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: MarefatColors.nightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: MarefatColors.mistDeepDark),
        ),
      ),
    );
  }
}
