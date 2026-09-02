import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_decorations.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';
import '../../data/models/entry.dart';
import '../../data/services/update_service.dart';
import '../../data/repositories/entry_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../viewmodels/entries_viewmodel.dart';
import '../widgets/swipeable_entry_card.dart';
import '../widgets/update_dialog.dart';
import '../entry_route.dart';
import 'day_screen.dart';
import 'new_entry_screen.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  String _currentVersion = '...';
  bool _isCheckingUpdate = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final ver = await UpdateService.getCurrentVersion();
    if (mounted) {
      setState(() => _currentVersion = ver);
    }
  }

  Future<void> _checkForUpdates() async {
    AppHaptics.light();
    setState(() => _isCheckingUpdate = true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: AppColors.primaryGlow, strokeWidth: 2)),
              SizedBox(width: 12),
              Text('Checking GitHub for update candidates…'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );
    }

    final info = await UpdateService.checkForUpdates();
    if (!mounted) return;
    setState(() => _isCheckingUpdate = false);

    UpdateDialog.show(context, info);
  }

  void _showDiagnosticsModal(BuildContext context) {
    AppHaptics.light();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Consumer<EntryRepository>(
          builder: (ctx, repo, _) {
            final state = repo.syncState;
            final accentColor = AppColors.isLight(ctx) ? AppColors.primary : AppColors.primaryGlow;
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.isLight(ctx) ? Colors.white : AppColors.backgroundSecondary,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.isLight(ctx)
                              ? const Color(0xFFCBD5E1)
                              : Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Dispatch Diary System Info',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.dynamicTextPrimary(ctx)),
                    ),
                    const SizedBox(height: 4),
                    Text('Native Flutter Engine · Cloud Diagnostics', style: TextStyle(fontSize: 11, color: AppColors.dynamicTextMuted(ctx))),
                    const SizedBox(height: 16),
                    _diagRow(ctx, 'Platform', 'Native Flutter (Android / APK)'),
                    _diagRow(ctx, 'Installed Version', _currentVersion),
                    _diagRow(
                      ctx,
                      'Cloud Sync Status',
                      state.status.name.toUpperCase(),
                      color: state.status.name == 'synced' ? AppColors.success : accentColor,
                    ),
                    _diagRow(ctx, 'Pending Changes', '${state.pendingCount}'),
                    const SizedBox(height: 18),

                    // Check for updates button
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _checkForUpdates();
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: accentColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: Icon(Icons.system_update_rounded, size: 18, color: accentColor),
                        label: Text('Check for Updates & Release Candidates', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Force sync button
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          AppHaptics.medium();
                          await repo.syncNow();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.sync_rounded, color: Colors.white, size: 18),
                        label: const Text('Force Cloud Sync Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _diagRow(BuildContext context, String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: AppColors.dynamicTextMuted(context))),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color ?? AppColors.dynamicTextPrimary(context),
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayKey = AppFormatters.dayKey(now);
    final yesterdayKey = AppFormatters.dayKey(now.subtract(const Duration(days: 1)));

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 76),
        child: FloatingActionButton(
          onPressed: () {
            AppHaptics.medium();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NewEntryScreen()),
            );
          },
          backgroundColor: AppColors.primary,
          elevation: 8,
          shape: const CircleBorder(),
          child: const Icon(Icons.add_rounded, size: 28, color: Colors.white),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primaryGlow,
        backgroundColor: AppColors.isLight(context) ? Colors.white : AppColors.backgroundSecondary,
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
                final isLoading = snapshot.connectionState == ConnectionState.waiting;

                return CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  slivers: [
                    // Header
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TODAY',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.isLight(context) ? AppColors.primary : AppColors.primaryGlow,
                                    letterSpacing: 2.0,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  AppFormatters.formatDayLabel(now.millisecondsSinceEpoch),
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.dynamicTextPrimary(context),
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  entries.isEmpty
                                      ? 'Nothing logged yet. Tap + to capture.'
                                      : '${entries.length} ${entries.length == 1 ? "trip entry" : "trip entries"}',
                                  style: TextStyle(fontSize: 12, color: AppColors.dynamicTextSecondary(context)),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Consumer<SettingsRepository>(
                                      builder: (context, settings, _) {
                                        final isSun = settings.isSunlightMode;
                                        return GestureDetector(
                                          onTap: () {
                                            AppHaptics.medium();
                                            settings.toggleSunlightMode();
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: isSun ? Colors.amber.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.08),
                                              borderRadius: BorderRadius.circular(14),
                                              border: Border.all(
                                                color: isSun ? Colors.amber : (AppColors.isLight(context) ? const Color(0xFFCBD5E1) : AppColors.glassBorderLight),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  isSun ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                                                  size: 14,
                                                  color: isSun ? Colors.amber : (AppColors.isLight(context) ? AppColors.primary : AppColors.primaryGlow),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  isSun ? 'Day' : 'Night',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: isSun ? Colors.amber.shade800 : AppColors.dynamicTextPrimary(context),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: () {
                                        AppHaptics.light();
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => DayScreen(dayKey: yesterdayKey)),
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: GlassDecorations.glassCard(context: context, borderRadius: 14),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.chevron_left_rounded, size: 14, color: AppColors.isLight(context) ? AppColors.primary : AppColors.primaryGlow),
                                            const SizedBox(width: 2),
                                            Text('Yesterday', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.dynamicTextPrimary(context))),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                GestureDetector(
                                  onTap: () => _showDiagnosticsModal(context),
                                  onLongPress: () => _checkForUpdates(),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.isLight(context) ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: AppColors.dynamicBorder(context)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          _isCheckingUpdate ? Icons.hourglass_top_rounded : Icons.system_update_rounded,
                                          size: 10,
                                          color: AppColors.isLight(context) ? AppColors.primary : AppColors.primaryGlow,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _currentVersion,
                                          style: TextStyle(fontSize: 10, color: AppColors.dynamicTextMuted(context), fontFamily: 'monospace', fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Entries List
                    if (isLoading)
                      SliverFillRemaining(
                        child: Center(
                          child: CircularProgressIndicator(color: AppColors.isLight(context) ? AppColors.primary : AppColors.primaryGlow),
                        ),
                      )
                    else if (entries.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.all(32),
                              decoration: GlassDecorations.glassCard(context: context, borderRadius: 24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.note_add_rounded, size: 36, color: AppColors.isLight(context) ? AppColors.primary : AppColors.primaryGlow),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No Trip Entries Today',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.dynamicTextPrimary(context)),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Tap the floating + button to capture trip loads, tyre counts, or notes.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 12, color: AppColors.dynamicTextMuted(context)),
                                  ),
                                  const SizedBox(height: 20),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      AppHaptics.medium();
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const NewEntryScreen()),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                    icon: const Icon(Icons.add_rounded, color: Colors.white),
                                    label: const Text('Capture First Trip', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
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
                                    AppHaptics.error();
                                    await vm.deleteEntry(entry.id);
                                  },
                                ),
                              );
                            },
                            childCount: entries.length,
                          ),
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
