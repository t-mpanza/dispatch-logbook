import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_decorations.dart';
import '../../core/utils/haptics.dart';
import '../../data/models/ibt_manifest.dart';
import '../../data/models/loading_sheet_trip.dart';
import '../viewmodels/loading_sheet_viewmodel.dart';
import 'number_pad.dart';

class IbtLineItemsSheet extends StatefulWidget {
  final LoadingSheetTrip trip;

  const IbtLineItemsSheet({super.key, required this.trip});

  static Future<void> show(
    BuildContext context, {
    required LoadingSheetTrip trip,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => IbtLineItemsSheet(trip: trip),
    );
  }

  @override
  State<IbtLineItemsSheet> createState() => _IbtLineItemsSheetState();
}

class _IbtLineItemsSheetState extends State<IbtLineItemsSheet> {
  late LoadingSheetTrip _currentTrip;

  @override
  void initState() {
    super.initState();
    _currentTrip = widget.trip;
  }

  /// Tap-to-add: type the exact number just loaded and add it as one clean
  /// batch (hard-clamped to the manifest target). Pad always starts empty.
  Future<void> _addLineBatch({
    required IbtDocument doc,
    required IbtLineItem line,
  }) async {
    AppHaptics.light();
    final value = await BatchPad.show(
      context,
      remaining: line.remaining,
      title: 'ADD TYRES — ${line.size ?? line.description}',
    );
    if (value == null || value == 0 || !mounted) return;

    final vm = context.read<LoadingSheetViewModel>();
    final result = await vm.applyIbtLineDelta(
      trip: _currentTrip,
      documentNo: doc.documentNo,
      lineItemId: line.id,
      delta: value,
    );
    if (result == null || !mounted) return;

    if (result.completed) {
      AppHaptics.success();
    } else if (result.wasClamped) {
      AppHaptics.heavy();
    } else {
      AppHaptics.medium();
    }

    final trips = await vm.getTripsForSelectedDate();
    final updated = trips.firstWhere(
      (t) => t.id == _currentTrip.id,
      orElse: () => _currentTrip,
    );

    if (mounted) {
      setState(() {
        _currentTrip = updated;
      });
    }
  }

  /// Revert the most recent change on a line item.
  Future<void> _undoLineLast({
    required IbtDocument doc,
    required IbtLineItem line,
  }) async {
    AppHaptics.medium();
    final vm = context.read<LoadingSheetViewModel>();
    final result = await vm.undoIbtLineLast(
      trip: _currentTrip,
      documentNo: doc.documentNo,
      lineItemId: line.id,
    );
    if (result == null || !mounted) return;

    final trips = await vm.getTripsForSelectedDate();
    final updated = trips.firstWhere(
      (t) => t.id == _currentTrip.id,
      orElse: () => _currentTrip,
    );

    if (mounted) {
      setState(() {
        _currentTrip = updated;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ibtDocs = _currentTrip.ibtDocuments ?? [];
    final totalTarget = _currentTrip.ibtTargetTotal;
    final totalLoaded = _currentTrip.ibtLoadedTotal;
    final totalRemaining = (totalTarget - totalLoaded).clamp(0, totalTarget);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: GlassDecorations.glassElevated(),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
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
                color: AppColors.dynamicBorder(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          color: AppColors.primaryGlow,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          _currentTrip.tripId.isNotEmpty
                              ? '${_currentTrip.tripId} — IBT Breakdown'
                              : 'IBT Manifest Breakdown',
                          style: TextStyle(
                            color: AppColors.dynamicTextPrimary(context),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    if (_currentTrip.reg.isNotEmpty) ...[
                      SizedBox(height: 2),
                      Text(
                        'Vehicle: ${_currentTrip.reg}${_currentTrip.driverName.isNotEmpty ? ' • Driver: ${_currentTrip.driverName}' : ''}',
                        style: TextStyle(
                          color: AppColors.dynamicTextSecondary(context),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.close,
                  color: AppColors.dynamicTextSecondary(context),
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          SizedBox(height: 14),

          // Summary KPI Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.glassSurfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.dynamicBorder(context)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildKpiItem('Target', '$totalTarget', AppColors.primaryGlow),
                Container(
                  height: 24,
                  width: 1,
                  color: AppColors.dynamicBorder(context),
                ),
                _buildKpiItem('Loaded', '$totalLoaded', Colors.greenAccent),
                Container(
                  height: 24,
                  width: 1,
                  color: AppColors.dynamicBorder(context),
                ),
                _buildKpiItem(
                  'Remaining',
                  '$totalRemaining',
                  totalRemaining == 0
                      ? Colors.greenAccent
                      : Colors.orangeAccent,
                ),
              ],
            ),
          ),
          SizedBox(height: 16),

          // Documents & Line Items List
          if (ibtDocs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'No IBT documents attached to this trip.\nAttach an IBT number to view line-item breakdowns.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.dynamicTextMuted(context),
                    fontSize: 14,
                  ),
                ),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: ibtDocs.length,
                itemBuilder: (context, docIdx) {
                  final doc = ibtDocs[docIdx];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.dynamicCardSurface(
                        context,
                      ).withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: doc.isComplete
                            ? Colors.greenAccent.withValues(alpha: 0.3)
                            : AppColors.dynamicBorder(context),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // IBT Document Header
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.dynamicCardSurface(context),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(14),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.description_outlined,
                                    size: 16,
                                    color: AppColors.primaryGlow,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    doc.documentNo,
                                    style: TextStyle(
                                      color: AppColors.dynamicTextPrimary(
                                        context,
                                      ),
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: doc.isComplete
                                      ? Colors.greenAccent.withValues(
                                          alpha: 0.15,
                                        )
                                      : Colors.orangeAccent.withValues(
                                          alpha: 0.15,
                                        ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${doc.loadedTotal} / ${doc.total} Tyres',
                                  style: TextStyle(
                                    color: doc.isComplete
                                        ? Colors.greenAccent
                                        : Colors.orangeAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Line Items
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(12),
                          itemCount: doc.lineItems.length,
                          separatorBuilder: (ctx, i) => Divider(
                            color: AppColors.dynamicBorder(context),
                            height: 16,
                          ),
                          itemBuilder: (context, lineIdx) {
                            final line = doc.lineItems[lineIdx];
                            return _buildLineItemRow(doc, line);
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildKpiItem(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.dynamicTextMuted(context),
            fontSize: 11,
          ),
        ),
        SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildLineItemRow(IbtDocument doc, IbtLineItem line) {
    final isDone = line.isComplete;
    final isOver = line.isOverloaded;
    final remaining = line.remaining;
    final statusColor = isDone
        ? AppColors.successStrong(context)
        : (isOver
              ? AppColors.warningStrong(context)
              : AppColors.presetStocksStrong(context));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Spec Details — SIZE + PATTERN prominent
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      line.size ?? line.description,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.dynamicTextPrimary(context),
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  if (line.rubber != null) ...[
                    const SizedBox(width: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.presetStocksStrong(
                          context,
                        ).withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: AppColors.presetStocksStrong(
                            context,
                          ).withValues(alpha: 0.45),
                        ),
                      ),
                      child: Text(
                        line.rubber!,
                        style: TextStyle(
                          color: AppColors.presetStocksStrong(context),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  if (line.rcsCode != null) ...[
                    Text(
                      'RCS ${line.rcsCode}',
                      style: TextStyle(
                        color: AppColors.dynamicTextDisabled(context),
                        fontSize: 9.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  // Status
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isDone
                          ? 'Complete ✓'
                          : (isOver
                                ? '+${line.overCount} Over'
                                : '$remaining left'),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Count Display (tap to add) — [loaded / target] with last-added chip
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () => _addLineBatch(doc: doc, line: line),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.isLight(context)
                          ? const Color(0xFFF1F5F9)
                          : Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${line.loadedQuantity} / ${line.targetTotal}',
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.dialpad_rounded,
                          size: 12,
                          color: AppColors.dynamicTextMuted(context),
                        ),
                      ],
                    ),
                  ),
                ),
                if (line.lastEvent != null)
                  Text(
                    _lastEventLabel(line.lastEvent!),
                    style: TextStyle(
                      fontSize: 9.5,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                      color: line.lastEvent!.delta >= 0
                          ? AppColors.successStrong(context)
                          : AppColors.warningStrong(context),
                    ),
                  ),
              ],
            ),
            if (line.lastEvent != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _undoLineLast(doc: doc, line: line),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.warningStrong(
                      context,
                    ).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.warningStrong(
                        context,
                      ).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Icon(
                    Icons.undo_rounded,
                    size: 14,
                    color: AppColors.warningStrong(context),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  String _lastEventLabel(IbtLineEvent event) {
    final t = DateTime.fromMillisecondsSinceEpoch(event.at);
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return 'last: ${event.delta >= 0 ? '+' : ''}${event.delta} · $hh:$mm';
  }
}
