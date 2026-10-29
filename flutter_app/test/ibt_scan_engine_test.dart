import 'package:flutter_test/flutter_test.dart';
import 'package:dispatch_diary/data/models/ibt_manifest.dart';
import 'package:dispatch_diary/data/models/loading_sheet_trip.dart';
import 'package:dispatch_diary/dispatch/domain/ibt_scan_engine.dart';
import 'package:dispatch_diary/dispatch/models/slip_tyre.dart';

LoadingSheetTrip _trip({
  List<IbtDocument>? docs,
  String reg = 'MN05XNGP',
}) {
  return LoadingSheetTrip(
    id: 't1',
    reg: reg,
    driverName: 'Neil',
    tripId: 'STOCKS 1',
    quantityLoaded: docs?.fold<int>(0, (s, d) => s + d.loadedTotal) ?? 0,
    createdAt: 0,
    ibtDocuments: docs,
  );
}

IbtDocument _doc(
  String no,
  List<IbtLineItem> lines,
) {
  return IbtDocument(
    documentNo: no,
    total: lines.fold<int>(0, (s, l) => s + l.targetTotal),
    lineItems: lines,
  );
}

IbtLineItem _line({
  required String id,
  required int sizeId,
  required int rubberId,
  int target = 10,
  int loaded = 0,
  String size = '315/80R22.5',
  String? rubber,
}) {
  return IbtLineItem(
    id: id,
    description: '$size ${rubber ?? ''}'.trim(),
    size: size,
    rubber: rubber,
    sizeId: sizeId,
    rubberId: rubberId,
    targetTotal: target,
    loadedQuantity: loaded,
  );
}

SlipTyre _tyre({
  String uid = '04A3F9E1C2B4D5',
  String job = 'Client Retread',
  int? sizeId = 70,
  int? rubberId = 36,
  int dump = 0,
  String size = '315/80R22.5',
  String pattern = 'M90L',
}) {
  return SlipTyre(
    uid: uid,
    job: job,
    sizeId: sizeId,
    rubberId: rubberId,
    dump: dump,
    size: size,
    pattern: pattern,
  );
}

void main() {
  group('IbtScanEngine — the full verdict matrix', () {
    test('operator missing → Operator not found', () {
      final v = IbtScanEngine.evaluate(
        trip: _trip(docs: [_doc('IBT1', [_line(id: 'l1', sizeId: 70, rubberId: 36)])]),
        tyre: _tyre(),
        sessionUids: {},
        operatorId: null,
      );
      expect(v.isSuccess, isFalse);
      expect(v.message, contains('Operator not found'));
    });

    test('empty registration → Set the truck REG first', () {
      final v = IbtScanEngine.evaluate(
        trip: _trip(
          reg: '',
          docs: [_doc('IBT1', [_line(id: 'l1', sizeId: 70, rubberId: 36)])],
        ),
        tyre: _tyre(),
        sessionUids: {},
        operatorId: 7,
      );
      expect(v.message, contains('REG'));
    });

    test('no IBT documents → Attach an IBT first', () {
      final v = IbtScanEngine.evaluate(
        trip: _trip(),
        tyre: _tyre(),
        sessionUids: {},
        operatorId: 7,
      );
      expect(v.message, contains('Attach an IBT'));
    });

    test('session duplicate → Already counted', () {
      final v = IbtScanEngine.evaluate(
        trip: _trip(docs: [_doc('IBT1', [_line(id: 'l1', sizeId: 70, rubberId: 36)])]),
        tyre: _tyre(),
        sessionUids: {'04A3F9E1C2B4D5'},
        operatorId: 7,
      );
      expect(v.message, contains('Already counted'));
    });

    test('dumped tyre → This tyre is dumped', () {
      final v = IbtScanEngine.evaluate(
        trip: _trip(docs: [_doc('IBT1', [_line(id: 'l1', sizeId: 70, rubberId: 36)])]),
        tyre: _tyre(dump: 1),
        sessionUids: {},
        operatorId: 7,
      );
      expect(v.message, contains('dumped'));
    });

    test('wrong job → Not a stocks tyre (the Client Retread gate)', () {
      final v = IbtScanEngine.evaluate(
        trip: _trip(docs: [_doc('IBT1', [_line(id: 'l1', sizeId: 70, rubberId: 36)])]),
        tyre: _tyre(job: 'Retread & Repair'),
        sessionUids: {},
        operatorId: 7,
      );
      expect(v.message, contains('Not a stocks tyre'));
      expect(v.message, contains('Retread & Repair'));
    });

    test('job gate is case/whitespace tolerant', () {
      expect(IbtScanEngine.isStocksJob('CLIENT RETREAD'), isTrue);
      expect(IbtScanEngine.isStocksJob(' client retread '), isTrue);
      expect(IbtScanEngine.isStocksJob('Claim'), isFalse);
      expect(IbtScanEngine.isStocksJob(null), isFalse);
    });

    test('size+rubber not on manifest → Not on IBT', () {
      final v = IbtScanEngine.evaluate(
        trip: _trip(docs: [_doc('IBT1', [_line(id: 'l1', sizeId: 70, rubberId: 36)])]),
        tyre: _tyre(sizeId: 16, rubberId: 16, size: '11R22.5', pattern: 'MM84'),
        sessionUids: {},
        operatorId: 7,
      );
      expect(v.message, contains("isn't on IBT"));
      expect(v.message, contains('11R22.5'));
    });

    test('line full (other lines still open) → Line full with numbers', () {
      final v = IbtScanEngine.evaluate(
        trip: _trip(
          docs: [
            _doc('IBT1', [
              _line(id: 'l1', sizeId: 70, rubberId: 36, target: 10, loaded: 10),
              _line(id: 'l2', sizeId: 16, rubberId: 16, target: 5, loaded: 2),
            ]),
          ],
        ),
        tyre: _tyre(),
        sessionUids: {},
        operatorId: 7,
      );
      expect(v.message, contains('Line full'));
      expect(v.message, contains('10/10'));
    });

    test('whole IBT complete → IBT complete', () {
      final v = IbtScanEngine.evaluate(
        trip: _trip(
          docs: [
            _doc('IBT1', [
              _line(id: 'l1', sizeId: 70, rubberId: 36, target: 10, loaded: 10),
              _line(id: 'l2', sizeId: 16, rubberId: 16, target: 5, loaded: 5),
            ]),
          ],
        ),
        tyre: _tyre(sizeId: 70, rubberId: 36),
        sessionUids: {},
        operatorId: 7,
      );
      expect(v.message, contains('IBT complete'));
    });

    test('accept → matched doc + line', () {
      final v = IbtScanEngine.evaluate(
        trip: _trip(
          docs: [
            _doc('IBT122773', [
              _line(id: 'l1', sizeId: 70, rubberId: 36, target: 10, loaded: 4),
            ]),
          ],
        ),
        tyre: _tyre(),
        sessionUids: {},
        operatorId: 7,
      );
      expect(v.isSuccess, isTrue);
      final accepted = v as ScanAccepted;
      expect(accepted.documentNo, 'IBT122773');
      expect(accepted.lineId, 'l1');
    });

    test('multi-doc ambiguity → line with most remaining capacity wins', () {
      final v = IbtScanEngine.evaluate(
        trip: _trip(
          docs: [
            _doc('IBT-A', [
              _line(id: 'a1', sizeId: 70, rubberId: 36, target: 10, loaded: 8),
            ]),
            _doc('IBT-B', [
              _line(id: 'b1', sizeId: 70, rubberId: 36, target: 10, loaded: 1),
            ]),
          ],
        ),
        tyre: _tyre(),
        sessionUids: {},
        operatorId: 7,
      );
      final accepted = v as ScanAccepted;
      expect(accepted.documentNo, 'IBT-B');
    });

    test('success verdict plays the success sound; rejections play error', () {
      final ok = IbtScanEngine.evaluate(
        trip: _trip(docs: [_doc('IBT1', [_line(id: 'l1', sizeId: 70, rubberId: 36)])]),
        tyre: _tyre(),
        sessionUids: {},
        operatorId: 7,
      );
      expect(ok.sound, ScanSound.success);

      final bad = IbtScanEngine.evaluate(
        trip: _trip(docs: [_doc('IBT1', [_line(id: 'l1', sizeId: 70, rubberId: 36)])]),
        tyre: _tyre(job: 'Other'),
        sessionUids: {},
        operatorId: 7,
      );
      expect(bad.sound, ScanSound.error);
    });
  });
}
