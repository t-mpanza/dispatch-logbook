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
  });
}
