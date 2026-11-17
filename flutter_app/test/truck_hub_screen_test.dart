import 'package:dispatch_diary/core/utils/scan_sounds.dart';
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
          if (documentNo.startsWith('DIBT9')) {
            return FetchedDocument(
              customerName: 'RECENT CUSTOMER',
              total: 1,
              slips: const [
                SlipTyre(uid: '1D000000000001', slipNumber: 90000001),
              ],
            );
          }
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
    SharedPreferences.setMockInitialValues({'nfc_enabled': false});
    // No audio plugin in widget tests — scan verdicts stay silent.
    ScanSounds.enabled = false;
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

  testWidgets('type + digits rows stage in parallel with customer chips',
      (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(
        home: TruckHubScreen(entryId: entryId, resolver: fakeResolver()),
      ));
      await settle(tester);

      // Row 1: DIBT + digits.
      await tester.tap(find.text('DIBT').first);
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(0), '0179154');

      // Row 2 (CC/BCC extension): IBT + digits.
      await tester.tap(find.text('ADD DOCUMENT'));
      await tester.pump();
      await tester.tap(find.text('IBT').last);
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(1), '122773');

      await tester.tap(find.text('STAGE ALL'));
      await settle(tester);

      expect(find.textContaining('DIBT0179154'), findsWidgets);
      expect(find.textContaining('IBT122773'), findsWidgets);
      // The chip carries the CUSTOMER — the staging-time error catcher.
      expect(find.textContaining('EPS COURIERS'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('RECENT chips appear and stage with one tap', (tester) async {
    await tester.runAsync(() async {
      // Seed a past document on another truck — it must show as a recent.
      final now = DateTime.now().millisecondsSinceEpoch;
      final recentNo = 'DIBT9${now % 1000000000000}';
      final db = await DatabaseService.database;
      await StagedDocumentRepository(db).save(StagedDocument(
        id: 'other-entry:$recentNo',
        entryId: 'other-entry',
        stream: DocumentStream.dibt,
        documentNo: recentNo,
        customerName: 'RECENT CUSTOMER',
        total: 1,
        cachedAt: now,
      ));

      await tester.pumpWidget(MaterialApp(
        home: TruckHubScreen(entryId: entryId, resolver: fakeResolver()),
      ));
      await settle(tester);

      expect(find.text(recentNo), findsOneWidget);
      await tester.tap(find.text(recentNo));
      await settle(tester);

      expect(find.textContaining('RECENT CUSTOMER'), findsWidgets);
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
      // closed — the accordion mentality). The number may also appear as
      // a RECENT chip from other tests; the header is the last match.
      expect(find.text('DIBT0179154'), findsWidgets);
      expect(find.text('EPS COURIERS SERVICES'), findsOneWidget);
      expect(find.text('96962259'), findsNothing);
      await tester.ensureVisible(find.text('DIBT0179154').last);
      await tester.pump();
      await tester.tap(find.text('DIBT0179154').last);
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

  testWidgets('manual slip entry exists and fails loud when offline',
      (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(
        home: TruckHubScreen(entryId: entryId, resolver: fakeResolver()),
      ));
      await settle(tester);
      expect(find.textContaining('TYPE SLIP NUMBER'), findsOneWidget);
      // Widget tests mock all HTTP to 400 → the lookup fails → banner.
      await tester.enterText(
        find.byType(TextField).last,
        '96962259',
      );
      await tester.tap(find.widgetWithText(TextButton, 'SCAN'));
      await settle(tester);
      expect(find.text('Connection failed — try again'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
