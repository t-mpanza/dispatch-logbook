import 'dart:io';

import 'package:dispatch_diary/core/utils/scan_sounds.dart';
import 'package:dispatch_diary/data/models/entry.dart';
import 'package:dispatch_diary/data/models/loading_sheet_trip.dart';
import 'package:dispatch_diary/data/models/staged_document.dart';
import 'package:dispatch_diary/data/repositories/staged_document_repository.dart';
import 'package:dispatch_diary/data/services/database_service.dart';
import 'package:dispatch_diary/dispatch/domain/document_number.dart';
import 'package:dispatch_diary/dispatch/models/slip_tyre.dart';
import 'package:dispatch_diary/presentation/screens/truck_hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// VISUAL tests — golden snapshots of the truck hub's key states.
/// Regenerate with: flutter test --update-goldens test/hub_golden_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const entryId = 'hub-golden-entry';

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({'nfc_enabled': false});
    ScanSounds.enabled = false;
  });

  setUp(() async {
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
          id: 'golden-trip',
          entryId: entryId,
          reg: 'MN05XNGP',
          driverName: 'Neil',
          tripId: 'NLS',
          quantityLoaded: 3,
          targetQuantity: 12,
          createdAt: now,
        ),
      ],
      createdAt: now,
      updatedAt: now,
      dayKey: '2026-11-18',
      monthKey: '2026-11',
      yearKey: '2026',
    ));
  });

  Future<void> pumpHub(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 2800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(
      home: TruckHubScreen(entryId: entryId),
    ));
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await tester.pump();
  }

  /// Golden bitmaps are machine-dependent (font rasterization) — they run
  /// locally as the visual regression net and skip on CI, where the 319
  /// deterministic tests carry the gate.
  final bool onCi = Platform.environment['CI'] == 'true';

  testWidgets('golden: empty truck hub', (tester) async {
    await tester.runAsync(() async {
      await pumpHub(tester);
    });
    await tester.pump();
    await expectLater(
      find.byType(TruckHubScreen),
      matchesGoldenFile('goldens/hub_empty.png'),
    );
  }, skip: onCi);

  testWidgets('golden: hub with a staged DIBT section open', (tester) async {
    await tester.runAsync(() async {
      final db = await DatabaseService.database;
      await StagedDocumentRepository(db).save(StagedDocument(
        id: '$entryId:dibt:DIBT0179154',
        entryId: entryId,
        stream: DocumentStream.dibt,
        documentNo: 'DIBT0179154',
        customerName: 'EPS COURIERS SERVICES',
        total: 5,
        slips: const [
          SlipTyre(uid: '1D0DF19A091080', slipNumber: 96962259, serial: '2608E105', make: 'GOOD YEAR', pattern: 'M90L'),
          SlipTyre(uid: '1D6D0297021080', slipNumber: 98962056, serial: '2608F001', make: 'BISON', pattern: 'M38', loaded: 1),
          SlipTyre(uid: '1DBA0297021080', slipNumber: 98962067, serial: 'DUD - DAMAGE BELT', make: 'GOOD YEAR', pattern: 'MM1', rejectAccepted: 2),
        ],
        cachedAt: 1,
      ));

      await pumpHub(tester);
      await tester.tap(find.text('DIBT0179154').last);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await tester.pump();
    });
    await tester.pump();
    await expectLater(
      find.byType(TruckHubScreen),
      matchesGoldenFile('goldens/hub_staged_open.png'),
    );
  }, skip: onCi);
}
