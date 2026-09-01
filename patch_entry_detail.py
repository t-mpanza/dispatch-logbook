import re

with open("flutter_app/lib/presentation/screens/entry_detail_screen.dart", "r") as f:
    content = f.read()

# 1. Imports
content = re.sub(
    r"import '\.\./\.\./core/theme/glass_decorations\.dart';",
    r"import '../../core/theme/glass_decorations.dart';\nimport '../../data/models/ibt_manifest.dart';",
    content
)

# 2. Add CounterPanel parameters
content = re.sub(
    r"CounterPanel\(\n\s*trips: trips,\n\s*onChange: \(nextTrips\) {",
    r"CounterPanel(\n                          currentTotal: currentEntry.totalLoaded,\n                          targetTotal: currentEntry.expectedTotal,\n                          trips: trips,\n                          onChange: (nextTrips) {",
    content
)

# 3. Insert IBT row builder before _buildEventLog
ibt_builder = """
Widget _buildIbtBreakdown(LoadingSheetTrip? trip) {
    if (trip == null || trip.ibtDocuments == null || trip.ibtDocuments!.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: GlassDecorations.glassElevated(borderRadius: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'IBT Manifest Breakdown',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            ...trip.ibtDocuments!.map((doc) => _buildIbtDocumentRow(doc)),
          ],
        ),
      ),
    );
  }

  Widget _buildIbtDocumentRow(IbtDocument doc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Manifest ${doc.documentNo}',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: doc.isComplete ? AppColors.success.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${doc.loadedTotal} / ${doc.total}',
                style: TextStyle(
                  color: doc.isComplete ? AppColors.success : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...doc.lineItems.map((item) => _buildIbtLineItemRow(item)),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildIbtLineItemRow(IbtLineItem item) {
    final progress = item.progressPercent;
    Color statusColor = AppColors.primary;
    if (item.isComplete) statusColor = AppColors.success;
    if (item.isOverloaded) statusColor = AppColors.warning;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.description,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                    ),
                    if (item.rcsCode != null || item.size != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          [item.rcsCode, item.size].where((e) => e != null && e.isNotEmpty).join(' • '),
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${item.loadedQuantity} / ${item.targetTotal}',
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              minHeight: 3,
            ),
          ),
        ],
      ),
    );
  }
"""

content = re.sub(
    r"(  Widget _buildEventLog\(List<Trip> trips, Entry currentEntry\))",
    ibt_builder + r"\n\1",
    content
)

insert_point = """                            _triggerSavedIndicator();
                          },
                        ),"""

replacement = """                            _triggerSavedIndicator();
                          },
                        ),
                        _buildIbtBreakdown(currentEntry.loadingSheetTrips?.isNotEmpty == true ? currentEntry.loadingSheetTrips!.first : null),"""

content = content.replace(insert_point, replacement)

with open("flutter_app/lib/presentation/screens/entry_detail_screen.dart", "w") as f:
    f.write(content)
