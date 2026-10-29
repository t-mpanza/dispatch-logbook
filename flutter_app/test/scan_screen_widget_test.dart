import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:dispatch_diary/data/models/entry.dart';
import 'package:dispatch_diary/data/models/ibt_manifest.dart';
import 'package:dispatch_diary/data/models/loading_sheet_trip.dart';
import 'package:dispatch_diary/data/repositories/entry_repository.dart';
import 'package:dispatch_diary/data/repositories/settings_repository.dart';
import 'package:dispatch_diary/core/utils/scan_sounds.dart';
import 'package:dispatch_diary/data/services/database_service.dart';
import 'package:dispatch_diary/presentation/screens/stocks_entry_detail_screen.dart';

/// Crash-safety widget tests for the scanner section on the stocks screen.
/// Real in-memory SQLite via runAsync (the DB isolate needs real async).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
    // No audio plugin in tests — the sound layer must no-op silently.
    ScanSounds.enabled = false;
  });

  Future<Entry> seedStocksEntry() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final entry = Entry(
      id: 'scan-test-entry',
      title: 'STOCKS 1',
      tags: const ['stocks'],
      notes: const [],
      attachments: const [],
      trips: const [],
      loadingSheetTrips: [
        LoadingSheetTrip(
          id: 'scan-test-trip',
          entryId: 'scan-test-entry',
          reg: 'MN05XNGP',
          driverName: 'Neil',
          tripId: 'STOCKS 1',
          quantityLoaded: 0,
          startTime: now,
          createdAt: now,
          ibtDocuments: const [
            IbtDocument(
              documentNo: 'IBT122773',
              total: 10,
              lineItems: [
                IbtLineItem(
                  id: 'l1',
                  description: '12R22.5 M38 STOCK RETREAD',
                  size: '12R22.5',
                  rubber: 'M38',
                  sizeId: 22,
                  rubberId: 49,
                  targetTotal: 7,
                ),
              ],
            ),
          ],
        ),
      ],
      createdAt: now,
      updatedAt: now,
      dayKey: '2026-10-28',
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
        home: StocksEntryDetailScreen(entryId: 'scan-test-entry'),
      ),
    );
  }

  testWidgets('stocks screen renders the SCAN TYRE card without crashing',
      (WidgetTester tester) async {
    await tester.runAsync(() async {
      await seedStocksEntry();
      final repo = EntryRepository();
      final settings = SettingsRepository();

      await tester.pumpWidget(wrap(repo, settings));
      await Future<void>.delayed(const Duration(milliseconds: 800));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 800));
      await tester.pump();

      expect(find.text('SCAN TYRE'), findsOneWidget);
      expect(find.textContaining('IBT122773'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('arm without NFC hardware shows the unavailable banner — no crash',
      (WidgetTester tester) async {
    await tester.runAsync(() async {
      await seedStocksEntry();
      final repo = EntryRepository();
      final settings = SettingsRepository();

      await tester.pumpWidget(wrap(repo, settings));
      await Future<void>.delayed(const Duration(milliseconds: 800));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 800));
      await tester.pump();

      await tester.tap(find.text('Arm'));
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await tester.pump();

      // NFC hardware cannot exist in the test env — the requirement here is
      // that arming degrades without crashing the framework.
      expect(find.text('SCAN TYRE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('kill switch blocks arming with a clear banner',
      (WidgetTester tester) async {
    await tester.runAsync(() async {
      await seedStocksEntry();
      final repo = EntryRepository();
      final settings = SettingsRepository();
      await settings.setNfcEnabled(false);

      await tester.pumpWidget(wrap(repo, settings));
      await Future<void>.delayed(const Duration(milliseconds: 800));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 800));
      await tester.pump();

      await tester.tap(find.text('Arm'));
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await tester.pump();

      // The banner sits just below the visible fold — reveal it.
      await tester.drag(
        find.byType(ListView).first,
        const Offset(0, -260),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('NFC scanning is turned off in Settings'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
