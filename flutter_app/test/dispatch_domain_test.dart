import 'package:flutter_test/flutter_test.dart';
import 'package:dispatch_diary/dispatch/domain/document_number.dart';
import 'package:dispatch_diary/dispatch/domain/scrap_marker.dart';
import 'package:dispatch_diary/dispatch/domain/tyre_story.dart';
import 'package:dispatch_diary/dispatch/models/dispatch_models.dart';
import 'package:dispatch_diary/dispatch/models/slip_tyre.dart';

void main() {
  group('DocumentNumberParser', () {
    test('bare number takes the fallback stream chip', () {
      final (stream, number) =
          DocumentNumberParser.parse('2392908', DocumentStream.inv)!;
      expect(stream, DocumentStream.inv);
      expect(number, 'INV2392908');
    });

    test('prefixed number overrides the chip', () {
      final (stream, number) =
          DocumentNumberParser.parse('DIBT0179154', DocumentStream.inv)!;
      expect(stream, DocumentStream.dibt);
      expect(number, 'DIBT0179154');
    });

    test('prefix matching is case-insensitive', () {
      final (_, number) =
          DocumentNumberParser.parse('ibt122773', DocumentStream.inv)!;
      expect(number, 'IBT122773');
    });

    test('every stream prefix maps correctly', () {
      expect(
        DocumentNumberParser.parse('AMS0099', DocumentStream.inv)?.$1,
        DocumentStream.amsInv,
      );
      expect(
        DocumentNumberParser.parse('IBT1', DocumentStream.amsInv)?.$1,
        DocumentStream.ibt,
      );
    });

    test('rejects fallback yields SCRAPS', () {
      final (stream, number) =
          DocumentNumberParser.parse('anything', DocumentStream.rejects)!;
      expect(stream, DocumentStream.rejects);
      expect(number, 'SCRAPS');
    });

    test('empty input returns null', () {
      expect(DocumentNumberParser.parse('  ', DocumentStream.inv), isNull);
      expect(DocumentNumberParser.parse('', DocumentStream.ibt), isNull);
    });
  });

  group('ScrapMarker', () {
    test('DUD codes anywhere count', () {
      expect(ScrapMarker.hasDudCode(['X', 'DUD-77']), isTrue);
      expect(ScrapMarker.hasDudCode(['x', null, 'y']), isFalse);
    });

    test('reject cells in history count', () {
      expect(ScrapMarker.cellMarksReject('REJECT INSPECTOR'), isTrue);
      expect(ScrapMarker.cellMarksReject('reject exit'), isTrue);
      expect(ScrapMarker.cellMarksReject('PEELING'), isFalse);
      expect(ScrapMarker.cellMarksReject(null), isFalse);
    });

    test('isScrap combines every signal', () {
      expect(ScrapMarker.isScrap(dump: 1), isTrue);
      expect(ScrapMarker.isScrap(rejectAccepted: 2), isTrue);
      expect(ScrapMarker.isScrap(serial: 'DUD-1'), isTrue);
      expect(
        ScrapMarker.isScrap(historyCells: ['REJECT RETURN']),
        isTrue,
      );
      expect(ScrapMarker.isScrap(rejectAccepted: 1, dump: 0), isFalse);
      expect(ScrapMarker.isScrap(), isFalse);
    });
  });

  group('TyreStory flags', () {
    test('dispatch delivery detected from history', () {
      final story = TyreStory(
        tyre: const SlipTyre(uid: 'A'),
        history: [
          TyreHistoryEntry.fromJson({'work_cell_name': 'DISPATCH DELIVERY'}),
        ],
      );
      expect(story.hasDispatchDelivery, isTrue);
    });

    test('scrap via history reject cell', () {
      final story = TyreStory(
        tyre: const SlipTyre(uid: 'A'),
        history: [
          TyreHistoryEntry.fromJson({'work_cell_name': 'REJECT DUMP'}),
        ],
      );
      expect(story.isScrapWithHistory, isTrue);
    });

    test('normal tyre is neither dispatched nor scrap', () {
      final story = TyreStory(
        tyre: const SlipTyre(uid: 'A'),
        history: [
          TyreHistoryEntry.fromJson({'work_cell_name': 'PEELING'}),
        ],
      );
      expect(story.hasDispatchDelivery, isFalse);
      expect(story.isScrapWithHistory, isFalse);
    });
  });
}
