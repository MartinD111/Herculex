import 'package:flutter/material.dart';

/// iOS-inspired dark palette: true black background, iOS system blue as the
/// accent, white/blue text. Every legacy token below is remapped onto this
/// palette so the ~550 existing `AppColors.*` references across the app adopt
/// the new look without per-widget edits.
class AppColors {
  // ── Core iOS dark palette ──
  /// True black — primary app background (OLED-friendly, Apple-style).
  static const Color background = Color(0xFF000000);

  /// iOS system blue — the single accent color.
  static const Color primary = Color(0xFF0A84FF);

  /// Slightly lighter blue for pressed / container fills.
  static const Color primaryContainer = Color(0xFF1C4A7E);

  /// Pure white — primary text on black.
  static const Color onSurface = Color(0xFFFFFFFF);

  /// iOS secondary label grey (visible on black).
  static const Color secondary = Color(0xFF98989F);

  /// Tertiary label / subtle text.
  static const Color tertiary = Color(0xFF8E8E93);

  static const Color onSurfaceVariant = Color(0xFFC7C7CC);

  // ── Elevated surfaces (iOS grouped-background greys on black) ──
  /// Cards / chips resting fill — elevated dark grey.
  static const Color surfaceContainer = Color(0xFF1C1C1E);

  /// Lowest elevation surface — near-black grouped background.
  static const Color surfaceContainerLowest = Color(0xFF121214);

  /// A touch lighter than surfaceContainer for layered fills.
  static const Color surfaceVariant = Color(0xFF2C2C2E);

  // ── Lines / borders ──
  static const Color outlineVariant = Color(0xFF38383A);
  static const Color outline = Color(0xFF48484A);

  /// Legacy accent kept as an alias of primary so old references stay on-brand.
  static const Color earthBrown = Color(0xFF0A84FF);

  // ── Dark-mode aliases (theme also reads these) ──
  static const Color darkBackground = background;
  static const Color darkOnSurface = onSurface;
  static const Color darkSurfaceContainer = surfaceContainer;
  static const Color darkSurfaceContainerLowest = surfaceContainerLowest;
  static const Color darkSurfaceVariant = surfaceVariant;
  static const Color darkOutlineVariant = outlineVariant;
  static const Color darkPrimary = primary;
}
