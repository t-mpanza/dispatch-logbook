import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:dispatch_diary/core/utils/scan_sounds.dart';
import 'package:dispatch_diary/data/models/entry.dart';
import 'package:dispatch_diary/data/models/loading_sheet_trip.dart';
import 'package:dispatch_diary/data/models/trip.dart';
import 'package:dispatch_diary/data/repositories/entry_repository.dart';
import 'package:dispatch_diary/data/repositories/settings_repository.dart';
import 'package:dispatch_diary/data/services/database_service.dart';
import 'package:dispatch_diary/presentation/screens/scraps_screen.dart';

/// Crash-safety + scraps-specific behaviour tests for the dedicated
/// SCRAPS screen (real in-memory SQLite).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
    ScanSounds.enabled = false;
  });

  Future<Entry> seedScrapsEntry() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final entry = Entry(
      id: 'scraps-test-entry',
      title: 'SCRAPS',
      tags: const ['despatch', 'scraps'],
      notes: const [],
      attachments: const [],
      trips: const [],
      loadingSheetTrips: [
        LoadingSheetTrip(
          id: 'scraps-test-trip',
          entryId: 'scraps-test-entry',
          reg: 'KH58XD',
          driverName: 'RICHMORE',
          tripId: 'SCRAPS',
          quantityLoaded: 0,
          startTime: now,
          createdAt: now,
        ),
      ],
      createdAt: now,
      updatedAt: now,
      dayKey: '2026-10-29',
      monthKey: '2026-10',
      yearKey: '2026',
    );
    await DatabaseService.insertOrUpdateEntry(entry);
    return entry;
  }

  Widget wrap(EntryRepository repo, SettingsRepository settings) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: repo),
        ChangeNotifierProvider.value(value: settings),
      ],
      child: const MaterialApp(
        home: ScrapsScreen(entryId: 'scraps-test-entry'),
      ),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await tester.pump();
  }

  testWidgets('scraps screen renders dedicated UI with no target',
      (WidgetTester tester) async {
    await tester.runAsync(() async {
      await seedScrapsEntry();
      final repo = EntryRepository();
      final settings = SettingsRepository();

      await tester.pumpWidget(wrap(repo, settings));
      await settle(tester);

      expect(find.text('SCRAP RUN-OUT'), findsOneWidget);
      expect(find.text('SCAN SCRAP'), findsOneWidget);
      expect(find.text('NO TARGET — WHATEVER SCANS, COUNTS'), findsOneWidget);
      expect(find.text('KH58XD'), findsOneWidget);
      expect(find.text('RICHMORE'), findsOneWidget);
      // Never the generic target affordances.
      expect(find.text('TARGET TYRES'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('remove one adjusts the count via the sheet-synced entry',
      (WidgetTester tester) async {
    await tester.runAsync(() async {
      final seeded = await seedScrapsEntry();
      // Pre-populate two counted trips.
      final repo = EntryRepository();
      final entry = seeded.copyWith(
        trips: [
          Trip(id: 't1', count: 1, createdAt: 1),
          Trip(id: 't2', count: 1, createdAt: 2),
        ],
      );
      await DatabaseService.insertOrUpdateEntry(entry);
      final settings = SettingsRepository();

      await tester.pumpWidget(wrap(repo, settings));
      await settle(tester);

      expect(find.text('2'), findsOneWidget); // hero count

      await tester.tap(find.text('REMOVE ONE'));
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await tester.pump();

      expect(find.text('1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('kill switch blocks arming with the clear banner',
      (WidgetTester tester) async {
    await tester.runAsync(() async {
      await seedScrapsEntry();
      final repo = EntryRepository();
      final settings = SettingsRepository();
      await settings.setNfcEnabled(false);

      await tester.pumpWidget(wrap(repo, settings));
      await settle(tester);

      await tester.tap(find.text('Arm'));
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await tester.pump();

      expect(
        find.text('NFC scanning is turned off in Settings'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
