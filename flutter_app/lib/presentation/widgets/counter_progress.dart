import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_decorations.dart';
import '../../core/utils/haptics.dart';

class CounterProgress extends StatelessWidget {
  final int total;
  final int tripCount;
  final int? expectedTotal;
  final String? truckReg;
  final String? driverName;
  final String? tripTitle;
  final Function(int?) onSetExpected;
  final Function(String? reg, String? driver, int? target)? onUpdateTruckDetails;

  const CounterProgress({
    super.key,
    required this.total,
    required this.tripCount,
    this.expectedTotal,
    this.truckReg,
    this.driverName,
    this.tripTitle,
    required this.onSetExpected,
    this.onUpdateTruckDetails,
  });

  void _showEditDetailsDialog(BuildContext context) {
    final regCtrl = TextEditingController(text: truckReg ?? '');
    final driverCtrl = TextEditingController(text: driverName ?? '');
    final targetCtrl = TextEditingController(
      text: expectedTotal != null ? '$expectedTotal' : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          decoration: const BoxDecoration(
            color: AppColors.backgroundSecondary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Truck & Target Settings',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildInput(
                        label: 'REG PLATE',
                        controller: regCtrl,
                        hint: 'e.g. MN27PT',
                        isMonospace: true,
                        isCaps: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildInput(
                        label: 'DRIVER NAME',
                        controller: driverCtrl,
                        hint: 'e.g. Stephen',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInput(
                  label: 'TARGET TYRES (EXPECTED LOAD)',
                  controller: targetCtrl,
                  hint: 'e.g. 285',
                  isNumber: true,
                  isMonospace: true,
                ),
                const SizedBox(height: 10),
                const Text(
                  'QUICK PRESETS:',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMuted,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [50, 100, 120, 150, 180, 200, 250, 285].map((qty) {
                    return GestureDetector(
                      onTap: () {
                        AppHaptics.light();
                        targetCtrl.text = '$qty';
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.glassSurfaceElevated,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: Text(
                          '$qty',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryGlow,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (expectedTotal != null)
                      TextButton(
                        onPressed: () {
                          AppHaptics.light();
                          targetCtrl.clear();
                        },
                        child: const Text('Clear Target', style: TextStyle(color: AppColors.error, fontSize: 12)),
                      ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () {
                        AppHaptics.success();
                        final reg = regCtrl.text.trim().toUpperCase();
                        final driver = driverCtrl.text.trim();
                        final target = int.tryParse(targetCtrl.text.trim());

                        if (onUpdateTruckDetails != null) {
                          onUpdateTruckDetails!(reg, driver, target);
                        } else {
                          onSetExpected(target);
                        }
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Save Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInput({
    required String label,
    required TextEditingController controller,
    required String hint,
    bool isMonospace = false,
    bool isCaps = false,
    bool isNumber = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: AppColors.textMuted,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 42,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: TextField(
            controller: controller,
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            textCapitalization: isCaps ? TextCapitalization.characters : TextCapitalization.words,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              fontFamily: isMonospace ? 'monospace' : null,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 11),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasTarget = expectedTotal != null && expectedTotal! > 0;
    final remaining = hasTarget ? expectedTotal! - total : 0;
    final isOver = hasTarget && total > expectedTotal!;
    final isComplete = hasTarget && total == expectedTotal!;
    final pct = hasTarget ? (total / expectedTotal!).clamp(0.0, 1.0) : 0.0;
    final pctText = hasTarget ? '${(pct * 100).toStringAsFixed(0)}%' : null;

    final hasTruck = (truckReg != null && truckReg!.isNotEmpty) || (driverName != null && driverName!.isNotEmpty);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: GlassDecorations.glassElevated(borderRadius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Compact Header Row: Truck Assignment & Target / Status Badge
          Row(
            children: [
              // Truck Info Clickable Pill
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    AppHaptics.light();
                    _showEditDetailsDialog(context);
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.local_shipping_rounded, size: 12, color: AppColors.primaryGlow),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          hasTruck
                              ? '${tripTitle != null && tripTitle!.isNotEmpty ? "$tripTitle • " : ""}${truckReg?.isNotEmpty == true ? truckReg : "NO REG"}${driverName?.isNotEmpty == true ? " ($driverName)" : ""}'
                              : (tripTitle ?? 'Tap to assign truck'),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit_outlined, size: 12, color: AppColors.textMuted),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Status / Target Action Pill
              GestureDetector(
                onTap: () {
                  AppHaptics.light();
                  _showEditDetailsDialog(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isComplete
                        ? AppColors.success.withValues(alpha: 0.15)
                        : (isOver
                            ? AppColors.warning.withValues(alpha: 0.15)
                            : (hasTarget ? AppColors.primary.withValues(alpha: 0.15) : AppColors.glassSurface)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isComplete
                          ? AppColors.success.withValues(alpha: 0.4)
                          : (isOver
                              ? AppColors.warning.withValues(alpha: 0.4)
                              : (hasTarget ? AppColors.primaryGlow.withValues(alpha: 0.4) : AppColors.glassBorder)),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isComplete
                            ? Icons.check_circle_rounded
                            : (isOver
                                ? Icons.warning_amber_rounded
                                : (hasTarget ? Icons.hourglass_bottom_rounded : Icons.track_changes)),
                        size: 11,
                        color: isComplete
                            ? AppColors.success
                            : (isOver
                                ? AppColors.warning
                                : (hasTarget ? AppColors.primaryGlow : AppColors.textMuted)),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isComplete
                            ? 'LOAD COMPLETE'
                            : (isOver
                                ? '+$remaining OVER'
                                : (hasTarget ? '$remaining LEFT' : '+ Set Target')),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: isComplete
                              ? AppColors.success
                              : (isOver
                                  ? AppColors.warning
                                  : (hasTarget ? AppColors.primaryGlow : AppColors.textSecondary)),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Counts Row: Tyres Count + Target Metric + Percentage
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$total',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryGlow,
                  fontFamily: 'monospace',
                  letterSpacing: -0.5,
                  height: 1.0,
                ),
              ),
              if (hasTarget)
                Text(
                  ' / $expectedTotal',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                    fontFamily: 'monospace',
                  ),
                ),
              const SizedBox(width: 4),
              const Text(
                'tyres',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMuted,
                ),
              ),
              const Spacer(),
              if (hasTarget && pctText != null)
                Text(
                  '$pctText loaded',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isComplete ? AppColors.success : (isOver ? AppColors.warning : AppColors.textSecondary),
                    fontFamily: 'monospace',
                  ),
                )
              else
                Text(
                  '$tripCount ${tripCount == 1 ? 'batch' : 'batches'}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                    fontFamily: 'monospace',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),

          // Mini High-Precision Gradient Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: hasTarget ? pct : 0.0,
              minHeight: 3.5,
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation<Color>(
                isComplete
                    ? AppColors.success
                    : (isOver ? AppColors.warning : AppColors.primaryGlow),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
