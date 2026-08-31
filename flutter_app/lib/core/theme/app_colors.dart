import 'package:flutter/material.dart';

class AppColors {
  // Background & Surface (Dark Theme defaults)
  static const Color background = Color(0xFF0B0C12);
  static const Color backgroundSecondary = Color(0xFF13151F);
  static const Color glassSurface = Color(0x1AFFFFFF); // 10% white
  static const Color glassSurfaceElevated = Color(0x26FFFFFF); // 15% white
  static const Color glassBorder = Color(0x1FFFFFFF); // 12% white
  static const Color glassBorderLight = Color(0x14FFFFFF); // 8% white
  static const Color dockBackground = Color(0xD910121A); // 85% opacity dark

  // Light Theme (Daylight / Sunlight Mode) Constants
  static const Color lightBackground = Color(0xFFF1F5F9); // Slate 100
  static const Color lightBackgroundSecondary = Color(0xFFFFFFFF); // Clean White
  static const Color lightGlassSurface = Color(0xFFFFFFFF);
  static const Color lightGlassSurfaceElevated = Color(0xFFFFFFFF);
  static const Color lightGlassBorder = Color(0xFFCBD5E1); // Slate 300
  static const Color lightGlassBorderLight = Color(0xFFE2E8F0); // Slate 200
  static const Color lightDockBackground = Color(0xF2FFFFFF); // 95% White

  // Accent & Brand Colors
  static const Color primary = Color(0xFF2563EB); // Vibrant Royal Blue
  static const Color primaryGlow = Color(0xFF60A5FA); // Sky Blue Glow
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color primaryDark = Color(0xFF1D4ED8);

  // Status & Functional Colors
  static const Color success = Color(0xFF10B981); // Emerald Green
  static const Color successBg = Color(0x2610B981);
  static const Color successBorder = Color(0x4D10B981);

  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color warningBg = Color(0x26F59E0B);
  static const Color warningBorder = Color(0x4DF59E0B);

  static const Color error = Color(0xFFEF4444); // Crimson Rose
  static const Color errorBg = Color(0x26EF4444);
  static const Color errorBorder = Color(0x4DEF4444);

  // Preset Badge Colors
  static const Color presetNlh = Color(0xFF8B5CF6); // Purple
  static const Color presetStocks = Color(0xFF3B82F6); // Blue
  static const Color presetDbn = Color(0xFF10B981); // Emerald
  static const Color presetNls = Color(0xFF06B6D4); // Cyan
  static const Color presetPlk = Color(0xFFF97316); // Orange
  static const Color presetBloem = Color(0xFFEC4899); // Pink
  static const Color presetTirepoint = Color(0xFF14B8A6); // Teal
  static const Color presetCustom = Color(0xFF64748B); // Slate

  // Typography Colors (Dark Theme)
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textDisabled = Color(0xFF475569);

  // Typography Colors (Light Theme)
  static const Color lightTextPrimary = Color(0xFF0F172A); // Deep Slate 900
  static const Color lightTextSecondary = Color(0xFF334155); // Slate 700
  static const Color lightTextMuted = Color(0xFF64748B); // Slate 500
  static const Color lightTextDisabled = Color(0xFF94A3B8); // Slate 400

  // Theme-aware Context Accessors
  static bool isLight(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light;

  static Color dynamicBackground(BuildContext context) =>
      isLight(context) ? lightBackground : background;

  static Color dynamicCardSurface(BuildContext context) =>
      isLight(context) ? lightGlassSurface : glassSurface;

  static Color dynamicCardElevated(BuildContext context) =>
      isLight(context) ? lightGlassSurfaceElevated : glassSurfaceElevated;

  static Color dynamicBorder(BuildContext context) =>
      isLight(context) ? lightGlassBorder : glassBorder;

  static Color dynamicTextPrimary(BuildContext context) =>
      isLight(context) ? lightTextPrimary : textPrimary;

  static Color dynamicTextSecondary(BuildContext context) =>
      isLight(context) ? lightTextSecondary : textSecondary;

  static Color dynamicTextMuted(BuildContext context) =>
      isLight(context) ? lightTextMuted : textMuted;
}
