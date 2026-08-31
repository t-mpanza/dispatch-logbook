import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_decorations.dart';
import '../../core/utils/haptics.dart';
import '../../data/services/update_service.dart';

class UpdateDialog extends StatefulWidget {
  final UpdateInfo updateInfo;

  const UpdateDialog({super.key, required this.updateInfo});

  static void show(BuildContext context, UpdateInfo updateInfo) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => UpdateDialog(updateInfo: updateInfo),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isLaunching = false;

  @override
  Widget build(BuildContext context) {
    final info = widget.updateInfo;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: info.hasUpdate
                            ? AppColors.primary.withValues(alpha: 0.2)
                            : AppColors.successBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        info.hasUpdate ? Icons.system_update_rounded : Icons.check_circle_rounded,
                        color: info.hasUpdate ? AppColors.primaryGlow : AppColors.success,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          info.hasUpdate ? 'UPDATE CANDIDATE' : 'UP TO DATE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: info.hasUpdate ? AppColors.primaryGlow : AppColors.success,
                            letterSpacing: 1.5,
                          ),
                        ),
                        Text(
                          info.hasUpdate ? 'New Version Available' : 'Latest Release Installed',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Release Channel Tag
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primaryGlow.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.primaryGlow.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.hub_outlined, size: 12, color: AppColors.primaryGlow),
                  const SizedBox(width: 4),
                  Text(
                    'Release Channel: ${info.releaseChannel}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryGlow),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Version Comparison Box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: GlassDecorations.glassCard(borderRadius: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text('CURRENT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 0.8)),
                      const SizedBox(height: 4),
                      Text(info.currentVersion, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.textPrimary, fontFamily: 'monospace')),
                    ],
                  ),
                  const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.textMuted),
                  Column(
                    children: [
                      const Text('LATEST CANDIDATE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 0.8)),
                      const SizedBox(height: 4),
                      Text(
                        info.latestVersion,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: info.hasUpdate ? AppColors.primaryGlow : AppColors.success,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Release Notes Section
            if (info.releaseNotes != null && info.releaseNotes!.isNotEmpty) ...[
              const Text('WHAT\'S NEW', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 1.0)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 140),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    info.releaseNotes!,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Action Buttons
            if (info.hasUpdate) ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isLaunching
                      ? null
                      : () async {
                          setState(() => _isLaunching = true);
                          AppHaptics.success();
                          final url = info.apkDownloadUrl ?? info.releaseUrl ?? UpdateService.releasesPageUrl;
                          await UpdateService.openDownload(url);
                          if (context.mounted) {
                            setState(() => _isLaunching = false);
                            Navigator.pop(context);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _isLaunching
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.download_rounded, color: Colors.white, size: 20),
                  label: Text(
                    _isLaunching ? 'Opening Download…' : 'DOWNLOAD & INSTALL APK (${info.latestVersion})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.6),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],

            // GitHub Releases Web link
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: () {
                  AppHaptics.light();
                  UpdateService.openDownload(info.releaseUrl ?? UpdateService.releasesPageUrl);
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.glassBorder),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.open_in_browser_rounded, size: 16, color: AppColors.textSecondary),
                label: const Text('View All Releases on GitHub', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
