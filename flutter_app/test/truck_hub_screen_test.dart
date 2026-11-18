import 'package:dispatch_diary/core/utils/scan_sounds.dart';
import 'package:dispatch_diary/data/models/entry.dart';
import 'package:dispatch_diary/data/models/ibt_manifest.dart';
import 'package:dispatch_diary/data/models/loading_sheet_trip.dart';
import 'package:dispatch_diary/data/models/staged_document.dart';
import 'package:dispatch_diary/data/repositories/entry_repository.dart';
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

/// The truck hub — P4b: staging rows, cash arm, manual count, legacy
/// import, remove document, block long-press, REG/driver/target edit.
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
    await StagedDocumentRepository(db).clearForEntry('other-entry');
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
  });

  /// Tall surface so lazy ListView sections actually build; pump + settle.
  Future<void> settle(WidgetTester tester) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await tester.pump();
  }

  Future<void> pumpHub(WidgetTester tester, {DocumentResolver? resolver}) async {
    // Tall surface: lazy ListView sections build AND the truck-details
    // sheet (with the simulated keyboard inset) fits fully on-screen.
    await tester.binding.setSurfaceSize(const Size(900, 3200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: TruckHubScreen(entryId: entryId, resolver: resolver ?? fakeResolver()),
    ));
    await settle(tester);
  }

  testWidgets('renders the stage card, cash toggle and truck REG',
      (tester) async {
    await tester.runAsync(() async {
      await pumpHub(tester);
      expect(find.text('STAGE DOCUMENTS'), findsOneWidget);
      expect(find.textContaining('CASH — tap to arm'), findsOneWidget);
      expect(find.textContaining('MN05XNGP'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('type + digits rows stage in parallel with customer chips',
      (tester) async {
    await tester.runAsync(() async {
      await pumpHub(tester);

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

      await pumpHub(tester);

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

      await pumpHub(tester);

      // Header shows document + customer; blocks stay hidden (default
      // closed — the accordion mentality).
      expect(find.text('DIBT0179154'), findsWidgets);
      expect(find.text('EPS COURIERS SERVICES'), findsOneWidget);
      expect(find.text('96962259'), findsNothing);
      await tester.tap(find.text('DIBT0179154').last);
      await settle(tester);
      expect(find.text('96962259'), findsOneWidget);
      expect(find.text('2608E105'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('cash toggle arms and disarms', (tester) async {
    await tester.runAsync(() async {
      await pumpHub(tester);
      await tester.tap(find.textContaining('CASH — tap to arm'));
      await settle(tester);
      expect(find.textContaining('CASH MODE ARMED'), findsOneWidget);
      await tester.tap(find.textContaining('CASH MODE ARMED'));
      await settle(tester);
      expect(find.textContaining('CASH — tap to arm'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('REG + driver + target editable from the header and persisted',
      (tester) async {
    await tester.runAsync(() async {
      await pumpHub(tester);
      expect(find.textContaining('MN05XNGP'), findsOneWidget);

      await tester.tap(find.text('NLH'));
      await settle(tester);
      expect(find.text('TRUCK DETAILS'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'MN05XNGP'),
        'HW72JS',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'TARGET (0 = none)'),
        '24',
      );
      // The simulated keyboard inflates the sheet's bottom inset beyond
      // any test surface — invoke SAVE directly (the intent is the tap).
      final saveButton = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('SAVE'),
          matching: find.byType(FilledButton),
        ),
      );
      saveButton.onPressed!();
      await settle(tester);

      expect(find.textContaining('HW72JS'), findsWidgets);
      expect(find.textContaining('/24 loaded'), findsOneWidget);
      // Persisted to the entry's sheet trip.
      final entry = await EntryRepository().getEntryById(entryId);
      final trip = entry!.loadingSheetTrips!.first;
      expect(trip.reg, 'HW72JS');
      expect(trip.targetQuantity, 24);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('manual slip entry exists and fails loud when offline',
      (tester) async {
    await tester.runAsync(() async {
      await pumpHub(tester);
      expect(find.textContaining('TYPE SLIP NUMBER'), findsOneWidget);
      // Widget tests mock all HTTP to 400 → the lookup fails → banner.
      await tester.enterText(
        find.byType(TextField).last,
        '96962259',
      );
      await tester.tap(find.widgetWithText(TextButton, 'SCAN'));
      await settle(tester);
      expect(find.text('Connection failed — try again'), findsOneWidget);
      // Audit #6 — error banners persist past the success-banner window.
      await Future<void>.delayed(const Duration(seconds: 5));
      await tester.pump();
      expect(find.text('Connection failed — try again'), findsOneWidget);
      // And a tap dismisses it.
      await tester.tap(find.text('Connection failed — try again'));
      await tester.pump();
      expect(find.text('Connection failed — try again'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('remove document: delete icon → confirm → section gone',
      (tester) async {
    await tester.runAsync(() async {
      final db = await DatabaseService.database;
      await StagedDocumentRepository(db).save(StagedDocument(
        id: '$entryId:dibt:DIBT0179154',
        entryId: entryId,
        stream: DocumentStream.dibt,
        documentNo: 'DIBT0179154',
        customerName: 'EPS COURIERS SERVICES',
        total: 2,
        slips: const [
          SlipTyre(uid: '1D0DF19A091080', slipNumber: 96962259),
        ],
        cachedAt: 1,
      ));

      await pumpHub(tester);

      // Delete now lives INSIDE the opened accordion (audit #7).
      await tester.tap(find.text('DIBT0179154').last);
      await settle(tester);
      await tester.tap(find.text('REMOVE DOCUMENT'));
      await settle(tester);
      expect(find.text('REMOVE DOCUMENT'), findsWidgets);
      await tester.tap(find.text('REMOVE').last);
      await settle(tester);

      // The section (and its delete action) is gone; the number may
      // remain only as a historical RECENT chip — that's by design.
      expect(find.text('REMOVE DOCUMENT'), findsNothing);
      expect(
        await StagedDocumentRepository(db).listForEntry(entryId),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('staged docs stay CLOSED — no auto-open', (tester) async {
    await tester.runAsync(() async {
      await pumpHub(tester);
      await tester.tap(find.text('DIBT').first);
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(0), '0179154');
      await tester.tap(find.text('STAGE ALL'));
      await settle(tester);

      // Section header exists, blocks stay hidden.
      expect(find.textContaining('DIBT0179154'), findsWidgets);
      expect(find.text('96962259'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('long-press an unscanned block offers LOAD', (tester) async {
    await tester.runAsync(() async {
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
          ),
        ],
        cachedAt: 1,
      ));

      await pumpHub(tester);

      await tester.tap(find.text('DIBT0179154').last);
      await settle(tester);
      await tester.longPress(find.text('96962259'));
      await settle(tester);
      // Operator resolution fails in widget tests (network mocked) — the
      // flow must reach the guard without crashing.
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('LEGACY: old trips import IBTs and show their tally',
      (tester) async {
    await tester.runAsync(() async {
      final now = DateTime.now().millisecondsSinceEpoch;
      // A pre-hub truck: 24/24 tallied, IBT manifest on the sheet trip.
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
            quantityLoaded: 24,
            targetQuantity: 24,
            ibtDocuments: [
              IbtDocument(
                documentNo: 'IBT122773',
                total: 151,
                lineItems: const [
                  IbtLineItem(
                    id: 'IBT122773_line_0',
                    description: '315/80R22.5 M90L STOCK RETREAD',
                    sizeId: 70,
                    rubberId: 36,
                    targetTotal: 83,
                    loadedQuantity: 24,
                  ),
                ],
              ),
            ],
            createdAt: now,
          ),
        ],
        createdAt: now,
        updatedAt: now,
        dayKey: '2026-11-17',
        monthKey: '2026-11',
        yearKey: '2026',
      ));

      await pumpHub(tester);

      // The old tally must not look empty, and the IBT must be staged.
      expect(find.textContaining('24/24 loaded'), findsOneWidget);
      expect(find.textContaining('IBT122773'), findsWidgets);
      // And the import persisted to the cache.
      final db = await DatabaseService.database;
      final docs = await StagedDocumentRepository(db).listForEntry(entryId);
      expect(docs.any((d) => d.documentNo == 'IBT122773'), isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('TRUCK TOTAL aggregates every staged document + what is left',
      (tester) async {
    await tester.runAsync(() async {
      await pumpHub(tester);

      // DIBT: 2 tyres, 1 loaded. IBT: 151 expected, none loaded.
      await tester.tap(find.text('DIBT').first);
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(0), '0179154');
      await tester.tap(find.text('ADD DOCUMENT'));
      await tester.pump();
      await tester.tap(find.text('IBT').last);
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(1), '122773');
      await tester.tap(find.text('STAGE ALL'));
      await settle(tester);

      // 1 loaded · 2 + 151 = 153 expected · 152 left.
      expect(find.text('1'), findsOneWidget);
      expect(find.text('/ 153 loaded'), findsOneWidget);
      expect(find.text('152 LEFT'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('REG guard: no REG → warning shown and Arm disabled (audit #4)',
      (tester) async {
    await tester.runAsync(() async {
      // Overwrite the trip with an empty REG.
      final entry = await EntryRepository().getEntryById(entryId);
      final trip = entry!.loadingSheetTrips!.first;
      await EntryRepository().saveEntry(entry.copyWith(loadingSheetTrips: [
        trip.copyWith(reg: ''),
      ]));

      await pumpHub(tester);

      expect(
        find.textContaining('No REG set — tap the header'),
        findsOneWidget,
      );
      final arm = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Arm'),
      );
      expect(arm.onPressed, isNull);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('MANUAL COUNT: +/− adjust the persisted tally',
      (tester) async {
    await tester.runAsync(() async {
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
            quantityLoaded: 24,
            targetQuantity: 24,
            createdAt: now,
          ),
        ],
        createdAt: now,
        updatedAt: now,
        dayKey: '2026-11-17',
        monthKey: '2026-11',
        yearKey: '2026',
      ));

      await pumpHub(tester);
      expect(find.textContaining('24/24 loaded'), findsOneWidget);

      // The + of the manual count card (the ADD DOCUMENT icon is earlier).
      await tester.tap(find.byIcon(Icons.add_rounded).last);
      await settle(tester);
      expect(find.textContaining('25/24 loaded'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.remove_rounded).first);
      await settle(tester);
      expect(find.textContaining('24/24 loaded'), findsOneWidget);

      final entry = await EntryRepository().getEntryById(entryId);
      expect(entry!.loadingSheetTrips!.first.quantityLoaded, 24);
      expect(tester.takeException(), isNull);
    });
  });
}
