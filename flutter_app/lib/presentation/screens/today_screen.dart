import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_decorations.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';
import '../../data/models/entry.dart';
import '../../data/services/update_service.dart';
import '../../data/repositories/entry_repository.dart';
import '../viewmodels/entries_viewmodel.dart';
import '../widgets/swipeable_entry_card.dart';
import '../widgets/update_dialog.dart';
import 'day_screen.dart';
import 'entry_detail_screen.dart';
import 'new_entry_screen.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  String _currentVersion = 'v2.0.0';
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
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Dispatch Diary System Info',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    const Text('Native Flutter Engine · Cloud Diagnostics', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    const SizedBox(height: 16),
                    _diagRow('Platform', 'Native Flutter (Android / APK)'),
                    _diagRow('Installed Version', _currentVersion),
                    _diagRow(
                      'Cloud Sync Status',
                      state.status.name.toUpperCase(),
                      color: state.status.name == 'synced' ? AppColors.success : AppColors.primaryGlow,
                    ),
                    _diagRow('Pending Changes', '${state.pendingCount}'),
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
                          side: const BorderSide(color: AppColors.primaryGlow),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.system_update_rounded, size: 18, color: AppColors.primaryGlow),
                        label: const Text('Check for Updates & Release Candidates', style: TextStyle(color: AppColors.primaryGlow, fontWeight: FontWeight.bold, fontSize: 12)),
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

  Widget _diagRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color ?? AppColors.textPrimary,
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
      body: Consumer<EntriesViewModel>(
        builder: (context, vm, _) {
          return FutureBuilder<List<Entry>>(
            future: vm.getEntriesForDay(todayKey),
            builder: (context, snapshot) {
              final entries = snapshot.data ?? [];
              final isLoading = snapshot.connectionState == ConnectionState.waiting;

              return RefreshIndicator(
                color: AppColors.primaryGlow,
                backgroundColor: AppColors.backgroundSecondary,
                onRefresh: () async {
                  await context.read<EntryRepository>().syncNow();
                },
                child: CustomScrollView(
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
                                const Text(
                                  'TODAY',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryGlow,
                                    letterSpacing: 2.0,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  AppFormatters.formatDayLabel(now.millisecondsSinceEpoch),
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.textPrimary,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  entries.isEmpty
                                      ? 'Nothing logged yet. Tap + to capture.'
                                      : '${entries.length} ${entries.length == 1 ? "trip entry" : "trip entries"}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    AppHaptics.light();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => DayScreen(dayKey: yesterdayKey)),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: GlassDecorations.glassCard(borderRadius: 16),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.chevron_left_rounded, size: 16, color: AppColors.primaryGlow),
                                        SizedBox(width: 2),
                                        Text('Yesterday', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                GestureDetector(
                                  onTap: () => _showDiagnosticsModal(context),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          _isCheckingUpdate ? Icons.hourglass_top_rounded : Icons.system_update_rounded,
                                          size: 10,
                                          color: AppColors.primaryGlow,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _currentVersion,
                                          style: const TextStyle(fontSize: 9, color: AppColors.textMuted, fontFamily: 'monospace', fontWeight: FontWeight.bold),
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
                      const SliverFillRemaining(
                        child: Center(
                          child: CircularProgressIndicator(color: AppColors.primaryGlow),
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
                              decoration: GlassDecorations.glassCard(borderRadius: 24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.note_add_rounded, size: 36, color: AppColors.primaryGlow),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No Trip Entries Today',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Tap the floating + button to capture trip loads, tyre counts, or notes.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
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
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => EntryDetailScreen(entryId: entry.id),
                                      ),
                                    );
                                  },
                                  onEdit: () {
                                    AppHaptics.light();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => EntryDetailScreen(entryId: entry.id),
                                      ),
                                    );
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
                ),
              );
            },
          );
        },
      ),
    );
  }
}
