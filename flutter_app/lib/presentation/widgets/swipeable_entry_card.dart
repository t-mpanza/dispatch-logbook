import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_decorations.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';
import '../../data/models/entry.dart';

class SwipeableEntryCard extends StatelessWidget {
  final Entry entry;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const SwipeableEntryCard({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final trips = entry.trips ?? [];
    final loadingTrips = entry.loadingSheetTrips ?? [];
    final hasCounter = trips.isNotEmpty || loadingTrips.isNotEmpty;

    int totalTyres = 0;
    if (loadingTrips.isNotEmpty) {
      totalTyres = loadingTrips.fold<int>(0, (s, t) => s + t.quantityLoaded);
    } else if (trips.isNotEmpty) {
      totalTyres = trips.fold<int>(0, (s, t) => s + t.count + (t.rejected ?? 0));
    }

    final hasAudio = entry.attachments.any((a) => a.kind.name == 'audio');
    final hasPhotos = entry.attachments.any((a) => a.kind.name == 'photo' || a.kind.name == 'image');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Slidable(
        key: ValueKey(entry.id),
        startActionPane: ActionPane(
          motion: const DrawerMotion(),
          children: [
            SlidableAction(
              onPressed: (_) {
                AppHaptics.light();
                onEdit();
              },
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: Icons.edit_rounded,
              label: 'Edit',
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
            ),
          ],
        ),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          children: [
            SlidableAction(
              onPressed: (_) {
                AppHaptics.error();
                onDelete();
              },
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(20)),
            ),
          ],
        ),
        child: GestureDetector(
          onTap: () {
            AppHaptics.light();
            onTap();
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: GlassDecorations.glassCard(borderRadius: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon / Type indicator
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: hasCounter
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : AppColors.glassSurfaceElevated,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: hasCounter
                          ? AppColors.primaryGlow.withValues(alpha: 0.3)
                          : AppColors.glassBorder,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      hasCounter ? Icons.local_shipping_rounded : Icons.note_alt_rounded,
                      size: 20,
                      color: hasCounter ? AppColors.primaryGlow : AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Title and tags
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title.isNotEmpty ? entry.title : 'Untitled Log',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${AppFormatters.formatDayLabel(entry.createdAt)} · ${AppFormatters.formatTimeHHmm(entry.createdAt)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Tags & Media Pills
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          for (final tag in entry.tags.take(3))
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.glassSurfaceElevated,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.glassBorderLight),
                              ),
                              child: Text(
                                '#$tag',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryGlow,
                                ),
                              ),
                            ),
                          if (hasAudio)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.presetNlh.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.mic_rounded, size: 10, color: AppColors.presetNlh),
                                  SizedBox(width: 2),
                                  Text(
                                    'Audio',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.presetNlh,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (hasPhotos)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.camera_alt_rounded, size: 10, color: AppColors.warning),
                                  SizedBox(width: 2),
                                  Text(
                                    'Photo',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.warning,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Tyres Loaded Badge (if counter session)
                if (hasCounter) ...[
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primaryGlow.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          '$totalTyres',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primaryGlow,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${loadingTrips.isNotEmpty ? loadingTrips.length : trips.length} trips',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
