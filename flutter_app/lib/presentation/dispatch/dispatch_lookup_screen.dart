import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_decorations.dart';
import '../../core/utils/haptics.dart';
import '../../dispatch/domain/tyre_story.dart';
import '../../dispatch/models/dispatch_models.dart';

/// Tyre lookup: slip number (the "cab number" on the tyre) or serial —
/// the only two identifiers visible to operators in the field.
class DispatchLookupScreen extends StatefulWidget {
  const DispatchLookupScreen({super.key});

  @override
  State<DispatchLookupScreen> createState() => _DispatchLookupScreenState();
}

enum _LookupMode { slip, serial }

class _DispatchLookupScreenState extends State<DispatchLookupScreen> {
  final TextEditingController _controller = TextEditingController();
  _LookupMode _mode = _LookupMode.slip;
  bool _busy = false;
  String? _error;
  TyreStory? _story;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
          const SizedBox(height: 14),
          _SectionLabel(
            'SCAN HISTORY · ${_story!.history.length}',
          ),
          const SizedBox(height: 8),
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
            for (final entry in _story!.history) _HistoryTile(entry: entry),
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
                child: Text(
                  tyre.displayLabel,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: AppColors.dynamicTextPrimary(context),
                  ),
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
          _row(context, 'Slip', '${tyre.slipNumber ?? '—'}'),
          _row(context, 'CS', tyre.csNumber ?? '—'),
          _row(context, 'Customer', tyre.customerName ?? '—'),
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

class _HistoryTile extends StatelessWidget {
  final TyreHistoryEntry entry;

  const _HistoryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isReject = (entry.workCellName ?? '').toUpperCase().contains('REJECT');
    final isDelivery =
        (entry.workCellName ?? '').toUpperCase().contains('DELIVERY');
    final color = isReject
        ? AppColors.errorStrong(context)
        : (isDelivery ? AppColors.successStrong(context) : AppColors.infoStrong(context));

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.workCellName ?? 'Unknown cell',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.dynamicTextPrimary(context),
                  ),
                ),
                Text(
                  entry.operatorName,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.dynamicTextMuted(context),
                  ),
                ),
              ],
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
