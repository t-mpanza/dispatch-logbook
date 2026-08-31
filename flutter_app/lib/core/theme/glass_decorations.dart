import 'dart:ui';
import 'package:flutter/material.dart';
import 'app_colors.dart';

class GlassDecorations {
  static BoxDecoration glassCard({
    double borderRadius = 20,
    Color? color,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: color ?? AppColors.glassSurface,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? AppColors.glassBorder,
        width: 1,
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: 16,
          offset: Offset(0, 4),
        ),
      ],
    );
  }

  static BoxDecoration glassElevated({
    double borderRadius = 24,
    Color? color,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: color ?? AppColors.glassSurfaceElevated,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? AppColors.glassBorder,
        width: 1,
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x4D000000),
          blurRadius: 24,
          offset: Offset(0, 8),
        ),
      ],
    );
  }

  static BoxDecoration glassDock({double borderRadius = 28}) {
    return BoxDecoration(
      color: AppColors.dockBackground,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: AppColors.glassBorder,
        width: 1,
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x66000000),
          blurRadius: 30,
          offset: Offset(0, 10),
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
