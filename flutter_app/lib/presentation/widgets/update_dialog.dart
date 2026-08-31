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
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  String? _errorMessage;
  bool _isInstalling = false;

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  Future<void> _handleStartDownloadAndInstall() async {
    final apkUrl = widget.updateInfo.apkDownloadUrl;
    if (apkUrl == null || !apkUrl.endsWith('.apk')) {
      // Fallback to browser if no direct APK asset found
      AppHaptics.light();
      await UpdateService.openDownload(
          widget.updateInfo.releaseUrl ?? UpdateService.releasesPageUrl);
      if (mounted) Navigator.pop(context);
      return;
    }

    AppHaptics.medium();
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _receivedBytes = 0;
      _totalBytes = 0;
      _errorMessage = null;
      _isInstalling = false;
    });

    final success = await UpdateService.downloadAndInstallApk(
      apkUrl,
      onProgress: (progress, received, total) {
        if (mounted) {
          setState(() {
            _downloadProgress = progress;
            _receivedBytes = received;
            _totalBytes = total;
          });
        }
      },
    );

    if (mounted) {
      if (success) {
        AppHaptics.success();
        setState(() {
          _isInstalling = true;
        });
      } else {
        AppHaptics.error();
        setState(() {
          _isDownloading = false;
          _errorMessage =
              'Could not launch installer automatically. Tap below to download manually via browser.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.updateInfo;
    final pctText = '${(_downloadProgress * 100).toStringAsFixed(0)}%';

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
                        info.hasUpdate
                            ? Icons.system_update_rounded
                            : Icons.check_circle_rounded,
                        color: info.hasUpdate
                            ? AppColors.primaryGlow
                            : AppColors.success,
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
                            color: info.hasUpdate
                                ? AppColors.primaryGlow
                                : AppColors.success,
                            letterSpacing: 1.5,
                          ),
                        ),
                        Text(
                          info.hasUpdate
                              ? 'New Version Available'
                              : 'Latest Release Installed',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Version Comparison Box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: GlassDecorations.glassCard(borderRadius: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text('CURRENT',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textMuted,
                              letterSpacing: 0.8)),
                      const SizedBox(height: 4),
                      Text(info.currentVersion,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                              fontFamily: 'monospace')),
                    ],
                  ),
                  const Icon(Icons.arrow_forward_rounded,
                      size: 16, color: AppColors.textMuted),
                  Column(
                    children: [
                      const Text('LATEST CANDIDATE',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textMuted,
                              letterSpacing: 0.8)),
                      const SizedBox(height: 4),
                      Text(
                        info.latestVersion,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: info.hasUpdate
                              ? AppColors.primaryGlow
                              : AppColors.success,
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
            if (info.releaseNotes != null &&
                info.releaseNotes!.isNotEmpty &&
                !_isDownloading) ...[
              const Text('WHAT\'S NEW',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textMuted,
                      letterSpacing: 1.0)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 120),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    info.releaseNotes!,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Active In-App Downloading Card
            if (_isDownloading) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: GlassDecorations.glassCard(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            if (_isInstalling)
                              const Icon(Icons.check_circle_rounded,
                                  color: AppColors.success, size: 18)
                            else
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primaryGlow,
                                ),
                              ),
                            const SizedBox(width: 8),
                            Text(
                              _isInstalling
                                  ? 'Launching System Installer…'
                                  : 'Downloading Update ($pctText)…',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        if (_totalBytes > 0)
                          Text(
                            '${_formatBytes(_receivedBytes)} / ${_formatBytes(_totalBytes)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                              fontFamily: 'monospace',
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: _downloadProgress > 0 ? _downloadProgress : null,
                        minHeight: 8,
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _isInstalling
                              ? AppColors.success
                              : AppColors.primaryGlow,
                        ),
                      ),
                    ),
                    if (_isInstalling) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'Tap "Update" on the system prompt to apply changes and reopen.',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.success,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Error Message
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppColors.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                            color: AppColors.error, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Action Buttons
            if (info.hasUpdate && !_isDownloading) ...[
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _handleStartDownloadAndInstall,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 6,
                  ),
                  icon: const Icon(Icons.system_update_rounded,
                      color: Colors.white, size: 20),
                  label: Text(
                    'AUTO-UPDATE NOW (${info.latestVersion})',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Browser Fallback link
            if (!_isDownloading)
              SizedBox(
                width: double.infinity,
                height: 42,
                child: OutlinedButton.icon(
                  onPressed: () {
                    AppHaptics.light();
                    UpdateService.openDownload(
                        info.releaseUrl ?? UpdateService.releasesPageUrl);
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.glassBorder),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.open_in_browser_rounded,
                      size: 16, color: AppColors.textSecondary),
                  label: const Text('View Release on GitHub',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
