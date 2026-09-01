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
import '../widgets/counter_panel.dart';
import '../widgets/counter_progress.dart';
import '../widgets/event_log_view.dart';
import '../widgets/floating_note_bar.dart';
import '../widgets/photo_lightbox.dart';
import '../widgets/tags_input.dart';

class EntryDetailScreen extends StatefulWidget {
  final String entryId;

  const EntryDetailScreen({super.key, required this.entryId});

  @override
  State<EntryDetailScreen> createState() => _EntryDetailScreenState();
}

class _EntryDetailScreenState extends State<EntryDetailScreen> {
  final AudioService _audioService = AudioService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _regController = TextEditingController();
  final TextEditingController _driverController = TextEditingController();

  bool _isDetailsOpen = false;
  bool _isSaved = false;
  Entry? _cachedEntry;

  void _triggerSavedIndicator() {
    if (!mounted) return;
    setState(() => _isSaved = true);
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _isSaved = false);
    });
  }

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
    if (_regController.text.isEmpty) {
      _regController.text = sheetTrip?.reg ?? '';
    }
    if (_driverController.text.isEmpty) {
      _driverController.text = sheetTrip?.driverName ?? '';
    }
  }

  List<LoadingSheetTrip> _syncTripsToLoadingSheet(Entry entry, List<Trip> newTrips) {
    final List<LoadingSheetTrip> current = [...?entry.loadingSheetTrips];
    final totalQty = newTrips.fold<int>(0, (s, t) => s + t.count + (t.rejected ?? 0));

    if (newTrips.isEmpty && current.isEmpty) return [];

    final sorted = [...newTrips]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final start = sorted.isNotEmpty ? sorted.first.createdAt : DateTime.now().millisecondsSinceEpoch;
    final finish = sorted.isNotEmpty ? sorted.last.createdAt : DateTime.now().millisecondsSinceEpoch;
    final diff = finish - start;
    final duration = diff > 0 ? (diff / (1000 * 60)).round() : 1;

    final targetIdx = current.indexWhere((t) => !t.isManual);
    if (targetIdx >= 0) {
      current[targetIdx] = current[targetIdx].copyWith(
        entryId: entry.id,
        reg: _regController.text.trim().isNotEmpty ? _regController.text.trim().toUpperCase() : current[targetIdx].reg,
        driverName: _driverController.text.trim().isNotEmpty ? _driverController.text.trim() : current[targetIdx].driverName,
        tripId: entry.title.isNotEmpty ? entry.title : current[targetIdx].tripId,
        quantityLoaded: totalQty,
        targetQuantity: entry.expectedTotal ?? current[targetIdx].targetQuantity,
        startTime: start,
        finishTime: finish,
        durationMinutes: duration,
      );
    } else {
      current.insert(
        0,
        LoadingSheetTrip(
          id: IdGenerator.generate(),
          entryId: entry.id,
          reg: _regController.text.trim().toUpperCase(),
          driverName: _driverController.text.trim(),
          tripId: entry.title.isNotEmpty ? entry.title : 'NLS',
          startTime: start,
          finishTime: finish,
          durationMinutes: duration,
          quantityLoaded: totalQty,
          targetQuantity: entry.expectedTotal,
          createdAt: start,
        ),
      );
    }

    return current;
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<EntryRepository>();
    final isLight = AppColors.isLight(context);

    return Scaffold(
      backgroundColor: AppColors.dynamicBackground(context),
      body: FutureBuilder<Entry?>(
        future: repo.getEntryById(widget.entryId),
        builder: (context, snapshot) {
          final entry = snapshot.data;
          if (snapshot.connectionState == ConnectionState.waiting && _cachedEntry == null) {
            return Center(child: CircularProgressIndicator(color: isLight ? AppColors.primary : AppColors.primaryGlow));
          }

          if (entry == null && _cachedEntry == null) {
            return Scaffold(
              backgroundColor: AppColors.dynamicBackground(context),
              appBar: AppBar(backgroundColor: Colors.transparent),
              body: const Center(child: Text('Entry not found', style: TextStyle(color: AppColors.textMuted))),
            );
          }

          final currentEntry = entry ?? _cachedEntry!;
          _cachedEntry = currentEntry;

          if (_titleController.text.isEmpty && currentEntry.title.isNotEmpty) {
            _titleController.text = currentEntry.title;
          }
          _syncTripDetailsToEntry(currentEntry);

          final trips = currentEntry.trips ?? [];
          final isCounterSession = currentEntry.trips != null || currentEntry.loadingSheetTrips != null;

          final totalScanned = trips.fold<int>(0, (s, t) => s + t.count);
          final totalManual = trips.fold<int>(0, (s, t) => s + (t.rejected ?? 0));
          final grandTotal = totalScanned + totalManual;

          // Resolve IBT documents from the primary (non-manual) sheet trip
          final sheetTrip = currentEntry.loadingSheetTrips?.firstWhere(
            (t) => !t.isManual,
            orElse: () => LoadingSheetTrip(
              id: '', entryId: '', reg: '', driverName: '',
              tripId: '', quantityLoaded: 0,
              createdAt: DateTime.now().millisecondsSinceEpoch,
            ),
          );
          final ibtDocs = sheetTrip?.ibtDocuments ?? [];
          final hasIbt = ibtDocs.isNotEmpty;

          // Effective target: entry.expectedTotal ?? IBT total from sheet trip
          final ibtTarget = hasIbt
              ? ibtDocs.fold<int>(0, (s, d) => s + d.total)
              : null;
          final effectiveTarget = currentEntry.expectedTotal ?? ibtTarget;

          return SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Top Custom Navigation Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: GlassDecorations.glassCard(context: context, borderRadius: 0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.arrow_back_rounded, color: AppColors.dynamicTextPrimary(context)),
                            onPressed: () {
                              AppHaptics.light();
                              Navigator.pop(context);
                            },
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  controller: _titleController,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.dynamicTextPrimary(context),
                                    fontFamily: 'monospace',
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  onSubmitted: (newTitle) {
                                    final updated = currentEntry.copyWith(title: newTitle.trim());
                                    setState(() => _cachedEntry = updated);
                                    repo.saveEntry(updated);
                                    _triggerSavedIndicator();
                                  },
                                ),
                                Row(
                                  children: [
                                    Text(
                                      '${AppFormatters.formatDayLabel(currentEntry.createdAt)} · ${AppFormatters.formatTimeHHmm(currentEntry.createdAt)}',
                                      style: TextStyle(fontSize: 10, color: AppColors.dynamicTextMuted(context)),
                                    ),
                                    if (_isSaved) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: AppColors.success.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.check_rounded, size: 10, color: AppColors.success),
                                            SizedBox(width: 2),
                                            Text('Saved', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppColors.success)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (isCounterSession)
                            IconButton(
                              icon: Icon(
                                _isDetailsOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                color: AppColors.dynamicTextMuted(context),
                              ),
                              onPressed: () {
                                AppHaptics.light();
                                setState(() => _isDetailsOpen = !_isDetailsOpen);
                              },
                            ),
                        ],
                      ),

                      // Collapsible Tag Bar
                      if (_isDetailsOpen) ...[
                        const SizedBox(height: 8),
                        TagsInput(
                          value: currentEntry.tags,
                          onChange: (newTags) {
                            final updated = currentEntry.copyWith(tags: newTags);
                            setState(() => _cachedEntry = updated);
                            repo.saveEntry(updated);
                            _triggerSavedIndicator();
                          },
                        ),
                      ],
                    ],
                  ),
                ),

                // Main Scrollable Area
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    children: [
                      // Counter Zone
                      if (isCounterSession) ...[
                        CounterProgress(
                          total: grandTotal,
                          tripCount: trips.length,
                          expectedTotal: effectiveTarget,
                          truckReg: _regController.text.trim(),
                          driverName: _driverController.text.trim(),
                          tripTitle: currentEntry.title,
                          onSetExpected: (target) {
                            final List<LoadingSheetTrip> sheetTrips = [...?currentEntry.loadingSheetTrips];
                            final idx = sheetTrips.indexWhere((t) => !t.isManual);
                            if (idx >= 0) {
                              sheetTrips[idx] = sheetTrips[idx].copyWith(targetQuantity: target);
                            } else {
                              sheetTrips.add(
                                LoadingSheetTrip(
                                  id: IdGenerator.generate(),
                                  entryId: currentEntry.id,
                                  reg: _regController.text.trim().toUpperCase(),
                                  driverName: _driverController.text.trim(),
                                  tripId: currentEntry.title.isNotEmpty ? currentEntry.title : 'NLS',
                                  quantityLoaded: grandTotal,
                                  targetQuantity: target,
                                  createdAt: DateTime.now().millisecondsSinceEpoch,
                                ),
                              );
                            }
                            final updatedEntry = currentEntry.copyWith(
                              expectedTotal: target,
                              loadingSheetTrips: sheetTrips,
                            );
                            setState(() => _cachedEntry = updatedEntry);
                            repo.saveEntry(updatedEntry);
                            _triggerSavedIndicator();
                          },
                          onUpdateTruckDetails: (reg, driver, target) {
                            if (reg != null && reg.isNotEmpty) _regController.text = reg;
                            if (driver != null && driver.isNotEmpty) _driverController.text = driver;

                            final List<LoadingSheetTrip> sheetTrips = [...?currentEntry.loadingSheetTrips];
                            final idx = sheetTrips.indexWhere((t) => !t.isManual);
                            if (idx >= 0) {
                              sheetTrips[idx] = sheetTrips[idx].copyWith(
                                reg: reg?.toUpperCase() ?? sheetTrips[idx].reg,
                                driverName: driver ?? sheetTrips[idx].driverName,
                                targetQuantity: target,
                              );
                            } else {
                              sheetTrips.add(
                                LoadingSheetTrip(
                                  id: IdGenerator.generate(),
                                  entryId: currentEntry.id,
                                  reg: reg?.toUpperCase() ?? _regController.text.trim().toUpperCase(),
                                  driverName: driver ?? _driverController.text.trim(),
                                  tripId: currentEntry.title.isNotEmpty ? currentEntry.title : 'NLS',
                                  quantityLoaded: grandTotal,
                                  targetQuantity: target,
                                  createdAt: DateTime.now().millisecondsSinceEpoch,
                                ),
                              );
                            }
                            final updatedEntry = currentEntry.copyWith(
                              expectedTotal: target,
                              loadingSheetTrips: sheetTrips,
                            );
                            setState(() => _cachedEntry = updatedEntry);
                            repo.saveEntry(updatedEntry);
                            _triggerSavedIndicator();
                          },
                        ),
                        const SizedBox(height: 10),
                        CounterPanel(
                          trips: trips,
                          currentTotal: grandTotal,
                          targetTotal: effectiveTarget,
                          onChange: (nextTrips) {
                            final sheetTrips = _syncTripsToLoadingSheet(currentEntry, nextTrips);
                            final updatedEntry = currentEntry.copyWith(
                              trips: nextTrips,
                              loadingSheetTrips: sheetTrips,
                            );
                            setState(() => _cachedEntry = updatedEntry);
                            repo.saveEntry(updatedEntry);
                            _triggerSavedIndicator();
                          },
                          onAttachment: (att) {
                            final updatedEntry = currentEntry.copyWith(
                              attachments: [...currentEntry.attachments, att],
                            );
                            setState(() => _cachedEntry = updatedEntry);
                            repo.saveEntry(updatedEntry);
                            _triggerSavedIndicator();
                          },
                        ),
                        if (hasIbt) ...[
                          const SizedBox(height: 12),
                          for (final doc in ibtDocs) ...[
                            Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: GlassDecorations.glassCard(context: context, borderRadius: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryGlow.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: AppColors.primaryGlow.withValues(alpha: 0.3)),
                                        ),
                                        child: Text(
                                          doc.documentNo,
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primaryGlow, fontFamily: 'monospace'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${doc.total} tyres total',
                                        style: TextStyle(fontSize: 11, color: AppColors.dynamicTextMuted(context)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  for (final line in doc.lineItems) ...[
                                    _IbtLineRow(line: line, grandTotal: grandTotal, ibtTarget: doc.total),
                                    const SizedBox(height: 6),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ],
                      ],

                      const SizedBox(height: 12),

                      // Event Log Header
                      Text(
                        'EVENT LOG',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.dynamicTextMuted(context),
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Event Log Feed
                      EventLogView(
                        notes: currentEntry.notes,
                        attachments: currentEntry.attachments,
                        trips: trips,
                        audioService: _audioService,
                        onRemoveNote: (nid) {
                          final updated = currentEntry.notes.where((n) => n.id != nid).toList();
                          final updatedEntry = currentEntry.copyWith(notes: updated);
                          setState(() => _cachedEntry = updatedEntry);
                          repo.saveEntry(updatedEntry);
                          _triggerSavedIndicator();
                        },
                        onRemoveAttachment: (aid) {
                          final updated = currentEntry.attachments.where((a) => a.id != aid).toList();
                          final updatedEntry = currentEntry.copyWith(attachments: updated);
                          setState(() => _cachedEntry = updatedEntry);
                          repo.saveEntry(updatedEntry);
                          _triggerSavedIndicator();
                        },
                        onRemoveTrip: (tid) {
                          final updatedTrips = (currentEntry.trips ?? []).where((t) => t.id != tid).toList();
                          final sheetTrips = _syncTripsToLoadingSheet(currentEntry, updatedTrips);
                          final updatedEntry = currentEntry.copyWith(
                            trips: updatedTrips,
                            loadingSheetTrips: sheetTrips,
                          );
                          setState(() => _cachedEntry = updatedEntry);
                          repo.saveEntry(updatedEntry);
                          _triggerSavedIndicator();
                        },
                        onOpenPhoto: (att) => PhotoLightbox.show(
                          context,
                          att,
                          allAttachments: currentEntry.attachments,
                          onUpdateAttachment: (updatedAtt) {
                            final updated = currentEntry.attachments
                                .map((a) => a.id == updatedAtt.id ? updatedAtt : a)
                                .toList();
                            final updatedEntry = currentEntry.copyWith(attachments: updated);
                            setState(() => _cachedEntry = updatedEntry);
                            repo.saveEntry(updatedEntry);
                            _triggerSavedIndicator();
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Floating Note Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: FloatingNoteBar(
                    onAddNote: (text) {
                      final newNote = NoteBlock(
                        id: IdGenerator.generate(),
                        text: text,
                        createdAt: DateTime.now().millisecondsSinceEpoch,
                      );
                      final updatedEntry = currentEntry.copyWith(
                        notes: [...currentEntry.notes, newNote],
                      );
                      setState(() => _cachedEntry = updatedEntry);
                      repo.saveEntry(updatedEntry);
                      _triggerSavedIndicator();
                    },
                    onAttachment: (att) {
                      final updatedEntry = currentEntry.copyWith(
                        attachments: [...currentEntry.attachments, att],
                      );
                      setState(() => _cachedEntry = updatedEntry);
                      repo.saveEntry(updatedEntry);
                      _triggerSavedIndicator();
                    },
                    onStartVoice: () async {
                      if (_audioService.isRecording) {
                        final att = await _audioService.stopRecording();
                        if (att != null) {
                          final updatedEntry = currentEntry.copyWith(
                            attachments: [...currentEntry.attachments, att],
                          );
                          setState(() => _cachedEntry = updatedEntry);
                          repo.saveEntry(updatedEntry);
                          _triggerSavedIndicator();
                        }
                      } else {
                        await _audioService.startRecording();
                        setState(() {});
                      }
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

/// Compact row showing one IBT line item's loaded progress vs its target
class _IbtLineRow extends StatelessWidget {
  final IbtLineItem line;
  final int grandTotal;
  final int ibtTarget;

  const _IbtLineRow({
    required this.line,
    required this.grandTotal,
    required this.ibtTarget,
  });

  @override
  Widget build(BuildContext context) {
    final target = line.targetTotal;
    final loaded = line.loadedQuantity;
    final pct = target > 0 ? (loaded / target).clamp(0.0, 1.0) : 0.0;
    final isOver = loaded > target && target > 0;
    final isDone = target > 0 && loaded >= target;

    final Color barColor = isOver
        ? AppColors.warning
        : (isDone ? AppColors.success : AppColors.primaryGlow);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (line.size != null)
                    Text(
                      line.size!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.dynamicTextPrimary(context),
                        fontFamily: 'monospace',
                      ),
                    ),
                  if (line.size != null && line.rubber != null)
                    Text(' · ', style: TextStyle(color: AppColors.dynamicTextMuted(context), fontSize: 11)),
                  if (line.rubber != null)
                    Text(
                      line.rubber!,
                      style: TextStyle(fontSize: 11, color: AppColors.dynamicTextSecondary(context)),
                    ),
                  if (line.size == null && line.rubber == null)
                    Expanded(
                      child: Text(
                        line.description,
                        style: TextStyle(fontSize: 10, color: AppColors.dynamicTextSecondary(context)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 5,
                  backgroundColor: AppColors.isLight(context)
                      ? Colors.black.withValues(alpha: 0.07)
                      : Colors.white.withValues(alpha: 0.07),
                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$loaded / $target',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: isOver
                ? AppColors.warning
                : (isDone ? AppColors.success : AppColors.dynamicTextPrimary(context)),
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}

