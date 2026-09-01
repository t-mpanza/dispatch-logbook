import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:dispatch_diary/data/models/entry.dart';
import 'package:dispatch_diary/data/models/ibt_manifest.dart';
import 'package:dispatch_diary/data/models/loading_sheet_trip.dart';
import 'package:dispatch_diary/data/models/preset.dart';
import 'package:dispatch_diary/data/repositories/entry_repository.dart';
import 'package:dispatch_diary/presentation/viewmodels/loading_sheet_viewmodel.dart';
import 'package:dispatch_diary/data/services/appsync_manifest_service.dart';
import 'package:dispatch_diary/data/services/whatsapp_export_service.dart';
import 'package:dispatch_diary/data/services/pdf_export_service.dart';

class MockEntryRepository extends EntryRepository {
  final Map<String, Entry> _storage = {};

  @override
  Future<List<Entry>> getEntriesByDay(String dayKey) async {
    return _storage.values.where((e) => e.dayKey == dayKey).toList();
  }

  @override
  Future<void> saveEntry(Entry entry, {bool triggerPush = true}) async {
    _storage[entry.id] = entry;
    notifyListeners();
  }

  @override
  Future<void> deleteEntry(String id) async {
    _storage.remove(id);
    notifyListeners();
  }
}

void main() {
  group('Adversarial Stress Test: IbtLineItem & IbtDocument Models', () {
    test('Zero and Negative values in IbtLineItem getters', () {
      const zeroItem = IbtLineItem(
        id: 'zero',
        description: 'Zero Item',
        targetTotal: 0,
        loadedQuantity: 0,
      );
      expect(zeroItem.remaining, 0);
      expect(zeroItem.overCount, 0);
      expect(zeroItem.isComplete, isFalse);
      expect(zeroItem.isShort, isFalse);
      expect(zeroItem.isOverloaded, isFalse);
      expect(zeroItem.progressPercent, 0.0);

      const negativeLoaded = IbtLineItem(
        id: 'neg_loaded',
        description: 'Negative Loaded',
        targetTotal: 10,
        loadedQuantity: -5,
      );
      expect(negativeLoaded.remaining, 10);
      expect(negativeLoaded.overCount, 0);
      expect(negativeLoaded.isComplete, isFalse);
      expect(negativeLoaded.isShort, isTrue);
      expect(negativeLoaded.isOverloaded, isFalse);
      expect(negativeLoaded.progressPercent, 0.0);

      const overloadedItem = IbtLineItem(
        id: 'overloaded',
        description: 'Overloaded',
        targetTotal: 15,
        loadedQuantity: 25,
      );
      expect(overloadedItem.remaining, 0);
      expect(overloadedItem.overCount, 10);
      expect(overloadedItem.isComplete, isTrue);
      expect(overloadedItem.isShort, isFalse);
      expect(overloadedItem.isOverloaded, isTrue);
      expect(overloadedItem.progressPercent, 1.0);
    });

    test('Fuzzing IbtLineItem fromMap with unexpected / dynamic types', () {
      final item = IbtLineItem.fromMap({
        'id': 12345,
        'description': null,
        'rcsCode': 999,
        'sizeId': 22,
        'rubberId': null,
        'size': '315/80R22.5',
        'rubber': 'RD2+',
        'targetTotal': 25.5,
        'loadedQuantity': 12,
      });

      expect(item.id, '12345');
      expect(item.description, '');
      expect(item.rcsCode, '999');
      expect(item.sizeId, 22);
      expect(item.targetTotal, 25);
      expect(item.loadedQuantity, 12);
      expect(item.remaining, 13);
    });

    test('IbtDocument multi-item calculations & edge cases', () {
      final doc = IbtDocument(
        documentNo: 'IBT-STRESS-1',
        total: 50,
        lineItems: [
          const IbtLineItem(
            id: 'l1',
            description: 'Item 1',
            targetTotal: 20,
            loadedQuantity: 25, // Overloaded (+5)
          ),
          const IbtLineItem(
            id: 'l2',
            description: 'Item 2',
            targetTotal: 20,
            loadedQuantity: 10, // Short (10)
          ),
          const IbtLineItem(
            id: 'l3',
            description: 'Item 3',
            targetTotal: 10,
            loadedQuantity: 10, // Complete (0)
          ),
        ],
      );

      expect(doc.loadedTotal, 45);
      expect(doc.remainingTotal, 5);
      expect(doc.isComplete, isFalse);
      expect(doc.hasShortages, isTrue);

      final serialized = doc.toMap();
      final roundtrip = IbtDocument.fromMap(serialized);
      expect(roundtrip.documentNo, 'IBT-STRESS-1');
      expect(roundtrip.total, 50);
      expect(roundtrip.lineItems.length, 3);
      expect(roundtrip.loadedTotal, 45);
    });

    test('Empty IbtDocument calculations', () {
      const emptyDoc = IbtDocument(
        documentNo: 'IBT-EMPTY',
        total: 0,
        lineItems: [],
      );

      expect(emptyDoc.loadedTotal, 0);
      expect(emptyDoc.remainingTotal, 0);
      expect(emptyDoc.isComplete, isFalse);
      expect(emptyDoc.hasShortages, isFalse);
    });
  });

  group('Adversarial Stress Test: LoadingSheetTrip Target Logic', () {
    test('effectiveTarget precedence: explicit targetQuantity vs ibtTargetTotal vs fallback', () {
      // 1. Explicit targetQuantity override takes precedence
      final tripWithExplicit = LoadingSheetTrip(
        id: 't1',
        reg: 'CA1234',
        driverName: 'John',
        tripId: 'TRIP-1',
        quantityLoaded: 15,
        targetQuantity: 30,
        createdAt: 1000,
        ibtDocuments: [
          const IbtDocument(
            documentNo: 'IBT-1',
            total: 20,
            lineItems: [],
          ),
        ],
      );
      expect(tripWithExplicit.remainingTyres, 15);
      expect(tripWithExplicit.overCount, 0);
      expect(tripWithExplicit.progressPercent, 0.5);
      expect(tripWithExplicit.isTargetReached, isFalse);

      // 2. targetQuantity is null, derives from IBT documents
      final tripWithIbt = tripWithExplicit.copyWith(
        clearTargetQuantity: true,
      );
      expect(tripWithIbt.targetQuantity, isNull);
      expect(tripWithIbt.ibtTargetTotal, 20);
      expect(tripWithIbt.remainingTyres, 5);
      expect(tripWithIbt.progressPercent, 0.75);

      // 3. Clear both IBT and targetQuantity
      final emptyTrip = tripWithIbt.copyWith(
        clearIbtDocuments: true,
      );
      expect(emptyTrip.hasIbtDocuments, isFalse);
      expect(emptyTrip.remainingTyres, 0);
      expect(emptyTrip.overCount, 0);
      expect(emptyTrip.progressPercent, isNull);
      expect(emptyTrip.isTargetReached, isFalse);
    });

    test('Multi-IBT aggregation with overloaded and short items', () {
      final trip = LoadingSheetTrip(
        id: 't2',
        reg: 'ND999',
        driverName: 'Sipho',
        tripId: 'TRIP-2',
        quantityLoaded: 42,
        createdAt: 2000,
        ibtDocuments: [
          const IbtDocument(
            documentNo: 'IBT-A',
            total: 20,
            lineItems: [
              IbtLineItem(id: 'a1', description: 'A1', targetTotal: 20, loadedQuantity: 22),
            ],
          ),
          const IbtDocument(
            documentNo: 'IBT-B',
            total: 20,
            lineItems: [
              IbtLineItem(id: 'b1', description: 'B1', targetTotal: 20, loadedQuantity: 20),
            ],
          ),
        ],
      );

      expect(trip.ibtTargetTotal, 40);
      expect(trip.ibtLoadedTotal, 42);
      expect(trip.isTargetReached, isTrue);
      expect(trip.isTargetExceeded, isTrue);
      expect(trip.overCount, 2);
      expect(trip.remainingTyres, 0);
      expect(trip.progressPercent, 1.0);
    });
  });

  group('Adversarial Stress Test: LoadingSheetViewModel Synchronization', () {
    late MockEntryRepository repository;
    late LoadingSheetViewModel viewModel;

    setUp(() {
      repository = MockEntryRepository();
      viewModel = LoadingSheetViewModel(repository);
    });

    test('ViewModel full lifecycle: add, attach IBT, step quantities, remove, and delete', () async {
      // 1. Add initial truck load
      final initialTrip = LoadingSheetTrip(
        id: 'trip_100',
        reg: 'GP999',
        driverName: 'David',
        tripId: 'STOCKS 1',
        presetKey: PresetKey.STOCKS,
        quantityLoaded: 0,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      await viewModel.addTruckLoad(initialTrip);

      var trips = await viewModel.getTripsForSelectedDate();
      expect(trips.length, 1);
      expect(trips.first.id, 'trip_100');
      expect(trips.first.hasIbtDocuments, isFalse);

      // 2. Attach first IBT document (Total: 30)
      const doc1 = IbtDocument(
        documentNo: 'IBT-7701',
        total: 30,
        lineItems: [
          IbtLineItem(id: 'line_1', description: 'Tyre 1', targetTotal: 20, loadedQuantity: 0),
          IbtLineItem(id: 'line_2', description: 'Tyre 2', targetTotal: 10, loadedQuantity: 0),
        ],
      );

      await viewModel.attachIbtDocument(trip: trips.first, ibtDoc: doc1);

      trips = await viewModel.getTripsForSelectedDate();
      expect(trips.first.hasIbtDocuments, isTrue);
      expect(trips.first.targetQuantity, 30);
      expect(trips.first.quantityLoaded, 0);

      // 3. Step line_1 up to 15
      await viewModel.updateIbtLineQuantity(
        trip: trips.first,
        documentNo: 'IBT-7701',
        lineItemId: 'line_1',
        newQuantity: 15,
      );

      trips = await viewModel.getTripsForSelectedDate();
      expect(trips.first.quantityLoaded, 15);
      expect(trips.first.ibtDocuments!.first.lineItems.first.loadedQuantity, 15);

      // 4. Attach second IBT document (Total: 20) -> Multi-IBT
      const doc2 = IbtDocument(
        documentNo: 'IBT-7702',
        total: 20,
        lineItems: [
          IbtLineItem(id: 'line_3', description: 'Tyre 3', targetTotal: 20, loadedQuantity: 0),
        ],
      );

      await viewModel.attachIbtDocument(trip: trips.first, ibtDoc: doc2);

      trips = await viewModel.getTripsForSelectedDate();
      expect(trips.first.ibtDocuments!.length, 2);
      expect(trips.first.targetQuantity, 50); // 30 + 20
      expect(trips.first.quantityLoaded, 15); // 15 + 0

      // 5. Step line_3 up to 22 (Overloaded by 2)
      await viewModel.updateIbtLineQuantity(
        trip: trips.first,
        documentNo: 'IBT-7702',
        lineItemId: 'line_3',
        newQuantity: 22,
      );

      trips = await viewModel.getTripsForSelectedDate();
      expect(trips.first.quantityLoaded, 37); // 15 + 22

      // 6. Step line_1 down to 0
      await viewModel.updateIbtLineQuantity(
        trip: trips.first,
        documentNo: 'IBT-7701',
        lineItemId: 'line_1',
        newQuantity: 0,
      );

      trips = await viewModel.getTripsForSelectedDate();
      expect(trips.first.quantityLoaded, 22); // 0 + 22

      // 7. Remove doc2 (IBT-7702) -> Target & quantityLoaded should revert to doc1 stats
      await viewModel.removeIbtDocument(trip: trips.first, documentNo: 'IBT-7702');

      trips = await viewModel.getTripsForSelectedDate();
      expect(trips.first.ibtDocuments!.length, 1);
      expect(trips.first.targetQuantity, 30);
      expect(trips.first.quantityLoaded, 0); // line_1 was 0, line_2 was 0

      // 8. Remove remaining doc1 (IBT-7701) -> Trip should have clearIbtDocuments
      await viewModel.removeIbtDocument(trip: trips.first, documentNo: 'IBT-7701');

      trips = await viewModel.getTripsForSelectedDate();
      expect(trips.first.hasIbtDocuments, isFalse);
      expect(trips.first.ibtDocuments, isNull);
      expect(trips.first.targetQuantity, isNull);
      expect(trips.first.quantityLoaded, 0);

      // 9. Delete truck load
      await viewModel.deleteTruckLoad('trip_100');

      trips = await viewModel.getTripsForSelectedDate();
      expect(trips.isEmpty, isTrue);
    });

    test('ViewModel non-existent document/line operations do not crash', () async {
      final trip = LoadingSheetTrip(
        id: 't_safe',
        reg: 'GP01',
        driverName: 'Sam',
        tripId: 'NLS',
        quantityLoaded: 10,
        createdAt: 1000,
        ibtDocuments: [
          const IbtDocument(
            documentNo: 'IBT-EXISTING',
            total: 10,
            lineItems: [
              IbtLineItem(id: 'l_ex', description: 'Item', targetTotal: 10, loadedQuantity: 10),
            ],
          ),
        ],
      );

      await viewModel.addTruckLoad(trip);
      var trips = await viewModel.getTripsForSelectedDate();

      // Attempt updating non-existent doc
      await viewModel.updateIbtLineQuantity(
        trip: trips.first,
        documentNo: 'IBT-NON-EXISTENT',
        lineItemId: 'l_ex',
        newQuantity: 5,
      );

      // Attempt updating non-existent line item in existing doc
      await viewModel.updateIbtLineQuantity(
        trip: trips.first,
        documentNo: 'IBT-EXISTING',
        lineItemId: 'l_non_existent',
        newQuantity: 5,
      );

      // Attempt removing non-existent doc
      await viewModel.removeIbtDocument(
        trip: trips.first,
        documentNo: 'IBT-DOES-NOT-EXIST',
      );

      trips = await viewModel.getTripsForSelectedDate();
      expect(trips.first.quantityLoaded, 10);
      expect(trips.first.ibtDocuments!.first.lineItems.first.loadedQuantity, 10);
    });

    test('ViewModel shiftDate and setSelectedDate updates state', () {
      viewModel.setSelectedDate('2026-09-01');
      expect(viewModel.selectedDate, '2026-09-01');

      viewModel.shiftDate(1);
      expect(viewModel.selectedDate, '2026-09-02');

      viewModel.shiftDate(-2);
      expect(viewModel.selectedDate, '2026-08-31');
    });
  });

  group('Adversarial Stress Test: AppSync Manifest Service Parsing & Helpers', () {
    test('parseIbtLines maps sizes and rubber compounds from masters or regex', () {
      final rawLines = [
        {
          'description': '315/80R22.5 RD2+ RETREAD',
          'rcs_code': 'RCS-101',
          'size_id': 22,
          'rubber_id': 12,
          'total': 20,
        },
        {
          'description': '295/80R22.5 SP571 DRIVE',
          'rcs_code': null,
          'size_id': 30,
          'rubber_id': 31,
          'total': 15,
        },
        {
          'description': '385/65R22.5 Multiway Trailer',
          'rcs_code': 'RCS-303',
          'size_id': null, // fallback to regex extraction
          'rubber_id': null, // fallback to regex extraction
          'total': 8,
        },
      ];

      final doc = AppSyncManifestService.parseIbtLines('IBT7890', rawLines);
      expect(doc.documentNo, 'IBT7890');
      expect(doc.total, 43);
      expect(doc.lineItems.length, 3);

      expect(doc.lineItems[0].size, '315/80R22.5');
      expect(doc.lineItems[0].rubber, 'RD2+');
      expect(doc.lineItems[0].targetTotal, 20);

      expect(doc.lineItems[1].size, '295/80R22.5');
      expect(doc.lineItems[1].rubber, 'SP571');

      expect(doc.lineItems[2].size, '385/65R22.5');
      expect(doc.lineItems[2].rubber, 'MULTIWAY');
    });

    test('extractSize and extractRubber fuzzing', () {
      expect(AppSyncManifestService.extractSize('11R22.5 M90L'), '11R22.5');
      expect(AppSyncManifestService.extractSize('275/70R22.5 MM84'), '275/70R22.5');
      expect(AppSyncManifestService.extractSize('No tyre size here'), isNull);

      expect(AppSyncManifestService.extractRubber('M90L TREAD'), 'M90L');
      expect(AppSyncManifestService.extractRubber('K-Max S STEER'), 'K-MAX');
      expect(AppSyncManifestService.extractRubber('Unknown pattern'), isNull);
    });

    test('Hosted UI URL generation contains expected parameters', () {
      final tokenUrl = AppSyncManifestService.getHostedUiAuthorizeUrl(tokenFlow: true);
      expect(tokenUrl, contains('response_type=token'));
      expect(tokenUrl, contains('client_id=78ikblrgsr8h27197iovkgrro6'));
      expect(tokenUrl, contains('redirect_uri=myapp%3A%2F%2F'));

      final codeUrl = AppSyncManifestService.getHostedUiAuthorizeUrl(tokenFlow: false);
      expect(codeUrl, contains('response_type=code'));
    });
  });

  group('Adversarial Stress Test: WhatsApp & PDF Export Engines', () {
    test('WhatsApp export handles empty, complex multi-IBT, and overloaded trips', () {
      final emptyEntry = Entry(
        id: 'e_empty',
        title: 'Empty Day',
        tags: [],
        notes: [],
        attachments: [],
        loadingSheetTrips: [],
        createdAt: 1000,
        updatedAt: 1000,
        dayKey: '2026-09-01',
        monthKey: '2026-09',
        yearKey: '2026',
      );

      final emptyText = WhatsAppExportService.formatWhatsAppText(emptyEntry, 'Despatcher Joe');
      expect(emptyText, contains('*DESPATCH LOADING SHEET*'));
      expect(emptyText, contains('👤 Despatcher: Despatcher Joe'));
      expect(emptyText, contains('🚚 Total Trucks: 0'));
      expect(emptyText, contains('📦 Total Tyres: 0'));

      final richEntry = Entry(
        id: 'e_rich',
        title: 'Rich Day',
        tags: [],
        notes: [],
        attachments: [],
        loadingSheetTrips: [
          LoadingSheetTrip(
            id: 't_rich1',
            reg: 'CA999',
            driverName: 'Neil',
            tripId: 'NLH',
            presetKey: PresetKey.NLH,
            startTime: DateTime(2026, 9, 1, 8, 0).millisecondsSinceEpoch,
            finishTime: DateTime(2026, 9, 1, 9, 30).millisecondsSinceEpoch,
            durationMinutes: 90,
            quantityLoaded: 35,
            createdAt: 1000,
            ibtDocuments: [
              const IbtDocument(
                documentNo: 'IBT-100',
                total: 30,
                lineItems: [
                  IbtLineItem(
                    id: 'l1',
                    description: '315/80R22.5 RD2+',
                    targetTotal: 20,
                    loadedQuantity: 25, // Overloaded (+5)
                  ),
                  IbtLineItem(
                    id: 'l2',
                    description: '11R22.5 M90L',
                    targetTotal: 10,
                    loadedQuantity: 10, // Complete (✓)
                  ),
                ],
              ),
            ],
            note: 'All straps secured tightly',
          ),
          LoadingSheetTrip(
            id: 't_rich2',
            reg: 'ZN123',
            driverName: 'Sipho',
            tripId: 'DBN',
            presetKey: PresetKey.DBN,
            startTime: DateTime(2026, 9, 1, 10, 0).millisecondsSinceEpoch,
            finishTime: DateTime(2026, 9, 1, 10, 45).millisecondsSinceEpoch,
            durationMinutes: 45,
            quantityLoaded: 15,
            createdAt: 2000,
            ibtDocuments: [
              const IbtDocument(
                documentNo: 'IBT-200',
                total: 20,
                lineItems: [
                  IbtLineItem(
                    id: 'l3',
                    description: '295/80R22.5 MM84',
                    targetTotal: 20,
                    loadedQuantity: 15, // Short (⚠️ Short 5)
                  ),
                ],
              ),
            ],
          ),
        ],
        createdAt: 1000,
        updatedAt: 1000,
        dayKey: '2026-09-01',
        monthKey: '2026-09',
        yearKey: '2026',
      );

      final richText = WhatsAppExportService.formatWhatsAppText(richEntry, 'Neil Despatch');
      expect(richText, contains('1. *NLH* | CA999'));
      expect(richText, contains('Driver: Neil'));
      expect(richText, contains('Tyres: 35'));
      expect(richText, contains('08:00 → 09:30 (90m)'));
      expect(richText, contains('📄 *IBT-100* (35/30 tyres)'));
      expect(richText, contains('▪ 25/20x 315/80R22.5 RD2+ [+5 Over]'));
      expect(richText, contains('▪ 10/10x 11R22.5 M90L [✓]'));
      expect(richText, contains('Note: All straps secured tightly'));

      expect(richText, contains('2. *DBN* | ZN123'));
      expect(richText, contains('📄 *IBT-200* (15/20 tyres)'));
      expect(richText, contains('▪ 15/20x 295/80R22.5 MM84 [⚠️ Short 5]'));

      expect(richText, contains('🚚 Total Trucks: 2'));
      expect(richText, contains('📦 Total Tyres: 50'));
      expect(richText, contains('⏱ Total Time: 2h 15m (135m)'));
    });

    test('PDF generation stress test: generates valid non-empty document with multi-page trips', () async {
      final List<LoadingSheetTrip> stressTrips = List.generate(25, (index) {
        return LoadingSheetTrip(
          id: 'stress_trip_$index',
          reg: 'STRESS-$index',
          driverName: 'Driver $index',
          tripId: 'TRIP-${index + 1}',
          startTime: DateTime(2026, 9, 1, 6 + (index % 10), 0).millisecondsSinceEpoch,
          finishTime: DateTime(2026, 9, 1, 6 + (index % 10), 45).millisecondsSinceEpoch,
          durationMinutes: 45,
          quantityLoaded: 20 + (index % 5),
          createdAt: 1000 + index * 100,
          ibtDocuments: index % 2 == 0
              ? [
                  IbtDocument(
                    documentNo: 'IBT-$index',
                    total: 20,
                    lineItems: [
                      IbtLineItem(
                        id: 'line_$index',
                        description: '315/80R22.5 Type $index',
                        targetTotal: 20,
                        loadedQuantity: index % 3 == 0 ? 25 : (index % 3 == 1 ? 18 : 20),
                      ),
                    ],
                  ),
                ]
              : null,
        );
      });

      final stressEntry = Entry(
        id: 'stress_entry',
        title: 'Stress Day',
        tags: [],
        notes: [],
        attachments: [],
        loadingSheetTrips: stressTrips,
        createdAt: 1000,
        updatedAt: 1000,
        dayKey: '2026-09-01',
        monthKey: '2026-09',
        yearKey: '2026',
      );

      final pdfBytes = await PdfExportService.generateLoadingSheetPdf(
        stressEntry,
        'Senior Despatch Controller',
      );

      expect(pdfBytes, isA<Uint8List>());
      expect(pdfBytes.isNotEmpty, isTrue);
      expect(pdfBytes.length, greaterThan(1000));
      // PDF files start with %PDF header
      final header = utf8.decode(pdfBytes.sublist(0, 4));
      expect(header, '%PDF');
    });
  });
}
