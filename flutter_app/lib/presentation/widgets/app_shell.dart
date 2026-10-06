import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_decorations.dart';
import '../../core/utils/haptics.dart';
import 'connection_status_banner.dart';
import 'capture_action_sheet.dart';

/// App frame: content area, floating status banner and a dock
/// (Home / Sheet / History, plus a hidden Dispatch tab that only appears
/// after the 7-tap version ritual + passcode).
class AppShell extends StatelessWidget {
  final Widget child;
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final bool showDispatch;

  const AppShell({
    super.key,
    required this.child,
    required this.currentIndex,
    required this.onTabSelected,
    this.showDispatch = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dynamicBackground(context),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.0, -0.55),
                  radius: 1.15,
                  colors: AppColors.isLight(context)
                      ? const [Color(0xFFFFFFFF), Color(0xFFEFF6FF)]
                      : const [Color(0x1F2F6BFF), Color(0xFF0A0F1E)],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const ConnectionStatusBanner(),
                Expanded(child: child),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: SafeArea(
              top: false,
              child: _Dock(
                currentIndex: currentIndex,
                showDispatch: showDispatch,
                onTabSelected: onTabSelected,
              ),
            ),
          ),
          Positioned(
            right: 20,
            bottom: 96,
            child: SafeArea(
              top: false,
              child: _CaptureButton(onTap: () => showCaptureSheet(context)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dock extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final bool showDispatch;

  const _Dock({
    required this.currentIndex,
    required this.onTabSelected,
    required this.showDispatch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: GlassDecorations.glassDock(
        context: context,
        borderRadius: 26,
      ),
      child: Row(
        children: [
          _navItem(
            context,
            index: 0,
            icon: Icons.home_rounded,
            activeIcon: Icons.home_rounded,
            label: 'Home',
          ),
          _navItem(
            context,
            index: 1,
            icon: Icons.article_rounded,
            activeIcon: Icons.article_rounded,
            label: 'Sheet',
          ),
          _navItem(
            context,
            index: 2,
            icon: Icons.history_rounded,
            activeIcon: Icons.history_rounded,
            label: 'History',
          ),
          if (showDispatch)
            _navItem(
              context,
              index: 3,
              icon: Icons.radar_rounded,
              activeIcon: Icons.radar_rounded,
              label: 'Dispatch',
            ),
        ],
      ),
    );
  }

  Widget _navItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final isActive = currentIndex == index;
    final isLight = AppColors.isLight(context);
    final accent = isLight ? AppColors.primary : AppColors.primaryGlow;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          AppHaptics.light();
          onTabSelected(index);
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primary.withValues(alpha: isLight ? 0.14 : 0.22)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isActive
                  ? accent.withValues(alpha: 0.5)
                  : Colors.transparent,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  isActive ? activeIcon : icon,
                  key: ValueKey(isActive),
                  size: 24,
                  color: isActive
                      ? accent
                      : AppColors.dynamicTextSecondary(context),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  color: isActive
                      ? AppColors.dynamicTextPrimary(context)
                      : AppColors.dynamicTextMuted(context),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaptureButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CaptureButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AppHaptics.medium();
        onTap();
      },
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryLight, AppColors.primaryDark],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.45),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.25),
            width: 1.5,
          ),
        ),
        child: const Icon(Icons.add_rounded, size: 34, color: Colors.white),
      ),
    );
  }
}

/// Opens the capture menu: the core jobs a despatch worker does all day.
Future<void> showCaptureSheet(BuildContext context) {
  return CaptureActionSheet.show(context);
}
