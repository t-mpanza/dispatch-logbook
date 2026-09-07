import 'dart:ui';
import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Shared surface language: layered glass cards, elevated panels and the
/// floating navigation dock. One set of radii and shadows keeps every
/// screen visually consistent, in both sunlight and dark mode.
class GlassDecorations {
  static const double _cardRadius = 20;

  static BoxDecoration glassCard({
    BuildContext? context,
    double borderRadius = _cardRadius,
    Color? color,
    Color? borderColor,
  }) {
    final isLight = context != null && AppColors.isLight(context);
    return BoxDecoration(
      color:
          color ??
          (isLight
              ? AppColors.lightGlassSurface
              : AppColors.backgroundSecondary),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color:
            borderColor ??
            (isLight
                ? AppColors.lightGlassBorderLight
                : AppColors.glassBorderLight),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: isLight ? const Color(0x14000000) : const Color(0x33000000),
          blurRadius: isLight ? 10 : 16,
          offset: isLight ? const Offset(0, 2) : const Offset(0, 4),
        ),
      ],
    );
  }

  static BoxDecoration glassElevated({
    BuildContext? context,
    double borderRadius = 24,
    Color? color,
    Color? borderColor,
  }) {
    final isLight = context != null && AppColors.isLight(context);
    return BoxDecoration(
      color: color ?? (isLight ? Colors.white : AppColors.surfaceRaised),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color:
            borderColor ??
            (isLight ? AppColors.lightGlassBorder : AppColors.glassBorder),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: isLight ? const Color(0x1A000000) : const Color(0x4D000000),
          blurRadius: isLight ? 14 : 24,
          offset: isLight ? const Offset(0, 4) : const Offset(0, 8),
        ),
      ],
    );
  }

  static BoxDecoration glassDock({
    BuildContext? context,
    double borderRadius = 28,
  }) {
    final isLight = context != null && AppColors.isLight(context);
    return BoxDecoration(
      color: isLight ? AppColors.lightDockBackground : AppColors.dockBackground,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: isLight
            ? AppColors.lightGlassBorder
            : AppColors.glassBorderLight,
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: isLight ? const Color(0x1F000000) : const Color(0x73000000),
          blurRadius: isLight ? 20 : 30,
          offset: isLight ? const Offset(0, 6) : const Offset(0, 10),
        ),
      ],
    );
  }

  /// Frosted pill used for status banners floating over content.
  static BoxDecoration frostedPill({
    BuildContext? context,
    double borderRadius = 16,
    Color? color,
  }) {
    final isLight = context != null && AppColors.isLight(context);
    return BoxDecoration(
      color:
          color ??
          (isLight
              ? AppColors.lightBackgroundSecondary
              : AppColors.backgroundSecondary),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: isLight
            ? AppColors.lightGlassBorderLight
            : AppColors.glassBorderLight,
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: isLight ? const Color(0x14000000) : const Color(0x40000000),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  static Widget backdropBlur({
    required Widget child,
    double blur = 16,
    double borderRadius = 20,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: child,
      ),
    );
  }
}
