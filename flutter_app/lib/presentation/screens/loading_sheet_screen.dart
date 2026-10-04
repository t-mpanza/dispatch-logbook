import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_decorations.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';
import '../../data/models/entry.dart';
import '../../data/models/loading_sheet_trip.dart';
import '../../data/repositories/entry_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/services/whatsapp_export_service.dart';
import '../viewmodels/loading_sheet_viewmodel.dart';
import '../widgets/ibt_line_items_sheet.dart';
import '../widgets/truck_load_dialog.dart';
import '../widgets/ui_kit.dart';
import '../entry_route.dart';
import 'pdf_preview_screen.dart';
import 'settings_screen.dart';

/// The daily loading sheet: trucks, tyres, timing and the end-of-day
/// export actions (WhatsApp / PDF).
class LoadingSheetScreen extends StatefulWidget {
  const LoadingSheetScreen({super.key});

  @override
  State<LoadingSheetScreen> createState() => _LoadingSheetScreenState();
}

class _LoadingSheetScreenState extends State<LoadingSheetScreen> {
  List<LoadingSheetTrip>? _tripsCache;
  String? _cacheDate;

  void _onSwipeUpdate(DragEndDetails details, LoadingSheetViewModel vm) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -300) {
      AppHaptics.light();
      vm.shiftDate(1);
    } else if (velocity > 300) {
      AppHaptics.light();
      vm.shiftDate(-1);
    }
  }

  Future<void> _pickDate(LoadingSheetViewModel vm) async {
    final current = DateTime.tryParse(vm.selectedDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      AppHaptics.light();
      vm.setSelectedDate(AppFormatters.dayKey(picked));
    }
  }

  Entry _syntheticEntry(
    String dayKey,
    List<LoadingSheetTrip> trips,
    String prefix,
  ) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return Entry(
      id: '$prefix-$dayKey',
      title: 'Loading Sheet',
      tags: const [],
      notes: const [],
      attachments: const [],
      loadingSheetTrips: trips,
      createdAt: now,
      updatedAt: now,
      dayKey: dayKey,
      monthKey: dayKey.substring(0, 7),
      yearKey: dayKey.substring(0, 4),
    );
  }

  Future<void> _openPdf(
    LoadingSheetViewModel vm,
    List<LoadingSheetTrip> trips,
    String despatcherName,
  ) async {
    AppHaptics.light();
    final dayEntries = await vm.getDayEntries();
    final entry = dayEntries.isNotEmpty
        ? dayEntries.first.copyWith(loadingSheetTrips: trips)
        : _syntheticEntry(vm.selectedDate, trips, 'pdf');
    if (!mounted) return;
    await PdfPreviewScreen.openLoadingSheet(
      context,
      entry: entry,
      despatcherName: despatcherName,
    );
  }

  Future<void> _exportWhatsApp(
    LoadingSheetViewModel vm,
    List<LoadingSheetTrip> trips,
    String despatcherName,
  ) async {
    AppHaptics.light();
    final dayEntries = await vm.getDayEntries();
    final entry = dayEntries.isNotEmpty
        ? dayEntries.first.copyWith(loadingSheetTrips: trips)
        : _syntheticEntry(vm.selectedDate, trips, 'wa');
    final text = WhatsAppExportService.formatWhatsAppText(
      entry,
      despatcherName,
    );
    await WhatsAppExportService.shareToWhatsApp(text);
    if (mounted) {
      AppSnacks.success(context, 'Loading sheet shared to WhatsApp');
    }
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
              var trips = snapshot.data ?? [];
              if (snapshot.hasData) {
                _tripsCache = trips;
                _cacheDate = vm.selectedDate;
              } else if (_tripsCache != null && _cacheDate == vm.selectedDate) {
                trips = _tripsCache!;
              }
              final isLoading =
                  snapshot.connectionState == ConnectionState.waiting &&
                  (_tripsCache == null || _cacheDate != vm.selectedDate);

              var totalTyres = 0;
              var totalMinutes = 0;
              for (final t in trips) {
                totalTyres += t.quantityLoaded;
                totalMinutes += t.durationMinutes ?? 0;
              }
              final hours = totalMinutes ~/ 60;
              final mins = totalMinutes % 60;
              final timeFormatted = totalMinutes > 0
                  ? (hours > 0 ? '${hours}h ${mins}m' : '$totalMinutes min')
                  : '0m';

              final isToday =
                  vm.selectedDate == AppFormatters.dayKey(DateTime.now());

              return Scaffold(
                backgroundColor: Colors.transparent,
                body: RefreshIndicator(
                  color: AppColors.dynamicAccent(context),
                  backgroundColor: AppColors.dynamicBackgroundSecondary(
                    context,
                  ),
                  onRefresh: () async {
                    await context.read<EntryRepository>().syncNow();
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 110),
                    children: [
                      SectionHeader(
                        eyebrow: 'Daily compliance',
                        title: 'Loading Sheet',
                        subtitle: 'Trucks dispatched from the yard',
                        trailing: _DespatcherPill(
                          name: despatcherName,
                          onTap: () {
                            AppHaptics.light();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SettingsScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 14),

                      _DateBar(
                        date: vm.selectedDate,
                        isToday: isToday,
                        onPrev: () {
                          AppHaptics.light();
                          vm.shiftDate(-1);
                        },
                        onNext: () {
                          AppHaptics.light();
                          vm.shiftDate(1);
                        },
                        onPick: () => _pickDate(vm),
                      ),
                      const SizedBox(height: 12),

                      _SummaryCard(
                        trucks: trips.length,
                        tyres: totalTyres,
                        time: timeFormatted,
                        isLoading: isLoading,
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: trips.isEmpty
                                  ? null
                                  : () => _exportWhatsApp(
                                      vm,
                                      trips,
                                      despatcherName,
                                    ),
                              icon: const Icon(Icons.share_rounded, size: 20),
                              label: const Text('WhatsApp'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: trips.isEmpty
                                  ? null
                                  : () => _openPdf(vm, trips, despatcherName),
                              icon: const Icon(
                                Icons.picture_as_pdf_rounded,
                                size: 20,
                              ),
                              label: const Text('PDF'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 52,
                            height: 52,
                            child: IconButton(
                              onPressed: () async {
                                AppHaptics.medium();
                                await TruckLoadDialog.show(
                                  context,
                                  dayKey: vm.selectedDate,
                                  existingTrips: trips,
                                  onSave: (trip) => vm.addTruckLoad(trip),
                                );
                              },
                              style: IconButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: const Icon(Icons.add_rounded, size: 28),
                              tooltip: 'Add truck load',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'TRUCKS TODAY',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.dynamicAccent(context),
                              letterSpacing: 1.5,
                            ),
                          ),
                          if (trips.isNotEmpty)
                            Text(
                              'Swipe to change day',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.dynamicTextMuted(
                                  context,
                                ).withValues(alpha: 0.9),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      if (isLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 48),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (trips.isEmpty)
                        EmptyState(
                          icon: Icons.local_shipping_outlined,
                          title: 'No truck loads on this day',
                          message: isToday
                              ? 'When a truck gets loaded, tap + to add it '
                                    'to the sheet.'
                              : 'Nothing was logged on this date.',
                          actionLabel: isToday ? 'Add truck load' : null,
                          onAction: isToday
                              ? () async {
                                  AppHaptics.medium();
                                  await TruckLoadDialog.show(
                                    context,
                                    dayKey: vm.selectedDate,
                                    existingTrips: trips,
                                    onSave: (trip) => vm.addTruckLoad(trip),
                                  );
                                }
                              : null,
                        )
                      else
                        for (var i = 0; i < trips.length; i++) ...[
                          _TruckCard(
                            index: i + 1,
                            trip: trips[i],
                            onTap: () {
                              AppHaptics.light();
                              TruckLoadDialog.show(
                                context,
                                existingTrip: trips[i],
                                dayKey: vm.selectedDate,
                                existingTrips: trips,
                                onSave: (updated) =>
                                    vm.updateTruckLoad(updated),
                                onDelete: () => vm.deleteTruckLoad(trips[i].id),
                              );
                            },
                            onOpenEntry:
                                trips[i].entryId != null && !trips[i].isManual
                                ? () {
                                    AppHaptics.light();
                                    context
                                        .read<EntryRepository>()
                                        .getEntryById(trips[i].entryId!)
                                        .then((entry) {
                                          if (entry != null &&
                                              context.mounted) {
                                            openEntryDetail(context, entry);
                                          }
                                        });
                                  }
                                : null,
                            onDelete: () async {
                              final confirmed = await AppDialogs.confirm(
                                context,
                                title: 'Remove this truck?',
                                message:
                                    'It will disappear from the loading sheet.',
                                confirmLabel: 'Remove',
                              );
                              if (confirmed) {
                                await vm.deleteTruckLoad(trips[i].id);
                                if (context.mounted) {
                                  AppSnacks.success(
                                    context,
                                    'Truck removed from sheet',
                                  );
                                }
                              }
                            },
                          ),
                          const SizedBox(height: 10),
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
}

class _DespatcherPill extends StatelessWidget {
  final String name;
  final VoidCallback onTap;

  const _DespatcherPill({required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: GlassDecorations.frostedPill(
          context: context,
          borderRadius: 100,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_rounded,
              size: 16,
              color: AppColors.dynamicAccent(context),
            ),
            const SizedBox(width: 6),
            Text(
              name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.dynamicTextPrimary(context),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.edit_rounded,
              size: 12,
              color: AppColors.dynamicTextMuted(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateBar extends StatelessWidget {
  final String date;
  final bool isToday;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onPick;

  const _DateBar({
    required this.date,
    required this.isToday,
    required this.onPrev,
    required this.onNext,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final parsed = DateTime.tryParse(date) ?? DateTime.now();
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: GlassDecorations.glassCard(
        context: context,
        borderRadius: 18,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrev,
            icon: Icon(
              Icons.chevron_left_rounded,
              color: AppColors.dynamicTextPrimary(context),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: onPick,
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 15,
                    color: AppColors.dynamicAccent(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppFormatters.formatShortDay(parsed),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.dynamicTextPrimary(context),
                    ),
                  ),
                  if (isToday) ...[
                    const SizedBox(width: 8),
                    StatusPill(label: 'TODAY', tone: PillTone.brand),
                  ],
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: Icon(
              Icons.chevron_right_rounded,
              color: AppColors.dynamicTextPrimary(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int trucks;
  final int tyres;
  final String time;
  final bool isLoading;

  const _SummaryCard({
    required this.trucks,
    required this.tyres,
    required this.time,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: GlassDecorations.glassElevated(
        context: context,
        borderRadius: 22,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          KpiTile(
            icon: Icons.local_shipping_rounded,
            label: 'Trucks',
            value: isLoading ? '—' : '$trucks',
          ),
          _divider(context),
          KpiTile(
            icon: Icons.layers_rounded,
            label: 'Tyres',
            value: isLoading ? '—' : '$tyres',
            accent: AppColors.dynamicAccent(context),
          ),
          _divider(context),
          KpiTile(
            icon: Icons.timer_outlined,
            label: 'Total time',
            value: isLoading ? '—' : time,
            accent: AppColors.dynamicTextSecondary(context),
          ),
        ],
      ),
    );
  }

  Widget _divider(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      color: AppColors.dynamicBorderLight(context),
    );
  }
}

class _TruckCard extends StatelessWidget {
  final int index;
  final LoadingSheetTrip trip;
  final VoidCallback onTap;
  final VoidCallback? onOpenEntry;
  final VoidCallback onDelete;

  const _TruckCard({
    required this.index,
    required this.trip,
    required this.onTap,
    required this.onOpenEntry,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final badgeColor = presetColor(trip.presetKey, trip.tripId);
    final hasTiming = trip.startTime != null && trip.finishTime != null;
    final timeRange = hasTiming
        ? '${AppFormatters.formatTimeHHmm(trip.startTime)} → ${AppFormatters.formatTimeHHmm(trip.finishTime)}'
        : 'No timestamps';
    final pct = trip.progressPercent;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: GlassDecorations.glassCard(
          context: context,
          borderRadius: 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.dynamicCardSurface(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      '$index',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppColors.dynamicTextSecondary(context),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PresetBadge(
                    presetKey: trip.presetKey,
                    tripId: trip.tripId,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.dynamicAccent(
                        context,
                      ).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    '${trip.quantityLoaded} tyres',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: AppColors.dynamicAccent(context),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (onOpenEntry != null)
                  GestureDetector(
                    onTap: onOpenEntry,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.open_in_new_rounded,
                        size: 17,
                        color: AppColors.dynamicAccent(context),
                      ),
                    ),
                  )
                else
                  GestureDetector(
                    onTap: onDelete,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppColors.dynamicTextMuted(context),
                      ),
                    ),
                  ),
              ],
            ),
            if (pct != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 6,
                        backgroundColor: Colors.white.withValues(alpha: 0.07),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          trip.isTargetExceeded
                              ? AppColors.warning
                              : (trip.isTargetReached
                                    ? AppColors.success
                                    : badgeColor),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    trip.isTargetExceeded
                        ? '+${trip.overCount} over'
                        : (trip.isTargetReached
                              ? 'Complete'
                              : '${trip.remainingTyres} to go'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: trip.isTargetExceeded
                          ? AppColors.warning
                          : (trip.isTargetReached
                                ? AppColors.success
                                : AppColors.dynamicTextSecondary(context)),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (trip.reg.isNotEmpty)
                  _infoChip(
                    context,
                    icon: Icons.local_shipping_outlined,
                    text: trip.reg,
                  ),
                if (trip.reg.isNotEmpty && trip.driverName.isNotEmpty)
                  const SizedBox(width: 8),
                if (trip.driverName.isNotEmpty)
                  _infoChip(
                    context,
                    icon: Icons.person_outline_rounded,
                    text: trip.driverName,
                  ),
                const Spacer(),
                Text(
                  timeRange,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.dynamicTextMuted(context),
                  ),
                ),
              ],
            ),
            if (trip.hasIbtDocuments) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.dynamicCardSurface(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.dynamicAccent(
                      context,
                    ).withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 16,
                      color: AppColors.dynamicAccent(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        trip.ibtDocuments!
                            .map(
                              (d) =>
                                  '${d.documentNo} (${d.loadedTotal}/${d.total})',
                            )
                            .join('  •  '),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.dynamicTextPrimary(context),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        AppHaptics.medium();
                        IbtLineItemsSheet.show(context, trip: trip);
                      },
                      child: Row(
                        children: [
                          Text(
                            'Breakdown',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.dynamicAccent(context),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: AppColors.dynamicAccent(context),
                          ),
                        ],
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

  Widget _infoChip(
    BuildContext context, {
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.dynamicCardSurface(context),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.dynamicAccent(context)),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.dynamicTextPrimary(context),
            ),
          ),
        ],
      ),
    );
  }
}
