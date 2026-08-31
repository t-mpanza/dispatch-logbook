import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_decorations.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';
import '../../data/models/entry.dart';
import '../../data/repositories/entry_repository.dart';
import '../viewmodels/entries_viewmodel.dart';
import '../widgets/swipeable_entry_card.dart';
import 'entry_detail_screen.dart';
import 'new_entry_screen.dart';

class DayScreen extends StatefulWidget {
  final String dayKey;

  const DayScreen({super.key, required this.dayKey});

  @override
  State<DayScreen> createState() => _DayScreenState();
}

class _DayScreenState extends State<DayScreen> {
  late String _currentDayKey;

  @override
  void initState() {
    super.initState();
    _currentDayKey = widget.dayKey;
  }

  void _shiftDay(int days) {
    AppHaptics.light();
    try {
      final current = DateTime.parse(_currentDayKey);
      final shifted = current.add(Duration(days: days));
      setState(() {
        _currentDayKey = AppFormatters.dayKey(shifted);
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final parsedDate = DateTime.tryParse(_currentDayKey) ?? DateTime.now();

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () {
            AppHaptics.light();
            Navigator.pop(context);
          },
        ),
        title: Text(
          AppFormatters.formatDayLabel(parsedDate.millisecondsSinceEpoch),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primaryGlow,
        backgroundColor: AppColors.backgroundSecondary,
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
              future: vm.getEntriesForDay(_currentDayKey),
              builder: (context, snapshot) {
                final entries = snapshot.data ?? [];
                final isLoading = snapshot.connectionState == ConnectionState.waiting;

                return Column(
                  children: [
                    // Date navigation bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: GlassDecorations.glassCard(borderRadius: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left_rounded, color: AppColors.textPrimary),
                              onPressed: () => _shiftDay(-1),
                            ),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.primaryGlow),
                                const SizedBox(width: 6),
                                Text(
                                  _currentDayKey,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right_rounded, color: AppColors.textPrimary),
                              onPressed: () => _shiftDay(1),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // List
                    Expanded(
                      child: isLoading
                          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGlow))
                          : entries.isEmpty
                              ? ListView(
                                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                                  children: [
                                    SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                                    Center(
                                      child: Text(
                                        'No entries logged for $_currentDayKey',
                                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.builder(
                                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
                                  itemCount: entries.length,
                                  itemBuilder: (context, index) {
                                    final entry = entries[index];
                                    return SwipeableEntryCard(
                                      entry: entry,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => EntryDetailScreen(entryId: entry.id)),
                                        );
                                      },
                                      onEdit: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => EntryDetailScreen(entryId: entry.id)),
                                        );
                                      },
                                      onDelete: () async {
                                        await vm.deleteEntry(entry.id);
                                      },
                                    );
                                  },
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
