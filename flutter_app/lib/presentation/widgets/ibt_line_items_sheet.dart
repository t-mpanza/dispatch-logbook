import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_decorations.dart';
import '../../core/utils/haptics.dart';
import '../../data/models/ibt_manifest.dart';
import '../../data/models/loading_sheet_trip.dart';
import '../viewmodels/loading_sheet_viewmodel.dart';

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

  void _onStepQuantity({
    required IbtDocument doc,
    required IbtLineItem line,
    required int delta,
  }) async {
    AppHaptics.light();
    final newQty = (line.loadedQuantity + delta).clamp(0, 9999);

    final vm = context.read<LoadingSheetViewModel>();
    await vm.updateIbtLineQuantity(
      trip: _currentTrip,
      documentNo: doc.documentNo,
      lineItemId: line.id,
      newQuantity: newQty,
    );

    // If quota just reached, trigger medium haptic
    if (newQty == line.targetTotal && line.targetTotal > 0) {
      AppHaptics.medium();
    }

    // Refresh trips in local state
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
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

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
                        const Icon(
                          Icons.inventory_2_outlined,
                          color: AppColors.primaryGlow,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _currentTrip.tripId.isNotEmpty
                              ? '${_currentTrip.tripId} — IBT Breakdown'
                              : 'IBT Manifest Breakdown',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    if (_currentTrip.reg.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Vehicle: ${_currentTrip.reg}${_currentTrip.driverName.isNotEmpty ? ' • Driver: ${_currentTrip.driverName}' : ''}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Summary KPI Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.glassSurfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildKpiItem('Target', '$totalTarget', AppColors.primaryGlow),
                Container(height: 24, width: 1, color: Colors.white12),
                _buildKpiItem('Loaded', '$totalLoaded', Colors.greenAccent),
                Container(height: 24, width: 1, color: Colors.white12),
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
          const SizedBox(height: 16),

          // Documents & Line Items List
          if (ibtDocs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'No IBT documents attached to this trip.\nAttach an IBT number to view line-item breakdowns.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
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
                      color: AppColors.backgroundSecondary.withValues(
                        alpha: 0.6,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: doc.isComplete
                            ? Colors.greenAccent.withValues(alpha: 0.3)
                            : Colors.white.withValues(alpha: 0.08),
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
                            color: Colors.white.withValues(alpha: 0.03),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(14),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.description_outlined,
                                    size: 16,
                                    color: AppColors.primaryGlow,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    doc.documentNo,
                                    style: const TextStyle(
                                      color: Colors.white,
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
                          separatorBuilder: (ctx, i) =>
                              const Divider(color: Colors.white10, height: 16),
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
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Spec Details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                line.description,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (line.size != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        line.size!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (line.rubber != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGlow.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        line.rubber!,
                        style: const TextStyle(
                          color: AppColors.primaryGlow,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isDone
                          ? Colors.greenAccent.withValues(alpha: 0.15)
                          : (isOver
                                ? Colors.redAccent.withValues(alpha: 0.15)
                                : Colors.orangeAccent.withValues(alpha: 0.15)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isDone
                          ? 'Complete ✓'
                          : (isOver
                                ? '+${line.overCount} Over'
                                : '$remaining left'),
                      style: TextStyle(
                        color: isDone
                            ? Colors.greenAccent
                            : (isOver ? Colors.redAccent : Colors.orangeAccent),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Count Stepper & Quota
        Row(
          children: [
            // Count Display: [loaded / target]
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isDone
                      ? Colors.greenAccent.withValues(alpha: 0.4)
                      : Colors.white12,
                ),
              ),
              child: Text(
                '${line.loadedQuantity} / ${line.targetTotal}',
                style: TextStyle(
                  color: isDone ? Colors.greenAccent : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(width: 6),

            // Minus 1
            _buildStepperButton(
              icon: Icons.remove,
              onTap: () => _onStepQuantity(doc: doc, line: line, delta: -1),
            ),
            const SizedBox(width: 4),

            // Plus 1
            _buildStepperButton(
              icon: Icons.add,
              isHighlight: !isDone,
              onTap: () => _onStepQuantity(doc: doc, line: line, delta: 1),
            ),
            const SizedBox(width: 4),

            // Plus 5
            _buildQuickButton(
              label: '+5',
              onTap: () => _onStepQuantity(doc: doc, line: line, delta: 5),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStepperButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isHighlight = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isHighlight
              ? AppColors.primaryGlow.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isHighlight
                ? AppColors.primaryGlow.withValues(alpha: 0.4)
                : Colors.white10,
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: isHighlight ? AppColors.primaryGlow : Colors.white70,
        ),
      ),
    );
  }

  Widget _buildQuickButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white10),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
