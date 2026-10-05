import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_decorations.dart';
import '../../dispatch/dispatch_api.dart';
import '../../dispatch/models/dispatch_models.dart';

/// TODAY board: live stat grid (tyres at dispatch, outstanding batches,
/// rejects, late tyres), the active dispatch session, late batches and the
/// tyres standing at dispatch grouped by customer.
class DispatchBoardScreen extends StatefulWidget {
  const DispatchBoardScreen({super.key});

  @override
  State<DispatchBoardScreen> createState() => _DispatchBoardScreenState();
}

class _BoardData {
  const _BoardData({
    this.session,
    this.atDispatch = const [],
    this.batches = const [],
    this.late = const [],
    this.rejects,
    this.totalTyres,
  });

  final ActiveDispatchSession? session;
  final List<DispatchTyre> atDispatch;
  final List<OutstandingBatch> batches;
  final List<LateBatchTyre> late;
  final int? rejects;
  final int? totalTyres;
}

class _DispatchBoardScreenState extends State<DispatchBoardScreen> {
  _BoardData? _data;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (mounted) setState(() => _loading = true);
    try {
      final (start, end) = DispatchApi.todayRange();
      final results = await Future.wait([
        DispatchApi.fetchActiveDispatchSession(),
        DispatchApi.fetchTyresAtDispatch(),
        DispatchApi.fetchOutstandingBatches(),
        DispatchApi.fetchLateBatches(),
        DispatchApi.fetchRejectsAmount(start, end),
        DispatchApi.fetchTotalTyres(start, end),
      ]);
      if (!mounted) return;
      setState(() {
        _data = _BoardData(
          session: results[0] as ActiveDispatchSession?,
          atDispatch: results[1] as List<DispatchTyre>,
          batches: results[2] as List<OutstandingBatch>,
          late: results[3] as List<LateBatchTyre>,
          rejects: results[4] as int?,
          totalTyres: results[5] as int?,
        );
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.info,
      backgroundColor: AppColors.dynamicBackgroundSecondary(context),
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          if (_loading && _data == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null && _data == null)
            _ErrorCard(message: _error!, onRetry: _refresh)
          else ...[
            _SessionCard(session: _data!.session),
            const SizedBox(height: 12),
            _StatGrid(
              atDispatch: _data!.atDispatch.length,
              batches: _data!.batches.length,
              late: _data!.late.length,
              rejects: _data!.rejects,
              totalTyres: _data!.totalTyres,
            ),
            if (_data!.late.isNotEmpty) ...[
              const SizedBox(height: 18),
              _SectionLabel('LATE BATCHES'),
              const SizedBox(height: 8),
              for (final tyre in _data!.late.take(10))
                _LateTyreTile(tyre: tyre),
            ],
            const SizedBox(height: 18),
            _SectionLabel(
              'TYRES AT DISPATCH · ${_data!.atDispatch.length}',
            ),
            const SizedBox(height: 8),
            if (_data!.atDispatch.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'Nothing standing at dispatch right now.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.dynamicTextMuted(context),
                  ),
                ),
              )
            else
              _groupedCustomers(_data!.atDispatch),
          ],
        ],
      ),
    );
  }

  Widget _groupedCustomers(List<DispatchTyre> tyres) {
    final grouped = <String, List<DispatchTyre>>{};
    for (final t in tyres) {
      final customer = t.customerName ?? 'Unknown';
      grouped.putIfAbsent(customer, () => []).add(t);
    }
    final entries = grouped.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in entries) ...[
          Text(
            '${entry.key} · ${entry.value.length}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.dynamicTextSecondary(context),
            ),
          ),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 2.6,
            children: [
              for (final t in entry.value) _TyreTile(tyre: t),
            ],
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _SessionCard extends StatelessWidget {
  final ActiveDispatchSession? session;

  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: GlassDecorations.glassCard(context: context, borderRadius: 18),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.local_shipping_rounded, color: AppColors.info),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ACTIVE SESSION',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: AppColors.dynamicTextMuted(context),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  session == null
                      ? 'No active dispatch session'
                      : '${session!.cLocation ?? 'Unknown location'} · ${session!.cName ?? ''}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.dynamicTextPrimary(context),
                  ),
                ),
                if (session?.dStartTime != null)
                  Text(
                    'Started ${session!.dStartTime}',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: AppColors.dynamicTextMuted(context),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  final int atDispatch;
  final int batches;
  final int late;
  final int? rejects;
  final int? totalTyres;

  const _StatGrid({
    required this.atDispatch,
    required this.batches,
    required this.late,
    required this.rejects,
    required this.totalTyres,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.15,
      children: [
        _stat(context, Icons.checkroom_rounded, AppColors.info,
            'AT DISPATCH', '$atDispatch'),
        _stat(context, Icons.inventory_2_rounded, AppColors.primaryGlow,
            'BATCHES', '$batches'),
        _stat(context, Icons.timer_off_rounded, AppColors.warning,
            'LATE', '$late'),
        _stat(context, Icons.close_rounded, AppColors.error,
            'REJECTS', rejects == null ? '—' : '$rejects'),
        _stat(context, Icons.album_rounded, AppColors.success,
            'TOTAL TYRES', totalTyres == null ? '—' : '$totalTyres'),
        _stat(context, Icons.build_rounded, AppColors.presetNls,
            'IN FACTORY', '—'),
      ],
    );
  }

  Widget _stat(
    BuildContext context,
    IconData icon,
    Color color,
    String label,
    String value,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: GlassDecorations.glassCard(context: context, borderRadius: 14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.dynamicTextPrimary(context),
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
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

class _TyreTile extends StatelessWidget {
  final DispatchTyre tyre;

  const _TyreTile({required this.tyre});

  @override
  Widget build(BuildContext context) {
    final isInvoiced = (tyre.invoiced ?? 0) == 1;
    final color = isInvoiced ? AppColors.success : AppColors.info;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            isInvoiced
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              tyre.displayLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.dynamicTextPrimary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LateTyreTile extends StatelessWidget {
  final LateBatchTyre tyre;

  const _LateTyreTile({required this.tyre});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_bottom_rounded,
              size: 16, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [tyre.size, tyre.make, tyre.pattern]
                      .whereType<String>()
                      .where((s) => s.isNotEmpty)
                      .join(' · '),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.dynamicTextPrimary(context),
                  ),
                ),
                Text(
                  '${tyre.customerName ?? ''} · CS ${tyre.csNumber ?? '—'} · '
                  'slip ${tyre.slipNumber ?? '—'}',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.dynamicTextMuted(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 30),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.errorBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.error, size: 28),
          const SizedBox(height: 8),
          Text(
            'Could not load the board.\n$message',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.error),
          ),
          const SizedBox(height: 10),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
