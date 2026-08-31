import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_decorations.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';
import '../../core/utils/id_generator.dart';
import '../../data/models/entry.dart';
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
import '../widgets/voice_recorder_sheet.dart';

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
        tripId: entry.title.isNotEmpty ? entry.title : current[targetIdx].tripId,
        quantityLoaded: totalQty,
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
          createdAt: start,
        ),
      );
    }

    return current;
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
          if (snapshot.connectionState == ConnectionState.waiting && _cachedEntry == null) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primaryGlow));
          }

          if (entry == null && _cachedEntry == null) {
            return Scaffold(
              appBar: AppBar(backgroundColor: Colors.transparent),
              body: const Center(child: Text('Entry not found', style: TextStyle(color: AppColors.textMuted))),
            );
          }

          final currentEntry = entry ?? _cachedEntry!;
          _cachedEntry = currentEntry;

          if (_titleController.text.isEmpty && currentEntry.title.isNotEmpty) {
            _titleController.text = currentEntry.title;
            _syncTripDetailsToEntry(currentEntry);
          }

          final trips = currentEntry.trips ?? [];
          final isCounterSession = currentEntry.trips != null || currentEntry.loadingSheetTrips != null;

          final totalScanned = trips.fold<int>(0, (s, t) => s + t.count);
          final totalManual = trips.fold<int>(0, (s, t) => s + (t.rejected ?? 0));
          final grandTotal = totalScanned + totalManual;

          return SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Top Custom Navigation Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: GlassDecorations.glassCard(borderRadius: 0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
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
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                    fontFamily: 'monospace',
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  onSubmitted: (newTitle) {
                                    repo.saveEntry(currentEntry.copyWith(title: newTitle.trim()));
                                  },
                                ),
                                Text(
                                  '${AppFormatters.formatDayLabel(currentEntry.createdAt)} · ${AppFormatters.formatTimeHHmm(currentEntry.createdAt)}',
                                  style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                          if (isCounterSession)
                            IconButton(
                              icon: Icon(
                                _isDetailsOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                color: AppColors.textMuted,
                              ),
                              onPressed: () {
                                AppHaptics.light();
                                setState(() => _isDetailsOpen = !_isDetailsOpen);
                              },
                            ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                            onPressed: () async {
                              AppHaptics.error();
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: AppColors.backgroundSecondary,
                                  title: const Text('Delete Entry?', style: TextStyle(color: Colors.white)),
                                  content: const Text('This will permanently delete this trip entry.', style: TextStyle(color: AppColors.textMuted)),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Delete', style: TextStyle(color: Colors.white)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await repo.deleteEntry(currentEntry.id);
                                if (context.mounted) {
                                  Navigator.pop(context);
                                }
                              }
                            },
                          ),
                        ],
                      ),

                      // Tags Bar
                      if (!isCounterSession || _isDetailsOpen)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, left: 8, right: 8),
                          child: TagsInput(
                            value: currentEntry.tags,
                            onChange: (nextTags) {
                              repo.saveEntry(currentEntry.copyWith(tags: nextTags));
                            },
                            suggestions: const ['tyres', 'stocks', 'nlh', 'dbn', 'bloem', 'plk'],
                          ),
                        ),
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
                          expectedTotal: currentEntry.expectedTotal,
                          onSetExpected: (target) {
                            repo.saveEntry(currentEntry.copyWith(expectedTotal: target));
                          },
                        ),
                        const SizedBox(height: 12),
                        CounterPanel(
                          trips: trips,
                          onChange: (nextTrips) {
                            final sheetTrips = _syncTripsToLoadingSheet(currentEntry, nextTrips);
                            repo.saveEntry(currentEntry.copyWith(
                              trips: nextTrips,
                              loadingSheetTrips: sheetTrips,
                            ));
                          },
                          onAttachment: (att) {
                            repo.saveEntry(currentEntry.copyWith(
                              attachments: [...currentEntry.attachments, att],
                            ));
                          },
                        ),
                        const SizedBox(height: 12),

                        // Trip Details (Reg & Driver)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: GlassDecorations.glassCard(borderRadius: 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'TRUCK ASSIGNMENT',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 1.0),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _regController,
                                      textCapitalization: TextCapitalization.characters,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'monospace'),
                                      decoration: InputDecoration(
                                        labelText: 'REG NO',
                                        labelStyle: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                        filled: true,
                                        fillColor: Colors.black.withValues(alpha: 0.3),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      onChanged: (val) {
                                        final List<LoadingSheetTrip> sheetTrips = [...?currentEntry.loadingSheetTrips];
                                        final idx = sheetTrips.indexWhere((t) => !t.isManual);
                                        if (idx >= 0) {
                                          sheetTrips[idx] = sheetTrips[idx].copyWith(reg: val.toUpperCase());
                                          repo.saveEntry(currentEntry.copyWith(loadingSheetTrips: sheetTrips));
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller: _driverController,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                      decoration: InputDecoration(
                                        labelText: 'DRIVER NAME',
                                        labelStyle: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                        filled: true,
                                        fillColor: Colors.black.withValues(alpha: 0.3),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      onChanged: (val) {
                                        final List<LoadingSheetTrip> sheetTrips = [...?currentEntry.loadingSheetTrips];
                                        final idx = sheetTrips.indexWhere((t) => !t.isManual);
                                        if (idx >= 0) {
                                          sheetTrips[idx] = sheetTrips[idx].copyWith(driverName: val);
                                          repo.saveEntry(currentEntry.copyWith(loadingSheetTrips: sheetTrips));
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Event Log Header
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

                      // Event Log Feed
                      EventLogView(
                        notes: currentEntry.notes,
                        attachments: currentEntry.attachments,
                        trips: trips,
                        audioService: _audioService,
                        onRemoveNote: (nid) {
                          final updated = currentEntry.notes.where((n) => n.id != nid).toList();
                          repo.saveEntry(currentEntry.copyWith(notes: updated));
                        },
                        onRemoveAttachment: (aid) {
                          final updated = currentEntry.attachments.where((a) => a.id != aid).toList();
                          repo.saveEntry(currentEntry.copyWith(attachments: updated));
                        },
                        onRemoveTrip: (tid) {
                          final updatedTrips = (currentEntry.trips ?? []).where((t) => t.id != tid).toList();
                          final sheetTrips = _syncTripsToLoadingSheet(currentEntry, updatedTrips);
                          repo.saveEntry(currentEntry.copyWith(
                            trips: updatedTrips,
                            loadingSheetTrips: sheetTrips,
                          ));
                        },
                        onOpenPhoto: (att) => PhotoLightbox.show(context, att),
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
                      repo.saveEntry(currentEntry.copyWith(
                        notes: [...currentEntry.notes, newNote],
                      ));
                    },
                    onAttachment: (att) {
                      repo.saveEntry(currentEntry.copyWith(
                        attachments: [...currentEntry.attachments, att],
                      ));
                    },
                    onStartVoice: () {
                      VoiceRecorderSheet.show(
                        context,
                        audioService: _audioService,
                        onSave: (att) {
                          repo.saveEntry(currentEntry.copyWith(
                            attachments: [...currentEntry.attachments, att],
                          ));
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
