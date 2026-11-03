import 'package:flutter_test/flutter_test.dart';
import 'package:dispatch_diary/dispatch/domain/scrap_scan_engine.dart';
import 'package:dispatch_diary/dispatch/models/slip_tyre.dart';

SlipTyre _tyre({
  String uid = '04A3F9E1C2B4D5',
  int rejectAccepted = 1,
  int dump = 0,
}) {
  return SlipTyre(
    uid: uid,
    rejectAccepted: rejectAccepted,
    dump: dump,
    size: '12R22.5',
    pattern: 'M38',
  );
}

void main() {
  group('ScrapScanEngine — the scrap run-out gate', () {
    test('reject_accepted == 1 is the scrap signal', () {
      expect(ScrapScanEngine.isScrapTyre(_tyre(rejectAccepted: 1)), isTrue);
      expect(ScrapScanEngine.isScrapTyre(_tyre(rejectAccepted: 2)), isFalse);
      expect(ScrapScanEngine.isScrapTyre(_tyre(rejectAccepted: 0)), isFalse);
    });

    test('valid scrap accepts with no target anywhere', () {
      final v = ScrapScanEngine.evaluate(
        tyre: _tyre(),
        sessionUids: const {},
        operatorId: 816,
        registration: 'KH58XD',
      );
      expect(v.isSuccess, isTrue);
      expect(v.sound, ScrapScanSound.success);
      final accepted = v as ScrapScanAccepted;
      expect(accepted.message, contains('SCRAPS'));
    });

    test('non-scrap tyre is rejected', () {
      final v = ScrapScanEngine.evaluate(
        tyre: _tyre(rejectAccepted: 0),
        sessionUids: const {},
        operatorId: 816,
        registration: 'KH58XD',
      );
      expect(v.message, contains('Not a scrap'));
      expect(v.sound, ScrapScanSound.error);
    });

    test('operator missing is rejected', () {
      final v = ScrapScanEngine.evaluate(
        tyre: _tyre(),
        sessionUids: const {},
        operatorId: null,
        registration: 'KH58XD',
      );
      expect(v.message, contains('Operator not found'));
    });

    test('empty registration is rejected', () {
      final v = ScrapScanEngine.evaluate(
        tyre: _tyre(),
        sessionUids: const {},
        operatorId: 816,
        registration: '',
      );
      expect(v.message, contains('REG'));
    });

    test('session duplicate is rejected', () {
      final v = ScrapScanEngine.evaluate(
        tyre: _tyre(),
        sessionUids: {'04A3F9E1C2B4D5'},
        operatorId: 816,
        registration: 'KH58XD',
      );
      expect(v.message, contains('Already counted'));
    });

    test('dumped tyre is rejected before the scrap gate', () {
      final v = ScrapScanEngine.evaluate(
        tyre: _tyre(dump: 1),
        sessionUids: const {},
        operatorId: 816,
        registration: 'KH58XD',
      );
      expect(v.message, contains('dumped'));
    });
  });
}
