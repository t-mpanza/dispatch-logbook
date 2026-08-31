import 'package:flutter_test/flutter_test.dart';
import 'package:dispatch_diary/data/models/preset.dart';

void main() {
  group('PresetEngine Tests', () {
    test('STOCKS dynamic counter increments correctly', () {
      final tripId1 = PresetEngine.getNextStocksTripId([]);
      expect(tripId1, equals('STOCKS 1'));

      final tripId2 = PresetEngine.getNextStocksTripId(['STOCKS 1']);
      expect(tripId2, equals('STOCKS 2'));

      final tripId3 = PresetEngine.getNextStocksTripId(['STOCKS 1', 'STOCKS 2', 'STOCKS 3']);
      expect(tripId3, equals('STOCKS 4'));

      final tripIdOutOfOrder = PresetEngine.getNextStocksTripId(['STOCKS 5', 'STOCKS 1']);
      expect(tripIdOutOfOrder, equals('STOCKS 6'));
    });

    test('NLH preset autofills driver Neil and reg MN05XNGP', () {
      final fill = PresetEngine.getPresetFill(PresetKey.NLH);
      expect(fill.presetKey, equals(PresetKey.NLH));
      expect(fill.tripId, equals('NLH'));
      expect(fill.driverName, equals('Neil'));
      expect(fill.reg, equals('MN05XNGP'));
    });

    test('Custom preset returns empty fields for user entry', () {
      final fill = PresetEngine.getPresetFill(PresetKey.CUSTOM);
      expect(fill.presetKey, equals(PresetKey.CUSTOM));
      expect(fill.tripId, isEmpty);
      expect(fill.driverName, isNull);
      expect(fill.reg, isNull);
    });

    test('Standard destination presets return their key names', () {
      for (final key in [PresetKey.DBN, PresetKey.NLS, PresetKey.BLOEM, PresetKey.PLK, PresetKey.TIREPOINT]) {
        final fill = PresetEngine.getPresetFill(key);
        expect(fill.tripId, equals(key.name));
      }
    });
  });
}
