import 'package:dispatch_diary/data/models/ibt_manifest.dart';
import 'package:dispatch_diary/data/models/staged_document.dart';
import 'package:dispatch_diary/dispatch/domain/document_number.dart';
import 'package:dispatch_diary/dispatch/models/slip_tyre.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SlipTyre tyre({String? uid, int? slipNumber, int? loaded}) => SlipTyre(
        uid: uid,
        slipNumber: slipNumber,
        loaded: loaded,
        size: '315/80R22.5',
        make: 'GOOD YEAR',
      );

  StagedDocument doc() => StagedDocument(
        id: 'e1:dibt:DIBT0179154',
        entryId: 'e1',
        stream: DocumentStream.dibt,
        documentNo: 'DIBT0179154',
        customerName: 'EPS COURIERS SERVICES',
        total: 5,
        slips: [
          tyre(uid: '1D0DF19A091080', slipNumber: 96962259, loaded: 1),
          tyre(uid: '1D6D0297021080', slipNumber: 98962056, loaded: 0),
        ],
        cachedAt: 1234,
      );

  group('StagedDocument model', () {
    test('JSON round-trip preserves everything', () {
      final d = doc();
      final restored = StagedDocument.fromJson(
        id: d.id,
        entryId: d.entryId,
        cachedAt: d.cachedAt,
        json: d.toJson(),
      );
      expect(restored.stream, DocumentStream.dibt);
      expect(restored.documentNo, 'DIBT0179154');
      expect(restored.customerName, 'EPS COURIERS SERVICES');
      expect(restored.total, 5);
      expect(restored.slips.length, 2);
      expect(restored.slips.first.slipNumber, 96962259);
      expect(restored.slips.first.isLoaded, isTrue);
      expect(restored.slips[1].isLoaded, isFalse);
      expect(restored.cachedAt, 1234);
    });

    test('IBT documents round-trip line items with history', () {
      final d = StagedDocument(
        id: 'e1:ibt:IBT122773',
        entryId: 'e1',
        stream: DocumentStream.ibt,
        documentNo: 'IBT122773',
        total: 151,
        lineItems: [
          IbtLineItem(
            id: 'IBT122773_line_0',
            description: '315/80R22.5 M90L STOCK RETREAD',
            sizeId: 70,
            rubberId: 36,
            targetTotal: 83,
            loadedQuantity: 4,
            history: [
              IbtLineEvent(id: 'h1', delta: 4, at: 1),
            ],
          ),
        ],
        cachedAt: 5,
      );
      final restored = StagedDocument.fromJson(
        id: d.id,
        entryId: d.entryId,
        cachedAt: d.cachedAt,
        json: d.toJson(),
      );
      expect(restored.isIbt, isTrue);
      expect(restored.lineItems.single.targetTotal, 83);
      expect(restored.lineItems.single.history.single.delta, 4);
    });

    test('membership helpers', () {
      final d = doc();
      expect(d.containsUid('1D0DF19A091080'), isTrue);
      expect(d.containsUid('FFFFFFFFFFFFFFFF'), isFalse);
      expect(d.containsSlip(96962259), isTrue);
      expect(d.loadedCount, 1);
    });
  });
}
