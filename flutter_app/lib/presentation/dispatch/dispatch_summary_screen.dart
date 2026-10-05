import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_decorations.dart';
import '../../dispatch/dispatch_api.dart';
import '../../dispatch/models/dispatch_models.dart';

/// Day summary: live per-work-cell shift totals, reject count and the
/// day's grand total — the same KPI spine the reports are built from.
class DispatchSummaryScreen extends StatefulWidget {
  const DispatchSummaryScreen({super.key});

  @override
  State<DispatchSummaryScreen> createState() => _DispatchSummaryScreenState();
}

class _SummaryData {
  const _SummaryData({
    this.shiftTotals = const [],
    this.rejects,
    this.totalTyres,
  });

  final List<ShiftTotal> shiftTotals;
  final int? rejects;
  final int? totalTyres;
}

class _DispatchSummaryScreenState extends State<DispatchSummaryScreen> {
  _SummaryData? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final (start, end) = DispatchApi.todayRange();
      final results = await Future.wait([
        DispatchApi.fetchShiftTotals(start, end),
        DispatchApi.fetchRejectsAmount(start, end),
        DispatchApi.fetchTotalTyres(start, end),
      ]);
      if (!mounted) return;
      setState(() {
        _data = _SummaryData(
          shiftTotals: results[0] as List<ShiftTotal>,
          rejects: results[1] as int?,
          totalTyres: results[2] as int?,
        );
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
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
          Row(
            children: [
              Expanded(
                child: _kpi(
                  context,
                  'TOTAL TYRES',
                  data == null || data.totalTyres == null
                      ? '—'
                      : '${data.totalTyres}',
                  AppColors.primaryGlow,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _kpi(
                  context,
                  'REJECTS',
                  data == null || data.rejects == null ? '—' : '${data.rejects}',
                  AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'WORK CELLS · SHIFT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: AppColors.dynamicTextMuted(context),
            ),
          ),
          const SizedBox(height: 8),
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.errorBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Could not load summary.\n$_error',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.error),
              ),
            )
          else if (data == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (data.shiftTotals.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Text(
                'No shift totals reported yet today.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.dynamicTextMuted(context),
                ),
              ),
            )
          else
            for (final cell in data.shiftTotals) _cellTile(context, cell),
        ],
      ),
    );
  }

  Widget _kpi(BuildContext context, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: GlassDecorations.glassCard(context: context, borderRadius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AppColors.dynamicTextMuted(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: -1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cellTile(BuildContext context, ShiftTotal cell) {
    final quota = cell.cellQuota;
    final done = cell.numberOfTyres ?? 0;
    final pct = (quota != null && quota > 0)
        ? (done / quota).clamp(0.0, 1.0)
        : null;
    final color = pct == null
        ? AppColors.info
        : (pct >= 1 ? AppColors.success : AppColors.primaryGlow);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: GlassDecorations.glassCard(context: context, borderRadius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  cell.workCellName ?? 'Unknown cell',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.dynamicTextPrimary(context),
                  ),
                ),
              ),
              Text(
                '$done${quota != null ? ' / $quota' : ''}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                  color: color,
                ),
              ),
            ],
          ),
          if (pct != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
