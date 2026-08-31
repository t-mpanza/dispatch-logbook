import 'package:flutter_test/flutter_test.dart';
import 'package:dispatch_diary/data/models/ibt_manifest.dart';
import 'package:dispatch_diary/data/models/loading_sheet_trip.dart';
import 'package:dispatch_diary/data/models/entry.dart';
import 'package:dispatch_diary/data/services/whatsapp_export_service.dart';

void main() {
  group('IbtLineItem Model & Calculations', () {
    test('Calculates remaining, completion and progress correctly', () {
      const line = IbtLineItem(
        id: 'line_1',
        description: '315/80R22.5 RD2+',
        rcsCode: 'LLS039',
        sizeId: 22,
        rubberId: 12,
        size: '315/80R22.5',
        rubber: 'RD2+',
        targetTotal: 20,
        loadedQuantity: 13,
      );

      expect(line.remaining, 7);
      expect(line.overCount, 0);
      expect(line.isComplete, isFalse);
      expect(line.isShort, isTrue);
      expect(line.isOverloaded, isFalse);
      expect(line.progressPercent, closeTo(0.65, 0.01));

      // Test complete state
      final completedLine = line.copyWith(loadedQuantity: 20);
      expect(completedLine.remaining, 0);
      expect(completedLine.isComplete, isTrue);
      expect(completedLine.isShort, isFalse);
      expect(completedLine.progressPercent, 1.0);

      // Test overloaded state
      final overLine = line.copyWith(loadedQuantity: 22);
      expect(overLine.remaining, 0);
      expect(overLine.overCount, 2);
      expect(overLine.isOverloaded, isTrue);
    });

    test('Serialization and Deserialization roundtrip', () {
      const line = IbtLineItem(
        id: 'line_1',
        description: '11R22.5 MM84',
        rcsCode: 'LLS018',
        sizeId: 45,
        rubberId: 18,
        size: '11R22.5',
        rubber: 'MM84',
        targetTotal: 15,
        loadedQuantity: 10,
      );

      final map = line.toMap();
      final reconstructed = IbtLineItem.fromMap(map);

      expect(reconstructed.id, line.id);
      expect(reconstructed.description, line.description);
      expect(reconstructed.rcsCode, line.rcsCode);
      expect(reconstructed.size, line.size);
      expect(reconstructed.rubber, line.rubber);
      expect(reconstructed.targetTotal, line.targetTotal);
      expect(reconstructed.loadedQuantity, line.loadedQuantity);
    });
  });

  group('IbtDocument Model & Quotas', () {
    test('Calculates loadedTotal and completion across all line items', () {
      const doc = IbtDocument(
        documentNo: 'IBT119512',
        total: 33,
        lineItems: [
          IbtLineItem(
            id: 'l1',
            description: '315/80R22.5 RD2+',
            targetTotal: 13,
            loadedQuantity: 13,
          ),
          IbtLineItem(
            id: 'l2',
            description: '11R22.5 MM84',
            targetTotal: 20,
            loadedQuantity: 15,
          ),
        ],
      );

      expect(doc.loadedTotal, 28);
      expect(doc.remainingTotal, 5);
      expect(doc.isComplete, isFalse);
      expect(doc.hasShortages, isTrue);

      final map = doc.toMap();
      final reconstructed = IbtDocument.fromMap(map);
      expect(reconstructed.documentNo, 'IBT119512');
      expect(reconstructed.total, 33);
      expect(reconstructed.lineItems.length, 2);
      expect(reconstructed.loadedTotal, 28);
    });
  });

  group('LoadingSheetTrip with IBT Documents', () {
    test('Integrates with LoadingSheetTrip and Entry serialization', () {
      final trip = LoadingSheetTrip(
        id: 'trip_1',
        reg: 'MN05XNGP',
        driverName: 'Neil',
        tripId: 'DBN',
        quantityLoaded: 45,
        createdAt: 1725000000000,
        ibtDocuments: const [
          IbtDocument(
            documentNo: 'IBT119512',
            total: 45,
            lineItems: [
              IbtLineItem(
                id: 'l1',
                description: '315/80R22.5 RD2+',
                size: '315/80R22.5',
                rubber: 'RD2+',
                targetTotal: 25,
                loadedQuantity: 25,
              ),
              IbtLineItem(
                id: 'l2',
                description: '315/80R22.5 M90L',
                size: '315/80R22.5',
                rubber: 'M90L',
                targetTotal: 20,
                loadedQuantity: 20,
              ),
            ],
          ),
        ],
      );

      expect(trip.hasIbtDocuments, isTrue);
      expect(trip.ibtTargetTotal, 45);
      expect(trip.ibtLoadedTotal, 45);
      expect(trip.isTargetReached, isTrue);

      // Serialize to Map and back
      final map = trip.toMap();
      final reconstructed = LoadingSheetTrip.fromMap(map);
      expect(reconstructed.hasIbtDocuments, isTrue);
      expect(reconstructed.ibtDocuments!.first.documentNo, 'IBT119512');
      expect(reconstructed.ibtDocuments!.first.lineItems.length, 2);

      // Wrap inside an Entry and test full SQLite JSON serialization
      final entry = Entry(
        id: 'entry_1',
        title: 'TODAY',
        tags: ['loading-sheet'],
        notes: [],
        attachments: [],
        loadingSheetTrips: [reconstructed],
        createdAt: 1725000000000,
        updatedAt: 1725000000000,
        dayKey: '2026-08-31',
        monthKey: '2026-08',
        yearKey: '2026',
      );

      final dbMap = entry.toMap();
      final entryReconstructed = Entry.fromMap(dbMap);
      expect(entryReconstructed.loadingSheetTrips!.length, 1);
      final rTrip = entryReconstructed.loadingSheetTrips!.first;
      expect(rTrip.hasIbtDocuments, isTrue);
      expect(rTrip.ibtDocuments!.first.lineItems.first.description, '315/80R22.5 RD2+');
    });

    test('WhatsApp export includes itemized IBT breakdown and shortages', () {
      final trip = LoadingSheetTrip(
        id: 'trip_1',
        reg: 'ND 984-210',
        driverName: 'Sipho',
        tripId: 'DBN',
        quantityLoaded: 38,
        createdAt: 1725000000000,
        ibtDocuments: const [
          IbtDocument(
            documentNo: 'IBT119512',
            total: 40,
            lineItems: [
              IbtLineItem(
                id: 'l1',
                description: '315/80R22.5 RD2+',
                targetTotal: 20,
                loadedQuantity: 20,
              ),
              IbtLineItem(
                id: 'l2',
                description: '315/80R22.5 M90L',
                targetTotal: 20,
                loadedQuantity: 18,
              ),
            ],
          ),
        ],
      );

      final entry = Entry(
        id: 'entry_1',
        title: 'TODAY',
        tags: [],
        notes: [],
        attachments: [],
        loadingSheetTrips: [trip],
        createdAt: 1725000000000,
        updatedAt: 1725000000000,
        dayKey: '2026-08-31',
        monthKey: '2026-08',
        yearKey: '2026',
      );

      final waText = WhatsAppExportService.formatWhatsAppText(entry, 'Theolus');
      expect(waText, contains('IBT119512'));
      expect(waText, contains('315/80R22.5 RD2+ [✓]'));
      expect(waText, contains('315/80R22.5 M90L [⚠️ Short 2]'));
    });
  });
}
