import '../widgets/aws_auth_dialog.dart';
import '../widgets/ibt_line_items_sheet.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_decorations.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';
import '../../data/models/entry.dart';
import '../../data/models/loading_sheet_trip.dart';
import '../../data/models/preset.dart';
import '../../data/services/pdf_export_service.dart';
import '../../data/services/whatsapp_export_service.dart';
import '../../data/repositories/entry_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../viewmodels/loading_sheet_viewmodel.dart';
import '../widgets/truck_load_dialog.dart';

class LoadingSheetScreen extends StatefulWidget {
  const LoadingSheetScreen({super.key});

  @override
  State<LoadingSheetScreen> createState() => _LoadingSheetScreenState();
}

class _LoadingSheetScreenState extends State<LoadingSheetScreen> {

  void _onSwipeUpdate(DragEndDetails details, LoadingSheetViewModel vm) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -300) {
      // Swiped left -> next day
      AppHaptics.light();
      vm.shiftDate(1);
    } else if (velocity > 300) {
      // Swiped right -> previous day
      AppHaptics.light();
      vm.shiftDate(-1);
    }
  }

  Color _getBadgeColor(String tripId, PresetKey? presetKey) {
    final name = (presetKey?.name ?? tripId).toUpperCase();
    if (name.contains('NLH') || name.contains('NEIL')) return AppColors.presetNlh;
    if (name.contains('STOCKS')) return AppColors.presetStocks;
    if (name.contains('DBN')) return AppColors.presetDbn;
    if (name.contains('PLK')) return AppColors.presetPlk;
    if (name.contains('BLOEM')) return AppColors.presetBloem;
    if (name.contains('TIREPOINT')) return AppColors.presetTirepoint;
    return AppColors.presetCustom;
  }

  @override
  Widget build(BuildContext context) {
    final settingsRepo = context.watch<SettingsRepository>();
    final despatcherName = settingsRepo.despatcherName;

    return Consumer<LoadingSheetViewModel>(
      builder: (context, vm, _) {
        return GestureDetector(
          onHorizontalDragEnd: (details) => _onSwipeUpdate(details, vm),
          child: FutureBuilder<List<LoadingSheetTrip>>(
            future: vm.getTripsForSelectedDate(),
            builder: (context, snapshot) {
              final trips = snapshot.data ?? [];
              final isLoading = snapshot.connectionState == ConnectionState.waiting;

              int totalTyres = 0;
              int totalMinutes = 0;
              for (final t in trips) {
                totalTyres += t.quantityLoaded;
                totalMinutes += t.durationMinutes ?? 0;
              }

              final hours = totalMinutes ~/ 60;
              final mins = totalMinutes % 60;
              final timeFormatted = totalMinutes > 0
                  ? (hours > 0 ? '${hours}h ${mins}m (${totalMinutes}m)' : '$totalMinutes mins')
                  : '0 mins';

              return Scaffold(
                backgroundColor: Colors.transparent,
                body: RefreshIndicator(
                  color: AppColors.primaryGlow,
                  backgroundColor: AppColors.backgroundSecondary,
                  onRefresh: () async {
                    await context.read<EntryRepository>().syncNow();
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                    children: [
                      // Header Title & Despatcher Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.description_rounded, size: 14, color: AppColors.primaryGlow),
                                  SizedBox(width: 4),
                                  Text(
                                    'DAILY COMPLIANCE',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryGlow, letterSpacing: 1.5),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Loading Sheet',
                                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.textPrimary, letterSpacing: -0.5),
                              ),
                            ],
                          ),

                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => AwsAuthDialog.show(context),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  decoration: GlassDecorations.glassCard(borderRadius: 14),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.cloud_sync_rounded, size: 14, color: AppColors.primaryGlow),
                                      SizedBox(width: 4),
                                      Text(
                                        'AWS Sync',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Despatcher Name Pill
                              GestureDetector(
                                onTap: () {
                                  _showEditDespatcherDialog(context, settingsRepo);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: GlassDecorations.glassCard(borderRadius: 14),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.person_rounded, size: 14, color: AppColors.primaryGlow),
                                      const SizedBox(width: 4),
                                      Text(
                                        despatcherName,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Date Navigation Bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: GlassDecorations.glassCard(borderRadius: 18),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left_rounded, color: AppColors.textPrimary),
                              onPressed: () {
                                AppHaptics.light();
                                vm.shiftDate(-1);
                              },
                            ),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.primaryGlow),
                                const SizedBox(width: 6),
                                Text(
                                  vm.selectedDate,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                if (vm.selectedDate == AppFormatters.dayKey(DateTime.now())) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text('TODAY', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.primaryGlow)),
                                  ),
                                ],
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right_rounded, color: AppColors.textPrimary),
                              onPressed: () {
                                AppHaptics.light();
                                vm.shiftDate(1);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // KPI Banner
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: GlassDecorations.glassElevated(borderRadius: 22),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildKpi(
                              icon: Icons.local_shipping_rounded,
                              label: 'TRUCKS',
                              value: '${trips.length}',
                              valueColor: AppColors.textPrimary,
                            ),
                            Container(width: 1, height: 36, color: AppColors.glassBorderLight),
                            _buildKpi(
                              icon: Icons.access_time_rounded,
                              label: 'TOTAL TIME',
                              value: timeFormatted,
                              valueColor: AppColors.textSecondary,
                            ),
                            Container(width: 1, height: 36, color: AppColors.glassBorderLight),
                            _buildKpi(
                              icon: Icons.layers_rounded,
                              label: 'TYRES',
                              value: '$totalTyres',
                              valueColor: AppColors.primaryGlow,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Action Export & Add Buttons Row
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                AppHaptics.light();
                                final dayEntries = await vm.getDayEntries();
                                final entry = dayEntries.isNotEmpty
                                    ? dayEntries.first.copyWith(loadingSheetTrips: trips)
                                    : Entry(
                                        id: 'pdf-${vm.selectedDate}',
                                        title: 'Loading Sheet',
                                        tags: [],
                                        notes: [],
                                        attachments: [],
                                        loadingSheetTrips: trips,
                                        createdAt: DateTime.now().millisecondsSinceEpoch,
                                        updatedAt: DateTime.now().millisecondsSinceEpoch,
                                        dayKey: vm.selectedDate,
                                        monthKey: vm.selectedDate.substring(0, 7),
                                        yearKey: vm.selectedDate.substring(0, 4),
                                      );

                                await PdfExportService.printOrSharePdf(entry, despatcherName);
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.glassBorder),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              icon: const Icon(Icons.print_rounded, size: 16, color: AppColors.primaryGlow),
                              label: const Text('Print PDF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                AppHaptics.light();
                                final dayEntries = await vm.getDayEntries();
                                final entry = dayEntries.isNotEmpty
                                    ? dayEntries.first.copyWith(loadingSheetTrips: trips)
                                    : Entry(
                                        id: 'wa-${vm.selectedDate}',
                                        title: 'Loading Sheet',
                                        tags: [],
                                        notes: [],
                                        attachments: [],
                                        loadingSheetTrips: trips,
                                        createdAt: DateTime.now().millisecondsSinceEpoch,
                                        updatedAt: DateTime.now().millisecondsSinceEpoch,
                                        dayKey: vm.selectedDate,
                                        monthKey: vm.selectedDate.substring(0, 7),
                                        yearKey: vm.selectedDate.substring(0, 4),
                                      );

                                final text = WhatsAppExportService.formatWhatsAppText(entry, despatcherName);
                                await WhatsAppExportService.shareToWhatsApp(text);

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Loading sheet text copied & shared!'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.successBorder),
                                backgroundColor: AppColors.successBg,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              icon: const Icon(Icons.share_rounded, size: 16, color: AppColors.success),
                              label: const Text('WhatsApp', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () {
                              AppHaptics.light();
                              TruckLoadDialog.show(
                                context,
                                dayKey: vm.selectedDate,
                                existingTrips: trips,
                                onSave: (newTrip) => vm.addTruckLoad(newTrip),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                            label: const Text('+ Truck', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Truck Load Cards List
                      if (isLoading)
                        const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: AppColors.primaryGlow)))
                      else if (trips.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: GlassDecorations.glassCard(borderRadius: 22),
                          child: Column(
                            children: [
                              const Icon(Icons.local_shipping_outlined, size: 40, color: AppColors.textMuted),
                              const SizedBox(height: 12),
                              const Text('No truck loads logged for this date', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                              const SizedBox(height: 4),
                              const Text('Tap "+ Truck" to record a delivery trip.', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () {
                                  AppHaptics.light();
                                  TruckLoadDialog.show(
                                    context,
                                    dayKey: vm.selectedDate,
                                    existingTrips: trips,
                                    onSave: (newTrip) => vm.addTruckLoad(newTrip),
                                  );
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                                icon: const Icon(Icons.add, color: Colors.white),
                                label: const Text('Add First Truck Load', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        )
                      else
                        for (var i = 0; i < trips.length; i++) ...[
                          _buildTruckCard(
                            context,
                            index: i + 1,
                            trip: trips[i],
                            onTap: () {
                              AppHaptics.light();
                              TruckLoadDialog.show(
                                context,
                                existingTrip: trips[i],
                                dayKey: vm.selectedDate,
                                existingTrips: trips,
                                onSave: (updated) => vm.updateTruckLoad(updated),
                                onDelete: () => vm.deleteTruckLoad(trips[i].id),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                        ],
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildKpi({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: AppColors.primaryGlow),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 0.8)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: valueColor, fontFamily: 'monospace'),
        ),
      ],
    );
  }

  Widget _buildTruckCard(
    BuildContext context, {
    required int index,
    required LoadingSheetTrip trip,
    required VoidCallback onTap,
  }) {
    final badgeColor = _getBadgeColor(trip.tripId, trip.presetKey);
    final hasTiming = trip.startTime != null && trip.finishTime != null;
    final timeRange = hasTiming
        ? '${AppFormatters.formatTimeHHmm(trip.startTime)} → ${AppFormatters.formatTimeHHmm(trip.finishTime)}'
        : 'No timestamps';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: GlassDecorations.glassCard(borderRadius: 18),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: AppColors.glassSurfaceElevated,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$index',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        trip.tripId.isNotEmpty ? trip.tripId : 'TRIP $index',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: badgeColor,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primaryGlow.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        '${trip.quantityLoaded} tyres',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryGlow,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.edit_outlined, size: 16, color: AppColors.textMuted),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (trip.reg.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.glassSurfaceElevated,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_shipping_outlined, size: 10, color: AppColors.primaryGlow),
                        const SizedBox(width: 4),
                        Text(trip.reg, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'monospace')),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                if (trip.driverName.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.glassSurfaceElevated,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_outline, size: 10, color: AppColors.primaryGlow),
                        const SizedBox(width: 4),
                        Text(trip.driverName, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                const Spacer(),
                Text(
                  timeRange,
                  style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontFamily: 'monospace'),
                ),
                if (trip.durationMinutes != null && trip.durationMinutes! > 0) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('${trip.durationMinutes}m', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  ),
                ],
              ],
            ),
            if (trip.hasIbtDocuments) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.glassSurfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primaryGlow.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long_outlined, size: 13, color: AppColors.primaryGlow),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        trip.ibtDocuments!.map((d) => '${d.documentNo} (${d.loadedTotal}/${d.total})').join(' • '),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        AppHaptics.medium();
                        IbtLineItemsSheet.show(context, trip: trip);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGlow.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Breakdown',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryGlow,
                              ),
                            ),
                            Icon(Icons.chevron_right, size: 12, color: AppColors.primaryGlow),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showEditDespatcherDialog(BuildContext context, SettingsRepository settings) {
    final controller = TextEditingController(text: settings.despatcherName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundSecondary,
        title: const Text('Change Despatcher Name', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: 'e.g. Theolus',
            hintStyle: const TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.glassSurface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
          ElevatedButton(
            onPressed: () {
              AppHaptics.light();
              settings.saveDespatcherName(controller.text);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
