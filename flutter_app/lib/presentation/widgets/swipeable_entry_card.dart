import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_decorations.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';
import '../../data/models/entry.dart';

/// List card for an entry: readable title, clear tyre total, status badges.
/// Swipe left to delete, tap anywhere to open.
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
    final isLight = AppColors.isLight(context);
    final trips = entry.trips ?? [];
    final loadingTrips = entry.loadingSheetTrips ?? [];
    final hasCounter = trips.isNotEmpty || loadingTrips.isNotEmpty;

    int totalTyres = 0;
    int tripCount = 0;
    int? target;
    if (loadingTrips.isNotEmpty) {
      totalTyres = loadingTrips.fold<int>(0, (s, t) => s + t.quantityLoaded);
      tripCount = loadingTrips.length;
      target = loadingTrips.fold<int>(0, (s, t) => s + (t.targetQuantity ?? 0));
    } else if (trips.isNotEmpty) {
      totalTyres = trips.fold<int>(
        0,
        (s, t) => s + t.count + (t.rejected ?? 0),
      );
      tripCount = trips.length;
    }
    if (target == 0) target = null;

    final hasAudio = entry.attachments.any((a) => a.kind.name == 'audio');
    final hasPhotos = entry.attachments.any(
      (a) => a.kind.name == 'photo' || a.kind.name == 'image',
    );

    return Slidable(
      key: ValueKey(entry.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.28,
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
            borderRadius: BorderRadius.circular(20),
          ),
        ],
      ),
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.28,
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
            borderRadius: BorderRadius.circular(20),
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
          padding: const EdgeInsets.all(16),
          decoration: GlassDecorations.glassCard(
            context: context,
            borderRadius: 20,
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: hasCounter
                      ? AppColors.primary.withValues(
                          alpha: isLight ? 0.12 : 0.15,
                        )
                      : AppColors.dynamicCardSurface(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: hasCounter
                        ? AppColors.dynamicAccent(
                            context,
                          ).withValues(alpha: 0.35)
                        : AppColors.dynamicBorderLight(context),
                  ),
                ),
                child: Icon(
                  hasCounter
                      ? Icons.local_shipping_rounded
                      : Icons.notes_rounded,
                  size: 22,
                  color: hasCounter
                      ? AppColors.dynamicAccent(context)
                      : AppColors.dynamicTextSecondary(context),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title.isNotEmpty ? entry.title : 'Untitled log',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.dynamicTextPrimary(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${AppFormatters.formatDayLabel(entry.createdAt)} · ${AppFormatters.formatTimeHHmm(entry.createdAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.dynamicTextMuted(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final tag in entry.tags.take(2))
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.dynamicCardSurface(context),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color: AppColors.dynamicBorderLight(context),
                              ),
                            ),
                            child: Text(
                              '#$tag',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.dynamicAccent(context),
                              ),
                            ),
                          ),
                        if (hasAudio)
                          _mediaPill(
                            Icons.mic_rounded,
                            'Audio',
                            AppColors.presetNlh,
                          ),
                        if (hasPhotos)
                          _mediaPill(
                            Icons.camera_alt_rounded,
                            'Photo',
                            AppColors.warning,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (hasCounter) ...[
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$totalTyres',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.dynamicAccent(context),
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      target != null
                          ? '/ $target tyres'
                          : '$tripCount ${tripCount == 1 ? "trip" : "trips"}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.dynamicTextMuted(context),
                      ),
                    ),
                    if (target != null) ...[
                      const SizedBox(height: 5),
                      SizedBox(
                        width: 64,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (totalTyres / target).clamp(0.0, 1.0),
                            minHeight: 5,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.08,
                            ),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              totalTyres >= target
                                  ? AppColors.success
                                  : AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _mediaPill(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
