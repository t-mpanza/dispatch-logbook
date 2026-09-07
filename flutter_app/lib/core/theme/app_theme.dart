import 'package:flutter/material.dart';
import 'app_colors.dart';

/// FieldMate design system, in both daylight and dark.
///
/// Principles:
/// - 48dp minimum touch targets (gloved hands, bumpy trucks)
/// - 15px+ body text (readable in direct sunlight)
/// - one primary colour for actions, semantic colours only for status
class AppTheme {
  static ThemeData get darkTheme => _build(Brightness.dark);
  static ThemeData get lightTheme => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;

    final scheme = isLight
        ? const ColorScheme.light(
            primary: Color(0xFF1D4ED8),
            onPrimary: Colors.white,
            secondary: Color(0xFF2563EB),
            onSecondary: Colors.white,
            surface: Colors.white,
            onSurface: Color(0xFF0F172A),
            error: Color(0xFFDC2626),
            onError: Colors.white,
            outline: Color(0xFFCBD5E1),
          )
        : const ColorScheme.dark(
            primary: AppColors.primary,
            onPrimary: AppColors.onPrimary,
            secondary: AppColors.primaryGlow,
            onSecondary: AppColors.onAccent,
            surface: AppColors.backgroundSecondary,
            onSurface: AppColors.textPrimary,
            error: AppColors.error,
            onError: Colors.white,
            outline: AppColors.glassBorder,
          );

    final textPrimary = isLight
        ? AppColors.lightTextPrimary
        : AppColors.textPrimary;
    final textSecondary = isLight
        ? AppColors.lightTextSecondary
        : AppColors.textSecondary;
    final textMuted = isLight ? AppColors.lightTextMuted : AppColors.textMuted;
    final accent = isLight ? const Color(0xFF1D4ED8) : AppColors.primaryGlow;
    final surfaceSecondary = isLight
        ? AppColors.lightBackgroundSecondary
        : AppColors.backgroundSecondary;
    final surfaceRaised = isLight
        ? AppColors.lightSurfaceRaised
        : AppColors.surfaceRaised;
    final borderLight = isLight
        ? AppColors.lightGlassBorderLight
        : AppColors.glassBorderLight;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: isLight
          ? AppColors.lightBackground
          : AppColors.background,
      colorScheme: scheme,
      fontFamily: 'Roboto',
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w900,
          color: textPrimary,
          letterSpacing: -0.5,
          height: 1.1,
        ),
        displayMedium: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w900,
          color: textPrimary,
          letterSpacing: -0.4,
          height: 1.15,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: textPrimary,
          letterSpacing: -0.3,
          height: 1.2,
        ),
        titleLarge: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          height: 1.25,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          height: 1.3,
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: textPrimary,
          height: 1.4,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textSecondary,
          height: 1.4,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textMuted,
          height: 1.35,
        ),
        labelLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: 0.2,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
          color: accent,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isLight
            ? AppColors.lightBackground
            : AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textPrimary, size: 24),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: textPrimary,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          backgroundColor: scheme.primary,
          foregroundColor: AppColors.onPrimary,
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 52),
          backgroundColor: scheme.primary,
          foregroundColor: AppColors.onPrimary,
          disabledBackgroundColor: isLight
              ? const Color(0xFFE2E8F0)
              : AppColors.glassSurface,
          disabledForegroundColor: isLight
              ? AppColors.lightTextDisabled
              : AppColors.textDisabled,
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          foregroundColor: textPrimary,
          side: BorderSide(
            color: isLight ? AppColors.lightGlassBorder : AppColors.glassBorder,
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          foregroundColor: accent,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: textPrimary,
          minimumSize: const Size(48, 48),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? AppColors.lightSurfaceSunk : AppColors.surfaceSunk,
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: textMuted,
        ),
        hintStyle: TextStyle(
          fontSize: 14,
          color: isLight ? AppColors.lightTextDisabled : AppColors.textDisabled,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surfaceRaised,
        contentTextStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: borderLight),
        ),
        elevation: 8,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceSecondary,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: textPrimary,
        ),
        contentTextStyle: TextStyle(
          fontSize: 14,
          color: textSecondary,
          height: 1.45,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaceSecondary,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        showDragHandle: false,
      ),
      dividerTheme: DividerThemeData(
        color: borderLight,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isLight
            ? AppColors.lightGlassSurface
            : AppColors.glassSurface,
        selectedColor: scheme.primary.withValues(alpha: 0.18),
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        secondaryLabelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        side: BorderSide(color: borderLight),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: isLight
            ? const Color(0x14FFFFFF)
            : const Color(0x1FFFFFFF),
        circularTrackColor: isLight
            ? const Color(0x140F172A)
            : const Color(0x1FFFFFFF),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? accent : textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary.withValues(alpha: isLight ? 0.4 : 0.55)
              : (isLight ? AppColors.lightSurfaceSunk : AppColors.glassSurface),
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.transparent
              : borderLight,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 6,
        focusElevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: textSecondary,
        textColor: textPrimary,
        titleTextStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        subtitleTextStyle: TextStyle(fontSize: 13, color: textMuted),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accent,
        selectionColor: scheme.primary.withValues(alpha: 0.3),
        selectionHandleColor: accent,
      ),
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
