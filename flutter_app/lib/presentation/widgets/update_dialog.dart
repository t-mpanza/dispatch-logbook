import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/haptics.dart';
import '../../data/services/update_download_store.dart';
import '../../data/services/update_service.dart';

/// The enterprise updater — resumable, verifiable, honest.
///
/// States: idle → downloading (persistent partial) → verifying checksum
/// → installing. Interruptions never lose work: the next open offers
/// RESUME (n%) or INSTALL (already verified) instead of re-downloading.
class UpdateDialog extends StatefulWidget {
  final UpdateInfo updateInfo;

  /// Test seam — production uses the app-support directory.
  final Directory? storageBase;

  const UpdateDialog({
    super.key,
    required this.updateInfo,
    this.storageBase,
  });

  static void show(
    BuildContext context,
    UpdateInfo updateInfo, {
    Directory? storageBase,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) =>
          UpdateDialog(updateInfo: updateInfo, storageBase: storageBase),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  static const _installChannel = MethodChannel(
    'com.dispatchdiary.dispatch_diary/install',
  );

  bool _busy = false;
  bool _verifying = false;
  bool _installing = false;
  bool _paused = false;
  bool _cancelled = false;
  double _progress = 0.0;
  int _received = 0;
  int _total = 0;
  String? _error;
  UpdateDownloadState? _resumeState;

  @override
  void initState() {
    super.initState();
    unawaited(_loadResumeState());
  }

  Future<void> _loadResumeState() async {
    final state = await UpdateService.existingDownloadState(
      widget.updateInfo.latestVersion,
      storageBase: widget.storageBase,
    );
    if (mounted && state != null) {
      setState(() {
        _resumeState = state;
        _received = state.received;
        _total = state.total;
        _progress = state.progress;
      });
    }
  }

  String _fmt(int bytes) {
    if (bytes <= 0) return '0 MB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _fmtSize(int? bytes) =>
      bytes == null ? '' : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

  bool get _resumable =>
      _resumeState != null && _resumeState!.phase != 'verified';
  bool get _readyToInstall =>
      _resumeState != null && _resumeState!.phase == 'verified';

  Future<void> _start() async {
    final info = widget.updateInfo;
    final apkUrl = info.apkDownloadUrl;
    if (apkUrl == null) {
      AppHaptics.light();
      await UpdateService.openReleasePage(
        info.releaseUrl ?? UpdateService.releasesPageUrl,
      );
      if (mounted) Navigator.pop(context);
      return;
    }

    AppHaptics.medium();
    setState(() {
      _busy = true;
      _paused = false;
      _cancelled = false;
      _error = null;
      _installing = false;
      _verifying = false;
    });

    final outcome = await UpdateService.resumeDownload(
      info,
      storageBase: widget.storageBase,
      isCancelled: () => _cancelled,
      onProgress: (progress, received, total) {
        if (!mounted) return;
        setState(() {
          _progress = progress;
          _received = received;
          _total = total;
          if (progress >= 1.0) {
            _verifying = true;
          }
        });
      },
    );

    if (!mounted) return;
    if (outcome.error != null) {
      if (outcome.error == 'cancelled') {
        AppHaptics.medium();
        setState(() {
          _busy = false;
          _paused = true;
          _verifying = false;
        });
        return;
      }
      AppHaptics.error();
      setState(() {
        _busy = false;
        _verifying = false;
        _error = outcome.error;
      });
      return;
    }

    AppHaptics.success();
    setState(() {
      _busy = false;
      _verifying = false;
      _installing = true;
    });
    try {
      await _installChannel.invokeMethod('installApk', {
        'path': outcome.filePath!,
      });
    } catch (e) {
      debugPrint('Install APK channel invoke failed: $e');
    }
  }

  void _pause() {
    AppHaptics.light();
    setState(() => _cancelled = true);
  }

  void _retry() {
    setState(() => _error = null);
    _start();
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.updateInfo;
    final isLight = AppColors.isLight(context);
    final accent = isLight ? AppColors.primary : AppColors.primaryGlow;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.dynamicSurfaceRaised(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: Border.all(color: AppColors.dynamicBorder(context)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.dynamicBorder(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    info.hasUpdate
                        ? Icons.system_update_rounded
                        : Icons.verified_rounded,
                    color: accent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dispatch Diary',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: AppColors.dynamicTextPrimary(context),
                        ),
                      ),
                      Text(
                        info.hasUpdate
                            ? 'A new version is ready'
                            : 'You\'re up to date',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.dynamicTextMuted(context),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: AppColors.dynamicTextMuted(context),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Version pill + release metadata
            Row(
              children: [
                _versionTag(
                  context,
                  info.currentVersion,
                  muted: true,
                  strike: info.hasUpdate,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: AppColors.dynamicTextMuted(context),
                  ),
                ),
                _versionTag(context, info.latestVersion, accent: accent),
              ],
            ),
            if (info.hasUpdate &&
                (info.publishedAt != null ||
                    info.apkSizeBytes != null ||
                    info.apkSha256 != null)) ...[
              const SizedBox(height: 8),
              Text(
                [
                  if (info.publishedAt != null)
                    'Released ${_formatDate(info.publishedAt!)}',
                  if (info.apkSizeBytes != null)
                    _fmtSize(info.apkSizeBytes),
                  if (info.apkSha256 != null) 'SHA-256 verified',
                ].join(' · '),
                style: TextStyle(
                  fontSize: 10.5,
                  color: AppColors.dynamicTextMuted(context),
                ),
              ),
            ],
            const SizedBox(height: 14),

            // Changelog (bulleted)
            if (info.hasUpdate &&
                info.releaseNotes != null &&
                info.releaseNotes!.isNotEmpty &&
                !_busy &&
                !_paused) ...[
              Text(
                'WHAT\'S NEW IN ${info.latestVersion.toUpperCase()}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: AppColors.dynamicTextMuted(context),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 130),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.dynamicSurfaceSunk(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  child: _changelogRows(context, info.releaseNotes!),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Downloading / verifying / installing
            if (_busy || _installing) ...[
              Row(
                children: [
                  if (_installing)
                    Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.successStrong(context),
                      size: 18,
                    )
                  else
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: accent,
                      ),
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _installing
                          ? 'Launching system installer…'
                          : _verifying
                              ? 'Verifying SHA-256 checksum…'
                              : 'Downloading ${(_progress * 100).toStringAsFixed(0)}%'
                                  '${_total > 0 ? ' · ${_fmt(_received)} / ${_fmt(_total)}' : ''}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.dynamicTextPrimary(context),
                      ),
                    ),
                  ),
                ],
              ),
              if (!_installing) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    minHeight: 8,
                    backgroundColor: AppColors.dynamicSurfaceSunk(context),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _verifying ? AppColors.warningStrong(context) : accent,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _pause,
                    child: Text(
                      'PAUSE — progress is saved',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.dynamicTextMuted(context),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
            ],

            // Paused state — the anti-"re-download" message
            if (_paused) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warningStrong(
                    context,
                  ).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.pause_circle_rounded,
                      size: 18,
                      color: AppColors.warningStrong(context),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Download paused — '
                        '${(_progress * 100).toStringAsFixed(0)}% saved. '
                        'It will resume here next time.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.warningStrong(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Error + retry
            if (_error != null) ...[
              Text(
                _error!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.errorStrong(context),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _retry,
                  child: const Text('TRY AGAIN'),
                ),
              ),
            ],

            // CTA
            if (info.hasUpdate && !_busy && !_installing) ...[
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _start,
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _readyToInstall
                        ? 'INSTALL — ${info.latestVersion}'
                        : _resumable
                            ? 'RESUME — ${(_progress * 100).toStringAsFixed(0)}%'
                            : 'UPDATE NOW — ${info.latestVersion}'
                                '${_fmtSize(info.apkSizeBytes).isEmpty ? '' : ' · ${_fmtSize(info.apkSizeBytes)}'}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: TextButton(
                  onPressed: () {
                    AppHaptics.light();
                    UpdateService.openReleasePage(
                      info.releaseUrl ?? UpdateService.releasesPageUrl,
                    );
                  },
                  child: Text(
                    'or open the release on GitHub',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.dynamicTextMuted(context),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _changelogRows(BuildContext context, String notes) {
    final lines = notes.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          if (line.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.dynamicTextMuted(context),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      line.trim().replaceFirst(RegExp(r'^[-*]\s*'), ''),
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: AppColors.dynamicTextSecondary(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  String _formatDate(String iso) {
    final t = DateTime.tryParse(iso);
    if (t == null) return iso;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[t.month - 1]} ${t.day}';
  }

  Widget _versionTag(
    BuildContext context,
    String version, {
    bool muted = false,
    bool strike = false,
    Color? accent,
  }) {
    final color = accent ??
        (muted
            ? AppColors.dynamicTextMuted(context)
            : AppColors.dynamicTextPrimary(context));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: accent != null
            ? accent.withValues(alpha: 0.12)
            : AppColors.dynamicSurfaceSunk(context),
        borderRadius: BorderRadius.circular(10),
        border: accent != null
            ? Border.all(color: accent.withValues(alpha: 0.5))
            : null,
      ),
      child: Text(
        version,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          fontFamily: 'monospace',
          letterSpacing: 0.5,
          color: color,
          decoration: strike ? TextDecoration.lineThrough : null,
          decorationColor: color,
        ),
      ),
    );
  }
}
