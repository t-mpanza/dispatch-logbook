import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_decorations.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';
import '../../core/utils/id_generator.dart';
import '../../data/models/entry.dart';
import '../../data/models/ibt_manifest.dart';
import '../../data/models/loading_sheet_trip.dart';
import '../../data/models/note_block.dart';
import '../../data/models/trip.dart';
import '../../data/services/audio_service.dart';
import '../../data/repositories/entry_repository.dart';
import '../widgets/event_log_view.dart';
import '../widgets/floating_note_bar.dart';
import '../widgets/photo_lightbox.dart';
import '../widgets/tags_input.dart';
import '../widgets/voice_recorder_sheet.dart';

class StocksEntryDetailScreen extends StatefulWidget {
  final String entryId;

  const StocksEntryDetailScreen({super.key, required this.entryId});

  @override
  State<StocksEntryDetailScreen> createState() =>
      _StocksEntryDetailScreenState();
}

class _StocksEntryDetailScreenState extends State<StocksEntryDetailScreen> {
  final AudioService _audioService = AudioService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _regController = TextEditingController();
  final TextEditingController _driverController = TextEditingController();

  bool _isDetailsOpen = false;
  Entry? _cachedEntry;

  @override
  void dispose() {
    _audioService.dispose();
    _titleController.dispose();
    _regController.dispose();
    _driverController.dispose();
    super.dispose();
  }

  void _syncTripDetailsToEntry(Entry entry) {
    final sheetTrip = entry.loadingSheetTrips?.firstWhere(
      (t) => !t.isManual,
      orElse: () => LoadingSheetTrip(
        id: IdGenerator.generate(),
        entryId: entry.id,
        reg: '',
        driverName: '',
        tripId: entry.title,
        quantityLoaded: 0,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    _regController.text = sheetTrip?.reg ?? '';
    _driverController.text = sheetTrip?.driverName ?? '';
  }

  /// Update an IBT line item's loaded count and persist to repository
  Future<void> _updateLineQuantity({
    required Entry currentEntry,
    required EntryRepository repo,
    required String docNo,
    required String lineId,
    required int newQuantity,
  }) async {
    final clampedQty = newQuantity < 0 ? 0 : newQuantity;

    final sheetTrips = <LoadingSheetTrip>[...?currentEntry.loadingSheetTrips];
    final sheetTripIdx = sheetTrips.indexWhere((t) => !t.isManual);

    if (sheetTripIdx < 0) return;

    final primarySheetTrip = sheetTrips[sheetTripIdx];
    final docs = <IbtDocument>[...?primarySheetTrip.ibtDocuments];

    final docIdx = docs.indexWhere(
      (d) => d.documentNo.toUpperCase() == docNo.toUpperCase(),
    );
    if (docIdx < 0) return;

    final doc = docs[docIdx];
    final lines = <IbtLineItem>[...doc.lineItems];
    final lineIdx = lines.indexWhere((l) => l.id == lineId);
    if (lineIdx < 0) return;

    lines[lineIdx] = lines[lineIdx].copyWith(loadedQuantity: clampedQty);
    docs[docIdx] = IbtDocument(
      documentNo: doc.documentNo,
      total: doc.total,
      lineItems: lines,
    );

    // Calculate new total across all IBT documents
    int totalLoadedAcrossAllIbts = 0;
    for (final d in docs) {
      totalLoadedAcrossAllIbts += d.loadedTotal;
    }

    final updatedSheetTrip = primarySheetTrip.copyWith(
      ibtDocuments: docs,
      quantityLoaded: totalLoadedAcrossAllIbts,
      finishTime: DateTime.now().millisecondsSinceEpoch,
    );
    sheetTrips[sheetTripIdx] = updatedSheetTrip;

    // Synchronize trips log for report consistency
    final updatedTrips = <Trip>[
      Trip(
        id: IdGenerator.generate(),
        count: totalLoadedAcrossAllIbts,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    ];

    final updatedEntry = currentEntry.copyWith(
      loadingSheetTrips: sheetTrips,
      trips: updatedTrips,
      expectedTotal: primarySheetTrip.ibtTargetTotal,
    );

    await repo.saveEntry(updatedEntry);
  }

  /// Show direct number edit dialog for a line item
  Future<void> _showEditCountDialog({
    required BuildContext context,
    required Entry currentEntry,
    required EntryRepository repo,
    required String docNo,
    required IbtLineItem line,
  }) async {
    final controller = TextEditingController(text: '${line.loadedQuantity}');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.presetStocks.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.inventory_2_rounded,
                color: AppColors.presetStocks,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                line.size ?? line.description,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  fontFamily: 'monospace',
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (line.rubber != null) ...[
              Text(
                line.rubber!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              'Target: ${line.targetTotal} tyres',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w900,
              ),
              decoration: InputDecoration(
                labelText: 'TYRES LOADED',
                labelStyle: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
                filled: true,
                fillColor: AppColors.glassSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.glassBorderLight,
                  ),
                ),
                suffixText: '/ ${line.targetTotal}',
                suffixStyle: const TextStyle(
                  color: AppColors.textMuted,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  label: const Text('0'),
                  backgroundColor: AppColors.glassSurfaceElevated,
                  labelStyle: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                  onPressed: () => controller.text = '0',
                ),
                ActionChip(
                  label: Text('Target (${line.targetTotal})'),
                  backgroundColor: AppColors.presetStocks.withValues(
                    alpha: 0.2,
                  ),
                  labelStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.presetStocks,
                  ),
                  onPressed: () => controller.text = '${line.targetTotal}',
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final val = int.tryParse(controller.text.trim()) ?? 0;
              Navigator.pop(ctx);
              _updateLineQuantity(
                currentEntry: currentEntry,
                repo: repo,
                docNo: docNo,
                lineId: line.id,
                newQuantity: val,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.presetStocks,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Set Count',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<EntryRepository>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<Entry?>(
        future: repo.getEntryById(widget.entryId),
        builder: (context, snapshot) {
          final entry = snapshot.data;
          if (snapshot.connectionState == ConnectionState.waiting &&
              _cachedEntry == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.presetStocks),
            );
          }

          if (entry == null && _cachedEntry == null) {
            return Scaffold(
              appBar: AppBar(backgroundColor: Colors.transparent),
              body: const Center(
                child: Text(
                  'Stocks entry not found',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
            );
          }

          final currentEntry = entry ?? _cachedEntry!;
          _cachedEntry = currentEntry;

          if (_titleController.text.isEmpty && currentEntry.title.isNotEmpty) {
            _titleController.text = currentEntry.title;
            _syncTripDetailsToEntry(currentEntry);
          }

          // Primary Stocks Sheet Trip & IBT Docs
          final sheetTrip = currentEntry.loadingSheetTrips?.firstWhere(
            (t) => !t.isManual,
            orElse: () => LoadingSheetTrip(
              id: '',
              entryId: currentEntry.id,
              reg: '',
              driverName: '',
              tripId: currentEntry.title,
              quantityLoaded: 0,
              createdAt: DateTime.now().millisecondsSinceEpoch,
            ),
          );

          final ibtDocs = sheetTrip?.ibtDocuments ?? [];
          final totalTarget = sheetTrip?.ibtTargetTotal ?? 0;
          final totalLoaded = sheetTrip?.ibtLoadedTotal ?? 0;
          final totalRemaining = (totalTarget - totalLoaded).clamp(
            0,
            totalTarget,
          );
          final isComplete = totalTarget > 0 && totalLoaded >= totalTarget;
          final isOver = totalTarget > 0 && totalLoaded > totalTarget;
          final totalPct = totalTarget > 0
              ? (totalLoaded / totalTarget).clamp(0.0, 1.0)
              : 0.0;

          return SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Top Custom Header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: GlassDecorations.glassCard(borderRadius: 0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              color: AppColors.textPrimary,
                            ),
                            onPressed: () {
                              AppHaptics.light();
                              Navigator.pop(context);
                            },
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _titleController,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.textPrimary,
                                        ),
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          contentPadding: EdgeInsets.zero,
                                          border: InputBorder.none,
                                        ),
                                        onSubmitted: (val) {
                                          if (val.trim().isNotEmpty) {
                                            repo.saveEntry(
                                              currentEntry.copyWith(
                                                title: val.trim(),
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.presetStocks
                                            .withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: AppColors.presetStocks
                                              .withValues(alpha: 0.4),
                                        ),
                                      ),
                                      child: const Text(
                                        'STOCKS',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.presetStocks,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  AppFormatters.formatDayLabel(
                                    currentEntry.createdAt,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: AnimatedRotation(
                              turns: _isDetailsOpen ? 0.5 : 0.0,
                              duration: const Duration(milliseconds: 200),
                              child: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            onPressed: () {
                              AppHaptics.light();
                              setState(() => _isDetailsOpen = !_isDetailsOpen);
                            },
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.error,
                            ),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor:
                                      AppColors.backgroundSecondary,
                                  title: const Text(
                                    'Delete Stocks Entry',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  content: const Text(
                                    'Are you sure you want to delete this stocks entry?',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.error,
                                      ),
                                      child: const Text(
                                        'Delete',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true && context.mounted) {
                                await repo.deleteEntry(currentEntry.id);
                                if (context.mounted) Navigator.pop(context);
                              }
                            },
                          ),
                        ],
                      ),

                      // Collapsible Tags Bar
                      if (_isDetailsOpen)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: TagsInput(
                            value: currentEntry.tags,
                            onChange: (nextTags) {
                              repo.saveEntry(
                                currentEntry.copyWith(tags: nextTags),
                              );
                            },
                            suggestions: const [
                              'stocks',
                              'despatch',
                              'tyres',
                              'warehouse',
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // Main Scrollable Area
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
                    children: [
                      // STOCKS HERO PROGRESS CARD
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: GlassDecorations.glassElevated(
                          borderRadius: 22,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Card Top: Trip Title & IBT Doc Badge
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: AppColors.presetStocks.withValues(
                                      alpha: 0.2,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.local_shipping_rounded,
                                    size: 16,
                                    color: AppColors.presetStocks,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        currentEntry.title.isNotEmpty
                                            ? currentEntry.title
                                            : 'STOCKS MANIFEST',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        '${ibtDocs.map((d) => d.documentNo).join(", ")} · ${ibtDocs.fold(0, (s, d) => s + d.lineItems.length)} items',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Target badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.presetStocks.withValues(
                                      alpha: 0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppColors.presetStocks.withValues(
                                        alpha: 0.35,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.track_changes_rounded,
                                        size: 13,
                                        color: AppColors.presetStocks,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        'Target: $totalTarget',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.presetStocks,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Numbers Row
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'TOTAL TYRES LOADED',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textMuted,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        Text(
                                          '$totalLoaded',
                                          style: const TextStyle(
                                            fontSize: 36,
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.presetStocks,
                                            fontFamily: 'monospace',
                                            letterSpacing: -1.0,
                                          ),
                                        ),
                                        Text(
                                          ' / $totalTarget',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textMuted,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Text(
                                          'tyres',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const Spacer(),

                                // Status Pill
                                if (isComplete && !isOver)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.success.withValues(
                                          alpha: 0.5,
                                        ),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.check_circle_rounded,
                                          size: 16,
                                          color: AppColors.success,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'ALL LOADED',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.success,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else if (isOver)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.warning.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.warning.withValues(
                                          alpha: 0.6,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.warning_amber_rounded,
                                          size: 16,
                                          color: AppColors.warning,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '+${totalLoaded - totalTarget} OVER',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.warning,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.presetStocks.withValues(
                                        alpha: 0.18,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.presetStocks
                                            .withValues(alpha: 0.5),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.hourglass_bottom_rounded,
                                          size: 16,
                                          color: AppColors.presetStocks,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '$totalRemaining LEFT',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.presetStocks,
                                            fontFamily: 'monospace',
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),

                            // Total Progress Bar
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: totalPct,
                                minHeight: 8,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.08,
                                ),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isComplete
                                      ? AppColors.success
                                      : (isOver
                                            ? AppColors.warning
                                            : AppColors.presetStocks),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // SECTION HEADER: SPECIFIC RCS / IBT LINE ITEMS
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'IBT LINE ITEMS (RCS)',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textMuted,
                              letterSpacing: 1.5,
                            ),
                          ),
                          Text(
                            'Tap line or steppers to update',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textMuted.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // LIST OF INTERACTIVE IBT LINE CARDS
                      if (ibtDocs.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: GlassDecorations.glassCard(
                            borderRadius: 16,
                          ),
                          child: const Center(
                            child: Text(
                              'No IBT documents attached to this Stocks trip.',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          ),
                        )
                      else
                        for (final doc in ibtDocs) ...[
                          for (final line in doc.lineItems)
                            _InteractiveIbtLineCard(
                              docNo: doc.documentNo,
                              line: line,
                              onIncrement: (by) {
                                AppHaptics.light();
                                _updateLineQuantity(
                                  currentEntry: currentEntry,
                                  repo: repo,
                                  docNo: doc.documentNo,
                                  lineId: line.id,
                                  newQuantity: line.loadedQuantity + by,
                                );
                              },
                              onDecrement: (by) {
                                AppHaptics.light();
                                _updateLineQuantity(
                                  currentEntry: currentEntry,
                                  repo: repo,
                                  docNo: doc.documentNo,
                                  lineId: line.id,
                                  newQuantity: line.loadedQuantity - by,
                                );
                              },
                              onFillTarget: () {
                                AppHaptics.success();
                                _updateLineQuantity(
                                  currentEntry: currentEntry,
                                  repo: repo,
                                  docNo: doc.documentNo,
                                  lineId: line.id,
                                  newQuantity: line.targetTotal,
                                );
                              },
                              onTapEdit: () {
                                AppHaptics.light();
                                _showEditCountDialog(
                                  context: context,
                                  currentEntry: currentEntry,
                                  repo: repo,
                                  docNo: doc.documentNo,
                                  line: line,
                                );
                              },
                            ),
                        ],

                      const SizedBox(height: 14),

                      // TRUCK ASSIGNMENT CARD (Compact)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: GlassDecorations.glassCard(
                          borderRadius: 18,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TRUCK ASSIGNMENT',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textMuted,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _regController,
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                      fontFamily: 'monospace',
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'REG NO',
                                      labelStyle: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textMuted,
                                      ),
                                      filled: true,
                                      fillColor: Colors.black.withValues(
                                        alpha: 0.3,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onChanged: (val) {
                                      final List<LoadingSheetTrip> sheetTrips =
                                          [...?currentEntry.loadingSheetTrips];
                                      final idx = sheetTrips.indexWhere(
                                        (t) => !t.isManual,
                                      );
                                      if (idx >= 0) {
                                        sheetTrips[idx] = sheetTrips[idx]
                                            .copyWith(reg: val.toUpperCase());
                                        repo.saveEntry(
                                          currentEntry.copyWith(
                                            loadingSheetTrips: sheetTrips,
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: _driverController,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'DRIVER NAME',
                                      labelStyle: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textMuted,
                                      ),
                                      filled: true,
                                      fillColor: Colors.black.withValues(
                                        alpha: 0.3,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onChanged: (val) {
                                      final List<LoadingSheetTrip> sheetTrips =
                                          [...?currentEntry.loadingSheetTrips];
                                      final idx = sheetTrips.indexWhere(
                                        (t) => !t.isManual,
                                      );
                                      if (idx >= 0) {
                                        sheetTrips[idx] = sheetTrips[idx]
                                            .copyWith(driverName: val);
                                        repo.saveEntry(
                                          currentEntry.copyWith(
                                            loadingSheetTrips: sheetTrips,
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // EVENT LOG
                      const Text(
                        'EVENT LOG',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMuted,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),

                      EventLogView(
                        notes: currentEntry.notes,
                        attachments: currentEntry.attachments,
                        trips: currentEntry.trips ?? [],
                        audioService: _audioService,
                        onRemoveNote: (nid) {
                          final updated = currentEntry.notes
                              .where((n) => n.id != nid)
                              .toList();
                          repo.saveEntry(currentEntry.copyWith(notes: updated));
                        },
                        onRemoveAttachment: (aid) {
                          final updated = currentEntry.attachments
                              .where((a) => a.id != aid)
                              .toList();
                          repo.saveEntry(
                            currentEntry.copyWith(attachments: updated),
                          );
                        },
                        onRemoveTrip: (tid) {
                          final updatedTrips = (currentEntry.trips ?? [])
                              .where((t) => t.id != tid)
                              .toList();
                          repo.saveEntry(
                            currentEntry.copyWith(trips: updatedTrips),
                          );
                        },
                        onOpenPhoto: (att) => PhotoLightbox.show(context, att),
                      ),
                    ],
                  ),
                ),

                // Floating Note / Photo Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: FloatingNoteBar(
                    onAddNote: (text) {
                      final newNote = NoteBlock(
                        id: IdGenerator.generate(),
                        text: text,
                        createdAt: DateTime.now().millisecondsSinceEpoch,
                      );
                      repo.saveEntry(
                        currentEntry.copyWith(
                          notes: [...currentEntry.notes, newNote],
                        ),
                      );
                    },
                    onAttachment: (att) {
                      repo.saveEntry(
                        currentEntry.copyWith(
                          attachments: [...currentEntry.attachments, att],
                        ),
                      );
                    },
                    onStartVoice: () {
                      VoiceRecorderSheet.show(
                        context,
                        audioService: _audioService,
                        onSave: (att) {
                          repo.saveEntry(
                            currentEntry.copyWith(
                              attachments: [...currentEntry.attachments, att],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Rich interactive card dedicated to a single IBT line item
class _InteractiveIbtLineCard extends StatelessWidget {
  final String docNo;
  final IbtLineItem line;
  final Function(int by) onIncrement;
  final Function(int by) onDecrement;
  final VoidCallback onFillTarget;
  final VoidCallback onTapEdit;

  const _InteractiveIbtLineCard({
    required this.docNo,
    required this.line,
    required this.onIncrement,
    required this.onDecrement,
    required this.onFillTarget,
    required this.onTapEdit,
  });

  @override
  Widget build(BuildContext context) {
    final target = line.targetTotal;
    final loaded = line.loadedQuantity;
    final pct = target > 0 ? (loaded / target).clamp(0.0, 1.0) : 0.0;
    final isDone = target > 0 && loaded >= target && loaded == target;
    final isOver = target > 0 && loaded > target;
    final remaining = (target - loaded).clamp(0, target);

    final Color statusColor = isOver
        ? AppColors.warning
        : (isDone ? AppColors.success : AppColors.presetStocks);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDone
            ? AppColors.success.withValues(alpha: 0.06)
            : (isOver
                  ? AppColors.warning.withValues(alpha: 0.06)
                  : AppColors.glassSurfaceElevated),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDone
              ? AppColors.success.withValues(alpha: 0.4)
              : (isOver
                    ? AppColors.warning.withValues(alpha: 0.5)
                    : AppColors.glassBorder),
          width: isDone || isOver ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Info Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Size Header
                    Text(
                      line.size ?? line.description,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        fontFamily: 'monospace',
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    // Rubber / Pattern Name
                    if (line.rubber != null)
                      Text(
                        line.rubber!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (line.rcsCode != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'RCS: ${line.rcsCode}',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textMuted,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Interactive Count Badge (Tap to edit)
              GestureDetector(
                onTap: onTapEdit,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$loaded',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: statusColor,
                              fontFamily: 'monospace',
                            ),
                          ),
                          Text(
                            ' / $target',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textMuted,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                      Text(
                        isOver
                            ? '+${loaded - target} over'
                            : (isDone ? '✓ complete' : '$remaining left'),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),

          const SizedBox(height: 12),

          // Quick Interactive Steppers & Fill Button Row
          Row(
            children: [
              // Stepper Minus (-)
              IconButton.filledTonal(
                icon: const Icon(Icons.remove_rounded, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.glassSurface,
                  foregroundColor: AppColors.textPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.all(8),
                ),
                onPressed: loaded > 0 ? () => onDecrement(1) : null,
              ),

              const SizedBox(width: 6),

              // Stepper Plus (+)
              IconButton.filledTonal(
                icon: const Icon(Icons.add_rounded, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.presetStocks.withValues(
                    alpha: 0.2,
                  ),
                  foregroundColor: AppColors.presetStocks,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.all(8),
                ),
                onPressed: () => onIncrement(1),
              ),

              const SizedBox(width: 8),

              // Quick Increment Pills
              Wrap(
                spacing: 6,
                children: [
                  _QuickPill(label: '+2', onTap: () => onIncrement(2)),
                  _QuickPill(label: '+5', onTap: () => onIncrement(5)),
                  if (remaining > 0 &&
                      remaining != 1 &&
                      remaining != 2 &&
                      remaining != 5)
                    _QuickPill(
                      label: 'Fill ($remaining)',
                      isAccent: true,
                      onTap: onFillTarget,
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickPill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isAccent;

  const _QuickPill({
    required this.label,
    required this.onTap,
    this.isAccent = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AppHaptics.light();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: isAccent
              ? AppColors.presetStocks.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isAccent
                ? AppColors.presetStocks.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: isAccent ? AppColors.presetStocks : AppColors.textSecondary,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }
}
