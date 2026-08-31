import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_decorations.dart';
import '../../core/utils/haptics.dart';
import '../../data/models/sync_state.dart';
import '../../data/repositories/entry_repository.dart';
import 'connection_status_banner.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  final int currentIndex;
  final Function(int) onTabSelected;

  const AppShell({
    super.key,
    required this.child,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = AppColors.isLight(context);

    return Scaffold(
      backgroundColor: AppColors.dynamicBackground(context),
      body: Stack(
        children: [
          // Background ambient gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.0, -0.6),
                  radius: 1.2,
                  colors: isLight
                      ? const [
                          Color(0xFFE2E8F0), // light slate glow
                          Color(0xFFF1F5F9), // slate 100
                        ]
                      : const [
                          Color(0x1A2563EB), // 10% cobalt glow
                          Color(0xFF0B0C12),
                        ],
                ),
              ),
            ),
          ),

          // Main content
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const ConnectionStatusBanner(),
                Expanded(child: child),
              ],
            ),
          ),

          // Floating Dock Navigation
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                decoration: GlassDecorations.glassDock(context: context),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildNavItem(
                      context: context,
                      index: 0,
                      label: 'Today',
                      icon: Icons.home_rounded,
                      isActive: currentIndex == 0,
                    ),
                    _buildNavItem(
                      context: context,
                      index: 1,
                      label: 'Sheet',
                      icon: Icons.description_rounded,
                      isActive: currentIndex == 1,
                    ),
                    _buildNavItem(
                      context: context,
                      index: 2,
                      label: 'Counter',
                      icon: Icons.local_shipping_rounded,
                      isActive: currentIndex == 2,
                    ),
                    _buildNavItem(
                      context: context,
                      index: 3,
                      label: 'Search',
                      icon: Icons.search_rounded,
                      isActive: currentIndex == 3,
                    ),
                    _buildNavItem(
                      context: context,
                      index: 4,
                      label: 'Archive',
                      icon: Icons.folder_rounded,
                      isActive: currentIndex == 4,
                    ),
                    _buildSyncButton(context),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required int index,
    required String label,
    required IconData icon,
    required bool isActive,
  }) {
    final isLight = AppColors.isLight(context);

    return GestureDetector(
      onTap: () {
        AppHaptics.light();
        onTabSelected(index);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: isLight ? 0.15 : 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? (isLight ? AppColors.primary : AppColors.primaryGlow.withValues(alpha: 0.4))
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isActive
                  ? (isLight ? AppColors.primary : AppColors.primaryGlow)
                  : AppColors.dynamicTextMuted(context),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                color: isActive
                    ? AppColors.dynamicTextPrimary(context)
                    : AppColors.dynamicTextMuted(context),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncButton(BuildContext context) {
    final isLight = AppColors.isLight(context);

    return Consumer<EntryRepository>(
      builder: (context, repo, _) {
        final state = repo.syncState;
        IconData iconData = Icons.cloud_done_rounded;
        Color iconColor = isLight ? AppColors.primary : AppColors.primaryGlow;
        String statusText = 'Live';

        if (state.status == SyncStatus.syncing) {
          iconData = Icons.sync_rounded;
          iconColor = isLight ? AppColors.primary : AppColors.primaryGlow;
          statusText = 'Sync';
        } else if (state.status == SyncStatus.error) {
          iconData = Icons.error_outline_rounded;
          iconColor = AppColors.error;
          statusText = 'Retry';
        } else if (state.status == SyncStatus.offline) {
          iconData = Icons.cloud_off_rounded;
          iconColor = AppColors.dynamicTextMuted(context);
          statusText = 'Off';
        }

        return GestureDetector(
          onTap: () async {
            AppHaptics.medium();
            final success = await repo.syncNow();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: isLight ? Colors.white : AppColors.backgroundSecondary,
                  content: Text(
                    success
                        ? 'Cloud database synchronized'
                        : (state.errorMessage ?? 'Sync failed — check network'),
                    style: TextStyle(
                      color: success ? AppColors.success : AppColors.error,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isLight ? const Color(0xFFF1F5F9) : AppColors.glassSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isLight ? const Color(0xFFCBD5E1) : AppColors.glassBorderLight,
                        ),
                      ),
                      child: Center(
                        child: state.status == SyncStatus.syncing
                            ? SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: iconColor,
                                ),
                              )
                            : Icon(iconData, size: 16, color: iconColor),
                      ),
                    ),
                    if (state.pendingCount > 0)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: AppColors.warning,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${state.pendingCount}',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 9,
                    color: AppColors.dynamicTextMuted(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
