import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/theme/app_colors.dart';
import '../../core/utils/haptics.dart';
import '../../data/services/update_service.dart';

/// The in-app version picker — INSTALL a newer release or ROLL BACK to
/// an older one, all through the same resumable, SHA-256-verified
/// pipeline. Downgrades are attempted via the system installer; Android
/// may refuse them, in which case the downloaded (verified) APK stays on
/// disk and the sheet tells the operator where it is.
class VersionPickerSheet extends StatefulWidget {
  const VersionPickerSheet({
    super.key,
    this.client,
    this.storageBase,
    this.currentVersionOverride,
  });

  /// Test seams.
  final http.Client? client;
  final Directory? storageBase;

  /// Production reads the installed version; tests pin it.
  final String? currentVersionOverride;

  static void show(
    BuildContext context, {
    http.Client? client,
    Directory? storageBase,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) =>
          VersionPickerSheet(client: client, storageBase: storageBase),
    );
  }

  @override
  State<VersionPickerSheet> createState() => _VersionPickerSheetState();
}

class _VersionPickerSheetState extends State<VersionPickerSheet> {
  List<ReleaseInfo> _releases = const [];
  String _current = '';
  bool _loading = true;
  bool _busy = false;
  String? _busyTag;
  double _progress = 0;
  String? _message;
  bool _messageOk = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final current = widget.currentVersionOverride ??
        await UpdateService.getCurrentVersion();
    final releases = await UpdateService.listReleases(client: widget.client);
    if (!mounted) return;
    setState(() {
      _current = current;
      _releases = releases;
      _loading = false;
    });
  }

  Future<void> _install(ReleaseInfo release) async {
    if (_busy) return;
    final isDowngrade = _current.isNotEmpty && release.tag != _current &&
        UpdateService.compareVersions(release.tag, _current) < 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isDowngrade ? 'ROLL BACK?' : 'INSTALL?',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Text(
          isDowngrade
              ? 'Install ${release.tag} over $_current?\n\nAndroid may '
                  'block downgrades — if the installer refuses, uninstall '
                  'the app and open the downloaded file instead.'
              : 'Download and install ${release.tag}?',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'DOWNLOAD',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    AppHaptics.medium();
    setState(() {
      _busy = true;
      _busyTag = release.tag;
      _progress = 0;
      _message = null;
    });

    final outcome = await UpdateService.resumeDownload(
      release.asUpdateInfo(_current),
      client: widget.client,
      storageBase: widget.storageBase,
      onProgress: (progress, received, total) {
        if (mounted) setState(() => _progress = progress);
      },
    );

    if (!mounted) return;
    if (outcome.error != null) {
      AppHaptics.error();
      setState(() {
        _busy = false;
        _busyTag = null;
        _message = 'Download failed — ${outcome.error}';
        _messageOk = false;
      });
      return;
    }

    AppHaptics.success();
    try {
      await UpdateService.installApk(outcome.filePath!);
      if (mounted) {
        setState(() {
          _busy = false;
          _busyTag = null;
          _message = isDowngrade
              ? 'Installer launched. If Android blocked the downgrade: '
                  'uninstall the app, then open\n${outcome.filePath}'
              : 'Installer launched — ${release.tag}';
          _messageOk = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyTag = null;
          _message = 'Install failed: $e';
          _messageOk = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
            const SizedBox(height: 14),
            Text(
              'APP VERSIONS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: AppColors.dynamicTextMuted(context),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Install or roll back · current: $_current',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.dynamicTextMuted(context),
              ),
            ),
            const SizedBox(height: 10),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (_releases.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'Could not reach the release server.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.dynamicTextMuted(context),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final r in _releases) _releaseRow(context, r),
                  ],
                ),
              ),
            if (_message != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (_messageOk
                          ? AppColors.successStrong(context)
                          : AppColors.errorStrong(context))
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _message!,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: _messageOk
                        ? AppColors.successStrong(context)
                        : AppColors.errorStrong(context),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _releaseRow(BuildContext context, ReleaseInfo r) {
    final isCurrent = r.tag == _current;
    final busy = _busy && _busyTag == r.tag;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      r.tag,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                        color: AppColors.dynamicTextPrimary(context),
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.successStrong(
                            context,
                          ).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'INSTALLED',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: AppColors.successStrong(context),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (r.publishedAt != null)
                  Text(
                    'Released ${r.publishedAt!.substring(0, 10)}',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: AppColors.dynamicTextMuted(context),
                    ),
                  ),
              ],
            ),
          ),
          if (!isCurrent)
            busy
                ? SizedBox(
                    width: 90,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${(_progress * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: AppColors.dynamicTextMuted(context),
                          ),
                        ),
                      ],
                    ),
                  )
                : TextButton(
                    onPressed: _busy ? null : () => _install(r),
                    child: Text(
                      'INSTALL',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: AppColors.infoStrong(context),
                      ),
                    ),
                  ),
        ],
      ),
    );
  }
}
