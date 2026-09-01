import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

enum _DownloadState { idle, downloading, done, error }

class _UpdateDialogState extends State<UpdateDialog> {
  _DownloadState _downloadState = _DownloadState.idle;
  double _progress = 0.0;
  String? _errorText;
  String? _apkPath;

  static const _installChannel = MethodChannel('com.dispatchdiary.ibt_edition/install');

  Future<void> _startDownload() async {
    final url = widget.updateInfo.apkDownloadUrl;
    if (url == null || url.isEmpty) {
      setState(() {
        _downloadState = _DownloadState.error;
        _errorText = 'No APK download URL found for this release.';
      });
      return;
    }

    setState(() {
      _downloadState = _DownloadState.downloading;
      _progress = 0.0;
      _errorText = null;
    });

    AppHaptics.light();

    await for (final event in UpdateService.downloadApk(url)) {
      if (!mounted) return;

      if (event.error != null) {
        setState(() {
          _downloadState = _DownloadState.error;
          _errorText = 'Download failed: ${event.error}';
        });
        return;
      }

      setState(() => _progress = event.progress);

      if (event.filePath != null) {
        _apkPath = event.filePath;
        setState(() => _downloadState = _DownloadState.done);
        AppHaptics.success();
        await _triggerInstall(event.filePath!);
        return;
      }
    }
  }

  Future<void> _triggerInstall(String apkPath) async {
    try {
      await _installChannel.invokeMethod('installApk', {'path': apkPath});
    } on PlatformException catch (e) {
      // Fallback: open the file via Android intent through native side
      debugPrint('Install channel error: $e — trying fallback');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('APK saved to ${apkPath.split('/').last}. Tap to install.'),
            action: SnackBarAction(
              label: 'Install',
              onPressed: () => _triggerInstall(apkPath),
            ),
            duration: const Duration(seconds: 10),
          ),
        );
      }
    }
  }

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
                        info.hasUpdate
                            ? Icons.system_update_rounded
                            : Icons.check_circle_rounded,
                        color: info.hasUpdate ? AppColors.primaryGlow : AppColors.success,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          info.hasUpdate ? 'UPDATE AVAILABLE' : 'UP TO DATE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: info.hasUpdate ? AppColors.primaryGlow : AppColors.success,
                            letterSpacing: 1.5,
                          ),
                        ),
                        Text(
                          info.hasUpdate ? 'New Version Ready to Install' : 'Latest Release Installed',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                  onPressed: _downloadState == _DownloadState.downloading
                      ? null
                      : () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Release Channel Badge
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
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGlow,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Version comparison row
            Container(
              padding: const EdgeInsets.all(14),
              decoration: GlassDecorations.glassCard(borderRadius: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text('INSTALLED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 0.8)),
                      const SizedBox(height: 4),
                      Text(info.currentVersion,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.textPrimary, fontFamily: 'monospace')),
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

            // Release notes
            if (info.releaseNotes != null && info.releaseNotes!.isNotEmpty) ...[
              const Text("WHAT'S NEW",
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 1.0)),
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
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Error message
            if (_errorText != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_errorText!,
                          style: const TextStyle(fontSize: 12, color: Colors.redAccent)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Download / progress section
            if (info.hasUpdate) ...[
              if (_downloadState == _DownloadState.downloading) ...[
                // Progress Bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Downloading APK…',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        Text(
                          _progress < 0 ? '—' : '${(_progress * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryGlow),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _progress < 0
                          ? const LinearProgressIndicator(
                              backgroundColor: Color(0xFF2A2A3A),
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGlow),
                              minHeight: 8,
                            )
                          : LinearProgressIndicator(
                              value: _progress,
                              backgroundColor: const Color(0xFF2A2A3A),
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryGlow),
                              minHeight: 8,
                            ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Please keep the app open until the download completes.',
                      style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ] else if (_downloadState == _DownloadState.done) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.successBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Download complete!',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.success)),
                            Text('The Android installer should have opened.',
                                style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                      if (_apkPath != null)
                        TextButton(
                          onPressed: () => _triggerInstall(_apkPath!),
                          child: const Text('Install', style: TextStyle(color: AppColors.success)),
                        ),
                    ],
                  ),
                ),
              ] else ...[
                // Primary download button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _startDownload,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.download_rounded, color: Colors.white, size: 22),
                    label: Text(
                      'DOWNLOAD & INSTALL ${info.latestVersion}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
            ],

            // Fallback: View on GitHub
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: _downloadState == _DownloadState.downloading
                    ? null
                    : () {
                        AppHaptics.light();
                        UpdateService.openReleasePage(
                            info.releaseUrl ?? UpdateService.releasesPageUrl);
                      },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.glassBorder),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.open_in_browser_rounded, size: 16, color: AppColors.textSecondary),
                label: const Text('View All Releases on GitHub',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
