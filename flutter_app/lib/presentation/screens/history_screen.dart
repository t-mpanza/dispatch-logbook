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
import 'day_screen.dart';

/// History: search everything or browse the archive by month, week and day.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 2,
    vsync: this,
  );
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _deleteEntry(EntriesViewModel vm, Entry e) async {
    final confirmed = await AppDialogs.confirm(
      context,
      title: 'Delete this entry?',
      message: 'This permanently removes the entry and its media.',
    );
    if (confirmed) {
      await vm.deleteEntry(e.id);
      if (mounted) {
        AppSnacks.success(context, 'Entry deleted');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: SectionHeader(
              eyebrow: 'Look back',
              title: 'History',
              subtitle: 'Search anything or browse the archive',
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: GlassDecorations.glassCard(
                context: context,
                borderRadius: 16,
              ),
              child: TabBar(
                controller: _tabController,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                labelColor: AppColors.dynamicTextPrimary(context),
                unselectedLabelColor: AppColors.dynamicTextMuted(context),
                labelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                tabs: const [
                  Tab(height: 40, text: 'Search'),
                  Tab(height: 40, text: 'Archive'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildSearchTab(), _buildArchiveTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchTab() {
    return Consumer<EntriesViewModel>(
      builder: (context, vm, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
          children: [
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Reg, trip ID, driver, tag or note…',
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: AppColors.dynamicAccent(context),
                ),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          AppHaptics.light();
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
              ),
              onChanged: (val) => setState(() => _query = val.trim()),
            ),
            const SizedBox(height: 14),
            FutureBuilder<List<String>>(
              future: vm.getAllTags(),
              builder: (context, snapshot) {
                final tags = snapshot.data ?? [];
                if (tags.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'POPULAR TAGS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.dynamicTextMuted(context),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final tag in tags.take(10))
                          GestureDetector(
                            onTap: () {
                              AppHaptics.light();
                              _searchController.text = tag;
                              setState(() => _query = tag);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: GlassDecorations.glassCard(
                                context: context,
                                borderRadius: 100,
                              ),
                              child: Text(
                                '#$tag',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.dynamicAccent(context),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                  ],
                );
              },
            ),
            FutureBuilder<List<Entry>>(
              future: _query.isNotEmpty ? vm.search(_query) : Future.value([]),
              builder: (context, snapshot) {
                final results = snapshot.data ?? [];
                if (_query.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        'Type above to search your records.\n'
                        'Try a truck reg, driver name or route like "DBN".',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.dynamicTextMuted(context),
                          height: 1.5,
                        ),
                      ),
                    ),
                  );
                }
                if (results.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 44,
                          color: AppColors.dynamicTextDisabled(context),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No matches for "$_query"',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.dynamicTextPrimary(context),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final e in results) ...[
                      SwipeableEntryCard(
                        entry: e,
                        onTap: () {
                          AppHaptics.light();
                          openEntryDetail(context, e);
                        },
                        onEdit: () {
                          AppHaptics.light();
                          openEntryDetail(context, e);
                        },
                        onDelete: () => _deleteEntry(vm, e),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildArchiveTab() {
    final repo = context.watch<EntryRepository>();
    return FutureBuilder<List<Entry>>(
      future: repo.getAllEntries(),
      builder: (context, snapshot) {
        final entries = snapshot.data ?? [];
        final grouped = _ArchiveGrouping.group(entries);

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
          children: [
            if (entries.isEmpty)
              EmptyState(
                icon: Icons.folder_open_rounded,
                title: 'No records yet',
                message:
                    'Everything you log will be archived here by month and day.',
              )
            else
              for (final year in grouped.sortedYears) ...[
                Text(
                  year,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.dynamicTextMuted(context),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                for (final monthKey in grouped.sortedMonths(year)) ...[
                  _MonthCard(
                    monthKey: monthKey,
                    weeksMap: grouped.byYear[year]![monthKey]!,
                    onDayTap: (dayKey) {
                      AppHaptics.light();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DayScreen(dayKey: dayKey),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 10),
              ],
          ],
        );
      },
    );
  }
}

class _ArchiveGrouping {
  final Map<String, Map<String, Map<int, List<Entry>>>> byYear = {};

  static _ArchiveGrouping group(List<Entry> entries) {
    final g = _ArchiveGrouping();
    for (final e in entries) {
      final y = e.yearKey.isNotEmpty ? e.yearKey : '2026';
      final m = e.monthKey.isNotEmpty ? e.monthKey : '2026-08';
      final dt =
          DateTime.tryParse(e.dayKey) ??
          DateTime.fromMillisecondsSinceEpoch(e.createdAt);
      final w = AppFormatters.getWeekNumber(dt);
      g.byYear
          .putIfAbsent(y, () => {})
          .putIfAbsent(m, () => {})
          .putIfAbsent(w, () => [])
          .add(e);
    }
    return g;
  }

  List<String> get sortedYears =>
      byYear.keys.toList()..sort((a, b) => b.compareTo(a));

  List<String> sortedMonths(String year) =>
      byYear[year]!.keys.toList()..sort((a, b) => b.compareTo(a));
}

class _MonthCard extends StatelessWidget {
  final String monthKey;
  final Map<int, List<Entry>> weeksMap;
  final ValueChanged<String> onDayTap;

  const _MonthCard({
    required this.monthKey,
    required this.weeksMap,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final monthDt = DateTime.tryParse('$monthKey-01') ?? DateTime.now();
    final monthLabel = AppFormatters.formatMonth(monthDt);
    final totalEntries = weeksMap.values.fold<int>(0, (s, l) => s + l.length);
    final sortedWeeks = weeksMap.keys.toList()..sort((a, b) => b.compareTo(a));

    return Container(
      decoration: GlassDecorations.glassCard(
        context: context,
        borderRadius: 20,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          iconColor: AppColors.dynamicAccent(context),
          collapsedIconColor: AppColors.dynamicTextMuted(context),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.calendar_month_rounded,
              size: 20,
              color: AppColors.dynamicAccent(context),
            ),
          ),
          title: Text(
            monthLabel,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.dynamicTextPrimary(context),
            ),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.dynamicCardSurface(context),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              '$totalEntries',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.dynamicAccent(context),
              ),
            ),
          ),
          children: [
            for (final wNum in sortedWeeks) ...[
              _WeekSection(
                weekNum: wNum,
                weekEntries: weeksMap[wNum]!,
                onDayTap: onDayTap,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WeekSection extends StatelessWidget {
  final int weekNum;
  final List<Entry> weekEntries;
  final ValueChanged<String> onDayTap;

  const _WeekSection({
    required this.weekNum,
    required this.weekEntries,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final Map<String, List<Entry>> daysMap = {};
    for (final e in weekEntries) {
      daysMap.putIfAbsent(e.dayKey, () => []).add(e);
    }
    final sortedDays = daysMap.keys.toList()..sort((a, b) => b.compareTo(a));
    final sampleDate =
        DateTime.tryParse(weekEntries.first.dayKey) ?? DateTime.now();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.dynamicSurfaceSunk(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          dense: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: Text(
            'Week $weekNum · ${AppFormatters.getWeekRangeLabel(sampleDate)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.dynamicTextSecondary(context),
            ),
          ),
          children: [
            for (final dayKey in sortedDays)
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                title: Text(
                  AppFormatters.formatShortDay(
                    DateTime.tryParse(dayKey) ?? DateTime.now(),
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.dynamicTextPrimary(context),
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${daysMap[dayKey]!.length}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.dynamicTextMuted(context),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AppColors.dynamicTextMuted(context),
                    ),
                  ],
                ),
                onTap: () => onDayTap(dayKey),
              ),
          ],
        ),
      ),
    );
  }
}
