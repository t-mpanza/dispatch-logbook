import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_decorations.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';
import '../../data/models/entry.dart';
import '../../data/repositories/entry_repository.dart';
import '../entry_route.dart';
import '../viewmodels/entries_viewmodel.dart';
import '../widgets/swipeable_entry_card.dart';
import '../widgets/ui_kit.dart';

/// Any single day's records, with prev/next navigation and pull-to-refresh.
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
    final isToday = _currentDayKey == AppFormatters.dayKey(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            AppHaptics.light();
            Navigator.pop(context);
          },
        ),
        title: Text(AppFormatters.formatShortDay(parsedDate)),
      ),
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
              future: vm.getEntriesForDay(_currentDayKey),
              builder: (context, snapshot) {
                final entries = snapshot.data ?? [];
                final isLoading =
                    snapshot.connectionState == ConnectionState.waiting;

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _shiftDay(-1),
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: GlassDecorations.glassCard(
                                  context: context,
                                  borderRadius: 16,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.chevron_left_rounded,
                                      color: AppColors.dynamicAccent(context),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Previous',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.dynamicTextPrimary(
                                          context,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (!isToday)
                            GestureDetector(
                              onTap: () {
                                AppHaptics.medium();
                                setState(
                                  () => _currentDayKey = AppFormatters.dayKey(
                                    DateTime.now(),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: GlassDecorations.frostedPill(
                                  context: context,
                                  borderRadius: 100,
                                ),
                                child: Text(
                                  'Back to today',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.dynamicAccent(context),
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GestureDetector(
                              onTap: isToday ? null : () => _shiftDay(1),
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: GlassDecorations.glassCard(
                                  context: context,
                                  borderRadius: 16,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Next',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: isToday
                                            ? AppColors.dynamicTextDisabled(
                                                context,
                                              )
                                            : AppColors.dynamicTextPrimary(
                                                context,
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: isToday
                                          ? AppColors.dynamicTextDisabled(
                                              context,
                                            )
                                          : AppColors.dynamicAccent(context),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : entries.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics(),
                              ),
                              padding: const EdgeInsets.all(20),
                              children: [
                                const SizedBox(height: 60),
                                EmptyState(
                                  icon: Icons.event_busy_rounded,
                                  title: 'Nothing on this day',
                                  message:
                                      'No entries were logged for '
                                      '$_currentDayKey.',
                                ),
                              ],
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics(),
                              ),
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                4,
                                20,
                                110,
                              ),
                              itemCount: entries.length,
                              itemBuilder: (context, index) {
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
                                      final confirmed =
                                          await AppDialogs.confirm(
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
