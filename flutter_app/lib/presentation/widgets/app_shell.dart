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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background ambient gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.0, -0.6),
                  radius: 1.2,
                  colors: [
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

          // Floating Titanium Obsidian Dock Navigation
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                decoration: GlassDecorations.glassDock(),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildNavItem(
                      index: 0,
                      label: 'Today',
                      icon: Icons.home_rounded,
                      isActive: currentIndex == 0,
                    ),
                    _buildNavItem(
                      index: 1,
                      label: 'Sheet',
                      icon: Icons.description_rounded,
                      isActive: currentIndex == 1,
                    ),
                    _buildNavItem(
                      index: 2,
                      label: 'Counter',
                      icon: Icons.local_shipping_rounded,
                      isActive: currentIndex == 2,
                    ),
                    _buildNavItem(
                      index: 3,
                      label: 'Search',
                      icon: Icons.search_rounded,
                      isActive: currentIndex == 3,
                    ),
                    _buildNavItem(
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
    required int index,
    required String label,
    required IconData icon,
    required bool isActive,
  }) {
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
              ? AppColors.primary.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? AppColors.primaryGlow.withValues(alpha: 0.4)
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
              color: isActive ? AppColors.primaryGlow : AppColors.textSecondary,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                color: isActive ? AppColors.textPrimary : AppColors.textMuted,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncButton(BuildContext context) {
    return Consumer<EntryRepository>(
      builder: (context, repo, _) {
        final state = repo.syncState;
        IconData iconData = Icons.cloud_done_rounded;
        Color iconColor = AppColors.primaryGlow;
        String statusText = 'Live';

        if (state.status == SyncStatus.syncing) {
          iconData = Icons.sync_rounded;
          iconColor = AppColors.primaryGlow;
          statusText = 'Sync';
        } else if (state.status == SyncStatus.error) {
          iconData = Icons.error_outline_rounded;
          iconColor = AppColors.error;
          statusText = 'Retry';
        } else if (state.status == SyncStatus.offline) {
          iconData = Icons.cloud_off_rounded;
          iconColor = AppColors.textMuted;
          statusText = 'Off';
        }

        return GestureDetector(
          onTap: () async {
            AppHaptics.medium();
            final success = await repo.syncNow();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.backgroundSecondary,
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
                        color: AppColors.glassSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.glassBorderLight),
                      ),
                      child: Center(
                        child: state.status == SyncStatus.syncing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.primaryGlow),
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
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${state.pendingCount}',
                            style: const TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  statusText,
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMuted,
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
