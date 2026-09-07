import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_decorations.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';
import '../../data/models/entry.dart';
import '../../data/models/sync_state.dart';
import '../../data/repositories/entry_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/services/update_service.dart';
import '../entry_route.dart';
import '../viewmodels/entries_viewmodel.dart';
import '../viewmodels/loading_sheet_viewmodel.dart';
import '../widgets/swipeable_entry_card.dart';
import '../widgets/truck_load_dialog.dart';
import '../widgets/ui_kit.dart';
import '../widgets/update_dialog.dart';
import '../widgets/welcome_sheet.dart';
import 'day_screen.dart';
import 'new_entry_screen.dart';
import 'settings_screen.dart';

/// Home: the day at a glance. Greeting, headline numbers, quick actions and
/// today's activity — everything a despatch worker needs first.
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  String _currentVersion = '…';
  static bool _autoUpdateCheckDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeWelcome());
    _loadVersion();
    _scheduleAutoUpdateCheck();
  }

  void _maybeWelcome() {
    final settings = context.read<SettingsRepository>();
    if (!settings.welcomeSeen) {
      WelcomeSheet.show(context);
    }
  }

  Future<void> _loadVersion() async {
    final ver = await UpdateService.getCurrentVersion();
    if (mounted) setState(() => _currentVersion = ver);
  }

  void _scheduleAutoUpdateCheck() {
    if (_autoUpdateCheckDone) return;
    _autoUpdateCheckDone = true;
    Future.delayed(const Duration(seconds: 5), () async {
      try {
        final info = await UpdateService.checkForUpdates();
        if (mounted && info.hasUpdate && info.apkDownloadUrl != null) {
          UpdateDialog.show(context, info);
        }
      } catch (_) {}
    });
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 5) return 'Working late';
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> _addTruckLoad() async {
    final vm = context.read<LoadingSheetViewModel>();
    final todayKey = AppFormatters.dayKey(DateTime.now());
    vm.setSelectedDate(todayKey);
    final trips = await vm.getTripsForSelectedDate();
    if (!mounted) return;
    await TruckLoadDialog.show(
      context,
      dayKey: todayKey,
      existingTrips: trips,
      onSave: (trip) => vm.addTruckLoad(trip),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayKey = AppFormatters.dayKey(now);
    final yesterdayKey = AppFormatters.dayKey(
      now.subtract(const Duration(days: 1)),
    );
    final settings = context.watch<SettingsRepository>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        color: AppColors.dynamicAccent(context),
        backgroundColor: AppColors.dynamicBackgroundSecondary(context),
        onRefresh: () async {
          AppHaptics.light();
          try {
            await context.read<EntryRepository>().syncNow().timeout(
              const Duration(seconds: 10),
              onTimeout: () => false,
            );
          } catch (_) {}
        },
        child: Consumer<EntriesViewModel>(
          builder: (context, vm, _) {
            return FutureBuilder<List<Entry>>(
              future: vm.getEntriesForDay(todayKey),
              builder: (context, snapshot) {
                final entries = snapshot.data ?? [];
                final isLoading =
                    snapshot.connectionState == ConnectionState.waiting;
                final stats = _DayStats.from(entries);

                return CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_greeting()}, ${settings.despatcherName}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.dynamicTextSecondary(
                                        context,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    AppFormatters.formatDayLabel(
                                      now.millisecondsSinceEpoch,
                                    ),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.headlineMedium,
                                  ),
                                ],
                              ),
                            ),
                            _HeaderActions(
                              version: _currentVersion,
                              onSettings: () {
                                AppHaptics.light();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SettingsScreen(),
                                  ),
                                );
                              },
                              onYesterday: () {
                                AppHaptics.light();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        DayScreen(dayKey: yesterdayKey),
                                  ),
                                );
                              },
                              onToggleSun: () {
                                AppHaptics.medium();
                                settings.toggleSunlightMode();
                              },
                              isSun: settings.isSunlightMode,
                            ),
                          ],
                        ),
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: _DaySummaryCard(
                          stats: stats,
                          isLoading: isLoading,
                        ),
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: ActionTile(
                                icon: Icons.local_shipping_rounded,
                                label: 'Truck Load',
                                caption: 'Add to sheet',
                                color: AppColors.dynamicAccent(context),
                                onTap: _addTruckLoad,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ActionTile(
                                icon: Icons.note_add_rounded,
                                label: 'Trip Entry',
                                caption: 'Route trip',
                                color: AppColors.presetNlh,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const NewEntryScreen(),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ActionTile(
                                icon: Icons.exposure_plus_1_rounded,
                                label: 'Count',
                                caption: 'Tally tyres',
                                color: AppColors.presetStocks,
                                onTap: () async {
                                  AppHaptics.medium();
                                  final entry = await vm.createEntry(
                                    title:
                                        'COUNT - ${AppFormatters.formatTimeHHmm(DateTime.now().millisecondsSinceEpoch)}',
                                    tags: const ['tyres', 'count'],
                                    withCounter: true,
                                  );
                                  if (context.mounted) {
                                    openEntryDetail(context, entry);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
                        child: _ActiveStocksSection(
                          entries: entries,
                          onResume: (id) {
                            AppHaptics.medium();
                            final e = entries.firstWhere((x) => x.id == id);
                            openEntryDetail(context, e);
                          },
                        ),
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'TODAY\'S ACTIVITY',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.dynamicAccent(context),
                                letterSpacing: 1.5,
                              ),
                            ),
                            Text(
                              entries.isEmpty
                                  ? 'Nothing yet'
                                  : '${entries.length} ${entries.length == 1 ? "entry" : "entries"}',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.dynamicTextMuted(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (isLoading)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (entries.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                          child: EmptyState(
                            icon: Icons.local_shipping_outlined,
                            title: 'No trips logged yet today',
                            message:
                                'Tap the + button to log a truck load, start a '
                                'trip or run a count session.',
                            actionLabel: 'Log first truck load',
                            onAction: _addTruckLoad,
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final entry = entries[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: SwipeableEntryCard(
                                entry: entry,
                                onTap: () {
                                  AppHaptics.light();
                                  openEntryDetail(context, entry);
                                },
                                onEdit: () {
                                  AppHaptics.light();
                                  openEntryDetail(context, entry);
                                },
                                onDelete: () async {
                                  final confirmed = await AppDialogs.confirm(
                                    context,
                                    title: 'Delete this entry?',
                                    message:
                                        'This permanently removes '
                                        'the entry and its media.',
                                  );
                                  if (confirmed) {
                                    await vm.deleteEntry(entry.id);
                                    if (context.mounted) {
                                      AppSnacks.success(
                                        context,
                                        'Entry deleted',
                                      );
                                    }
                                  }
                                },
                              ),
                            );
                          }, childCount: entries.length),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _DayStats {
  final int tyres;
  final int trips;
  final int trucks;

  const _DayStats({
    required this.tyres,
    required this.trips,
    required this.trucks,
  });

  factory _DayStats.from(List<Entry> entries) {
    var tyres = 0;
    var trips = 0;
    var trucks = 0;
    for (final e in entries) {
      final loading = e.loadingSheetTrips ?? [];
      final legacy = e.trips ?? [];
      if (loading.isNotEmpty) {
        tyres += loading.fold<int>(0, (s, t) => s + t.quantityLoaded);
        trucks += loading.length;
        trips += loading.length;
      } else if (legacy.isNotEmpty) {
        tyres += legacy.fold<int>(0, (s, t) => s + t.count + (t.rejected ?? 0));
        trips += legacy.length;
      }
    }
    return _DayStats(tyres: tyres, trips: trips, trucks: trucks);
  }
}

/// Today's active STOCKS runs: manifest progress at a glance with a
/// one-tap resume into the tally screen.
class _ActiveStocksSection extends StatelessWidget {
  final List<Entry> entries;
  final ValueChanged<String> onResume;

  const _ActiveStocksSection({required this.entries, required this.onResume});

  @override
  Widget build(BuildContext context) {
    final stocks = entries.where(isStocksEntry).toList();
    if (stocks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'ACTIVE STOCKS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.presetStocks,
                letterSpacing: 1.5,
              ),
            ),
            Text(
              '${stocks.length} run${stocks.length == 1 ? "" : "s"}',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.dynamicTextMuted(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final e in stocks.take(2)) ...[
          _StocksRunCard(entry: e, onResume: () => onResume(e.id)),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _StocksRunCard extends StatelessWidget {
  final Entry entry;
  final VoidCallback onResume;

  const _StocksRunCard({required this.entry, required this.onResume});

  @override
  Widget build(BuildContext context) {
    final trips = entry.loadingSheetTrips ?? [];
    var loaded = 0;
    var target = 0;
    var docCount = 0;
    var lineCount = 0;
    var incompleteLines = 0;
    for (final t in trips) {
      loaded += t.ibtLoadedTotal;
      target += t.ibtTargetTotal;
      final docs = t.ibtDocuments ?? [];
      for (final d in docs) {
        docCount++;
        lineCount += d.lineItems.length;
        incompleteLines += d.lineItems.where((l) => !l.isComplete).length;
      }
    }
    final pct = target > 0 ? (loaded / target).clamp(0.0, 1.0) : 0.0;
    final complete = target > 0 && loaded >= target;

    return GestureDetector(
      onTap: onResume,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: GlassDecorations.glassCard(
          context: context,
          borderRadius: 20,
          borderColor: complete
              ? AppColors.success.withValues(alpha: 0.5)
              : AppColors.presetStocks.withValues(alpha: 0.45),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.presetStocks.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.presetStocks.withValues(alpha: 0.4),
                ),
              ),
              child: const Icon(
                Icons.inventory_2_rounded,
                color: AppColors.presetStocks,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title.isNotEmpty ? entry.title : 'STOCKS RUN',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.dynamicTextPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    complete
                        ? 'Manifest complete — ready for the sheet'
                        : (incompleteLines > 0
                              ? '$incompleteLines line${incompleteLines == 1 ? "" : "s"} still loading'
                              : '$docCount IBT doc${docCount == 1 ? "" : "s"}'),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.dynamicTextSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 8,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.08,
                            ),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              complete
                                  ? AppColors.success
                                  : AppColors.presetStocks,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '$loaded/$target',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: AppColors.dynamicTextPrimary(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              children: [
                FilledButton(
                  onPressed: onResume,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    backgroundColor: AppColors.presetStocks,
                    foregroundColor: AppColors.onAccent,
                  ),
                  child: Text(complete ? 'View' : 'Resume'),
                ),
                const SizedBox(height: 6),
                Text(
                  '$lineCount lines',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.dynamicTextMuted(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DaySummaryCard extends StatelessWidget {
  final _DayStats stats;
  final bool isLoading;

  const _DaySummaryCard({required this.stats, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<EntryRepository>().syncState;
    final healthy =
        sync.status == SyncStatus.synced || sync.status == SyncStatus.idle;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      decoration: GlassDecorations.glassElevated(
        context: context,
        borderRadius: 24,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              KpiTile(
                icon: Icons.layers_rounded,
                label: 'Tyres',
                value: isLoading ? '—' : '${stats.tyres}',
                accent: AppColors.dynamicAccent(context),
              ),
              _divider(context),
              KpiTile(
                icon: Icons.local_shipping_rounded,
                label: 'Trucks',
                value: isLoading ? '—' : '${stats.trucks}',
              ),
              _divider(context),
              KpiTile(
                icon: Icons.route_rounded,
                label: 'Trips',
                value: isLoading ? '—' : '${stats.trips}',
              ),
            ],
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () {
              AppHaptics.medium();
              context.read<EntryRepository>().syncNow();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  healthy ? Icons.cloud_done_rounded : Icons.cloud_sync_rounded,
                  size: 14,
                  color: healthy
                      ? AppColors.success
                      : AppColors.dynamicAccent(context),
                ),
                const SizedBox(width: 6),
                Text(
                  healthy
                      ? 'Cloud synced'
                      : '${sync.pendingCount} change(s) waiting — tap to sync',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: healthy
                        ? AppColors.dynamicTextMuted(context)
                        : AppColors.dynamicAccent(context),
                  ),
                ),
              ],
            ),
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

class _HeaderActions extends StatelessWidget {
  final String version;
  final VoidCallback onSettings;
  final VoidCallback onYesterday;
  final VoidCallback onToggleSun;
  final bool isSun;

  const _HeaderActions({
    required this.version,
    required this.onSettings,
    required this.onYesterday,
    required this.onToggleSun,
    required this.isSun,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _roundIconButton(
              context,
              icon: isSun ? Icons.wb_sunny_rounded : Icons.nightlight_round,
              label: isSun ? 'Day' : 'Night',
              highlight: isSun,
              onTap: onToggleSun,
            ),
            const SizedBox(width: 6),
            _roundIconButton(
              context,
              icon: Icons.settings_rounded,
              label: 'Settings',
              onTap: onSettings,
            ),
          ],
        ),
        const SizedBox(height: 6),
        _roundIconButton(
          context,
          icon: Icons.chevron_left_rounded,
          label: 'Yesterday',
          onTap: onYesterday,
        ),
      ],
    );
  }

  Widget _roundIconButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool highlight = false,
  }) {
    return GestureDetector(
      onTap: () {
        AppHaptics.light();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: highlight
            ? BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.5),
                ),
              )
            : GlassDecorations.frostedPill(context: context, borderRadius: 100),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: highlight
                  ? AppColors.warning
                  : AppColors.dynamicAccent(context),
            ),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: highlight
                    ? AppColors.warning
                    : AppColors.dynamicTextPrimary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
