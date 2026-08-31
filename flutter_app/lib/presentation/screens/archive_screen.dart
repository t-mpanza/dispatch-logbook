import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_decorations.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';
import '../../data/models/entry.dart';
import '../../data/repositories/entry_repository.dart';
import 'day_screen.dart';

class ArchiveScreen extends StatelessWidget {
  const ArchiveScreen({super.key});

  Map<String, Map<String, Map<int, List<Entry>>>> _groupEntries(List<Entry> entries) {
    // Year -> Month -> WeekNum -> List<Entry>
    final Map<String, Map<String, Map<int, List<Entry>>>> result = {};

    for (final e in entries) {
      final y = e.yearKey.isNotEmpty ? e.yearKey : '2026';
      final m = e.monthKey.isNotEmpty ? e.monthKey : '2026-08';
      final dt = DateTime.tryParse(e.dayKey) ?? DateTime.fromMillisecondsSinceEpoch(e.createdAt);
      final w = AppFormatters.getWeekNumber(dt);

      result.putIfAbsent(y, () => {});
      result[y]!.putIfAbsent(m, () => {});
      result[y]![m]!.putIfAbsent(w, () => []);
      result[y]![m]![w]!.add(e);
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<EntryRepository>();

    return FutureBuilder<List<Entry>>(
      future: repo.getAllEntries(),
      builder: (context, snapshot) {
        final entries = snapshot.data ?? [];
        final grouped = _groupEntries(entries);
        final sortedYears = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
            children: [
              // Header
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ARCHIVE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryGlow,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'All Records',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${entries.length} ${entries.length == 1 ? "entry" : "entries"} stored locally & cloud synced',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (entries.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: GlassDecorations.glassCard(borderRadius: 22),
                  alignment: Alignment.center,
                  child: const Text('No records archived yet.', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                )
              else
                for (final year in sortedYears) ...[
                  Text(
                    year,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMuted,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final monthKey in (grouped[year]!.keys.toList()..sort((a, b) => b.compareTo(a)))) ...[
                    _buildMonthCard(context, monthKey, grouped[year]![monthKey]!),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 12),
                ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildMonthCard(
    BuildContext context,
    String monthKey,
    Map<int, List<Entry>> weeksMap,
  ) {
    final monthDt = DateTime.tryParse('$monthKey-01') ?? DateTime.now();
    final monthLabel = AppFormatters.formatMonth(monthDt);
    final totalEntries = weeksMap.values.fold<int>(0, (s, l) => s + l.length);
    final sortedWeeks = weeksMap.keys.toList()..sort((a, b) => b.compareTo(a));

    return Container(
      decoration: GlassDecorations.glassCard(borderRadius: 20),
      child: Theme(
        data: ThemeData(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          iconColor: AppColors.primaryGlow,
          collapsedIconColor: AppColors.textMuted,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.folder_rounded, size: 18, color: AppColors.primaryGlow),
          ),
          title: Text(
            monthLabel,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.glassSurfaceElevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$totalEntries',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryGlow, fontFamily: 'monospace'),
            ),
          ),
          children: [
            for (final wNum in sortedWeeks) ...[
              _buildWeekSection(context, wNum, weeksMap[wNum]!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWeekSection(
    BuildContext context,
    int weekNum,
    List<Entry> weekEntries,
  ) {
    // Group days in this week
    final Map<String, List<Entry>> daysMap = {};
    for (final e in weekEntries) {
      daysMap.putIfAbsent(e.dayKey, () => []).add(e);
    }
    final sortedDays = daysMap.keys.toList()..sort((a, b) => b.compareTo(a));
    final sampleDate = DateTime.tryParse(weekEntries.first.dayKey) ?? DateTime.now();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Theme(
        data: ThemeData(dividerColor: Colors.transparent),
        child: ExpansionTile(
          dense: true,
          title: Text(
            'Week $weekNum · ${AppFormatters.getWeekRangeLabel(sampleDate)}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
          ),
          children: [
            for (final dayKey in sortedDays) ...[
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                title: Text(
                  AppFormatters.formatShortDay(DateTime.tryParse(dayKey) ?? DateTime.now()),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                trailing: Text(
                  '${daysMap[dayKey]!.length} ${daysMap[dayKey]!.length == 1 ? "entry" : "entries"}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontFamily: 'monospace'),
                ),
                onTap: () {
                  AppHaptics.light();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => DayScreen(dayKey: dayKey)),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
