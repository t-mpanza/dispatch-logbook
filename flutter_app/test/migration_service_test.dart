import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dispatch_diary/data/models/entry.dart';
import 'package:dispatch_diary/data/models/ibt_manifest.dart';
import 'package:dispatch_diary/data/models/loading_sheet_trip.dart';
import 'package:dispatch_diary/data/services/database_service.dart';
import 'package:dispatch_diary/data/services/migration_service.dart';
import 'package:dispatch_diary/data/services/supabase_service.dart';

Entry _entry({
  required String id,
  required String title,
  required String dayKey,
  int updatedAt = 1000,
  List<LoadingSheetTrip> loadingSheetTrips = const [],
  int? deletedAt,
}) {
  return Entry(
    id: id,
    title: title,
    tags: const ['despatch'],
    notes: const [],
    attachments: const [],
    trips: const [],
    loadingSheetTrips: loadingSheetTrips,
    createdAt: updatedAt,
    updatedAt: updatedAt,
    dayKey: dayKey,
    monthKey: dayKey.substring(0, 7),
    yearKey: dayKey.substring(0, 4),
    deletedAt: deletedAt,
  );
}

LoadingSheetTrip _trip({
  required String id,
  required String tripId,
  int quantityLoaded = 0,
  bool isManual = false,
  List<IbtDocument>? ibtDocuments,
}) {
  return LoadingSheetTrip(
    id: id,
    tripId: tripId,
    reg: '',
    driverName: '',
    quantityLoaded: quantityLoaded,
    isManual: isManual,
    createdAt: 1000,
    ibtDocuments: ibtDocuments,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = Directory.systemTemp.createTempSync('dd_migration_test');
    databaseFactory.setDatabasesPath(dir.path);
  });

  setUp(() async {
    final db = await DatabaseService.database;
    await db.delete('entries');
    await db.delete('settings');
  });

  group('MigrationService', () {
    test('splits squashed multi-trip entries into one entry per truck', () async {
      final squashed = _entry(
        id: 'squashed',
        title: 'STOCKS 1',
        dayKey: '2026-09-02',
        loadingSheetTrips: [
          _trip(id: 't1', tripId: 'STOCKS 1', quantityLoaded: 40),
          _trip(id: 't2', tripId: 'STOCKS 2', quantityLoaded: 25),
          _trip(id: 't3', tripId: 'BLOEM', quantityLoaded: 12),
        ],
      );
      await DatabaseService.insertOrUpdateEntry(squashed);

      await MigrationService.runIfNeeded();

      final entries = await DatabaseService.getAllEntries();
      expect(entries.length, 3);

      for (final e in entries) {
        expect(e.loadingSheetTrips!.length, 1);
        expect(e.dayKey, '2026-09-02');
      }

      final tripIds = entries
          .map((e) => e.loadingSheetTrips!.first.tripId)
          .toSet();
      expect(tripIds, containsAll(['STOCKS 1', 'STOCKS 2', 'BLOEM']));

      // New entries back-reference their own id.
      for (final e in entries.where((e) => e.id != 'squashed')) {
        expect(e.loadingSheetTrips!.first.entryId, e.id);
      }
    });

    test('dedupe is scoped per day: same tripId on different days survives', () async {
      await DatabaseService.insertOrUpdateEntry(
        _entry(
          id: 'day1_old',
          title: 'STOCKS 1',
          dayKey: '2026-09-01',
          updatedAt: 1000,
          loadingSheetTrips: [_trip(id: 'a', tripId: 'STOCKS 1', quantityLoaded: 10)],
        ),
      );
      await DatabaseService.insertOrUpdateEntry(
        _entry(
          id: 'day2',
          title: 'STOCKS 1',
          dayKey: '2026-09-02',
          updatedAt: 2000,
          loadingSheetTrips: [_trip(id: 'b', tripId: 'STOCKS 1', quantityLoaded: 20)],
        ),
      );
      await DatabaseService.insertOrUpdateEntry(
        _entry(
          id: 'day1_new',
          title: 'STOCKS 1',
          dayKey: '2026-09-01',
          updatedAt: 3000,
          loadingSheetTrips: [
            _trip(
              id: 'c',
              tripId: 'STOCKS 1',
              quantityLoaded: 30,
              ibtDocuments: const [
                IbtDocument(documentNo: 'IBT-1', total: 30, lineItems: []),
              ],
            ),
          ],
        ),
      );

      await MigrationService.runIfNeeded();

      final live = await DatabaseService.getAllEntries();
      // day1_old merged into day1_new (same day), day2 untouched.
      expect(live.length, 2);
      final ids = live.map((e) => e.id).toSet();
      expect(ids, contains('day1_new'));
      expect(ids, contains('day2'));

      final tombstones = await DatabaseService.getAllTombstonedEntries();
      expect(tombstones.map((e) => e.id), contains('day1_old'));

      // Winner kept the richer trip (IBT docs) and merged nothing away.
      final winner = live.firstWhere((e) => e.id == 'day1_new');
      expect(winner.loadingSheetTrips!.first.ibtDocuments, isNotNull);
    });

    test('never touches tombstoned entries (no resurrection)', () async {
      final squashed = _entry(
        id: 'deleted_squash',
        title: 'STOCKS 1',
        dayKey: '2026-09-02',
        deletedAt: 500,
        loadingSheetTrips: [
          _trip(id: 't1', tripId: 'STOCKS 1'),
          _trip(id: 't2', tripId: 'STOCKS 2'),
        ],
      );
      await DatabaseService.insertOrUpdateEntry(squashed);

      await MigrationService.runIfNeeded();

      final live = await DatabaseService.getAllEntries();
      expect(live, isEmpty);
      final tombstones = await DatabaseService.getAllTombstonedEntries();
      expect(tombstones.length, 1);
      expect(tombstones.first.id, 'deleted_squash');
    });

    test('manual trips with the same tripId are never merged', () async {
      await DatabaseService.insertOrUpdateEntry(
        _entry(
          id: 'm1',
          title: 'Cash Sale',
          dayKey: '2026-09-02',
          updatedAt: 1000,
          loadingSheetTrips: [
            _trip(id: 'ma', tripId: 'CASH SALE', quantityLoaded: 4, isManual: true),
          ],
        ),
      );
      await DatabaseService.insertOrUpdateEntry(
        _entry(
          id: 'm2',
          title: 'Cash Sale',
          dayKey: '2026-09-02',
          updatedAt: 2000,
          loadingSheetTrips: [
            _trip(id: 'mb', tripId: 'CASH SALE', quantityLoaded: 6, isManual: true),
          ],
        ),
      );

      await MigrationService.runIfNeeded();

      final live = await DatabaseService.getAllEntries();
      expect(live.length, 2);
      final tombstones = await DatabaseService.getAllTombstonedEntries();
      expect(tombstones, isEmpty);
    });

    test('runs only once (flag persisted)', () async {
      await MigrationService.runIfNeeded();
      expect(await DatabaseService.getSetting('migration_ungroup_dedupe_v1'), '1');
    });
  });

  group('SupabaseService.formatEntryPayload tombstone invariant', () {
    test('live payload omits deleted_at so stale pushes cannot clear tombstones', () {
      final entry = _entry(
        id: 'live',
        title: 'STOCKS 1',
        dayKey: '2026-09-02',
      );
      final payload = SupabaseService.formatEntryPayload(entry, 'user-1');
      expect(payload.containsKey('deleted_at'), isFalse);
    });

    test('tombstone payload always carries deleted_at', () {
      final entry = _entry(
        id: 'gone',
        title: 'STOCKS 1',
        dayKey: '2026-09-02',
        deletedAt: 123456,
      );
      final payload = SupabaseService.formatEntryPayload(entry, 'user-1');
      expect(payload['deleted_at'], 123456);
    });
  });
}
