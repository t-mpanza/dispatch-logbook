import 'package:flutter/foundation.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/id_generator.dart';
import '../../data/models/entry.dart';
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
        result.addAll(e.loadingSheetTrips!);
      } else if (e.trips != null && e.trips!.isNotEmpty) {
        // Synthesize loading sheet trip from counter trips
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
          tripId: e.title,
          quantityLoaded: totalQty,
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
