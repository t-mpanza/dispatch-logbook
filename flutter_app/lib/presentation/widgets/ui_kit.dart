import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_decorations.dart';
import '../../core/utils/haptics.dart';
import '../../data/models/preset.dart';

/// FieldMate UI kit — shared building blocks so every screen feels like one
/// product. Big touch targets, plain language, consistent feedback, and
/// every component adapts to Sunlight Mode automatically.
class SectionHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 3),
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 20,
    this.color,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: GlassDecorations.glassCard(
        context: context,
        borderRadius: borderRadius,
        color: color,
        borderColor: borderColor,
      ),
      child: child,
    );
    if (onTap == null) return card;
    return InkWell(
      onTap: () {
        AppHaptics.light();
        onTap!();
      },
      borderRadius: BorderRadius.circular(borderRadius),
      child: card,
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.35),
              ),
            ),
            child: Icon(
              icon,
              size: 34,
              color: AppColors.dynamicAccent(context),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

enum PillTone { success, warning, error, info, brand, neutral }

class StatusPill extends StatelessWidget {
  final String label;
  final PillTone tone;
  final IconData? icon;
  final VoidCallback? onTap;

  const StatusPill({
    super.key,
    required this.label,
    this.tone = PillTone.neutral,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = _fgFor(tone, context);
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: fg.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: fg,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return pill;
    return InkWell(
      onTap: () {
        AppHaptics.light();
        onTap!();
      },
      borderRadius: BorderRadius.circular(100),
      child: pill,
    );
  }

  Color _fgFor(PillTone t, BuildContext context) {
    switch (t) {
      case PillTone.success:
        return AppColors.success;
      case PillTone.warning:
        return AppColors.warning;
      case PillTone.error:
        return AppColors.error;
      case PillTone.info:
        return AppColors.info;
      case PillTone.brand:
        return AppColors.dynamicAccent(context);
      case PillTone.neutral:
        return AppColors.dynamicTextSecondary(context);
    }
  }
}

class KpiTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? accent;

  const KpiTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppColors.dynamicTextPrimary(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.dynamicAccent(context)),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w900,
            color: color,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AppColors.dynamicTextMuted(context),
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }
}

class AppSheet extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const AppSheet({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 10, 20, 20),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.dynamicBackgroundSecondary(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.isLight(context)
                      ? AppColors.lightGlassBorder
                      : Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

Future<void> showAppSheet(BuildContext context, {required Widget child}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => AppSheet(child: child),
  );
}

class AppSnacks {
  static void show(
    BuildContext context, {
    required String message,
    PillTone tone = PillTone.neutral,
    IconData? icon,
    Duration duration = const Duration(seconds: 2),
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: _fg(tone, context)),
              const SizedBox(width: 10),
            ],
            Expanded(child: Text(message)),
          ],
        ),
        duration: duration,
      ),
    );
  }

  static void success(BuildContext context, String message) => show(
    context,
    message: message,
    tone: PillTone.success,
    icon: Icons.check_circle_rounded,
  );

  static void error(BuildContext context, String message) => show(
    context,
    message: message,
    tone: PillTone.error,
    icon: Icons.error_rounded,
  );

  static void info(BuildContext context, String message) => show(
    context,
    message: message,
    tone: PillTone.info,
    icon: Icons.info_rounded,
  );

  static Color _fg(PillTone tone, BuildContext context) {
    switch (tone) {
      case PillTone.success:
        return AppColors.success;
      case PillTone.warning:
        return AppColors.warning;
      case PillTone.error:
        return AppColors.error;
      case PillTone.info:
        return AppColors.info;
      case PillTone.brand:
        return AppColors.dynamicAccent(context);
      case PillTone.neutral:
        return AppColors.dynamicTextPrimary(context);
    }
  }
}

class AppDialogs {
  /// Destructive confirmation dialog with a clear, unambiguous layout.
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Delete',
    IconData icon = Icons.delete_outline_rounded,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.error, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.dynamicTextPrimary(context),
                ),
              ),
            ),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Keep it',
              style: TextStyle(color: AppColors.dynamicTextSecondary(context)),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 48),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result == true;
  }
}

Color presetColor(PresetKey? key, String tripId) {
  final name = (key?.name ?? tripId).toUpperCase();
  if (name.contains('NLH') || name.contains('NEIL')) return AppColors.presetNlh;
  if (name.contains('STOCKS')) return AppColors.presetStocks;
  if (name.contains('DBN')) return AppColors.presetDbn;
  if (name.contains('PLK')) return AppColors.presetPlk;
  if (name.contains('BLOEM')) return AppColors.presetBloem;
  if (name.contains('TIREPOINT')) return AppColors.presetTirepoint;
  return AppColors.presetCustom;
}

class PresetBadge extends StatelessWidget {
  final PresetKey? presetKey;
  final String tripId;

  const PresetBadge({super.key, this.presetKey, this.tripId = ''});

  @override
  Widget build(BuildContext context) {
    final color = presetColor(presetKey, tripId);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        tripId.isNotEmpty ? tripId.toUpperCase() : 'TRIP',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// Scales the child down slightly while pressed, giving physical feedback
/// on every interactive element in the field.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? caption;
  final Color color;
  final VoidCallback onTap;

  const ActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.caption,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () {
        AppHaptics.medium();
        onTap();
      },
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withValues(alpha: 0.4)),
              ),
              child: Icon(icon, size: 26, color: color),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.dynamicTextPrimary(context),
              ),
            ),
            if (caption != null) ...[
              const SizedBox(height: 2),
              Text(
                caption!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.dynamicTextMuted(context),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
