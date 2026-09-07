import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_decorations.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';
import '../../data/models/preset.dart';
import '../screens/entry_detail_screen.dart';
import '../screens/new_entry_screen.dart';
import '../viewmodels/entries_viewmodel.dart';
import '../viewmodels/loading_sheet_viewmodel.dart';
import 'truck_load_dialog.dart';
import 'ui_kit.dart';

/// The capture menu — the jobs a despatch worker does all day, with the
/// STOCKS run front and centre.
///
/// [hostContext] is the context of the screen that opened the sheet; all
/// navigation after the sheet is dismissed goes through it.
class CaptureActionSheet extends StatelessWidget {
  final BuildContext hostContext;

  const CaptureActionSheet({super.key, required this.hostContext});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => CaptureActionSheet(hostContext: context),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What are you doing?',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.dynamicTextPrimary(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pick an action — everything saves offline and syncs later.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.dynamicTextMuted(context),
            ),
          ),
          const SizedBox(height: 16),

          // Primary action: STOCKS run with IBT manifest tracking
          _PrimaryAction(
            icon: Icons.inventory_2_rounded,
            color: AppColors.presetStocks,
            title: 'Stocks Run',
            subtitle: 'Fetch IBT docs & tally tyres per line item',
            onTap: () {
              AppHaptics.medium();
              Navigator.pop(context);
              Navigator.push(
                hostContext,
                MaterialPageRoute(
                  builder: (_) =>
                      const NewEntryScreen(initialPreset: PresetKey.STOCKS),
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          _Action(
            icon: Icons.local_shipping_rounded,
            color: AppColors.dynamicAccent(context),
            title: 'Truck Load',
            subtitle: 'Add a truck to today\'s loading sheet',
            onTap: () async {
              final vm = context.read<LoadingSheetViewModel>();
              final trips = await vm.getTripsForSelectedDate();
              if (!hostContext.mounted) return;
              Navigator.pop(context);
              await TruckLoadDialog.show(
                hostContext,
                dayKey: vm.selectedDate,
                existingTrips: trips,
                onSave: (trip) => vm.addTruckLoad(trip),
              );
            },
          ),
          const SizedBox(height: 12),

          _Action(
            icon: Icons.note_add_rounded,
            color: AppColors.presetNlh,
            title: 'Trip Entry',
            subtitle: 'Start a route trip (DBN, NLS, PLK…)',
            onTap: () {
              AppHaptics.medium();
              Navigator.pop(context);
              Navigator.push(
                hostContext,
                MaterialPageRoute(builder: (_) => const NewEntryScreen()),
              );
            },
          ),
          const SizedBox(height: 12),

          _Action(
            icon: Icons.exposure_plus_1_rounded,
            color: AppColors.presetDbn,
            title: 'Count Session',
            subtitle: 'Tally tyres with the live counter',
            onTap: () async {
              final vm = context.read<EntriesViewModel>();
              final now = DateTime.now();
              final entry = await vm.createEntry(
                title:
                    'COUNT - ${AppFormatters.formatTimeHHmm(now.millisecondsSinceEpoch)}',
                tags: const ['tyres', 'count'],
                withCounter: true,
              );
              if (!hostContext.mounted) return;
              Navigator.pop(context);
              Navigator.push(
                hostContext,
                MaterialPageRoute(
                  builder: (_) => EntryDetailScreen(entryId: entry.id),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PrimaryAction({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          AppHaptics.medium();
          onTap();
        },
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.28),
                color.withValues(alpha: 0.10),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: color.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.15),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, size: 30, color: AppColors.onAccent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'STOCKS RUN',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: AppColors.presetStocks,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.dynamicTextPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.dynamicTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.dynamicTextMuted(context),
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _Action({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          AppHaptics.medium();
          onTap();
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: GlassDecorations.glassCard(
            context: context,
            borderRadius: 20,
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: color.withValues(alpha: 0.45)),
                ),
                child: Icon(icon, size: 28, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.dynamicTextPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.dynamicTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.dynamicTextMuted(context),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
