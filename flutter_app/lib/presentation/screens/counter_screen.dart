import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_decorations.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';
import '../../data/models/entry.dart';
import '../viewmodels/entries_viewmodel.dart';
import 'entry_detail_screen.dart';

class CounterScreen extends StatelessWidget {
  const CounterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<EntriesViewModel>(
      builder: (context, vm, _) {
        return FutureBuilder<List<Entry>>(
          future: vm.getCounterSessions(),
          builder: (context, snapshot) {
            final sessions = snapshot.data ?? [];
            final isLoading = snapshot.connectionState == ConnectionState.waiting;

            return Scaffold(
              backgroundColor: Colors.transparent,
              body: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                children: [
                  // Header
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'COUNTER',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryGlow,
                          letterSpacing: 2.0,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Trip Counting',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Fast tally, NFC scan simulation & digital loading sheets.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Start New Count Session Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        AppHaptics.success();
                        final entry = await vm.createEntry(
                          title: 'Tyre count – ${AppFormatters.formatTimeHHmm(DateTime.now().millisecondsSinceEpoch)}',
                          tags: ['tyres', 'count'],
                          withCounter: true,
                        );

                        if (context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => EntryDetailScreen(entryId: entry.id)),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 8,
                      ),
                      icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                      label: const Text(
                        'START NEW COUNT SESSION',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Session Cards List
                  if (isLoading)
                    const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: AppColors.primaryGlow)))
                  else if (sessions.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: GlassDecorations.glassCard(borderRadius: 22),
                      child: const Column(
                        children: [
                          Icon(Icons.local_shipping_outlined, size: 36, color: AppColors.textMuted),
                          SizedBox(height: 12),
                          Text('No counter sessions yet', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          SizedBox(height: 4),
                          Text('Each session has its own running total, history and media attachments.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                    )
                  else
                    for (final s in sessions) ...[
                      _buildSessionCard(context, s),
                      const SizedBox(height: 10),
                    ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSessionCard(BuildContext context, Entry entry) {
    final loadingTrips = entry.loadingSheetTrips ?? [];
    final legacyTrips = entry.trips ?? [];

    int totalTyres = 0;
    int tripCount = 0;

    if (loadingTrips.isNotEmpty) {
      totalTyres = loadingTrips.fold<int>(0, (sum, t) => sum + t.quantityLoaded);
      tripCount = loadingTrips.length;
    } else {
      totalTyres = legacyTrips.fold<int>(0, (sum, t) => sum + t.count + (t.rejected ?? 0));
      tripCount = legacyTrips.length;
    }

    return GestureDetector(
      onTap: () {
        AppHaptics.light();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EntryDetailScreen(entryId: entry.id)),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: GlassDecorations.glassCard(borderRadius: 20),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primaryGlow.withValues(alpha: 0.3)),
              ),
              child: const Center(
                child: Icon(Icons.local_shipping_rounded, color: AppColors.primaryGlow, size: 22),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${AppFormatters.formatDayLabel(entry.createdAt)} · ${AppFormatters.formatTimeHHmm(entry.createdAt)}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$totalTyres',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryGlow,
                    fontFamily: 'monospace',
                  ),
                ),
                Text(
                  '$tripCount ${tripCount == 1 ? "trip" : "trips"}',
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
