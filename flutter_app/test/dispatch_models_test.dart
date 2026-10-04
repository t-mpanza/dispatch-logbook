import 'package:flutter_test/flutter_test.dart';
import 'package:dispatch_diary/dispatch/models/dispatch_models.dart';
import 'package:dispatch_diary/dispatch/models/slip_tyre.dart';

void main() {
  group('SlipTyre parsing & flags', () {
    test('parses a full live-shaped payload with mixed types', () {
      final tyre = SlipTyre.fromJson({
        'uid': '04A3F9E1C2B4D5',
        'idSlip': 1024,
        'slip_number': '900123',
        'pattern': 'M38',
        'CustomerName': 'ATT TYRES',
        'cs_number': 71,
        'make': 'BRIDGESTONE',
        'size': '12R22.5',
        'serial': 'X123456',
        'loaded': '1',
        'reject_accepted': 0,
        'dump': 0,
        'job': 'Claim',
        'on_rim': 1,
        'location_id': '8',
      });

      expect(tyre.uid, '04A3F9E1C2B4D5');
      expect(tyre.idSlip, 1024);
      expect(tyre.slipNumber, 900123);
      expect(tyre.csNumber, '71');
      expect(tyre.isLoaded, isTrue);
      expect(tyre.isOnRim, isTrue);
      expect(tyre.isClaim, isTrue);
      expect(tyre.isDump, isFalse);
      expect(tyre.locationId, 8);
    });

    test('displayLabel joins size · make · pattern', () {
      const tyre = SlipTyre(size: '12R22.5', make: 'BRIDGESTONE', pattern: 'M38');
      expect(tyre.displayLabel, '12R22.5 · BRIDGESTONE · M38');
      const bare = SlipTyre(serial: 'S-1');
      expect(bare.displayLabel, 'S-1');
      const empty = SlipTyre();
      expect(empty.displayLabel, 'Tyre');
    });

    test('scrap detection via dump and reject flags', () {
      expect(
        SlipTyre.fromJson({'dump': 1}).isScrap,
        isTrue,
      );
      expect(
        SlipTyre.fromJson({'reject_accepted': 2}).isScrap,
        isTrue,
      );
      expect(
        SlipTyre.fromJson({'serial': 'DUD-101'}).isScrap,
        isTrue,
      );
      expect(
        SlipTyre.fromJson({'reject_accepted': 1}).isScrap,
        isFalse,
      );
    });

    test('tolerates nulls everywhere', () {
      final tyre = SlipTyre.fromJson({});
      expect(tyre.uid, isNull);
      expect(tyre.isLoaded, isFalse);
      expect(tyre.displayLabel, 'Tyre');
    });
  });

  group('board DTO parsing', () {
    test('DispatchTyre parses tyres-at-dispatch rows', () {
      final t = DispatchTyre.fromJson({
        'idSlip': 1,
        'slip_number': 2,
        'cs_number': 'CS-9',
        'CustomerName': 'CUSTOMER A',
        'size': '315/80R22.5',
        'make': 'MAKE',
        'serial': 'SER',
        'pattern': 'M90L',
        'at_dispatch': 1,
        'invoiced': 1,
        'through_dispatch_inspection': 0,
        'first_in_time': '2026-10-04T06:00:00',
        'EVO_status': 'STOCK',
        'idConfirmation_Sheet': 5,
      });
      expect(t.displayLabel, '315/80R22.5 · MAKE · M90L');
      expect(t.customerName, 'CUSTOMER A');
      expect(t.invoiced, 1);
    });

    test('OutstandingBatch parses defensive numbers', () {
      final b = OutstandingBatch.fromJson({
        'slips': '14',
        'CustomerName': 'BATCH CO',
        'cs_number': 'CS-3',
        'at_dispatch': 1,
        'first_in_time': '06:00',
        'last_out_time': null,
      });
      expect(b.slips, 14);
      expect(b.customerName, 'BATCH CO');
    });

    test('LateBatchTyre tolerates missing optional fields', () {
      final t = LateBatchTyre.fromJson({'slip_number': 3});
      expect(t.slipNumber, 3);
      expect(t.customerName, isNull);
    });

    test('ShiftTotal parses numbers-as-strings', () {
      final s = ShiftTotal.fromJson({
        'work_cell_name': 'PEELING',
        'number_of_tyres': '88',
        'work_cell_id': 2,
        'cell_quota': '120',
      });
      expect(s.numberOfTyres, 88);
      expect(s.cellQuota, 120);
    });

    test('TyreHistoryEntry parses scan rows', () {
      final h = TyreHistoryEntry.fromJson({
        'first_name': 'Theolus',
        'last_name': 'M',
        'work_cell_name': 'REJECT EXIT',
        'scan_in_time': '2026-10-04T07:15:00',
        'scan_out': 1,
      });
      expect(h.operatorName, 'Theolus M');
      expect(h.workCellName, 'REJECT EXIT');
      expect(h.newestTimestamp, '2026-10-04T07:15:00');
    });

    test('SlipDetail parses the long slip row defensively', () {
      final s = SlipDetail.fromJson({
        'idSlip': 99,
        'slip_number': '100',
        'cs_id': 8,
        'reject_accepted': '2',
        'casing_grade': 'A1',
        'created_at': '2026-10-01',
      });
      expect(s.idSlip, 99);
      expect(s.csId, 8);
      expect(s.rejectAccepted, 2);
      expect(s.casingGrade, 'A1');
    });

    test('ActiveDispatchSession parses mixed-case columns', () {
      final s = ActiveDispatchSession.fromJson({
        'idDispatch_Session': 7,
        'iLocation_ID': 2,
        'cLocation': 'DISPATCH BAY',
        'iPersonnel_ID': 11,
        'cName': 'NEIL',
        'bPrep': 0,
        'dStart_Time': '2026-10-04T05:59:00',
      });
      expect(s.idDispatchSession, 7);
      expect(s.cLocation, 'DISPATCH BAY');
      expect(s.cName, 'NEIL');
    });
  });
}
