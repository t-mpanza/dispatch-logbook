import 'package:dispatch_diary/data/models/entry.dart';
import 'package:dispatch_diary/data/models/loading_sheet_trip.dart';
import 'package:dispatch_diary/data/models/staged_document.dart';
import 'package:dispatch_diary/data/repositories/staged_document_repository.dart';
import 'package:dispatch_diary/data/services/database_service.dart';
import 'package:dispatch_diary/data/services/document_resolver.dart';
import 'package:dispatch_diary/dispatch/domain/document_number.dart';
import 'package:dispatch_diary/dispatch/models/slip_tyre.dart';
import 'package:dispatch_diary/presentation/screens/truck_hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The truck hub — P4b: parallel staging, customer on the document
/// accordion, closed-by-default sections, tyre blocks inside, cash arm.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const entryId = 'hub-test-entry';

  DocumentResolver fakeResolver() => DocumentResolver(
        fetcher: (stream, documentNo) async {
          switch (documentNo) {
            case 'DIBT0179154':
              return FetchedDocument(
                customerName: 'EPS COURIERS SERVICES',
                total: 2,
                slips: const [
                  SlipTyre(
                    uid: '1D0DF19A091080',
                    slipNumber: 96962259,
                    serial: '2608E105',
                    make: 'GOOD YEAR',
                    pattern: 'M90L',
                  ),
                  SlipTyre(
                    uid: '1D6D0297021080',
                    slipNumber: 98962056,
                    serial: '2608F001',
                    make: 'BISON',
                    pattern: 'M38',
                    loaded: 1,
                  ),
                ],
              );
            case 'IBT122773':
              return const FetchedDocument(total: 151, lineItems: []);
            default:
              throw Exception('Document number not found');
          }
        },
      );

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() async {
    // Deterministic on CI: staged docs from a previous run/test must not
    // leak into this one (the fake resolver writes to the real DB).
    final db = await DatabaseService.database;
    await StagedDocumentRepository(db).clearForEntry(entryId);
    final now = DateTime.now().millisecondsSinceEpoch;
    await DatabaseService.insertOrUpdateEntry(Entry(
      id: entryId,
      title: 'TRUCK 1',
      tags: const [],
      notes: const [],
      attachments: const [],
      loadingSheetTrips: [
        LoadingSheetTrip(
          id: 'hub-trip',
          entryId: entryId,
          reg: 'MN05XNGP',
          driverName: 'Neil',
          tripId: 'NLH',
          quantityLoaded: 0,
          createdAt: now,
        ),
      ],
      createdAt: now,
      updatedAt: now,
      dayKey: '2026-11-17',
      monthKey: '2026-11',
      yearKey: '2026',
    ));
    // NFC off — widget tests have no NFC plugin.
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('nfc_enabled', false);
  });

  Future<void> settle(WidgetTester tester) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await tester.pump();
  }

  testWidgets('renders the stage card, cash toggle and truck REG',
      (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(
        home: TruckHubScreen(entryId: entryId, resolver: fakeResolver()),
      ));
      await settle(tester);
      expect(find.text('STAGE DOCUMENTS'), findsOneWidget);
      expect(find.textContaining('CASH — tap to arm'), findsOneWidget);
      expect(find.textContaining('MN05XNGP'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('staging pastes documents in parallel with chips',
      (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(
        home: TruckHubScreen(entryId: entryId, resolver: fakeResolver()),
      ));
      await settle(tester);
      await tester.enterText(
        find.byType(TextField).first,
        'DIBT0179154, IBT122773',
      );
      await tester.tap(find.text('STAGE'));
      await settle(tester);

      expect(find.text('DIBT0179154'), findsWidgets);
      expect(find.text('IBT122773'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('cached docs open CLOSED; customer on the header; blocks inside',
      (tester) async {
    await tester.runAsync(() async {
      // Pre-seed the cache — this is the reopen path.
      final db = await DatabaseService.database;
      await StagedDocumentRepository(db).save(StagedDocument(
        id: '$entryId:dibt:DIBT0179154',
        entryId: entryId,
        stream: DocumentStream.dibt,
        documentNo: 'DIBT0179154',
        customerName: 'EPS COURIERS SERVICES',
        total: 2,
        slips: const [
          SlipTyre(
            uid: '1D0DF19A091080',
            slipNumber: 96962259,
            serial: '2608E105',
            make: 'GOOD YEAR',
            pattern: 'M90L',
          ),
        ],
        cachedAt: 1,
      ));

      await tester.pumpWidget(MaterialApp(
        home: TruckHubScreen(entryId: entryId, resolver: fakeResolver()),
      ));
      await settle(tester);

      // Header shows document + customer; blocks stay hidden (default
      // closed — the accordion mentality).
      expect(find.text('DIBT0179154'), findsOneWidget);
      expect(find.text('EPS COURIERS SERVICES'), findsOneWidget);
      expect(find.text('96962259'), findsNothing);
      await tester.tap(find.text('DIBT0179154'));
      await settle(tester);
      expect(find.text('96962259'), findsOneWidget);
      expect(find.text('2608E105'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('cash toggle arms and disarms', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(
        home: TruckHubScreen(entryId: entryId, resolver: fakeResolver()),
      ));
      await settle(tester);
      await tester.tap(find.textContaining('CASH — tap to arm'));
      await settle(tester);
      expect(find.textContaining('CASH MODE ARMED'), findsOneWidget);
      await tester.tap(find.textContaining('CASH MODE ARMED'));
      await settle(tester);
      expect(find.textContaining('CASH — tap to arm'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
