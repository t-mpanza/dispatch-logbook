import 'package:flutter/foundation.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/id_generator.dart';
import '../../data/models/entry.dart';
import '../../data/repositories/entry_repository.dart';

class EntriesViewModel extends ChangeNotifier {
  final EntryRepository _repository;

  EntriesViewModel(this._repository) {
    _repository.addListener(_onRepositoryChanged);
  }

  void _onRepositoryChanged() {
    notifyListeners();
  }

  Future<List<Entry>> getEntriesForDay(String dayKey) async {
    return await _repository.getEntriesByDay(dayKey);
  }

  Future<List<Entry>> getTodayEntries() async {
    final todayKey = AppFormatters.dayKey(DateTime.now());
    return await _repository.getEntriesByDay(todayKey);
  }

  Future<List<Entry>> getCounterSessions() async {
    final all = await _repository.getAllEntries();
    return all.where((e) {
      final hasTrips = e.trips != null && e.trips!.isNotEmpty;
      final hasLoadingTrips =
          e.loadingSheetTrips != null && e.loadingSheetTrips!.isNotEmpty;
      return hasTrips || hasLoadingTrips;
    }).toList();
  }

  Future<Entry> createEntry({
    required String title,
    List<String> tags = const [],
    bool withCounter = false,
  }) async {
    final now = DateTime.now();
    final epoch = now.millisecondsSinceEpoch;
    final dKey = AppFormatters.dayKey(now);
    final mKey = AppFormatters.monthKey(now);
    final yKey = AppFormatters.yearKey(now);

    final entry = Entry(
      id: IdGenerator.generate(),
      title: title,
      tags: tags,
      notes: [],
      attachments: [],
      trips: withCounter ? [] : null,
      loadingSheetTrips: withCounter ? [] : null,
      createdAt: epoch,
      updatedAt: epoch,
      dayKey: dKey,
      monthKey: mKey,
      yearKey: yKey,
    );

    await _repository.saveEntry(entry);
    return entry;
  }

  Future<void> updateEntry(Entry entry) async {
    await _repository.saveEntry(entry);
  }

  Future<void> deleteEntry(String id) async {
    await _repository.deleteEntry(id);
  }

  Future<List<Entry>> search(String q) async {
    return await _repository.search(q);
  }

  Future<List<String>> getAllTags() async {
    return await _repository.getAllTags();
  }

  @override
  void dispose() {
    _repository.removeListener(_onRepositoryChanged);
    super.dispose();
  }
}
