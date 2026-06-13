import 'package:flutter/material.dart';
import 'colors.dart';

/// iOS-inspired dark theme. Black backgrounds, system-blue accent, white text,
/// and pill (stadium) shapes for every interactive surface — buttons, chips,
/// inputs, and toggles. Both `lightTheme` and `darkTheme` return the same dark
/// theme so the app is always black regardless of the OS setting.
class AppTheme {
  /// Universal pill shape used across buttons and containers.
  static const StadiumBorder _pill = StadiumBorder();

  static ThemeData get lightTheme => _buildTheme();
  static ThemeData get darkTheme => _buildTheme();

  static ThemeData _buildTheme() {
    const scheme = ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.primary,
      surface: AppColors.background,
      onSurface: AppColors.onSurface,
      surfaceContainerHighest: AppColors.surfaceVariant,
      tertiary: AppColors.tertiary,
      outline: AppColors.outline,
      outlineVariant: AppColors.outlineVariant,
    );

    final base = ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.primary,
      colorScheme: scheme,
      fontFamily: 'Inter',
      splashFactory: NoSplash.splashFactory, // iOS has no ripple
      highlightColor: Colors.transparent,
    );

    return base.copyWith(
      textTheme: _textTheme,

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurface,
          letterSpacing: -0.2,
        ),
      ),

      // ── Pill-shaped buttons ──
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: _pill,
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: _pill,
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.2),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          shape: _pill,
          minimumSize: const Size(0, 50),
          side: const BorderSide(color: AppColors.outlineVariant),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.2),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          shape: _pill,
          textStyle: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: -0.2),
        ),
      ),

      // ── Pill-shaped chips ──
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceContainer,
        selectedColor: AppColors.primary,
        disabledColor: AppColors.surfaceContainer,
        labelStyle: const TextStyle(
          color: AppColors.onSurface, fontSize: 14, fontWeight: FontWeight.w500),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
        side: BorderSide.none,
        shape: _pill,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        showCheckmark: false,
      ),

      // ── Inputs: pill text fields ──
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceContainer,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        hintStyle: const TextStyle(color: AppColors.secondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),

      // ── Cards: rounded (not pill — content needs corners, not capsules) ──
      cardTheme: CardThemeData(
        color: AppColors.surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: EdgeInsets.zero,
      ),

      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.primary,
        textColor: AppColors.onSurface,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.surfaceVariant),
        trackOutlineColor:
            const WidgetStatePropertyAll(Colors.transparent),
      ),

      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: AppColors.surfaceVariant,
        thumbColor: Colors.white,
        overlayColor: Color(0x330A84FF),
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(_pill),
          backgroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? AppColors.primary
                  : AppColors.surfaceContainer),
          foregroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? Colors.white
                  : AppColors.onSurface),
          side: const WidgetStatePropertyAll(BorderSide.none),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: StadiumBorder(),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceContainerLowest,
        modalBackgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurface,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: 'Inter', fontSize: 15, color: AppColors.onSurfaceVariant),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.outlineVariant,
        thickness: 0.5,
        space: 0.5,
      ),

      iconTheme: const IconThemeData(color: AppColors.onSurface),

      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.secondary,
        indicatorColor: AppColors.primary,
        dividerColor: Colors.transparent,
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceContainerLowest,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.secondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceContainerLowest,
        indicatorColor: AppColors.primary.withValues(alpha: 0.18),
        elevation: 0,
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceVariant,
        contentTextStyle: const TextStyle(color: AppColors.onSurface),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        behavior: SnackBarBehavior.floating,
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static const TextTheme _textTheme = TextTheme(
    displayLarge: TextStyle(
        fontSize: 34, fontWeight: FontWeight.w700, color: AppColors.onSurface, letterSpacing: -0.6),
    displayMedium: TextStyle(
        fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.onSurface, letterSpacing: -0.5),
    titleLarge: TextStyle(
        fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.onSurface, letterSpacing: -0.4),
    titleMedium: TextStyle(
        fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.onSurface, letterSpacing: -0.2),
    titleSmall: TextStyle(
        fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.onSurface, letterSpacing: -0.1),
    bodyLarge: TextStyle(fontSize: 17, color: AppColors.onSurface, letterSpacing: -0.2),
    bodyMedium: TextStyle(fontSize: 15, color: AppColors.onSurfaceVariant, letterSpacing: -0.1),
    bodySmall: TextStyle(fontSize: 13, color: AppColors.secondary),
    labelLarge: TextStyle(
        fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.onSurface),
    labelMedium: TextStyle(
        fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.secondary),
    labelSmall: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.secondary),
  );
}
