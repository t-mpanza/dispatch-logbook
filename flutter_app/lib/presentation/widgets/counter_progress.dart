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

  const CounterProgress({
    super.key,
    required this.total,
    required this.tripCount,
    this.expectedTotal,
    this.truckReg,
    this.driverName,
    this.tripTitle,
    required this.onSetExpected,
  });

  void _showSetTargetDialog(BuildContext context) {
    final controller = TextEditingController(
      text: expectedTotal != null ? '$expectedTotal' : '',
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.backgroundSecondary,
          title: const Row(
            children: [
              Icon(Icons.track_changes, color: AppColors.primaryGlow, size: 20),
              SizedBox(width: 8),
              Text('Set Target Tyres for Truck',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter total tyre quantity required for this truck:',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. 180',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.glassSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.glassBorderLight),
                  ),
                  prefixIcon: const Icon(Icons.pin, color: AppColors.primaryGlow),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Quick Presets:',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [50, 100, 120, 150, 180, 200].map((qty) {
                  return ActionChip(
                    backgroundColor: AppColors.glassSurfaceElevated,
                    label: Text('$qty', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryGlow)),
                    onPressed: () {
                      controller.text = '$qty';
                    },
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            if (expectedTotal != null)
              TextButton(
                onPressed: () {
                  AppHaptics.light();
                  onSetExpected(null);
                  Navigator.pop(ctx);
                },
                child: const Text('Clear Target', style: TextStyle(color: AppColors.error)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              onPressed: () {
                AppHaptics.light();
                final val = int.tryParse(controller.text.trim());
                onSetExpected(val);
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Set Target', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasTarget = expectedTotal != null && expectedTotal! > 0;
    final remaining = hasTarget ? expectedTotal! - total : 0;
    final isOver = hasTarget && total > expectedTotal!;
    final isComplete = hasTarget && total == expectedTotal!;
    final pct = hasTarget ? (total / expectedTotal!).clamp(0.0, 1.0) : null;
    final pctText = pct != null ? '${(pct * 100).toStringAsFixed(1)}%' : null;

    final hasTruck = (truckReg != null && truckReg!.isNotEmpty) || (driverName != null && driverName!.isNotEmpty);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: GlassDecorations.glassElevated(borderRadius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Truck Header Banner (if assigned)
          if (hasTruck || (tripTitle != null && tripTitle!.isNotEmpty))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.local_shipping_rounded, size: 14, color: AppColors.primaryGlow),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tripTitle ?? 'TRUCK LOAD',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (hasTruck)
                          Text(
                            '${truckReg?.isNotEmpty == true ? truckReg : "NO REG"} • ${driverName?.isNotEmpty == true ? driverName : "Unassigned"}',
                            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                          ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      AppHaptics.light();
                      _showSetTargetDialog(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: hasTarget ? AppColors.primary.withValues(alpha: 0.2) : AppColors.glassSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: hasTarget ? AppColors.primaryGlow : AppColors.glassBorderLight,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            hasTarget ? Icons.track_changes : Icons.add_chart_rounded,
                            size: 12,
                            color: hasTarget ? AppColors.primaryGlow : AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            hasTarget ? 'Target: $expectedTotal' : '+ Set Target',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: hasTarget ? AppColors.primaryGlow : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Main Counts Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              // Loaded Count
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TYRES LOADED',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMuted,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$total',
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryGlow,
                          fontFamily: 'monospace',
                          letterSpacing: -1.0,
                        ),
                      ),
                      if (hasTarget)
                        Text(
                          ' / $expectedTotal',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                            fontFamily: 'monospace',
                          ),
                        ),
                      const SizedBox(width: 6),
                      const Text(
                        'tyres',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const Spacer(),

              // REMAINING TYRES / PROGRESS PILL
              if (hasTarget) ...[
                if (isComplete)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.5)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success),
                        SizedBox(width: 6),
                        Text(
                          'LOAD COMPLETE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: AppColors.success,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (isOver)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.6)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.warning),
                        const SizedBox(width: 6),
                        Text(
                          '+${total - expectedTotal!} OVER TARGET',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: AppColors.warning,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primaryGlow.withValues(alpha: 0.6)),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryGlow.withValues(alpha: 0.15),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.hourglass_bottom_rounded, size: 16, color: AppColors.primaryGlow),
                        const SizedBox(width: 6),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$remaining LEFT',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primaryGlow,
                                fontFamily: 'monospace',
                                letterSpacing: 0.5,
                              ),
                            ),
                            if (pctText != null)
                              Text(
                                '$pctText loaded',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ] else
                GestureDetector(
                  onTap: () => _showSetTargetDialog(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.glassSurfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.glassBorderLight),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.add_chart_rounded, size: 14, color: AppColors.textMuted),
                        SizedBox(width: 6),
                        Text(
                          'Set Target to See Left',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          // Visual Progress Bar
          if (hasTarget && pct != null) ...[
            const SizedBox(height: 12),
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isComplete
                          ? AppColors.success
                          : (isOver ? AppColors.warning : AppColors.primaryGlow),
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Quick Target Selection Pills if no target set yet
          if (!hasTarget) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Text(
                  'Quick Target: ',
                  style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [60, 100, 120, 150, 180, 200].map((target) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: GestureDetector(
                            onTap: () {
                              AppHaptics.light();
                              onSetExpected(target);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                              ),
                              child: Text(
                                '$target',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondary,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
