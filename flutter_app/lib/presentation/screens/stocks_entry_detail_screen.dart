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
import '../../data/models/preset.dart';
import '../../data/repositories/entry_repository.dart';
import '../../data/services/audio_service.dart';
import '../../data/services/ibt_line_ops.dart';
import '../../dispatch/domain/ibt_search.dart';
import '../widgets/event_log_view.dart';
import '../widgets/floating_note_bar.dart';
import '../widgets/ibt_picker.dart';
import '../widgets/number_pad.dart';
import '../widgets/photo_lightbox.dart';
import '../widgets/tags_input.dart';
import '../widgets/ui_kit.dart';
import '../widgets/voice_recorder_sheet.dart';

/// THE stocks / IBT tally screen — the heart of the app.
///
/// Layout (top to bottom):
///  1. Hero card — manifest-wide loaded vs target, completion state
///  2. Add-another-IBT picker — fetch more documents mid-run
///  3. Line cards grouped by IBT document, incomplete lines first
///  4. Truck assignment + event log
///  5. Focus mode — tap any line to dock a giant tally bar at the bottom
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

  /// Focus mode: the line currently docked in the tally bar.
  String? _focusedDocNo;
  String? _focusedLineId;

  /// Smart line search — the star feature.
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _activePattern;

  @override
  void dispose() {
    _audioService.dispose();
    _titleController.dispose();
    _regController.dispose();
    _driverController.dispose();
    _searchController.dispose();
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

  LoadingSheetTrip? _primarySheetTrip(Entry entry) {
    final trips = entry.loadingSheetTrips;
    if (trips == null) return null;
    for (final t in trips) {
      if (!t.isManual) return t;
    }
    return null;
  }

  /// Update one line item's loaded count through the shared tally engine.
  /// Haptics fire here — the bay is noisy, so every key press must be felt.
  Future<void> _updateLineQuantity({
    required Entry currentEntry,
    required EntryRepository repo,
    required String docNo,
    required String lineId,
    required int newQuantity,
  }) async {
    final sheetTrips = <LoadingSheetTrip>[...?currentEntry.loadingSheetTrips];
    final sheetTripIdx = sheetTrips.indexWhere((t) => !t.isManual);
    if (sheetTripIdx < 0) return;

    final result = IbtLineOps.setQuantity(
      trip: sheetTrips[sheetTripIdx],
      documentNo: docNo,
      lineItemId: lineId,
      newQuantity: newQuantity,
    );

    sheetTrips[sheetTripIdx] = result.trip;
    final updatedEntry = currentEntry.copyWith(
      loadingSheetTrips: sheetTrips,
      expectedTotal: result.trip.ibtTargetTotal,
    );

    await repo.saveEntry(updatedEntry);
    _reactToDelta(result);
  }

  /// Revert the most recent change on a line (undo the last mistaken tap).
  Future<void> _undoLineLast({
    required Entry currentEntry,
    required EntryRepository repo,
    required String docNo,
    required String lineId,
  }) async {
    final sheetTrips = <LoadingSheetTrip>[...?currentEntry.loadingSheetTrips];
    final sheetTripIdx = sheetTrips.indexWhere((t) => !t.isManual);
    if (sheetTripIdx < 0) return;

    final result = IbtLineOps.undoLast(
      trip: sheetTrips[sheetTripIdx],
      documentNo: docNo,
      lineItemId: lineId,
    );
    if (result == null) return;

    sheetTrips[sheetTripIdx] = result.trip;
    await repo.saveEntry(
      currentEntry.copyWith(
        loadingSheetTrips: sheetTrips,
        expectedTotal: result.trip.ibtTargetTotal,
      ),
    );
    _reactToDelta(result);
  }

  /// Central haptic feedback for every line change: felt, not just seen.
  void _reactToDelta(IbtLineDeltaResult result) {
    if (result.wasClamped) {
      AppHaptics.heavy();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot exceed manifest target.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } else if (result.completed) {
      AppHaptics.success();
    } else if (result.uncompleted) {
      AppHaptics.medium();
    } else {
      AppHaptics.light();
    }
  }

  /// Show precise numeric entry for a line item using the in-app keypad.
  /// The keypad hard-clamps input at the manifest target (overshoot cap).
  Future<void> _showEditCountDialog({
    required Entry currentEntry,
    required EntryRepository repo,
    required String docNo,
    required IbtLineItem line,
  }) async {
    final value = await NumberPad.show(
      context,
      initial: line.loadedQuantity,
      maxValue: line.targetTotal,
      title: 'EXACT TOTAL — ${line.size ?? line.description}',
    );
    if (value == null || !mounted) return;

    await _updateLineQuantity(
      currentEntry: currentEntry,
      repo: repo,
      docNo: docNo,
      lineId: line.id,
      newQuantity: value,
    );
  }

  /// THE primary interaction: type the exact number just loaded and add it
  /// in one clean batch. The pad always starts EMPTY — no stale batches.
  Future<void> _showBatchAddDialog({
    required Entry currentEntry,
    required EntryRepository repo,
    required String docNo,
    required IbtLineItem line,
  }) async {
    final value = await BatchPad.show(
      context,
      remaining: line.remaining,
      title: 'ADD TYRES — ${line.size ?? line.description}',
    );
    if (value == null || value == 0 || !mounted) return;

    await _updateLineQuantity(
      currentEntry: currentEntry,
      repo: repo,
      docNo: docNo,
      lineId: line.id,
      newQuantity: line.loadedQuantity + value,
    );
  }

  /// Undo one specific batch from the line's history.
  Future<void> _undoBatch({
    required Entry currentEntry,
    required EntryRepository repo,
    required String docNo,
    required String lineId,
    required String eventId,
  }) async {
    final sheetTrips = <LoadingSheetTrip>[...?currentEntry.loadingSheetTrips];
    final sheetTripIdx = sheetTrips.indexWhere((t) => !t.isManual);
    if (sheetTripIdx < 0) return;

    final result = IbtLineOps.undoBatch(
      trip: sheetTrips[sheetTripIdx],
      documentNo: docNo,
      lineItemId: lineId,
      eventId: eventId,
    );
    if (result == null) return;

    sheetTrips[sheetTripIdx] = result.trip;
    await repo.saveEntry(
      currentEntry.copyWith(
        loadingSheetTrips: sheetTrips,
        expectedTotal: result.trip.ibtTargetTotal,
      ),
    );
    _reactToDelta(result);
  }

  Widget _buildAddIbtSection(Entry currentEntry, EntryRepository repo) {
    final sheetTrips = <LoadingSheetTrip>[...?currentEntry.loadingSheetTrips];
    final sheetTripIdx = sheetTrips.indexWhere((t) => !t.isManual);
    if (sheetTripIdx < 0) return const SizedBox.shrink();
    final primary = sheetTrips[sheetTripIdx];

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.receipt_long_rounded,
                size: 18,
                color: AppColors.presetStocks,
              ),
              SizedBox(width: 8),
              Text(
                'ADD IBT DOCUMENTS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          IbtPicker(
            documents: primary.ibtDocuments ?? [],
            onChanged: (docs) {
              final totalTarget = docs.fold<int>(0, (s, d) => s + d.total);
              final totalLoaded = docs.fold<int>(
                0,
                (s, d) => s + d.loadedTotal,
              );
              final nowMs = DateTime.now().millisecondsSinceEpoch;

              final updatedTrip = primary.copyWith(
                ibtDocuments: docs,
                targetQuantity: totalTarget > 0 ? totalTarget : null,
                quantityLoaded: docs.isNotEmpty ? totalLoaded : 0,
                startTime: primary.startTime ?? nowMs,
                finishTime: nowMs,
              );

              final updatedSheetTrips = <LoadingSheetTrip>[
                ...?currentEntry.loadingSheetTrips,
              ];
              final idx = updatedSheetTrips.indexWhere((t) => !t.isManual);
              if (idx >= 0) {
                updatedSheetTrips[idx] = updatedTrip;
              }

              repo.saveEntry(
                currentEntry.copyWith(
                  loadingSheetTrips: updatedSheetTrips,
                  expectedTotal: totalTarget > 0
                      ? totalTarget
                      : currentEntry.expectedTotal,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Line items render EXACTLY in the order the manifest was fetched —
  /// static, stable, predictable. No dynamic re-sorting mid-tally.

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<EntryRepository>();

    return Scaffold(
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

          final sheetTrip = _primarySheetTrip(currentEntry);
          final ibtDocs = sheetTrip?.ibtDocuments ?? [];
          final totalTarget = ibtDocs.isNotEmpty
              ? (sheetTrip?.ibtTargetTotal ?? 0)
              : (sheetTrip?.targetQuantity ?? currentEntry.expectedTotal ?? 0);
          final totalLoaded = ibtDocs.isNotEmpty
              ? (sheetTrip?.ibtLoadedTotal ?? 0)
              : (sheetTrip?.quantityLoaded ?? 0);
          final totalRemaining = totalTarget > 0
              ? (totalTarget - totalLoaded).clamp(0, totalTarget)
              : 0;
          final isComplete = totalTarget > 0 && totalLoaded >= totalTarget;
          final isOver = totalTarget > 0 && totalLoaded > totalTarget;
          final totalPct = totalTarget > 0
              ? (totalLoaded / totalTarget).clamp(0.0, 1.0)
              : 0.0;

          // Resolve focused line from latest data
          IbtLineItem? focusedLine;
          String? focusedDocNo;
          if (_focusedDocNo != null && _focusedLineId != null) {
            for (final doc in ibtDocs) {
              if (doc.documentNo.toUpperCase() ==
                  _focusedDocNo!.toUpperCase()) {
                for (final line in doc.lineItems) {
                  if (line.id == _focusedLineId) {
                    focusedLine = line;
                    focusedDocNo = doc.documentNo;
                  }
                }
              }
            }
          }
          final activeLine = focusedLine;
          final activeDocNo = focusedDocNo;

          return SafeArea(
            bottom: false,
            child: Column(
              children: [
                _Header(
                  titleController: _titleController,
                  entry: currentEntry,
                  isDetailsOpen: _isDetailsOpen,
                  onBack: () {
                    AppHaptics.light();
                    Navigator.pop(context);
                  },
                  onToggleDetails: () {
                    AppHaptics.light();
                    setState(() => _isDetailsOpen = !_isDetailsOpen);
                  },
                  onTitleSubmitted: (val) {
                    if (val.trim().isNotEmpty) {
                      repo.saveEntry(currentEntry.copyWith(title: val.trim()));
                    }
                  },
                  onDelete: () async {
                    final confirmed = await AppDialogs.confirm(
                      context,
                      title: 'Delete this stocks entry?',
                      message:
                          'The manifest progress and counts will be '
                          'permanently removed.',
                    );
                    if (confirmed) {
                      await repo.deleteEntry(currentEntry.id);
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  details: _isDetailsOpen
                      ? TagsInput(
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
                        )
                      : null,
                ),

                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      activeLine != null ? 150 : 100,
                    ),
                    children: [
                      _HeroCard(
                        title: currentEntry.title.isNotEmpty
                            ? currentEntry.title
                            : 'STOCKS MANIFEST',
                        ibtDocs: ibtDocs,
                        totalLoaded: totalLoaded,
                        totalTarget: totalTarget,
                        totalRemaining: totalRemaining,
                        isComplete: isComplete,
                        isOver: isOver,
                        totalPct: totalPct,
                      ),

                      if (isComplete) ...[
                        const SizedBox(height: 12),
                        const _CompleteBanner(),
                      ],

                      const SizedBox(height: 16),

                      _buildAddIbtSection(currentEntry, repo),
                      const SizedBox(height: 18),

                      if (ibtDocs.isEmpty)
                        EmptyState(
                          icon: Icons.inventory_2_outlined,
                          title: 'No IBT documents yet',
                          message:
                              'Fetch an IBT number above to load its line '
                              'items and start tallying.',
                        )
                      else ...[
                        Text(
                          'LINE ITEMS — TAP A LINE TO TALLY',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.dynamicTextMuted(context),
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _IbtSearchBar(
                          controller: _searchController,
                          query: _searchQuery,
                          patterns: IbtSearch.patternCounts([
                            for (final d in ibtDocs) ...d.lineItems,
                          ]),
                          activePattern: _activePattern,
                          onQueryChanged: (q) {
                            AppHaptics.light();
                            setState(() => _searchQuery = q);
                          },
                          onPatternToggled: (p) {
                            AppHaptics.light();
                            setState(() =>
                                _activePattern = _activePattern == p ? null : p);
                          },
                          onClear: () {
                            AppHaptics.light();
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                              _activePattern = null;
                            });
                          },
                        ),
                        const SizedBox(height: 14),
                        for (final doc in ibtDocs) ...[
                          _DocHeader(doc: doc, remaining: doc.remainingTotal),
                          const SizedBox(height: 8),
                          if (IbtSearch.search(
                            doc.lineItems,
                            query: _searchQuery,
                            patternFilter: _activePattern,
                          ).isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Text(
                                'No lines match — tap × to clear the search.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.dynamicTextMuted(context),
                                ),
                              ),
                            )
                          else
                            for (final hit in IbtSearch.search(
                              doc.lineItems,
                              query: _searchQuery,
                              patternFilter: _activePattern,
                            ))
                              _LineCard(
                                line: hit.line,
                                isFocused:
                                    activeLine != null &&
                                    activeLine.id == hit.line.id,
                                onTap: () {
                                  AppHaptics.light();
                                  setState(() {
                                    _focusedDocNo = doc.documentNo;
                                    _focusedLineId = hit.line.id;
                                  });
                                },
                                onAddBatch: () => _showBatchAddDialog(
                                  currentEntry: currentEntry,
                                  repo: repo,
                                  docNo: doc.documentNo,
                                  line: hit.line,
                                ),
                                onUndoBatch: (eventId) => _undoBatch(
                                  currentEntry: currentEntry,
                                  repo: repo,
                                  docNo: doc.documentNo,
                                  lineId: hit.line.id,
                                  eventId: eventId,
                                ),
                                onUndoLast: () => _undoLineLast(
                                  currentEntry: currentEntry,
                                  repo: repo,
                                  docNo: doc.documentNo,
                                  lineId: hit.line.id,
                                ),
                                onEdit: () => _showEditCountDialog(
                                  currentEntry: currentEntry,
                                  repo: repo,
                                  docNo: doc.documentNo,
                                  line: hit.line,
                                ),
                              ),
                          const SizedBox(height: 14),
                        ],
                      ],

                      const SizedBox(height: 4),

                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TRUCK ASSIGNMENT',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.dynamicTextMuted(context),
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _regController,
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.dynamicTextPrimary(
                                        context,
                                      ),
                                      letterSpacing: 1.0,
                                    ),
                                    decoration: const InputDecoration(
                                      labelText: 'REG NUMBER',
                                      isDense: true,
                                    ),
                                    onChanged: (val) {
                                      final sheetTrips = [
                                        ...?currentEntry.loadingSheetTrips,
                                      ];
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
                                    textCapitalization:
                                        TextCapitalization.words,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.dynamicTextPrimary(
                                        context,
                                      ),
                                    ),
                                    decoration: const InputDecoration(
                                      labelText: 'DRIVER NAME',
                                      isDense: true,
                                    ),
                                    onChanged: (val) {
                                      final sheetTrips = [
                                        ...?currentEntry.loadingSheetTrips,
                                      ];
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

                      Text(
                        'EVENT LOG',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.dynamicTextMuted(context),
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
                        onOpenPhoto: (att) => PhotoLightbox.show(
                          context,
                          att,
                          allAttachments: currentEntry.attachments,
                          onUpdateAttachment: (updatedAtt) {
                            final updated = currentEntry.attachments
                                .map(
                                  (a) => a.id == updatedAtt.id ? updatedAtt : a,
                                )
                                .toList();
                            repo.saveEntry(
                              currentEntry.copyWith(attachments: updated),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom area: focus tally bar (when a line is selected)
                // or the note/photo/voice bar.
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: activeLine != null && activeDocNo != null
                      ? _TallyBar(
                          docNo: activeDocNo,
                          line: activeLine,
                          onAddBatch: () => _showBatchAddDialog(
                            currentEntry: currentEntry,
                            repo: repo,
                            docNo: activeDocNo,
                            line: activeLine,
                          ),
                          onEdit: () => _showEditCountDialog(
                            currentEntry: currentEntry,
                            repo: repo,
                            docNo: activeDocNo,
                            line: activeLine,
                          ),
                          onUndoLast: () => _undoLineLast(
                            currentEntry: currentEntry,
                            repo: repo,
                            docNo: activeDocNo,
                            lineId: activeLine.id,
                          ),
                          onClose: () {
                            AppHaptics.light();
                            setState(() {
                              _focusedDocNo = null;
                              _focusedLineId = null;
                            });
                          },
                        )
                      : FloatingNoteBar(
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
                                    attachments: [
                                      ...currentEntry.attachments,
                                      att,
                                    ],
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

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  final TextEditingController titleController;
  final Entry entry;
  final bool isDetailsOpen;
  final VoidCallback onBack;
  final VoidCallback onToggleDetails;
  final ValueChanged<String> onTitleSubmitted;
  final VoidCallback onDelete;
  final Widget? details;

  const _Header({
    required this.titleController,
    required this.entry,
    required this.isDetailsOpen,
    required this.onBack,
    required this.onToggleDetails,
    required this.onTitleSubmitted,
    required this.onDelete,
    required this.details,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.dynamicBackground(context),
        border: Border(
          bottom: BorderSide(color: AppColors.dynamicBorderLight(context)),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: titleController,
                            textCapitalization: TextCapitalization.characters,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: AppColors.dynamicTextPrimary(context),
                              letterSpacing: 0.5,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              border: InputBorder.none,
                            ),
                            onSubmitted: onTitleSubmitted,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const PresetBadge(
                          presetKey: PresetKey.STOCKS,
                          tripId: 'STOCKS',
                        ),
                      ],
                    ),
                    Text(
                      AppFormatters.formatDayLabel(entry.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.dynamicTextMuted(context),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onToggleDetails,
                tooltip: isDetailsOpen ? 'Hide details' : 'Show details',
                icon: AnimatedRotation(
                  turns: isDetailsOpen ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.dynamicTextSecondary(context),
                  ),
                ),
              ),
              IconButton(
                onPressed: onDelete,
                tooltip: 'Delete entry',
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          if (details != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: details!,
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero manifest progress
// ---------------------------------------------------------------------------

class _HeroCard extends StatelessWidget {
  final String title;
  final List<IbtDocument> ibtDocs;
  final int totalLoaded;
  final int totalTarget;
  final int totalRemaining;
  final bool isComplete;
  final bool isOver;
  final double totalPct;

  const _HeroCard({
    required this.title,
    required this.ibtDocs,
    required this.totalLoaded,
    required this.totalTarget,
    required this.totalRemaining,
    required this.isComplete,
    required this.isOver,
    required this.totalPct,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = isComplete
        ? AppColors.success
        : (isOver ? AppColors.warning : AppColors.presetStocks);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: GlassDecorations.glassElevated(
        context: context,
        borderRadius: 26,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.presetStocks.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.local_shipping_rounded,
                  size: 22,
                  color: AppColors.presetStocks,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.dynamicTextPrimary(context),
                      ),
                    ),
                    Text(
                      '${ibtDocs.map((d) => d.documentNo).join(", ")} · ${ibtDocs.fold(0, (s, d) => s + d.lineItems.length)} line items',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.dynamicTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL TYRES LOADED',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.dynamicTextMuted(context),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$totalLoaded',
                          style: TextStyle(
                            fontSize: 52,
                            fontWeight: FontWeight.w900,
                            color: AppColors.dynamicTextPrimary(context),
                            letterSpacing: -1.5,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '/ $totalTarget',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.dynamicTextMuted(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isComplete
                          ? Icons.check_circle_rounded
                          : (isOver
                                ? Icons.warning_amber_rounded
                                : Icons.hourglass_bottom_rounded),
                      size: 18,
                      color: statusColor,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      isComplete
                          ? 'ALL LOADED'
                          : (isOver
                                ? '+${totalLoaded - totalTarget} OVER'
                                : '$totalRemaining LEFT'),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: statusColor,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: totalPct,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompleteBanner extends StatelessWidget {
  const _CompleteBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.5)),
      ),
      child: const Row(
        children: [
          Icon(Icons.celebration_rounded, color: AppColors.success, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'MANIFEST COMPLETE — every line item loaded',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.success,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Document header
// ---------------------------------------------------------------------------

class _DocHeader extends StatelessWidget {
  final IbtDocument doc;
  final int remaining;

  const _DocHeader({required this.doc, required this.remaining});

  @override
  Widget build(BuildContext context) {
    final done = doc.isComplete;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.presetStocks.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: AppColors.presetStocks.withValues(alpha: 0.4),
            ),
          ),
          child: Text(
            doc.documentNo,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: AppColors.presetStocks,
              letterSpacing: 0.6,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            done
                ? 'Complete'
                : '$remaining ${remaining == 1 ? "tyre" : "tyres"} to go',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: done
                  ? AppColors.success
                  : AppColors.dynamicTextMuted(context),
            ),
          ),
        ),
        Text(
          '${doc.loadedTotal} / ${doc.total}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.dynamicTextSecondary(context),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Line card
// ---------------------------------------------------------------------------

class _LineCard extends StatelessWidget {
  final IbtLineItem line;
  final bool isFocused;
  final VoidCallback onTap;
  final VoidCallback onAddBatch;
  final ValueChanged<String> onUndoBatch; // event id
  final VoidCallback onUndoLast;
  final VoidCallback onEdit;

  const _LineCard({
    required this.line,
    required this.isFocused,
    required this.onTap,
    required this.onAddBatch,
    required this.onUndoBatch,
    required this.onUndoLast,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final target = line.targetTotal;
    final loaded = line.loadedQuantity;
    final pct = target > 0 ? (loaded / target).clamp(0.0, 1.0) : 0.0;
    final isDone = target > 0 && loaded >= target;
    final isOver = target > 0 && loaded > target;
    final remaining = (target - loaded).clamp(0, target);

    final Color statusColor = isOver
        ? AppColors.warningStrong(context)
        : (isDone
              ? AppColors.successStrong(context)
              : AppColors.presetStocksStrong(context));

    return GestureDetector(
      onTap: isDone ? null : onAddBatch,
      onLongPress: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: GlassDecorations.glassCard(
          context: context,
          borderRadius: 14,
          borderColor: isFocused
              ? AppColors.presetStocksStrong(context).withValues(alpha: 0.9)
              : (isDone
                    ? AppColors.successStrong(context).withValues(alpha: 0.35)
                    : (isOver
                          ? AppColors.warningStrong(context).withValues(alpha: 0.5)
                          : null)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: SIZE + PATTERN prominent, RCS as a footnote ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          line.size ?? line.description,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.2,
                            color: AppColors.dynamicTextPrimary(context),
                          ),
                        ),
                      ),
                      if (line.rubber != null) ...[
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.presetStocksStrong(
                              context,
                            ).withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppColors.presetStocksStrong(
                                context,
                              ).withValues(alpha: 0.45),
                            ),
                          ),
                          child: Text(
                            line.rubber!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                              color: AppColors.presetStocksStrong(context),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Count — tap for exact-total edit
                GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$loaded',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            color: statusColor,
                          ),
                        ),
                        Text(
                          ' / $target',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.dynamicTextMuted(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (line.rcsCode != null)
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(
                  'RCS ${line.rcsCode}',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: AppColors.dynamicTextDisabled(context),
                  ),
                ),
              ),
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 4,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Expanded(
                  child: Text(
                    isOver
                        ? '+${loaded - target} over'
                        : (isDone ? 'Complete' : '$remaining left'),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ),
                Text(
                  'TAP TO ADD · HOLD TO DOCK',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.dynamicTextDisabled(context),
                  ),
                ),
              ],
            ),

            // ── Full batch history: scrollable strip, tap a chip to undo ──
            if (line.history.isNotEmpty) ...[
              const SizedBox(height: 6),
              SizedBox(
                height: 22,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final ev in line.history.reversed)
                      Padding(
                        padding: const EdgeInsets.only(right: 5),
                        child: GestureDetector(
                          onTap: () {
                            AppHaptics.medium();
                            onUndoBatch(ev.id);
                          },
                          child: _HistoryChip(event: ev),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(right: 5),
                      child: GestureDetector(
                        onTap: () {
                          AppHaptics.medium();
                          onUndoLast();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7),
                          decoration: BoxDecoration(
                            color: AppColors.warningStrong(
                              context,
                            ).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppColors.warningStrong(
                                context,
                              ).withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.undo_rounded,
                                size: 10,
                                color: AppColors.warningStrong(context),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'undo last',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.warningStrong(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One line-activity chip: "+4 · 07:32" — tap to undo that batch.
class _HistoryChip extends StatelessWidget {
  final IbtLineEvent event;

  const _HistoryChip({required this.event});

  @override
  Widget build(BuildContext context) {
    final t = DateTime.fromMillisecondsSinceEpoch(event.at);
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    final isAdd = event.delta >= 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
      decoration: BoxDecoration(
        color: isAdd
            ? AppColors.successStrong(context).withValues(alpha: 0.14)
            : AppColors.warningStrong(context).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: (isAdd
                  ? AppColors.successStrong(context)
                  : AppColors.warningStrong(context))
              .withValues(alpha: 0.4),
        ),
      ),
      child: Text(
        '${isAdd ? '+' : ''}${event.delta} · $hh:$mm',
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          fontFamily: 'monospace',
          color: isAdd
              ? AppColors.successStrong(context)
              : AppColors.warningStrong(context),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Focus tally bar — the thumb-first counting dock
// ---------------------------------------------------------------------------

class _TallyBar extends StatelessWidget {
  final String docNo;
  final IbtLineItem line;
  final VoidCallback onAddBatch;
  final VoidCallback onEdit;
  final VoidCallback onUndoLast;
  final VoidCallback onClose;

  const _TallyBar({
    required this.docNo,
    required this.line,
    required this.onAddBatch,
    required this.onEdit,
    required this.onUndoLast,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final target = line.targetTotal;
    final loaded = line.loadedQuantity;
    final isDone = target > 0 && loaded >= target;
    final statusColor = isDone
        ? AppColors.successStrong(context)
        : AppColors.presetStocksStrong(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: GlassDecorations.glassDock(
        context: context,
        borderRadius: 22,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        line.size ?? line.description,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppColors.dynamicTextPrimary(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (line.rubber != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        line.rubber!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: AppColors.presetStocksStrong(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                '$loaded / $target',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.dynamicTextPrimary(context),
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: Icon(
                  Icons.close_rounded,
                  color: AppColors.dynamicTextMuted(context),
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              // Primary: type the number and add it in one batch
              Expanded(
                flex: 3,
                child: GestureDetector(
                  onTap: isDone
                      ? null
                      : () {
                          AppHaptics.medium();
                          onAddBatch();
                        },
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: isDone
                          ? AppColors.dynamicCardSurface(context)
                          : AppColors.presetStocksStrong(context),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: AppColors.presetStocksStrong(
                          context,
                        ).withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isDone
                              ? Icons.check_circle_rounded
                              : Icons.dialpad_rounded,
                          size: 20,
                          color: isDone
                              ? AppColors.successStrong(context)
                              : AppColors.onAccent,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isDone ? 'COMPLETE' : 'ADD TYRES',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: isDone
                                ? AppColors.successStrong(context)
                                : AppColors.onAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (line.history.isNotEmpty) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    AppHaptics.medium();
                    onUndoLast();
                  },
                  child: Container(
                    height: 52,
                    width: 52,
                    decoration: BoxDecoration(
                      color: AppColors.warningStrong(
                        context,
                      ).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: AppColors.warningStrong(
                          context,
                        ).withValues(alpha: 0.5),
                      ),
                    ),
                    child: Icon(
                      Icons.undo_rounded,
                      size: 20,
                      color: AppColors.warningStrong(context),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  AppHaptics.light();
                  onEdit();
                },
                child: Container(
                  height: 52,
                  width: 52,
                  decoration: BoxDecoration(
                    color: AppColors.dynamicCardSurface(context),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: AppColors.dynamicBorder(context),
                    ),
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    size: 18,
                    color: AppColors.dynamicTextSecondary(context),
                  ),
                ),
              ),
            ],
          ),
          if (line.history.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 20,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final ev in line.history.reversed)
                    Padding(
                      padding: const EdgeInsets.only(right: 5),
                      child: _HistoryChip(event: ev),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Subtle but smart IBT search — free-text tokens + pattern chips with
/// counts. The star feature: find one line among 14 patterns in a tap.
class _IbtSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final List<(String, int)> patterns;
  final String? activePattern;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onPatternToggled;
  final VoidCallback onClear;

  const _IbtSearchBar({
    required this.controller,
    required this.query,
    required this.patterns,
    required this.activePattern,
    required this.onQueryChanged,
    required this.onPatternToggled,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final filtering = query.trim().isNotEmpty || activePattern != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: GlassDecorations.glassCard(
            context: context,
            borderRadius: 14,
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              Icon(
                Icons.search_rounded,
                size: 18,
                color: filtering
                    ? AppColors.presetStocksStrong(context)
                    : AppColors.dynamicTextMuted(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onQueryChanged,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dynamicTextPrimary(context),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search size, pattern, RCS…',
                    hintStyle: TextStyle(
                      fontSize: 12,
                      color: AppColors.dynamicTextMuted(context),
                    ),
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (filtering)
                GestureDetector(
                  onTap: onClear,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: AppColors.dynamicTextMuted(context),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (patterns.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 30,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final (pattern, count) in patterns)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _patternChip(context, pattern, count),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _patternChip(BuildContext context, String pattern, int count) {
    final active = activePattern == pattern;
    return GestureDetector(
      onTap: () => onPatternToggled(pattern),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: active
              ? AppColors.presetStocksStrong(context).withValues(alpha: 0.2)
              : AppColors.dynamicCardSurface(context),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: active
                ? AppColors.presetStocksStrong(context).withValues(alpha: 0.6)
                : AppColors.dynamicBorder(context),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              pattern,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
                color: active
                    ? AppColors.presetStocksStrong(context)
                    : AppColors.dynamicTextSecondary(context),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '×$count',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.dynamicTextMuted(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
