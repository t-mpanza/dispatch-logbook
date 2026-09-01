import 'package:flutter_test/flutter_test.dart';
import 'package:dispatch_diary/data/models/ibt_manifest.dart';
import 'package:dispatch_diary/data/models/loading_sheet_trip.dart';
import 'package:dispatch_diary/data/models/entry.dart';
import 'package:dispatch_diary/data/repositories/entry_repository.dart';
import 'package:dispatch_diary/presentation/viewmodels/loading_sheet_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InMemoryEntryRepository extends EntryRepository {
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

  group('IBT End-to-End Workflow TDD Tests', () {
    late InMemoryEntryRepository repo;
    late LoadingSheetViewModel vm;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      repo = InMemoryEntryRepository();
      vm = LoadingSheetViewModel(repo);
    });

    test('Attaching an IBT to a trip auto-calculates targets and updates state', () async {
      final trip = LoadingSheetTrip(
        id: 'trip_100',
        reg: 'ND556677',
        driverName: 'Sipho',
        tripId: 'DBN',
        quantityLoaded: 0,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      await vm.addTruckLoad(trip);

      const ibtDoc = IbtDocument(
        documentNo: 'IBT119512',
        total: 53,
        lineItems: [
          IbtLineItem(
            id: 'line_1',
            description: '315/80R22.5 RD2+',
            size: '315/80R22.5',
            rubber: 'RD2+',
            targetTotal: 13,
            loadedQuantity: 0,
          ),
          IbtLineItem(
            id: 'line_2',
            description: '315/80R22.5 M90L',
            size: '315/80R22.5',
            rubber: 'M90L',
            targetTotal: 40,
            loadedQuantity: 0,
          ),
        ],
      );

      // Attach IBT
      await vm.attachIbtDocument(trip: trip, ibtDoc: ibtDoc);

      final trips = await vm.getTripsForSelectedDate();
      expect(trips.length, 1);
      final attachedTrip = trips.first;

      expect(attachedTrip.hasIbtDocuments, isTrue);
      expect(attachedTrip.ibtTargetTotal, 53);
      expect(attachedTrip.ibtLoadedTotal, 0);
      expect(attachedTrip.remainingTyres, 53);
      expect(attachedTrip.isTargetReached, isFalse);

      // Step quantity on Line 1 (+13)
      await vm.updateIbtLineQuantity(
        trip: attachedTrip,
        documentNo: 'IBT119512',
        lineItemId: 'line_1',
        newQuantity: 13,
      );

      final afterLine1 = (await vm.getTripsForSelectedDate()).first;
      expect(afterLine1.quantityLoaded, 13);
      expect(afterLine1.remainingTyres, 40);
      expect(afterLine1.ibtDocuments!.first.lineItems[0].isComplete, isTrue);
      expect(afterLine1.ibtDocuments!.first.lineItems[1].isShort, isTrue);

      // Step quantity on Line 2 (+40)
      await vm.updateIbtLineQuantity(
        trip: afterLine1,
        documentNo: 'IBT119512',
        lineItemId: 'line_2',
        newQuantity: 40,
      );

      final completedTrip = (await vm.getTripsForSelectedDate()).first;
      expect(completedTrip.quantityLoaded, 53);
      expect(completedTrip.remainingTyres, 0);
      expect(completedTrip.isTargetReached, isTrue);
      expect(completedTrip.ibtDocuments!.first.isComplete, isTrue);
    });

    test('Stepping loaded quantities down to 0 properly sets quantityLoaded to 0', () async {
      final trip = LoadingSheetTrip(
        id: 'trip_step_zero',
        reg: 'ND112233',
        driverName: 'John',
        tripId: 'DBN',
        quantityLoaded: 0,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      await vm.addTruckLoad(trip);

      const ibtDoc = IbtDocument(
        documentNo: 'IBT100',
        total: 10,
        lineItems: [
          IbtLineItem(
            id: 'line_1',
            description: '315/80R22.5',
            targetTotal: 10,
            loadedQuantity: 0,
          ),
        ],
      );

      await vm.attachIbtDocument(trip: trip, ibtDoc: ibtDoc);
      var currentTrip = (await vm.getTripsForSelectedDate()).first;

      // Increment to 5
      await vm.updateIbtLineQuantity(
        trip: currentTrip,
        documentNo: 'IBT100',
        lineItemId: 'line_1',
        newQuantity: 5,
      );
      currentTrip = (await vm.getTripsForSelectedDate()).first;
      expect(currentTrip.quantityLoaded, 5);

      // Decrement back to 0
      await vm.updateIbtLineQuantity(
        trip: currentTrip,
        documentNo: 'IBT100',
        lineItemId: 'line_1',
        newQuantity: 0,
      );
      currentTrip = (await vm.getTripsForSelectedDate()).first;
      expect(currentTrip.quantityLoaded, 0);
      expect(currentTrip.ibtDocuments!.first.lineItems.first.loadedQuantity, 0);
    });

    test('Removing the last IBT document clears ibtDocuments and sets hasIbtDocuments to false', () async {
      final trip = LoadingSheetTrip(
        id: 'trip_remove_last',
        reg: 'ND998877',
        driverName: 'Neil',
        tripId: 'NLH',
        quantityLoaded: 0,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      await vm.addTruckLoad(trip);

      const ibtDoc = IbtDocument(
        documentNo: 'IBT200',
        total: 25,
        lineItems: [
          IbtLineItem(
            id: 'line_1',
            description: '11R22.5',
            targetTotal: 25,
            loadedQuantity: 10,
          ),
        ],
      );

      await vm.attachIbtDocument(trip: trip, ibtDoc: ibtDoc);
      var currentTrip = (await vm.getTripsForSelectedDate()).first;
      expect(currentTrip.hasIbtDocuments, isTrue);
      expect(currentTrip.ibtDocuments, isNotNull);

      // Remove the only IBT document
      await vm.removeIbtDocument(trip: currentTrip, documentNo: 'IBT200');
      currentTrip = (await vm.getTripsForSelectedDate()).first;

      expect(currentTrip.hasIbtDocuments, isFalse);
      expect(currentTrip.ibtDocuments, isNull);
      expect(currentTrip.targetQuantity, isNull);
      expect(currentTrip.quantityLoaded, 0);
    });

    test('Multi-IBT document target recalculation upon removal', () async {
      final trip = LoadingSheetTrip(
        id: 'trip_multi_ibt',
        reg: 'ND334455',
        driverName: 'Sipho',
        tripId: 'DBN',
        quantityLoaded: 0,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      await vm.addTruckLoad(trip);

      const docA = IbtDocument(
        documentNo: 'IBT-A',
        total: 30,
        lineItems: [
          IbtLineItem(
            id: 'line_a1',
            description: '315/80R22.5',
            targetTotal: 30,
            loadedQuantity: 15,
          ),
        ],
      );

      const docB = IbtDocument(
        documentNo: 'IBT-B',
        total: 20,
        lineItems: [
          IbtLineItem(
            id: 'line_b1',
            description: '11R22.5',
            targetTotal: 20,
            loadedQuantity: 10,
          ),
        ],
      );

      // Attach both documents
      await vm.attachIbtDocument(trip: trip, ibtDoc: docA);
      var currentTrip = (await vm.getTripsForSelectedDate()).first;
      await vm.attachIbtDocument(trip: currentTrip, ibtDoc: docB);
      currentTrip = (await vm.getTripsForSelectedDate()).first;

      expect(currentTrip.ibtDocuments!.length, 2);
      expect(currentTrip.ibtTargetTotal, 50);
      expect(currentTrip.targetQuantity, 50);
      expect(currentTrip.quantityLoaded, 25);
      expect(currentTrip.remainingTyres, 25);

      // Remove docB (target 20, loaded 10)
      await vm.removeIbtDocument(trip: currentTrip, documentNo: 'IBT-B');
      currentTrip = (await vm.getTripsForSelectedDate()).first;

      expect(currentTrip.ibtDocuments!.length, 1);
      expect(currentTrip.ibtDocuments!.first.documentNo, 'IBT-A');
      expect(currentTrip.ibtTargetTotal, 30);
      expect(currentTrip.targetQuantity, 30);
      expect(currentTrip.quantityLoaded, 15);
      expect(currentTrip.remainingTyres, 15);
    });
  });
}
