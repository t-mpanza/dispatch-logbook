import 'package:flutter/material.dart';

/// Field-grade palette supporting both the standard dark theme and
/// "Sunlight Mode" (light theme for bright outdoor use).
///
/// Rules:
/// - Every colour resolves per-theme via the `dynamic*` accessors.
/// - Status colours stay identical in both themes so operators always
///   read success/warning/error the same way.
class AppColors {
  // Background & Surface (Dark Theme defaults)
  static const Color background = Color(0xFF0A0F1E);
  static const Color backgroundSecondary = Color(0xFF121A2E);
  static const Color surfaceRaised = Color(0xFF1A2440);
  static const Color surfaceSunk = Color(0xFF070B16);
  static const Color glassSurface = Color(0x0FFFFFFF);
  static const Color glassSurfaceElevated = Color(0x1AFFFFFF);
  static const Color glassBorder = Color(0x26FFFFFF);
  static const Color glassBorderLight = Color(0x14FFFFFF);
  static const Color dockBackground = Color(0xED0E1526);

  // Light Theme (Sunlight Mode) Constants
  static const Color lightBackground = Color(0xFFF1F5F9);
  static const Color lightBackgroundSecondary = Color(0xFFFFFFFF);
  static const Color lightSurfaceRaised = Color(0xFFFFFFFF);
  static const Color lightSurfaceSunk = Color(0xFFE2E8F0);
  static const Color lightGlassSurface = Color(0xFFFFFFFF);
  static const Color lightGlassSurfaceElevated = Color(0xFFFFFFFF);
  static const Color lightGlassBorder = Color(0xFFCBD5E1);
  static const Color lightGlassBorderLight = Color(0xFFE2E8F0);
  static const Color lightDockBackground = Color(0xF7FFFFFF);

  // Accent & Brand
  static const Color primary = Color(0xFF2F6BFF);
  static const Color primaryGlow = Color(0xFF7BA8FF);
  static const Color primaryLight = Color(0xFF5C8CFF);
  static const Color primaryDark = Color(0xFF2355CC);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onAccent = Color(0xFF071233);

  // Status & Functional (identical in both themes)
  static const Color success = Color(0xFF2EE6A8);
  static const Color successBg = Color(0x1F2EE6A8);
  static const Color successBorder = Color(0x4D2EE6A8);

  static const Color warning = Color(0xFFFFB020);
  static const Color warningBg = Color(0x26FFB020);
  static const Color warningBorder = Color(0x4DFFB020);

  static const Color error = Color(0xFFFF5C5C);
  static const Color errorBg = Color(0x26FF5C5C);
  static const Color errorBorder = Color(0x4DFF5C5C);

  static const Color info = Color(0xFF4DC3FF);
  static const Color infoBg = Color(0x1F4DC3FF);

  // Preset Badge Colors
  static const Color presetNlh = Color(0xFFA78BFA);
  static const Color presetStocks = Color(0xFF5C8CFF);
  static const Color presetDbn = Color(0xFF2EE6A8);
  static const Color presetNls = Color(0xFF22D3EE);
  static const Color presetPlk = Color(0xFFFFA04D);
  static const Color presetBloem = Color(0xFFF472B6);
  static const Color presetTirepoint = Color(0xFF2DD4BF);
  static const Color presetCustom = Color(0xFF8B9BB8);

  // Typography (Dark)
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB6C2DC);
  static const Color textMuted = Color(0xFF7A88A6);
  static const Color textDisabled = Color(0xFF4C5875);

  // Typography (Light)
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF334155);
  static const Color lightTextMuted = Color(0xFF64748B);
  static const Color lightTextDisabled = Color(0xFF94A3B8);

  // Theme-aware Context Accessors
  static bool isLight(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light;

  static Color dynamicBackground(BuildContext context) =>
      isLight(context) ? lightBackground : background;

  static Color dynamicBackgroundSecondary(BuildContext context) =>
      isLight(context) ? lightBackgroundSecondary : backgroundSecondary;

  static Color dynamicSurfaceRaised(BuildContext context) =>
      isLight(context) ? lightSurfaceRaised : surfaceRaised;

  static Color dynamicSurfaceSunk(BuildContext context) =>
      isLight(context) ? lightSurfaceSunk : surfaceSunk;

  static Color dynamicCardSurface(BuildContext context) =>
      isLight(context) ? lightGlassSurface : glassSurface;

  static Color dynamicCardElevated(BuildContext context) =>
      isLight(context) ? lightGlassSurfaceElevated : glassSurfaceElevated;

  static Color dynamicBorder(BuildContext context) =>
      isLight(context) ? lightGlassBorder : glassBorder;

  static Color dynamicBorderLight(BuildContext context) =>
      isLight(context) ? lightGlassBorderLight : glassBorderLight;

  static Color dynamicDockBackground(BuildContext context) =>
      isLight(context) ? lightDockBackground : dockBackground;

  static Color dynamicTextPrimary(BuildContext context) =>
      isLight(context) ? lightTextPrimary : textPrimary;

  static Color dynamicTextSecondary(BuildContext context) =>
      isLight(context) ? lightTextSecondary : textSecondary;

  static Color dynamicTextMuted(BuildContext context) =>
      isLight(context) ? lightTextMuted : textMuted;

  static Color dynamicTextDisabled(BuildContext context) =>
      isLight(context) ? lightTextDisabled : textDisabled;

  /// Brand accent that stays readable on the current theme's surfaces.
  static Color dynamicAccent(BuildContext context) =>
      isLight(context) ? primary : primaryGlow;
}
