import 'package:flutter/foundation.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/id_generator.dart';
import '../../data/models/entry.dart';
import '../../data/models/ibt_manifest.dart';
import '../../data/models/loading_sheet_trip.dart';
import '../../data/repositories/entry_repository.dart';

class LoadingSheetViewModel extends ChangeNotifier {
  final EntryRepository _repository;

  String _selectedDate = AppFormatters.dayKey(DateTime.now());
  String get selectedDate => _selectedDate;

  LoadingSheetViewModel(this._repository) {
    _repository.addListener(_onRepositoryChanged);
  }

  void _onRepositoryChanged() {
    notifyListeners();
  }

  void setSelectedDate(String dateStr) {
    _selectedDate = dateStr;
    notifyListeners();
  }

  void shiftDate(int days) {
    try {
      final current = DateTime.parse(_selectedDate);
      final shifted = current.add(Duration(days: days));
      _selectedDate = AppFormatters.dayKey(shifted);
      notifyListeners();
    } catch (_) {}
  }

  Future<List<Entry>> getDayEntries() async {
    return await _repository.getEntriesByDay(_selectedDate);
  }

  Future<List<LoadingSheetTrip>> getTripsForSelectedDate() async {
    final dayEntries = await getDayEntries();

    final List<LoadingSheetTrip> result = [];
    for (final e in dayEntries) {
      if (e.loadingSheetTrips != null && e.loadingSheetTrips!.isNotEmpty) {
        // Sync entry.expectedTotal → targetQuantity for all entry-linked non-manual trips.
        // The entry is the single source of truth for the target; the sheet just reflects it.
        final trips = e.loadingSheetTrips!.map((t) {
          if (!t.isManual &&
              !t.hasIbtDocuments &&
              e.expectedTotal != null &&
              e.expectedTotal! > 0 &&
              t.targetQuantity != e.expectedTotal) {
            return t.copyWith(targetQuantity: e.expectedTotal);
          }
          return t;
        }).toList();
        result.addAll(trips);
      } else if (e.trips != null && e.trips!.isNotEmpty) {
        // Synthesize loading sheet trip from counter trips, carrying expectedTotal as target.
        final totalQty = e.trips!.fold<int>(0, (s, t) => s + t.count + (t.rejected ?? 0));
        final sorted = [...e.trips!]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        final start = sorted.first.createdAt;
        final finish = sorted.last.createdAt;
        final dur = ((finish - start) / (1000 * 60)).round();

        result.add(LoadingSheetTrip(
          id: e.id,
          entryId: e.id,
          reg: '',
          driverName: '',
          tripId: e.title.isNotEmpty ? e.title : 'Truck Load',
          quantityLoaded: totalQty,
          targetQuantity: e.expectedTotal, // ← entry target → sheet target
          startTime: start,
          finishTime: finish,
          durationMinutes: dur > 0 ? dur : 1,
          createdAt: start,
        ));
      }
    }

    result.sort((a, b) => (a.startTime ?? 0).compareTo(b.startTime ?? 0));
    return result;
  }

  Future<void> addTruckLoad(LoadingSheetTrip trip) async {
    final dayEntries = await getDayEntries();
    final primaryEntry = dayEntries.isNotEmpty ? dayEntries.first : null;

    if (primaryEntry != null) {
      final existingTrips = primaryEntry.loadingSheetTrips ?? [];
      final updated = primaryEntry.copyWith(
        loadingSheetTrips: [...existingTrips, trip],
      );
      await _repository.saveEntry(updated);
    } else {
      // Create new daily container entry
      final now = DateTime.now().millisecondsSinceEpoch;
      final newEntry = Entry(
        id: IdGenerator.generate(),
        title: trip.tripId.isNotEmpty ? trip.tripId : 'Truck Load',
        tags: ['truck-load', trip.presetKey?.name.toLowerCase() ?? 'custom'],
        notes: [],
        attachments: [],
        loadingSheetTrips: [trip],
        createdAt: trip.startTime ?? now,
        updatedAt: now,
        dayKey: _selectedDate,
        monthKey: _selectedDate.substring(0, 7),
        yearKey: _selectedDate.substring(0, 4),
      );
      await _repository.saveEntry(newEntry);
    }
  }

  Future<void> updateTruckLoad(LoadingSheetTrip updatedTrip) async {
    final dayEntries = await getDayEntries();
    for (final e in dayEntries) {
      if (e.loadingSheetTrips != null) {
        final idx = e.loadingSheetTrips!.indexWhere((t) => t.id == updatedTrip.id);
        if (idx >= 0) {
          final list = [...e.loadingSheetTrips!];
          list[idx] = updatedTrip;
          await _repository.saveEntry(e.copyWith(loadingSheetTrips: list));
          return;
        }
      }
    }
  }

  /// Update quantity loaded on a specific IBT line item and sync overall trip quantity
  Future<void> updateIbtLineQuantity({
    required LoadingSheetTrip trip,
    required String documentNo,
    required String lineItemId,
    required int newQuantity,
  }) async {
    if (trip.ibtDocuments == null || trip.ibtDocuments!.isEmpty) return;

    final updatedDocs = <IbtDocument>[];
    int totalLoadedAcrossAllIbts = 0;

    for (final doc in trip.ibtDocuments!) {
      if (doc.documentNo.toUpperCase() == documentNo.toUpperCase()) {
        final updatedLines = <IbtLineItem>[];
        for (final line in doc.lineItems) {
          if (line.id == lineItemId) {
            final clamped = newQuantity < 0 ? 0 : newQuantity;
            updatedLines.add(line.copyWith(loadedQuantity: clamped));
          } else {
            updatedLines.add(line);
          }
        }
        final updatedDoc = doc.copyWith(lineItems: updatedLines);
        updatedDocs.add(updatedDoc);
        totalLoadedAcrossAllIbts += updatedDoc.loadedTotal;
      } else {
        updatedDocs.add(doc);
        totalLoadedAcrossAllIbts += doc.loadedTotal;
      }
    }

    final updatedTrip = trip.copyWith(
      ibtDocuments: updatedDocs,
      quantityLoaded: totalLoadedAcrossAllIbts,
    );

    await updateTruckLoad(updatedTrip);
  }

  /// Attach or replace an IBT document on a trip
  Future<void> attachIbtDocument({
    required LoadingSheetTrip trip,
    required IbtDocument ibtDoc,
  }) async {
    final currentDocs = <IbtDocument>[...(trip.ibtDocuments ?? [])];
    final existingIdx = currentDocs.indexWhere(
      (d) => d.documentNo.toUpperCase() == ibtDoc.documentNo.toUpperCase(),
    );

    if (existingIdx >= 0) {
      currentDocs[existingIdx] = ibtDoc;
    } else {
      currentDocs.add(ibtDoc);
    }

    final int totalTarget = currentDocs.fold<int>(0, (int sum, IbtDocument d) => sum + d.total);
    final int totalLoaded = currentDocs.fold<int>(0, (int sum, IbtDocument d) => sum + d.loadedTotal);

    final updatedTrip = trip.copyWith(
      ibtDocuments: currentDocs,
      targetQuantity: totalTarget > 0 ? totalTarget : trip.targetQuantity,
      quantityLoaded: totalLoaded > 0 ? totalLoaded : trip.quantityLoaded,
    );

    await updateTruckLoad(updatedTrip);
  }

  /// Remove an IBT document from a trip
  Future<void> removeIbtDocument({
    required LoadingSheetTrip trip,
    required String documentNo,
  }) async {
    if (trip.ibtDocuments == null) return;
    final filtered = trip.ibtDocuments!
        .where((d) => d.documentNo.toUpperCase() != documentNo.toUpperCase())
        .toList();

    final LoadingSheetTrip updatedTrip;
    if (filtered.isNotEmpty) {
      final int totalTarget =
          filtered.fold<int>(0, (int sum, IbtDocument d) => sum + d.total);
      final int totalLoaded =
          filtered.fold<int>(0, (int sum, IbtDocument d) => sum + d.loadedTotal);
      updatedTrip = trip.copyWith(
        ibtDocuments: filtered,
        targetQuantity: totalTarget > 0 ? totalTarget : null,
        clearTargetQuantity: totalTarget <= 0,
        quantityLoaded: totalLoaded,
      );
    } else {
      updatedTrip = trip.copyWith(
        clearIbtDocuments: true,
        clearTargetQuantity: true,
        targetQuantity: null,
        quantityLoaded: 0,
      );
    }

    await updateTruckLoad(updatedTrip);
  }

  Future<void> deleteTruckLoad(String tripId) async {
    final dayEntries = await getDayEntries();
    for (final e in dayEntries) {
      if (e.loadingSheetTrips != null) {
        final filtered = e.loadingSheetTrips!.where((t) => t.id != tripId).toList();
        if (filtered.length != e.loadingSheetTrips!.length) {
          await _repository.saveEntry(e.copyWith(loadingSheetTrips: filtered));
          return;
        }
      }
    }
  }

  @override
  void dispose() {
    _repository.removeListener(_onRepositoryChanged);
    super.dispose();
  }
}
