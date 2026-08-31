import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_decorations.dart';
import '../../core/utils/haptics.dart';

class CounterProgress extends StatelessWidget {
  final int total;
  final int tripCount;
  final int? expectedTotal;
  final Function(int?) onSetExpected;

  const CounterProgress({
    super.key,
    required this.total,
    required this.tripCount,
    this.expectedTotal,
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
          title: const Text('Set Expected Tyres', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'monospace', fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: 'e.g. 100',
              hintStyle: const TextStyle(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.glassSurface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          actions: [
            if (expectedTotal != null)
              TextButton(
                onPressed: () {
                  AppHaptics.light();
                  onSetExpected(null);
                  Navigator.pop(ctx);
                },
                child: const Text('Clear', style: TextStyle(color: AppColors.error)),
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
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pct = expectedTotal != null && expectedTotal! > 0
        ? (total / expectedTotal!).clamp(0.0, 1.0)
        : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: GlassDecorations.glassCard(borderRadius: 18),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'RUNNING TOTAL',
                    style: TextStyle(
                      fontSize: 10,
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
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryGlow,
                          fontFamily: 'monospace',
                        ),
                      ),
                      if (expectedTotal != null)
                        Text(
                          ' / $expectedTotal',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
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
              GestureDetector(
                onTap: () {
                  AppHaptics.light();
                  _showSetTargetDialog(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.glassSurfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.glassBorderLight),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        expectedTotal != null ? Icons.track_changes : Icons.add_chart_rounded,
                        size: 14,
                        color: AppColors.primaryGlow,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        expectedTotal != null ? 'Target: $expectedTotal' : '+ Target',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryGlow,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (pct != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryGlow),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
