import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_decorations.dart';
import '../../core/utils/haptics.dart';
import '../../data/services/database_service.dart';
import '../../dispatch/domain/tyre_story.dart';
import '../../dispatch/hardware/nfc_scan_service.dart';

/// The inspection HUD — NFC-first. Every tyre carries an NFC chip; the app
/// actively expects a scan and resolves the tag live. Typed slip/serial
/// entry stays as the fallback for tags that won't read.
class DispatchInspectScreen extends StatefulWidget {
  const DispatchInspectScreen({super.key});

  @override
  State<DispatchInspectScreen> createState() => _DispatchInspectScreenState();
}

class _FeedEntry {
  const _FeedEntry(this.identifier, this.label, this.color);

  final String identifier;
  final String label;
  final Color color;
}

class _DispatchInspectScreenState extends State<DispatchInspectScreen> with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final NfcScanService _nfc = NfcScanService();
  StreamSubscription<String>? _scanSub;

  final List<_FeedEntry> _feed = [];
  bool _busy = false;
  bool _nfcArmed = false;
  bool _nfcAvailable = false;
  TyreStory? _last;
  String? _banner;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restoreDecisions();
    _checkNfc();
    _scanSub = _nfc.scans.listen(_onNfcScan);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanSub?.cancel();
    _nfc.stop();
    _nfc.dispose();
    _controller.dispose();
    super.dispose();
  }

  bool _resumeNfc = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_resumeNfc && _nfcAvailable) {
        _resumeNfc = false;
        _armNfc();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      if (_nfcArmed) {
        _resumeNfc = true;
        _disarmNfc();
      }
    }
  }

  Future<void> _checkNfc() async {
    final available = await _nfc.isAvailable;
    if (!mounted) return;
    setState(() => _nfcAvailable = available);
    if (available) {
      await _armNfc();
    }
  }

  Future<void> _armNfc() async {
    try {
      await _nfc.start();
      if (mounted) setState(() => _nfcArmed = true);
    } catch (_) {
      if (mounted) setState(() => _nfcArmed = false);
    }
  }

  Future<void> _disarmNfc() async {
    await _nfc.stop();
    if (mounted) setState(() => _nfcArmed = false);
  }

  Future<void> _onNfcScan(String uid) async {
    if (_busy) return;
    AppHaptics.medium();
    setState(() {
      _busy = true;
      _banner = null;
      _last = null;
      _controller.text = uid;
    });

    try {
      final story = await const TyreStoryUsecase().byUid(uid);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _last = story;
        if (story == null) {
          _banner = 'Tag $uid — no tyre on the system.';
          AppHaptics.error();
        } else {
          AppHaptics.success();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _banner = 'Scan failed: $e';
      });
      AppHaptics.error();
    }
  }

  Future<void> _restoreDecisions() async {
    final decisions = await DatabaseService.getDispatchDecisions();
    if (!mounted) return;
    setState(() {
      for (final entry in decisions.entries) {
        final parts = entry.value.split('|');
        final label = parts[0] == 'APPROVE'
            ? 'APPROVED'
            : 'SCRAPPED${parts.length > 1 ? ' — ${parts[1]}' : ''}';
        _feed.insert(
          0,
          _FeedEntry(
            entry.key,
            label,
            parts[0] == 'APPROVE'
                ? AppColors.successStrong(context)
                : AppColors.errorStrong(context),
          ),
        );
      }
    });
  }

  String _identifierFor(TyreStory story) {
    final slip = story.tyre.slipNumber;
    if (slip != null) return 'SLIP $slip';
    final serial = story.tyre.serial;
    if (serial != null && serial.isNotEmpty) return serial;
    final uid = story.tyre.uid;
    if (uid != null && uid.isNotEmpty) return 'TAG $uid';
    return _controller.text.trim().toUpperCase();
  }

  Future<void> _typedLookup() async {
    final input = _controller.text.trim().toUpperCase();
    if (input.isEmpty) return;
    AppHaptics.medium();
    setState(() {
      _busy = true;
      _banner = null;
      _last = null;
    });

    try {
      const usecase = TyreStoryUsecase();
      final asNumber = int.tryParse(input);
      final story = asNumber != null
          ? await usecase.bySlipOrJobNumber(asNumber)
          : await usecase.bySerial(input);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _last = story;
        if (story == null) {
          _banner = 'No tyre found for "$input".';
          AppHaptics.error();
        } else {
          AppHaptics.light();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _banner = 'Lookup failed: $e';
      });
      AppHaptics.error();
    }
  }

  Future<void> _approve() async {
    final story = _last;
    if (story == null) return;
    final identifier = _identifierFor(story);
    AppHaptics.success();
    await DatabaseService.saveDispatchDecision(
      uid: identifier,
      decision: 'APPROVE',
    );
    if (!mounted) return;
    setState(() {
      _feed.insert(
        0,
        _FeedEntry(
          identifier,
          'APPROVED',
          AppColors.successStrong(context),
        ),
      );
      _last = null;
      _controller.clear();
    });
  }

  Future<void> _scrap() async {
    final story = _last;
    if (story == null) return;
    final reason = await _pickScrapReason();
    if (reason == null || !mounted) return;
    final identifier = _identifierFor(story);
    AppHaptics.success();
    await DatabaseService.saveDispatchDecision(
      uid: identifier,
      decision: 'SCRAP',
      reason: reason,
    );
    if (!mounted) return;
    setState(() {
      _feed.insert(
        0,
        _FeedEntry(
          identifier,
          'SCRAPPED — $reason',
          AppColors.errorStrong(context),
        ),
      );
      _last = null;
      _controller.clear();
    });
  }

  Future<String?> _pickScrapReason() async {
    var selected = 'DAMAGED';
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text('Scrap reason'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final reason in const [
                      'DAMAGED',
                      'WRONG TYRE',
                      'DUMP',
                      'NOT ON DOCUMENT',
                      'OTHER',
                    ])
                      ChoiceChip(
                        label: Text(reason),
                        selected: selected == reason,
                        onSelected: (_) =>
                            setDialogState(() => selected = reason),
                      ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.dynamicTextMuted(context)),
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, selected),
                child: const Text('Scrap it'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final story = _last;
    final scrap = story?.isScrapWithHistory ?? false;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      children: [
        // ── NFC STATUS ──────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: GlassDecorations.glassCard(
            context: context,
            borderRadius: 16,
            borderColor: (_nfcArmed ? AppColors.successStrong(context) : AppColors.warningStrong(context))
                .withValues(alpha: 0.4),
          ),
          child: Row(
            children: [
              Icon(
                Icons.nfc_rounded,
                size: 22,
                color: _nfcArmed
                    ? AppColors.successStrong(context)
                    : AppColors.warningStrong(context),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _nfcArmed ? 'SCANNING — WAITING FOR TAG' : 'NFC OFF',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                        color: _nfcArmed
                            ? AppColors.successStrong(context)
                            : AppColors.warningStrong(context),
                      ),
                    ),
                    Text(
                      _nfcAvailable
                          ? 'Hold the tyre tag to the reader'
                          : 'No NFC hardware on this device',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.dynamicTextMuted(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (_nfcAvailable)
                TextButton(
                  onPressed: _nfcArmed ? _disarmNfc : _armNfc,
                  child: Text(_nfcArmed ? 'Stop' : 'Arm'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Typed fallback ─────────────────────────────────────────────────
        Container(
          decoration: GlassDecorations.glassCard(context: context, borderRadius: 16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  textCapitalization: TextCapitalization.characters,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                    letterSpacing: 1.4,
                    color: AppColors.dynamicTextPrimary(context),
                  ),
                  decoration: InputDecoration(
                    hintText: 'SLIP / SERIAL / UID FALLBACK',
                    hintStyle: TextStyle(
                      fontSize: 11,
                      color: AppColors.dynamicTextMuted(context),
                      letterSpacing: 0.6,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _typedLookup(),
                ),
              ),
              IconButton(
                onPressed: _busy ? null : _typedLookup,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search_rounded, color: AppColors.info),
                tooltip: 'Resolve',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        if (_banner != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.errorBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _banner!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.error),
            ),
          ),

        if (story != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: GlassDecorations.glassCard(
              context: context,
              borderRadius: 18,
              borderColor: (scrap
                      ? AppColors.errorStrong(context)
                      : AppColors.successStrong(context))
                  .withValues(alpha: 0.5),
            ),
            child: Column(
              children: [
                Text(
                  story.tyre.customerName ?? 'Unknown customer',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: AppColors.dynamicTextPrimary(context),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  story.tyre.displayLabel,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dynamicTextSecondary(context),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'SLIP ${story.tyre.slipNumber ?? '—'} · '
                  'CS ${story.tyre.csNumber ?? '—'}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                    color: AppColors.infoStrong(context),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _DecisionButton(
                        label: 'APPROVE',
                        icon: Icons.check_rounded,
                        color: AppColors.successStrong(context),
                        onTap: _approve,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DecisionButton(
                        label: 'SCRAP',
                        icon: Icons.close_rounded,
                        color: AppColors.errorStrong(context),
                        onTap: _scrap,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 18),
        Text(
          'DECISION FEED · ${_feed.length}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
            color: AppColors.dynamicTextMuted(context),
          ),
        ),
        const SizedBox(height: 8),
        if (_feed.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Decisions land here as you approve or scrap tyres.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.dynamicTextMuted(context),
              ),
            ),
          )
        else
          for (final entry in _feed.take(50)) _feedTile(entry),
      ],
    );
  }

  Widget _feedTile(_FeedEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: entry.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: entry.color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.circle, size: 10, color: entry.color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              entry.identifier,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                fontFamily: 'monospace',
                letterSpacing: 1.2,
                color: AppColors.dynamicTextPrimary(context),
              ),
            ),
          ),
          Text(
            entry.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              color: entry.color,
            ),
          ),
        ],
      ),
    );
  }
}

class _DecisionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DecisionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.55)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
