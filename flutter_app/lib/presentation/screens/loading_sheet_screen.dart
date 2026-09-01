import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_decorations.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';
import '../../data/models/entry.dart';
import '../../data/models/loading_sheet_trip.dart';
import '../../data/models/preset.dart';
import '../../data/services/whatsapp_export_service.dart';
import '../../data/repositories/entry_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../viewmodels/loading_sheet_viewmodel.dart';
import '../widgets/aws_auth_dialog.dart';
import '../widgets/ibt_line_items_sheet.dart';
import '../widgets/truck_load_dialog.dart';
import 'entry_detail_screen.dart';
import 'pdf_preview_screen.dart';

class LoadingSheetScreen extends StatefulWidget {
  const LoadingSheetScreen({super.key});

  @override
  State<LoadingSheetScreen> createState() => _LoadingSheetScreenState();
}

class _LoadingSheetScreenState extends State<LoadingSheetScreen> {
  // Cache trips to avoid spinner flash on IBT stepper updates or other re-renders.
  // isLoading only shows a spinner when we have no data yet (first load for a date).
  List<LoadingSheetTrip> _tripsCache = [];
  String? _cacheDate;

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
              // Update cache when data arrives so re-renders don't flash a spinner
              if (snapshot.hasData) {
                _tripsCache = snapshot.data!;
                _cacheDate = vm.selectedDate;
              }
              // Show cached data while re-loading; spinner only on true first load for this date
              final trips = snapshot.data ??
                  (_cacheDate == vm.selectedDate ? _tripsCache : []);
              final isLoading =
                  snapshot.connectionState == ConnectionState.waiting && trips.isEmpty;

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

              final isLight = AppColors.isLight(context);

              return Scaffold(
                backgroundColor: Colors.transparent,
                body: RefreshIndicator(
                  color: isLight ? AppColors.primary : AppColors.primaryGlow,
                  backgroundColor: isLight ? Colors.white : AppColors.backgroundSecondary,
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
                              Row(
                                children: [
                                  Icon(Icons.description_rounded, size: 14, color: isLight ? AppColors.primary : AppColors.primaryGlow),
                                  const SizedBox(width: 4),
                                  Text(
                                    'DAILY COMPLIANCE',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isLight ? AppColors.primary : AppColors.primaryGlow,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Loading Sheet',
                                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.dynamicTextPrimary(context), letterSpacing: -0.5),
                              ),
                            ],
                          ),

                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => AwsAuthDialog.show(context),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  decoration: GlassDecorations.glassCard(context: context, borderRadius: 14),
                                  child: Row(
                                    children: [
                                      Icon(Icons.cloud_sync_rounded, size: 14, color: isLight ? AppColors.primary : AppColors.primaryGlow),
                                      const SizedBox(width: 4),
                                      Text(
                                        'AWS Sync',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.dynamicTextPrimary(context)),
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
                                  decoration: GlassDecorations.glassCard(context: context, borderRadius: 14),
                                  child: Row(
                                    children: [
                                      Icon(Icons.person_rounded, size: 14, color: isLight ? AppColors.primary : AppColors.primaryGlow),
                                      const SizedBox(width: 4),
                                      Text(
                                        despatcherName,
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.dynamicTextPrimary(context)),
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
                        decoration: GlassDecorations.glassCard(context: context, borderRadius: 18),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: Icon(Icons.chevron_left_rounded, color: AppColors.dynamicTextPrimary(context)),
                              onPressed: () {
                                AppHaptics.light();
                                vm.shiftDate(-1);
                              },
                            ),
                            Row(
                              children: [
                                Icon(Icons.calendar_today_rounded, size: 14, color: isLight ? AppColors.primary : AppColors.primaryGlow),
                                const SizedBox(width: 6),
                                Text(
                                  vm.selectedDate,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.dynamicTextPrimary(context),
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                if (vm.selectedDate == AppFormatters.dayKey(DateTime.now())) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: isLight ? 0.12 : 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text('TODAY', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: isLight ? AppColors.primary : AppColors.primaryGlow)),
                                  ),
                                ],
                              ],
                            ),
                            IconButton(
                              icon: Icon(Icons.chevron_right_rounded, color: AppColors.dynamicTextPrimary(context)),
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
                        decoration: isLight
                            ? BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFEFF6FF), Color(0xFFEEF2FF)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: const Color(0xFFBFDBFE)),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              )
                            : GlassDecorations.glassElevated(borderRadius: 22),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildKpi(
                              context: context,
                              icon: Icons.local_shipping_rounded,
                              label: 'TRUCKS',
                              value: '${trips.length}',
                            ),
                            Container(width: 1, height: 36, color: AppColors.dynamicBorder(context)),
                            _buildKpi(
                              context: context,
                              icon: Icons.access_time_rounded,
                              label: 'TOTAL TIME',
                              value: timeFormatted,
                            ),
                            Container(width: 1, height: 36, color: AppColors.dynamicBorder(context)),
                            _buildKpi(
                              context: context,
                              icon: Icons.layers_rounded,
                              label: 'TYRES',
                              value: '$totalTyres',
                              valueColor: isLight ? AppColors.primary : AppColors.primaryGlow,
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

                                if (context.mounted) {
                                  await PdfPreviewScreen.openLoadingSheet(
                                    context,
                                    entry: entry,
                                    despatcherName: despatcherName,
                                  );
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: AppColors.dynamicBorder(context)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              icon: Icon(Icons.picture_as_pdf_rounded, size: 16, color: isLight ? AppColors.primary : AppColors.primaryGlow),
                              label: Text('PDF Preview', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.dynamicTextPrimary(context))),
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
                        Center(child: Padding(padding: const EdgeInsets.all(32), child: CircularProgressIndicator(color: isLight ? AppColors.primary : AppColors.primaryGlow)))
                      else if (trips.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: GlassDecorations.glassCard(context: context, borderRadius: 22),
                          child: Column(
                            children: [
                              Icon(Icons.local_shipping_outlined, size: 40, color: AppColors.dynamicTextMuted(context)),
                              const SizedBox(height: 12),
                              Text('No truck loads logged for this date', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.dynamicTextPrimary(context))),
                              const SizedBox(height: 4),
                              Text('Tap "+ Truck" to record a delivery trip.', style: TextStyle(fontSize: 11, color: AppColors.dynamicTextMuted(context))),
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
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    final isLight = AppColors.isLight(context);
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: isLight ? AppColors.primary : AppColors.primaryGlow),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.dynamicTextMuted(context), letterSpacing: 0.8)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: valueColor ?? AppColors.dynamicTextPrimary(context),
            fontFamily: 'monospace',
          ),
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
    final isLight = AppColors.isLight(context);
    final badgeColor = _getBadgeColor(trip.tripId, trip.presetKey);
    final hasTiming = trip.startTime != null && trip.finishTime != null;
    final timeRange = hasTiming
        ? '${AppFormatters.formatTimeHHmm(trip.startTime)} → ${AppFormatters.formatTimeHHmm(trip.finishTime)}'
        : 'No timestamps';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: GlassDecorations.glassCard(context: context, borderRadius: 18),
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
                      decoration: BoxDecoration(
                        color: isLight ? const Color(0xFFE2E8F0) : AppColors.glassSurfaceElevated,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$index',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.dynamicTextPrimary(context)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: isLight ? 0.12 : 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: badgeColor.withValues(alpha: isLight ? 0.4 : 0.3)),
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
                    if (trip.targetQuantity != null && trip.targetQuantity! > 0) ...[
                      if (trip.isTargetReached && !trip.isTargetExceeded)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Done', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.success)),
                        )
                      else if (trip.isTargetExceeded)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('+${trip.overCount} over', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.warning)),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (isLight ? AppColors.primary : AppColors.primaryGlow).withValues(alpha: isLight ? 0.12 : 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${trip.remainingTyres} left',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isLight ? AppColors.primary : AppColors.primaryGlow,
                            ),
                          ),
                        ),
                      const SizedBox(width: 6),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: isLight ? 0.12 : 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: (isLight ? AppColors.primary : AppColors.primaryGlow).withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        trip.targetQuantity != null && trip.targetQuantity! > 0
                            ? '${trip.quantityLoaded} / ${trip.targetQuantity}'
                            : '${trip.quantityLoaded} tyres',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: isLight ? AppColors.primary : AppColors.primaryGlow,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (trip.entryId != null && !trip.isManual)
                      GestureDetector(
                        onTap: () {
                          AppHaptics.light();
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => EntryDetailScreen(entryId: trip.entryId!)),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: isLight ? 0.1 : 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.open_in_new_rounded,
                            size: 14,
                            color: isLight ? AppColors.primary : AppColors.primaryGlow,
                          ),
                        ),
                      )
                    else
                      Icon(Icons.edit_outlined, size: 16, color: AppColors.dynamicTextMuted(context)),
                  ],
                ),
              ],
            ),
            if (trip.progressPercent != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: trip.progressPercent!,
                  minHeight: 4,
                  backgroundColor: isLight ? const Color(0xFFE2E8F0) : Colors.white.withValues(alpha: 0.06),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    trip.isTargetReached
                        ? AppColors.success
                        : (trip.isTargetExceeded ? AppColors.warning : (isLight ? AppColors.primary : AppColors.primaryGlow)),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                if (trip.reg.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isLight ? const Color(0xFFF1F5F9) : AppColors.glassSurfaceElevated,
                      borderRadius: BorderRadius.circular(6),
                      border: isLight ? Border.all(color: const Color(0xFFCBD5E1)) : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.local_shipping_outlined, size: 10, color: isLight ? AppColors.primary : AppColors.primaryGlow),
                        const SizedBox(width: 4),
                        Text(trip.reg, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.dynamicTextPrimary(context), fontFamily: 'monospace')),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                if (trip.driverName.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isLight ? const Color(0xFFF1F5F9) : AppColors.glassSurfaceElevated,
                      borderRadius: BorderRadius.circular(6),
                      border: isLight ? Border.all(color: const Color(0xFFCBD5E1)) : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_outline, size: 10, color: isLight ? AppColors.primary : AppColors.primaryGlow),
                        const SizedBox(width: 4),
                        Text(trip.driverName, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.dynamicTextPrimary(context))),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                const Spacer(),
                Text(
                  timeRange,
                  style: TextStyle(fontSize: 10, color: AppColors.dynamicTextMuted(context), fontFamily: 'monospace'),
                ),
                if (trip.durationMinutes != null && trip.durationMinutes! > 0) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: isLight ? const Color(0xFFE2E8F0) : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('${trip.durationMinutes}m', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.dynamicTextPrimary(context))),
                  ),
                ],
              ],
            ),
            if (trip.hasIbtDocuments) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isLight ? const Color(0xFFF1F5F9) : AppColors.glassSurfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: (isLight ? AppColors.primary : AppColors.primaryGlow).withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 13, color: isLight ? AppColors.primary : AppColors.primaryGlow),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        trip.ibtDocuments!.map((d) => '${d.documentNo} (${d.loadedTotal}/${d.total})').join(' • '),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.dynamicTextPrimary(context),
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
                          color: (isLight ? AppColors.primary : AppColors.primaryGlow).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Breakdown',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isLight ? AppColors.primary : AppColors.primaryGlow,
                              ),
                            ),
                            Icon(Icons.chevron_right, size: 12, color: isLight ? AppColors.primary : AppColors.primaryGlow),
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
    final isLight = AppColors.isLight(context);
    final controller = TextEditingController(text: settings.despatcherName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isLight ? Colors.white : AppColors.backgroundSecondary,
        title: Text('Change Despatcher Name', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.dynamicTextPrimary(context))),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: AppColors.dynamicTextPrimary(context), fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: 'e.g. Theolus',
            hintStyle: TextStyle(color: AppColors.dynamicTextMuted(context)),
            filled: true,
            fillColor: isLight ? const Color(0xFFF8FAFC) : AppColors.glassSurface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: isLight ? const BorderSide(color: Color(0xFFCBD5E1)) : BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: AppColors.dynamicTextMuted(context)))),
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
