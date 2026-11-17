import 'dart:async';

import 'package:dispatch_diary/data/models/ibt_manifest.dart';
import 'package:dispatch_diary/data/repositories/staged_document_repository.dart';
import 'package:dispatch_diary/data/services/document_resolver.dart';
import 'package:dispatch_diary/dispatch/domain/document_number.dart';
import 'package:dispatch_diary/dispatch/models/slip_tyre.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The parallel multi-document resolver — TDD pins:
///  - prefix classification (DIBT0179154 overrides the fallback chip)
///  - PARALLEL fetches (never sequential)
///  - per-document error isolation (one failure never kills the batch)
///  - duplicate refusal (D8) at the cache layer
///  - SCRAPS is a mode, not a document
void main() {
  late StagedDocumentRepository repo;
  final fetchLog = <(DocumentStream, String)>[];

  Future<FetchedDocument> fakeFetcher(
    DocumentStream stream,
    String documentNo,
  ) async {
    fetchLog.add((stream, documentNo));
    switch (documentNo) {
      case 'DIBT0179154':
        return FetchedDocument(
          customerName: 'EPS',
          total: 5,
          slips: [SlipTyre(uid: '1D0DF19A091080', slipNumber: 96962259)],
        );
      case 'INV2392908':
        return FetchedDocument(
          customerName: 'EPS COURIERS',
          total: 14,
          slips: [SlipTyre(uid: '1DCD7A9B091080', slipNumber: 96975621)],
        );
      case 'IBT122773':
        return FetchedDocument(
          total: 151,
          lineItems: [
            IbtLineItem(
              id: 'IBT122773_line_0',
              description: '315/80R22.5 M90L STOCK RETREAD',
              sizeId: 70,
              rubberId: 36,
              targetTotal: 83,
            ),
          ],
        );
      case 'DIBT0000000':
        throw Exception('Document number not found');
      default:
        throw Exception('Connection failed: boom');
    }
  }

  setUp(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    fetchLog.clear();
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (d, _) => d.execute('''
          CREATE TABLE staged_documents (
            id TEXT PRIMARY KEY,
            entry_id TEXT NOT NULL,
            stream TEXT NOT NULL,
            document_no TEXT NOT NULL,
            customer_name TEXT,
            total INTEGER,
            manifest_json TEXT NOT NULL,
            cached_at INTEGER NOT NULL,
            UNIQUE(entry_id, stream, document_no)
          )
        '''),
      ),
    );
    repo = StagedDocumentRepository(db);
  });

  test('classifies by prefix and resolves a mixed batch in parallel', () async {
    final resolver = DocumentResolver(fetcher: fakeFetcher, repository: repo);
    final results = await resolver.resolveBatch(
      entryId: 'e1',
      input: 'INV2392908, DIBT0179154, IBT122773',
    );
    expect(results.length, 3);
    expect(results.every((r) => r.isOk), isTrue);
    expect(fetchLog, containsAll([
      (DocumentStream.inv, 'INV2392908'),
      (DocumentStream.dibt, 'DIBT0179154'),
      (DocumentStream.ibt, 'IBT122773'),
    ]));
    final docs = await repo.listForEntry('e1');
    expect(docs.length, 3);
    expect(docs.firstWhere((d) => d.stream == DocumentStream.ibt).lineItems,
        isNotEmpty);
  });

  test('fetches run CONCURRENTLY, not sequentially', () async {
    final barrier = Completer<void>();
    var started = 0;
    Future<FetchedDocument> gated(DocumentStream s, String n) async {
      started++;
      await barrier.future;
      return FetchedDocument(customerName: n, total: 1, slips: const []);
    }
    final resolver = DocumentResolver(fetcher: gated, repository: repo);
    final pending = resolver.resolveBatch(
      entryId: 'e2',
      input: 'INV1111111, DIBT2222222',
    );
    // Give the batch a beat to start both futures.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(started, 2, reason: 'both fetches must start before either finishes');
    barrier.complete();
    final results = await pending;
    expect(results.every((r) => r.isOk), isTrue);
  });

  test('one not-found document does not kill the batch', () async {
    final resolver = DocumentResolver(fetcher: fakeFetcher, repository: repo);
    final results = await resolver.resolveBatch(
      entryId: 'e3',
      input: 'DIBT0179154, DIBT0000000',
    );
    expect(results[0].isOk, isTrue);
    expect(results[1].status, DocumentResolveStatus.notFound);
    expect((await repo.listForEntry('e3')).length, 1);
  });

  test('duplicate document number is refused (D8)', () async {
    final resolver = DocumentResolver(fetcher: fakeFetcher, repository: repo);
    await resolver.resolveBatch(entryId: 'e4', input: 'DIBT0179154');
    final again = await resolver.resolveBatch(entryId: 'e4', input: 'DIBT0179154');
    expect(again.single.status, DocumentResolveStatus.duplicate);
  });

  test('SCRAPS input is unsupported — a mode, not a document', () async {
    final resolver = DocumentResolver(fetcher: fakeFetcher, repository: repo);
    final results = await resolver.resolveBatch(
      entryId: 'e5',
      input: 'SCRAPS',
    );
    expect(results.single.status, DocumentResolveStatus.unsupported);
  });

  test('empty input yields nothing', () async {
    final resolver = DocumentResolver(fetcher: fakeFetcher, repository: repo);
    expect(await resolver.resolveBatch(entryId: 'e6', input: '  , \n '), isEmpty);
  });

  test('network failure maps to error, not notFound', () async {
    final resolver = DocumentResolver(fetcher: fakeFetcher, repository: repo);
    final results = await resolver.resolveBatch(entryId: 'e7', input: 'INV9999999');
    expect(results.single.status, DocumentResolveStatus.error);
  });
}
