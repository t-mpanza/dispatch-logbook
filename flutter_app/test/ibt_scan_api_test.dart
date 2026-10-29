import 'package:flutter_test/flutter_test.dart';
import 'package:dispatch_diary/dispatch/ibt_scan_api.dart';

void main() {
  group('IbtScanApi — mutation contract', () {
    test('buildScanPayload matches createDispatchDeliveryINV_V2 exactly', () {
      final payload = IbtScanApi.buildScanPayload(
        uid: '04A3F9E1C2B4D5',
        registration: 'MN05XNGP',
        personnelId: 7,
        documentNo: 'IBT122773',
      );
      expect(payload, {
        'uid': '04A3F9E1C2B4D5',
        'registration': 'MN05XNGP',
        'personnel_id': 7,
        'document_no': 'IBT122773',
        'loaded': 1,
        'location_id': 12,
      });
    });

    test('payload honours the offload flag', () {
      final payload = IbtScanApi.buildScanPayload(
        uid: '04A3F9E1C2B4D5',
        registration: 'MN05XNGP',
        personnelId: 7,
        documentNo: 'IBT122773',
        loaded: 0,
        location: 13,
      );
      expect(payload['loaded'], 0);
      expect(payload['location_id'], 13);
    });

    test('successful == 1 → ScanCommitSuccess', () {
      final result = IbtScanApi.parseCommitResponse({
        'createDispatchDeliveryINV_V2': [
          {
            'successful': 1,
            'duplicate_scan': 0,
            'name': 'Theolus',
            'scan_time': '2026-10-28T08:15:00',
          },
        ],
      });
      expect(result, isA<ScanCommitSuccess>());
    });

    test('duplicate_scan == 1 → ScanCommitDuplicate with loader info', () {
      final result = IbtScanApi.parseCommitResponse({
        'createDispatchDeliveryINV_V2': [
          {
            'successful': '0',
            'duplicate_scan': '1',
            'name': 'Neil',
            'scan_time': '2026-10-27T16:40:00',
          },
        ],
      });
      final duplicate = result as ScanCommitDuplicate;
      expect(duplicate.name, 'Neil');
      expect(duplicate.scanTime, '2026-10-27T16:40:00');
    });

    test('successful == 0 and no duplicate → ScanCommitRejected', () {
      final result = IbtScanApi.parseCommitResponse({
        'createDispatchDeliveryINV_V2': [
          {'successful': 0, 'duplicate_scan': 0},
        ],
      });
      expect(result, isA<ScanCommitRejected>());
    });

    test('missing row tolerates empty shapes', () {
      final result = IbtScanApi.parseCommitResponse({});
      expect(result, isA<ScanCommitRejected>());
    });
  });
}
