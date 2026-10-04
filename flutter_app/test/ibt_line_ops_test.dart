import 'package:flutter_test/flutter_test.dart';
import 'package:dispatch_diary/data/models/ibt_manifest.dart';
import 'package:dispatch_diary/data/models/loading_sheet_trip.dart';
import 'package:dispatch_diary/data/services/ibt_line_ops.dart';

LoadingSheetTrip _tripWithLines({
  required String docNo,
  required List<IbtLineItem> lines,
}) {
  return LoadingSheetTrip(
    id: 't1',
    reg: 'GP01',
    driverName: 'Sam',
    tripId: 'STOCKS 1',
    quantityLoaded: lines.fold<int>(0, (s, l) => s + l.loadedQuantity),
    createdAt: 1000,
    ibtDocuments: [
      IbtDocument(
        documentNo: docNo,
        total: lines.fold<int>(0, (s, l) => s + l.targetTotal),
        lineItems: lines,
      ),
    ],
  );
}

void main() {
  group('IbtLineOps — per-line tally engine', () {
    test('applyDelta appends a history event and updates totals', () {
      final trip = _tripWithLines(docNo: 'IBT-1', lines: [
        const IbtLineItem(
          id: 'l1',
          description: '12R22.5 RD2+',
          targetTotal: 10,
        ),
      ]);

      final result = IbtLineOps.applyDelta(
        trip: trip,
        documentNo: 'IBT-1',
        lineItemId: 'l1',
        delta: 4,
        nowMs: 5000,
      );

      expect(result.line.loadedQuantity, 4);
      expect(result.line.history.length, 1);
      expect(result.line.history.single.delta, 4);
      expect(result.line.history.single.at, 5000);
      expect(result.line.lastEvent!.delta, 4);
      expect(result.trip.quantityLoaded, 4);
      expect(result.completed, isFalse);
      expect(result.wasClamped, isFalse);
    });

    test('manifest target is a hard cap — overshoot clamps and flags', () {
      final trip = _tripWithLines(docNo: 'IBT-1', lines: [
        const IbtLineItem(
          id: 'l1',
          description: 'Item',
          targetTotal: 10,
          loadedQuantity: 8,
        ),
      ]);

      final result = IbtLineOps.applyDelta(
        trip: trip,
        documentNo: 'IBT-1',
        lineItemId: 'l1',
        delta: 5,
      );

      expect(result.appliedDelta, 2);
      expect(result.wasClamped, isTrue);
      expect(result.line.loadedQuantity, 10);
      expect(result.line.history.last.delta, 2);
    });

    test('negative deltas clamp at zero', () {
      final trip = _tripWithLines(docNo: 'IBT-1', lines: [
        const IbtLineItem(
          id: 'l1',
          description: 'Item',
          targetTotal: 10,
          loadedQuantity: 2,
        ),
      ]);

      final result = IbtLineOps.applyDelta(
        trip: trip,
        documentNo: 'IBT-1',
        lineItemId: 'l1',
        delta: -9,
      );

      expect(result.appliedDelta, -2);
      expect(result.wasClamped, isTrue);
      expect(result.line.loadedQuantity, 0);
    });

    test('completing a line reports completed: true', () {
      final trip = _tripWithLines(docNo: 'IBT-1', lines: [
        const IbtLineItem(
          id: 'l1',
          description: 'Item',
          targetTotal: 10,
          loadedQuantity: 7,
        ),
      ]);

      final result = IbtLineOps.applyDelta(
        trip: trip,
        documentNo: 'IBT-1',
        lineItemId: 'l1',
        delta: 3,
      );

      expect(result.completed, isTrue);
      expect(result.line.isComplete, isTrue);
    });

    test('undoLast reverts the most recent change', () {
      var trip = _tripWithLines(docNo: 'IBT-1', lines: [
        const IbtLineItem(
          id: 'l1',
          description: 'Item',
          targetTotal: 10,
          loadedQuantity: 5,
        ),
      ]);

      trip = IbtLineOps.applyDelta(
        trip: trip,
        documentNo: 'IBT-1',
        lineItemId: 'l1',
        delta: 5, // completes the line at 10
      ).trip;

      final undone = IbtLineOps.undoLast(
        trip: trip,
        documentNo: 'IBT-1',
        lineItemId: 'l1',
      );

      expect(undone, isNotNull);
      expect(undone!.line.loadedQuantity, 5);
      expect(undone.line.history.length, 2); // +5 then -5
      expect(undone.uncompleted, isTrue);
    });

    test('undoLast returns null when there is no history', () {
      final trip = _tripWithLines(docNo: 'IBT-1', lines: [
        const IbtLineItem(
          id: 'l1',
          description: 'Item',
          targetTotal: 10,
        ),
      ]);

      expect(
        IbtLineOps.undoLast(
          trip: trip,
          documentNo: 'IBT-1',
          lineItemId: 'l1',
        ),
        isNull,
      );
    });

    test('setQuantity computes and logs the effective delta', () {
      final trip = _tripWithLines(docNo: 'IBT-1', lines: [
        const IbtLineItem(
          id: 'l1',
          description: 'Item',
          targetTotal: 10,
          loadedQuantity: 2,
        ),
      ]);

      final result = IbtLineOps.setQuantity(
        trip: trip,
        documentNo: 'IBT-1',
        lineItemId: 'l1',
        newQuantity: 9,
      );

      expect(result.line.loadedQuantity, 9);
      expect(result.line.history.last.delta, 7);
    });

    test('setQuantity above target clamps to the manifest cap', () {
      final trip = _tripWithLines(docNo: 'IBT-1', lines: [
        const IbtLineItem(
          id: 'l1',
          description: 'Item',
          targetTotal: 10,
          loadedQuantity: 2,
        ),
      ]);

      final result = IbtLineOps.setQuantity(
        trip: trip,
        documentNo: 'IBT-1',
        lineItemId: 'l1',
        newQuantity: 25,
      );

      expect(result.line.loadedQuantity, 10);
      expect(result.wasClamped, isTrue);
    });

    test('unknown document throws ArgumentError (callers must guard)', () {
      final trip = _tripWithLines(docNo: 'IBT-1', lines: [
        const IbtLineItem(
          id: 'l1',
          description: 'Item',
          targetTotal: 10,
        ),
      ]);

      expect(
        () => IbtLineOps.applyDelta(
          trip: trip,
          documentNo: 'IBT-MISSING',
          lineItemId: 'l1',
          delta: 1,
        ),
        throwsArgumentError,
      );
    });

    test('history serializes through toMap/fromMap round-trip', () {
      final trip = _tripWithLines(docNo: 'IBT-1', lines: [
        const IbtLineItem(
          id: 'l1',
          description: 'Item',
          targetTotal: 10,
        ),
      ]);

      final result = IbtLineOps.applyDelta(
        trip: trip,
        documentNo: 'IBT-1',
        lineItemId: 'l1',
        delta: 3,
        nowMs: 1234,
      );

      final restored = LoadingSheetTrip.fromMap(result.trip.toMap());
      final line = restored.ibtDocuments!.single.lineItems.single;
      expect(line.history.length, 1);
      expect(line.history.single.delta, 3);
      expect(line.history.single.at, 1234);
    });

    test('legacy maps without history load as empty history', () {
      final line = IbtLineItem.fromMap({
        'id': 'l1',
        'description': 'Legacy line',
        'targetTotal': 10,
        'loadedQuantity': 4,
      });
      expect(line.history, isEmpty);
      expect(line.lastEvent, isNull);
    });
  });
}
