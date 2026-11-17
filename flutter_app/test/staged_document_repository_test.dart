import 'package:dispatch_diary/data/models/staged_document.dart';
import 'package:dispatch_diary/data/repositories/staged_document_repository.dart';
import 'package:dispatch_diary/data/services/database_service.dart';
import 'package:dispatch_diary/dispatch/domain/document_number.dart';
import 'package:dispatch_diary/dispatch/models/slip_tyre.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The staged-document cache — SQLite v7, keyed by entry (truck).
/// Runs against the real migration path (DatabaseService) on FFI.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
  });

  final entryId = 'p2-repo-${DateTime.now().millisecondsSinceEpoch}';

  StagedDocument make({String docNo = 'DIBT0179154'}) => StagedDocument(
        id: '$entryId:dibt:$docNo',
        entryId: entryId,
        stream: DocumentStream.dibt,
        documentNo: docNo,
        customerName: 'EPS',
        total: 2,
        slips: [
          SlipTyre(uid: 'AABBCCDDEEFF01', slipNumber: 111, loaded: 1),
        ],
        cachedAt: 1,
      );

  tearDown(() async {
    final repo = StagedDocumentRepository(await DatabaseService.database);
    await repo.clearForEntry(entryId);
  });

  test('v7 migration created staged_documents', () async {
    final db = await DatabaseService.database;
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='staged_documents'",
    );
    expect(rows, isNotEmpty);
  });

  test('save + listForEntry round-trips slips', () async {
    final repo = StagedDocumentRepository(await DatabaseService.database);
    await repo.save(make());
    final docs = await repo.listForEntry(entryId);
    expect(docs.length, 1);
    expect(docs.single.documentNo, 'DIBT0179154');
    expect(docs.single.customerName, 'EPS');
    expect(docs.single.slips.single.slipNumber, 111);
    expect(docs.single.slips.single.isLoaded, isTrue);
  });

  test('same document number twice on one truck is refused (D8)', () async {
    final repo = StagedDocumentRepository(await DatabaseService.database);
    await repo.save(make());
    expect(() => repo.save(make()), throwsA(isA<DuplicateDocumentException>()));
  });

  test('upsert refreshes an existing document', () async {
    final repo = StagedDocumentRepository(await DatabaseService.database);
    await repo.save(make());
    await repo.upsert(
      StagedDocument(
        id: '$entryId:dibt:DIBT0179154',
        entryId: entryId,
        stream: DocumentStream.dibt,
        documentNo: 'DIBT0179154',
        customerName: 'EPS REFRESHED',
        total: 2,
        slips: const [],
        cachedAt: 2,
      ),
    );
    final docs = await repo.listForEntry(entryId);
    expect(docs.single.customerName, 'EPS REFRESHED');
  });

  test('remove deletes one; clearForEntry empties the truck', () async {
    final repo = StagedDocumentRepository(await DatabaseService.database);
    await repo.save(make());
    await repo.save(make(docNo: 'DIBT0177452'));
    await repo.remove(entryId, 'DIBT0179154');
    expect((await repo.listForEntry(entryId)).length, 1);
    await repo.clearForEntry(entryId);
    expect(await repo.listForEntry(entryId), isEmpty);
  });

  test('recentDocumentNos returns distinct numbers, newest first', () async {
    final repo = StagedDocumentRepository(await DatabaseService.database);
    await repo.save(make());
    await repo.save(StagedDocument(
      id: '$entryId:dibt:DIBT0177452',
      entryId: entryId,
      stream: DocumentStream.dibt,
      documentNo: 'DIBT0177452',
      total: 32,
      cachedAt: 99, // older
    ));
    final recents = await repo.recentDocumentNos(limit: 100);
    expect(recents, containsAll(['DIBT0179154', 'DIBT0177452']));
    // cachedAt 99 (DIBT0177452) is newer than 1 — newest first.
    expect(
      recents.indexOf('DIBT0177452'),
      lessThan(recents.indexOf('DIBT0179154')),
    );
  });
}
