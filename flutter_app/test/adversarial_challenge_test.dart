import 'package:flutter_test/flutter_test.dart';
import 'package:dispatch_diary/data/models/ibt_manifest.dart';
import 'package:dispatch_diary/data/models/loading_sheet_trip.dart';
import 'package:dispatch_diary/data/models/entry.dart';
import 'package:dispatch_diary/data/repositories/entry_repository.dart';
import 'package:dispatch_diary/presentation/viewmodels/loading_sheet_viewmodel.dart';
import 'package:dispatch_diary/data/services/whatsapp_export_service.dart';
import 'package:dispatch_diary/data/services/pdf_export_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockInMemoryEntryRepository extends EntryRepository {
  final Map<String, Entry> _entries = {};

  @override
  Future<List<Entry>> getEntriesByDay(String dayKey) async {
    return _entries.values.where((e) => e.dayKey == dayKey).toList();
  }

  @override
  Future<void> saveEntry(Entry entry, {bool triggerPush = true}) async {
    _entries[entry.id] = entry;
    notifyListeners();
  }

  @override
  Future<void> deleteEntry(String id) async {
    _entries.remove(id);
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Adversarial Challenge 1: Document Removal (Single and Multi-Document Scenarios)', () {
    late MockInMemoryEntryRepository repo;
    late LoadingSheetViewModel vm;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      repo = MockInMemoryEntryRepository();
      vm = LoadingSheetViewModel(repo);
    });

    test('Single document removal resets target, loaded quantity, and nullifies ibtDocuments', () async {
      final trip = LoadingSheetTrip(
        id: 'trip_single_doc',
        reg: 'CA123456',
        driverName: 'Test Driver',
        tripId: 'DBN',
        quantityLoaded: 0,
        createdAt: 100000,
      );
      await vm.addTruckLoad(trip);

      const doc = IbtDocument(
        documentNo: 'IBT-SINGLE',
        total: 25,
        lineItems: [
          IbtLineItem(
            id: 'l1',
            description: 'Item 1',
            targetTotal: 25,
            loadedQuantity: 15,
          ),
        ],
      );

      await vm.attachIbtDocument(trip: trip, ibtDoc: doc);
      var current = (await vm.getTripsForSelectedDate()).first;
      expect(current.hasIbtDocuments, isTrue);
      expect(current.targetQuantity, 25);
      expect(current.quantityLoaded, 15);
      expect(current.remainingTyres, 10);

      // Remove with lowercase documentNo to test case-insensitivity
      await vm.removeIbtDocument(trip: current, documentNo: 'ibt-single');
      current = (await vm.getTripsForSelectedDate()).first;

      expect(current.hasIbtDocuments, isFalse);
      expect(current.ibtDocuments, isNull);
      expect(current.targetQuantity, isNull);
      expect(current.quantityLoaded, 0);
      expect(current.remainingTyres, 0);
      expect(current.isTargetReached, isFalse);
      expect(current.isTargetExceeded, isFalse);
      expect(current.progressPercent, isNull);
    });

    test('Cascading multi-document removal (5 documents down to 0)', () async {
      final trip = LoadingSheetTrip(
        id: 'trip_cascade',
        reg: 'ZN999888',
        driverName: 'Cascade Driver',
        tripId: 'BLOEM',
        quantityLoaded: 0,
        createdAt: 200000,
      );
      await vm.addTruckLoad(trip);

      final docs = List.generate(5, (i) {
        return IbtDocument(
          documentNo: 'DOC_$i',
          total: 10 * (i + 1), // 10, 20, 30, 40, 50 -> sum = 150
          lineItems: [
            IbtLineItem(
              id: 'line_$i',
              description: 'Tyre $i',
              targetTotal: 10 * (i + 1),
              loadedQuantity: 5 * (i + 1), // 5, 10, 15, 20, 25 -> sum = 75
            ),
          ],
        );
      });

      var current = (await vm.getTripsForSelectedDate()).first;
      for (final d in docs) {
        await vm.attachIbtDocument(trip: current, ibtDoc: d);
        current = (await vm.getTripsForSelectedDate()).first;
      }

      expect(current.ibtDocuments!.length, 5);
      expect(current.targetQuantity, 150);
      expect(current.quantityLoaded, 75);
      expect(current.remainingTyres, 75);

      // Remove DOC_4 (target 50, loaded 25)
      await vm.removeIbtDocument(trip: current, documentNo: 'DOC_4');
      current = (await vm.getTripsForSelectedDate()).first;
      expect(current.ibtDocuments!.length, 4);
      expect(current.targetQuantity, 100);
      expect(current.quantityLoaded, 50);

      // Remove DOC_2 (target 30, loaded 15)
      await vm.removeIbtDocument(trip: current, documentNo: 'DOC_2');
      current = (await vm.getTripsForSelectedDate()).first;
      expect(current.ibtDocuments!.length, 3);
      expect(current.targetQuantity, 70);
      expect(current.quantityLoaded, 35);

      // Remove DOC_0, DOC_1, DOC_3
      await vm.removeIbtDocument(trip: current, documentNo: 'DOC_0');
      current = (await vm.getTripsForSelectedDate()).first;
      await vm.removeIbtDocument(trip: current, documentNo: 'DOC_1');
      current = (await vm.getTripsForSelectedDate()).first;
      expect(current.ibtDocuments!.length, 1);
      expect(current.targetQuantity, 40);
      expect(current.quantityLoaded, 20);

      // Remove final DOC_3
      await vm.removeIbtDocument(trip: current, documentNo: 'DOC_3');
      current = (await vm.getTripsForSelectedDate()).first;
      expect(current.hasIbtDocuments, isFalse);
      expect(current.ibtDocuments, isNull);
      expect(current.targetQuantity, isNull);
      expect(current.quantityLoaded, 0);
    });

    test('Removing non-existent document does not corrupt existing documents or quantities', () async {
      final trip = LoadingSheetTrip(
        id: 'trip_noop',
        reg: 'ND12345',
        driverName: 'Driver',
        tripId: 'DBN',
        quantityLoaded: 0,
        createdAt: 300000,
      );
      await vm.addTruckLoad(trip);

      const doc = IbtDocument(
        documentNo: 'REAL_DOC',
        total: 20,
        lineItems: [
          IbtLineItem(id: 'l1', description: 'Tyre', targetTotal: 20, loadedQuantity: 12),
        ],
      );
      await vm.attachIbtDocument(trip: trip, ibtDoc: doc);
      var current = (await vm.getTripsForSelectedDate()).first;

      await vm.removeIbtDocument(trip: current, documentNo: 'GHOST_DOC');
      current = (await vm.getTripsForSelectedDate()).first;

      expect(current.ibtDocuments!.length, 1);
      expect(current.targetQuantity, 20);
      expect(current.quantityLoaded, 12);
    });
  });

  group('Adversarial Challenge 2: Stepping Down Line Quantities to 0 and Negative Clamping', () {
    late MockInMemoryEntryRepository repo;
    late LoadingSheetViewModel vm;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      repo = MockInMemoryEntryRepository();
      vm = LoadingSheetViewModel(repo);
    });

    test('Stepping down multiple lines across multiple documents to 0 preserves accurate sums', () async {
      final trip = LoadingSheetTrip(
        id: 'trip_multi_step',
        reg: 'GP999111',
        driverName: 'Step Driver',
        tripId: 'PLK',
        quantityLoaded: 0,
        createdAt: 400000,
      );
      await vm.addTruckLoad(trip);

      const doc1 = IbtDocument(
        documentNo: 'IBT-1',
        total: 30,
        lineItems: [
          IbtLineItem(id: 'd1_l1', description: 'Item 1', targetTotal: 10, loadedQuantity: 5),
          IbtLineItem(id: 'd1_l2', description: 'Item 2', targetTotal: 20, loadedQuantity: 10),
        ],
      );
      const doc2 = IbtDocument(
        documentNo: 'IBT-2',
        total: 15,
        lineItems: [
          IbtLineItem(id: 'd2_l1', description: 'Item 3', targetTotal: 15, loadedQuantity: 15),
        ],
      );

      await vm.attachIbtDocument(trip: trip, ibtDoc: doc1);
      var current = (await vm.getTripsForSelectedDate()).first;
      await vm.attachIbtDocument(trip: current, ibtDoc: doc2);
      current = (await vm.getTripsForSelectedDate()).first;

      expect(current.quantityLoaded, 30); // 5 + 10 + 15

      // Step d1_l1 to 0
      await vm.updateIbtLineQuantity(trip: current, documentNo: 'IBT-1', lineItemId: 'd1_l1', newQuantity: 0);
      current = (await vm.getTripsForSelectedDate()).first;
      expect(current.quantityLoaded, 25);

      // Step d1_l2 to 0
      await vm.updateIbtLineQuantity(trip: current, documentNo: 'IBT-1', lineItemId: 'd1_l2', newQuantity: 0);
      current = (await vm.getTripsForSelectedDate()).first;
      expect(current.quantityLoaded, 15);

      // Step d2_l1 with negative quantity (-100) -> clamps to 0
      await vm.updateIbtLineQuantity(trip: current, documentNo: 'IBT-2', lineItemId: 'd2_l1', newQuantity: -100);
      current = (await vm.getTripsForSelectedDate()).first;
      expect(current.quantityLoaded, 0);
      expect(current.ibtDocuments![1].lineItems[0].loadedQuantity, 0);
    });
  });

  group('Adversarial Challenge 3: Negative and Extreme Values in IbtLineItem and LoadingSheetTrip', () {
    test('Extreme and negative values in IbtLineItem properties', () {
      // 1. Extreme negative loaded quantity
      const negLine = IbtLineItem(
        id: 'neg_1',
        description: 'Negative Item',
        targetTotal: 50,
        loadedQuantity: -9999,
      );
      expect(negLine.overCount, 0);
      expect(negLine.remaining, 50);
      expect(negLine.isComplete, isFalse);
      expect(negLine.isShort, isTrue);
      expect(negLine.isOverloaded, isFalse);
      expect(negLine.progressPercent, 0.0);

      // 2. Zero target total with positive loaded
      const zeroTargetPosLoaded = IbtLineItem(
        id: 'zero_target',
        description: 'Zero Target',
        targetTotal: 0,
        loadedQuantity: 10,
      );
      expect(zeroTargetPosLoaded.overCount, 10);
      expect(zeroTargetPosLoaded.remaining, 0);
      expect(zeroTargetPosLoaded.isComplete, isFalse);
      expect(zeroTargetPosLoaded.isShort, isFalse);
      expect(zeroTargetPosLoaded.isOverloaded, isFalse);
      expect(zeroTargetPosLoaded.progressPercent, 0.0);

      // 3. Zero target total with negative loaded
      const zeroTargetNegLoaded = IbtLineItem(
        id: 'zero_target_neg',
        description: 'Zero Target Neg',
        targetTotal: 0,
        loadedQuantity: -5,
      );
      expect(zeroTargetNegLoaded.overCount, 0);
      expect(zeroTargetNegLoaded.remaining, 0);
      expect(zeroTargetNegLoaded.isComplete, isFalse);
      expect(zeroTargetNegLoaded.isShort, isFalse);
      expect(zeroTargetNegLoaded.isOverloaded, isFalse);

      // 4. Large values
      const hugeLine = IbtLineItem(
        id: 'huge',
        description: 'Huge',
        targetTotal: 100000,
        loadedQuantity: 150000,
      );
      expect(hugeLine.overCount, 50000);
      expect(hugeLine.remaining, 0);
      expect(hugeLine.isComplete, isTrue);
      expect(hugeLine.isShort, isFalse);
      expect(hugeLine.isOverloaded, isTrue);
      expect(hugeLine.progressPercent, 1.0);
    });

    test('LoadingSheetTrip copyWith clearing flags behavior', () {
      final trip = LoadingSheetTrip(
        id: 't_copy',
        reg: 'REG1',
        driverName: 'Driver',
        tripId: 'DBN',
        quantityLoaded: 10,
        targetQuantity: 20,
        createdAt: 100,
        ibtDocuments: const [
          IbtDocument(documentNo: 'IBT-1', total: 20, lineItems: []),
        ],
      );

      // Passing clearTargetQuantity: false without targetQuantity preserves targetQuantity
      final keptTarget = trip.copyWith(clearTargetQuantity: false);
      expect(keptTarget.targetQuantity, 20);

      // Passing clearTargetQuantity: true clears targetQuantity to null
      final clearedTarget = trip.copyWith(clearTargetQuantity: true);
      expect(clearedTarget.targetQuantity, isNull);

      // Passing clearIbtDocuments: false without ibtDocuments preserves ibtDocuments
      final keptIbts = trip.copyWith(clearIbtDocuments: false);
      expect(keptIbts.ibtDocuments!.length, 1);

      // Passing clearIbtDocuments: true clears ibtDocuments to null
      final clearedIbts = trip.copyWith(clearIbtDocuments: true);
      expect(clearedIbts.ibtDocuments, isNull);
    });
  });

  group('Adversarial Challenge 4: Export Status Badge Logic for Overloaded Items', () {
    test('WhatsApp export distinguishes between overload, shortage, and exact completion in single trip', () {
      final trip = LoadingSheetTrip(
        id: 'trip_mixed_export',
        reg: 'ND 777-888',
        driverName: 'Thabo',
        tripId: 'DBN',
        quantityLoaded: 65,
        startTime: 1725000000000,
        finishTime: 1725003600000,
        durationMinutes: 60,
        createdAt: 1725000000000,
        ibtDocuments: const [
          IbtDocument(
            documentNo: 'IBT-MIXED',
            total: 60,
            lineItems: [
              IbtLineItem(
                id: 'l1',
                description: 'Exact Match',
                targetTotal: 20,
                loadedQuantity: 20,
              ),
              IbtLineItem(
                id: 'l2',
                description: 'Short Item',
                targetTotal: 20,
                loadedQuantity: 15,
              ),
              IbtLineItem(
                id: 'l3',
                description: 'Overloaded Item',
                targetTotal: 20,
                loadedQuantity: 30,
              ),
            ],
          ),
        ],
      );

      final entry = Entry(
        id: 'entry_mixed',
        title: 'TODAY',
        tags: [],
        notes: [],
        attachments: [],
        loadingSheetTrips: [trip],
        createdAt: 1725000000000,
        updatedAt: 1725000000000,
        dayKey: '2026-09-01',
        monthKey: '2026-09',
        yearKey: '2026',
      );

      final text = WhatsAppExportService.formatWhatsAppText(entry, 'Tester');

      expect(text, contains('Exact Match [✓]'));
      expect(text, contains('Short Item [⚠️ Short 5]'));
      expect(text, contains('Overloaded Item [+10 Over]'));
      expect(text, isNot(contains('Overloaded Item [✓]')));
    });

    test('PDF export handles mixed states and generates valid PDF bytes', () async {
      final trip = LoadingSheetTrip(
        id: 'trip_pdf',
        reg: 'ND 777-888',
        driverName: 'Thabo',
        tripId: 'DBN',
        quantityLoaded: 45,
        startTime: 1725000000000,
        finishTime: 1725003600000,
        durationMinutes: 60,
        createdAt: 1725000000000,
        ibtDocuments: const [
          IbtDocument(
            documentNo: 'IBT-PDF',
            total: 40,
            lineItems: [
              IbtLineItem(
                id: 'p1',
                description: 'Overloaded Tyre',
                targetTotal: 20,
                loadedQuantity: 25,
              ),
              IbtLineItem(
                id: 'p2',
                description: 'Short Tyre',
                targetTotal: 20,
                loadedQuantity: 18,
              ),
            ],
          ),
        ],
      );

      final entry = Entry(
        id: 'entry_pdf',
        title: 'TODAY',
        tags: [],
        notes: [],
        attachments: [],
        loadingSheetTrips: [trip],
        createdAt: 1725000000000,
        updatedAt: 1725000000000,
        dayKey: '2026-09-01',
        monthKey: '2026-09',
        yearKey: '2026',
      );

      final bytes = await PdfExportService.generateLoadingSheetPdf(entry, 'Manager');
      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(1000));
    });
  });
}
