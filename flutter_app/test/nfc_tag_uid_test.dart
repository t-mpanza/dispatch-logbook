import 'package:flutter_test/flutter_test.dart';
import 'package:dispatch_diary/dispatch/hardware/nfc_scan_service.dart';

void main() {
  group('NfcTagUid — tag identification', () {
    test('fromBytes joins bytes into uppercase hex', () {
      expect(NfcTagUid.fromBytes([0x04, 0xa3, 0xf9, 0xe1]), '04A3F9E1');
      expect(NfcTagUid.fromBytes([]), isNull);
      expect(NfcTagUid.fromBytes([-1]), isNull);
      expect(NfcTagUid.fromBytes([256]), isNull);
    });

    test('fromBytes can reverse ISO 15693 iOS identifiers', () {
      expect(
        NfcTagUid.fromBytes([0x01, 0x02, 0x03], reverseBytes: true),
        '030201',
      );
    });

    test('normalize trims, uppercases and rejects non-hex', () {
      expect(NfcTagUid.normalize(' 04a3f9e1 '), '04A3F9E1');
      expect(NfcTagUid.normalize('04A3-F9E1'), isNull);
      expect(NfcTagUid.normalize(''), isNull);
      expect(NfcTagUid.normalize('xyz'), isNull);
    });

    test('tyre tags are 14 hex chars, badges 8', () {
      expect(NfcTagUid.isTyreTag('04A3F9E1C2B4D5'), isTrue);
      expect(NfcTagUid.isTyreTag('04A3F9E1'), isFalse);
      expect(NfcTagUid.isPersonnelBadge('04A3F9E1'), isTrue);
      expect(NfcTagUid.isPersonnelBadge('04A3F9E1C2B4D5'), isFalse);
    });
  });
}
