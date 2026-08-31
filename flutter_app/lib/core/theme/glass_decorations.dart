import 'dart:ui';
import 'package:flutter/material.dart';
import 'app_colors.dart';

class GlassDecorations {
  static BoxDecoration glassCard({
    BuildContext? context,
    double borderRadius = 20,
    Color? color,
    Color? borderColor,
  }) {
    final isLight = context != null && Theme.of(context).brightness == Brightness.light;

    return BoxDecoration(
      color: color ?? (isLight ? Colors.white : AppColors.glassSurface),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? (isLight ? const Color(0xFFCBD5E1) : AppColors.glassBorder),
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
    final isLight = context != null && Theme.of(context).brightness == Brightness.light;

    return BoxDecoration(
      color: color ?? (isLight ? Colors.white : AppColors.glassSurfaceElevated),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? (isLight ? const Color(0xFFCBD5E1) : AppColors.glassBorder),
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
    final isLight = context != null && Theme.of(context).brightness == Brightness.light;

    return BoxDecoration(
      color: isLight ? Colors.white.withValues(alpha: 0.96) : AppColors.dockBackground,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: isLight ? const Color(0xFFCBD5E1) : AppColors.glassBorder,
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: isLight ? const Color(0x1F000000) : const Color(0x66000000),
          blurRadius: isLight ? 20 : 30,
          offset: isLight ? const Offset(0, 6) : const Offset(0, 10),
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
