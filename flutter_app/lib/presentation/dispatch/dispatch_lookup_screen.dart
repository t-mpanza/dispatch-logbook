import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_decorations.dart';
import '../../core/utils/haptics.dart';
import '../../data/repositories/settings_repository.dart';
import '../../dispatch/domain/tyre_story.dart';
import '../../dispatch/hardware/nfc_scan_service.dart';
import '../../dispatch/models/dispatch_models.dart';

/// Tyre lookup: scan the NFC tag or type a slip number (the "cab number")
/// or serial. Customer, make and slip number lead the story.
class DispatchLookupScreen extends StatefulWidget {
  const DispatchLookupScreen({super.key});

  @override
  State<DispatchLookupScreen> createState() => _DispatchLookupScreenState();
}

enum _LookupMode { slip, serial }

class _DispatchLookupScreenState extends State<DispatchLookupScreen>
    with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final NfcScanService _nfc = NfcScanService();
  StreamSubscription<String>? _scanSub;

  _LookupMode _mode = _LookupMode.slip;
  bool _busy = false;
  bool _nfcArmed = false;
  bool _nfcAvailable = false;
  String? _error;
  TyreStory? _story;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Never keep the NFC session alive in the background — that is what
    // crashed the app on leave/reopen.
    if (state != AppLifecycleState.resumed && _nfcArmed) {
      _disarmNfc();
    }
  }

  Future<void> _checkNfc() async {
    final settings = context.read<SettingsRepository>();
    if (!settings.nfcEnabled) return;
    final available = await _nfc.isAvailable;
    if (!mounted) return;
    setState(() => _nfcAvailable = available);
  }

  Future<void> _armNfc() async {
    final settings = context.read<SettingsRepository>();
    if (!settings.nfcEnabled) return;
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
    // One read is enough — disarm immediately so the session never lingers.
    await _disarmNfc();
    if (_busy) return;
    AppHaptics.medium();
    setState(() {
      _busy = true;
      _error = null;
      _story = null;
      _controller.text = uid;
    });

    try {
      final story = await const TyreStoryUsecase().byUid(uid);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _story = story;
        if (story == null) _error = 'Tag $uid — no tyre on the system.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Scan failed: $e';
      });
    }
  }

  Future<void> _search() async {
    final q = _controller.text.trim().toUpperCase();
    if (q.isEmpty) return;
    AppHaptics.medium();
    setState(() {
      _busy = true;
      _error = null;
      _story = null;
    });

    try {
      const usecase = TyreStoryUsecase();
      TyreStory? story;
      switch (_mode) {
        case _LookupMode.slip:
          final n = int.tryParse(q);
          if (n != null) story = await usecase.bySlipOrJobNumber(n);
        case _LookupMode.serial:
          story = await usecase.bySerial(q);
      }
      if (!mounted) return;
      setState(() {
        _busy = false;
        _story = story;
        if (story == null) _error = 'No tyre found for "$q".';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Lookup failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      children: [
        if (_nfcAvailable)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: GlassDecorations.glassCard(
              context: context,
              borderRadius: 16,
              borderColor: (_nfcArmed
                      ? AppColors.successStrong(context)
                      : AppColors.infoStrong(context))
                  .withValues(alpha: 0.4),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.nfc_rounded,
                  size: 20,
                  color: _nfcArmed
                      ? AppColors.successStrong(context)
                      : AppColors.infoStrong(context),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _nfcArmed ? 'SCANNING — hold tag to reader' : 'Tap to scan a tyre tag',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _nfcArmed
                          ? AppColors.successStrong(context)
                          : AppColors.dynamicTextPrimary(context),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _nfcArmed ? _disarmNfc : _armNfc,
                  child: Text(_nfcArmed ? 'Stop' : 'Scan'),
                ),
              ],
            ),
          ),
        Container(
          decoration: GlassDecorations.glassCard(context: context, borderRadius: 16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  textCapitalization: TextCapitalization.characters,
                  keyboardType: _mode == _LookupMode.slip
                      ? TextInputType.number
                      : TextInputType.text,
                  inputFormatters: _mode == _LookupMode.slip
                      ? [FilteringTextInputFormatter.digitsOnly]
                      : [],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                    letterSpacing: 1.2,
                    color: AppColors.dynamicTextPrimary(context),
                  ),
                  decoration: InputDecoration(
                    hintText: _mode == _LookupMode.slip
                        ? 'Slip number (cab number)'
                        : 'Tyre serial number',
                    hintStyle: TextStyle(
                      fontSize: 12,
                      color: AppColors.dynamicTextMuted(context),
                      letterSpacing: 0,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _search(),
                ),
              ),
              IconButton(
                onPressed: _busy ? null : _search,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search_rounded, color: AppColors.info),
                tooltip: 'Search',
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _modeChip(_LookupMode.slip, 'SLIP NUMBER')),
            const SizedBox(width: 6),
            Expanded(child: _modeChip(_LookupMode.serial, 'SERIAL')),
          ],
        ),
        const SizedBox(height: 14),
        if (_error != null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.errorBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.error),
            ),
          ),
        if (_story != null) ...[
          _SpecCard(story: _story!),
          const SizedBox(height: 16),
          _SectionLabel(
            'SCAN HISTORY · ${_story!.history.length}',
          ),
          const SizedBox(height: 10),
          if (_story!.history.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No scan history recorded for this tyre.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.dynamicTextMuted(context),
                ),
              ),
            )
          else
            for (var i = 0; i < _story!.history.length; i++)
              _TimelineTile(
                entry: _story!.history[i],
                isFirst: i == 0,
                isLast: i == _story!.history.length - 1,
              ),
        ],
      ],
    );
  }

  Widget _modeChip(_LookupMode mode, String label) {
    final active = _mode == mode;
    return GestureDetector(
      onTap: () {
        AppHaptics.light();
        setState(() => _mode = mode);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? AppColors.info.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? AppColors.info.withValues(alpha: 0.45)
                : AppColors.dynamicBorder(context),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            fontWeight: active ? FontWeight.w900 : FontWeight.w600,
            letterSpacing: 0.8,
            color: active
                ? AppColors.infoStrong(context)
                : AppColors.dynamicTextMuted(context),
          ),
        ),
      ),
    );
  }
}

/// Customer, make and slip lead the story — that is what the operator is
/// looking for.
class _SpecCard extends StatelessWidget {
  final TyreStory story;

  const _SpecCard({required this.story});

  @override
  Widget build(BuildContext context) {
    final tyre = story.tyre;
    final scrap = story.isScrapWithHistory;
    final statusColor = story.hasDispatchDelivery
        ? AppColors.successStrong(context)
        : (scrap ? AppColors.errorStrong(context) : AppColors.infoStrong(context));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: GlassDecorations.glassCard(context: context, borderRadius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tyre.customerName ?? 'Unknown customer',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                        color: AppColors.dynamicTextPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        tyre.make,
                        tyre.size,
                        tyre.pattern,
                      ].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.dynamicTextSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.infoStrong(context).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: AppColors.infoStrong(context).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        'SLIP ${tyre.slipNumber ?? '—'}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                          letterSpacing: 0.5,
                          color: AppColors.infoStrong(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  story.hasDispatchDelivery
                      ? 'DISPATCHED'
                      : (scrap ? 'SCRAP' : 'IN PROCESS'),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _row(context, 'CS', tyre.csNumber ?? '—'),
          _row(context, 'Serial', tyre.serial ?? '—'),
          if (tyre.invoiceNumber != null)
            _row(context, 'Invoice', tyre.invoiceNumber!),
          if (story.slip?.casingGrade != null)
            _row(context, 'Casing grade', story.slip!.casingGrade!),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.dynamicTextMuted(context),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
                color: AppColors.dynamicTextPrimary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One stop on the tyre's journey — a real timeline: rail, dot, event.
class _TimelineTile extends StatelessWidget {
  final TyreHistoryEntry entry;
  final bool isFirst;
  final bool isLast;

  const _TimelineTile({
    required this.entry,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final isReject = (entry.workCellName ?? '').toUpperCase().contains('REJECT');
    final isDelivery =
        (entry.workCellName ?? '').toUpperCase().contains('DELIVERY');
    final color = isReject
        ? AppColors.errorStrong(context)
        : (isDelivery
              ? AppColors.successStrong(context)
              : AppColors.infoStrong(context));

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Rail: connector + dot ──
          SizedBox(
            width: 26,
            child: Column(
              children: [
                // top connector (hidden for the newest entry)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isFirst
                        ? Colors.transparent
                        : AppColors.dynamicBorder(context),
                  ),
                ),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                // bottom connector (hidden for the oldest entry)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast
                        ? Colors.transparent
                        : AppColors.dynamicBorder(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // ── Event card ──
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.workCellName ?? 'Unknown cell',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.dynamicTextPrimary(context),
                          ),
                        ),
                      ),
                      Text(
                        entry.newestTimestamp ?? '',
                        style: TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                          color: AppColors.dynamicTextMuted(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.operatorName,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: AppColors.dynamicTextMuted(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
        color: AppColors.dynamicTextMuted(context),
      ),
    );
  }
}
