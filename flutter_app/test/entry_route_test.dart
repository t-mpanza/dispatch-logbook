import 'package:dispatch_diary/data/models/entry.dart';
import 'package:dispatch_diary/data/models/staged_document.dart';
import 'package:dispatch_diary/data/repositories/entry_repository.dart';
import 'package:dispatch_diary/data/repositories/staged_document_repository.dart';
import 'package:dispatch_diary/data/services/database_service.dart';
import 'package:dispatch_diary/dispatch/domain/document_number.dart';
import 'package:dispatch_diary/presentation/entry_route.dart';
import 'package:dispatch_diary/presentation/screens/entry_detail_screen.dart';
import 'package:dispatch_diary/presentation/screens/truck_hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// P4c — routing: entries with staged documents open the TRUCK HUB;
/// everything else keeps the legacy screen. One decision, no flicker.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final runId = DateTime.now().millisecondsSinceEpoch;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({'nfc_enabled': false});
  });

  Future<Entry> seedEntry(String id, String title) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final entry = Entry(
      id: id,
      title: title,
      tags: const [],
      notes: const [],
      attachments: const [],
      createdAt: now,
      updatedAt: now,
      dayKey: '2026-11-17',
      monthKey: '2026-11',
      yearKey: '2026',
    );
    await DatabaseService.insertOrUpdateEntry(entry);
    return entry;
  }

  Widget launcher(Entry entry) => ChangeNotifierProvider<EntryRepository>(
        create: (_) => EntryRepository(),
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => openEntryDetail(context, entry),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

  Future<void> pushAndPump(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await tester.pump();
  }

  testWidgets('entry with staged documents opens the truck hub',
      (tester) async {
    await tester.runAsync(() async {
      final entry = await seedEntry('hub-route-$runId', 'TRUCK 1');
      final db = await DatabaseService.database;
      await StagedDocumentRepository(db).save(StagedDocument(
        id: 'hub-route-$runId:dibt:DIBT0179154',
        entryId: entry.id,
        stream: DocumentStream.dibt,
        documentNo: 'DIBT0179154',
        customerName: 'EPS',
        total: 5,
        cachedAt: 1,
      ));

      await tester.pumpWidget(launcher(entry));
      await pushAndPump(tester);

      expect(find.byType(TruckHubScreen), findsOneWidget);
      expect(find.byType(EntryDetailScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('entry without staged documents keeps the legacy screen',
      (tester) async {
    await tester.runAsync(() async {
      final entry = await seedEntry('legacy-route-$runId', 'TRIP 1');

      await tester.pumpWidget(launcher(entry));
      await pushAndPump(tester);

      expect(find.byType(EntryDetailScreen), findsOneWidget);
      expect(find.byType(TruckHubScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
