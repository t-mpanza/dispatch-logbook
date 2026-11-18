import 'package:dispatch_diary/dispatch/ibt_scan_api.dart';
import 'package:flutter_test/flutter_test.dart';

/// #1 (UX audit) — the operator is whoever Settings says, not a
/// hardcoded person. The pure selector picks their personnel row:
/// configured name → active rows → real-badge uid preferred.
void main() {
  Map<String, dynamic> row({
    required int id,
    String first = 'Theolus',
    String last = 'Mpanza',
    String uid = '30000000',
    int active = 1,
  }) =>
      {
        'idFactory_Personnel': id,
        'first_name': first,
        'last_name': last,
        'uid': uid,
        'active': active,
      };

  group('selectOperatorId — the configured-name selector', () {
    test('full name matches first + last', () {
      final rows = [row(id: 1, first: 'Theolus', last: 'Mpanza')];
      expect(IbtScanApi.selectOperatorId(rows, 'Theolus Mpanza'), 1);
    });

    test('first-name-only matches (the settings field holds one name)', () {
      final rows = [
        row(id: 1, first: 'Theolus', last: 'Mpanza'),
        row(id: 2, first: 'Other', last: 'Driver'),
      ];
      expect(IbtScanApi.selectOperatorId(rows, 'Theolus'), 1);
    });

    test('a single token can match the last name too', () {
      final rows = [row(id: 7, first: 'John', last: 'Mpanza')];
      expect(IbtScanApi.selectOperatorId(rows, 'Mpanza'), 7);
    });

    test('case and surrounding whitespace do not matter', () {
      final rows = [row(id: 3, first: 'Theolus', last: 'Mpanza')];
      expect(IbtScanApi.selectOperatorId(rows, '  theolus mpanza  '), 3);
    });

    test('prefers the row with a real badge uid over the 30000000 dup', () {
      final rows = [
        row(id: 1, first: 'Theolus', last: 'Mpanza', uid: '30000000'),
        row(id: 2, first: 'Theolus', last: 'Mpanza', uid: 'ADEE8A04'),
      ];
      expect(IbtScanApi.selectOperatorId(rows, 'Theolus'), 2);
    });

    test('falls back to the active row when no real badge exists', () {
      final rows = [
        row(id: 1, first: 'Theolus', last: 'Mpanza', uid: '30000000'),
        row(id: 2, first: 'Theolus', last: 'Mpanza', uid: '30000000'),
      ];
      expect(IbtScanApi.selectOperatorId(rows, 'Theolus Mpanza'), 1);
    });

    test('inactive rows never match', () {
      final rows = [
        row(id: 1, first: 'Theolus', last: 'Mpanza', active: 0),
        row(id: 2, first: 'Other', last: 'Driver'),
      ];
      expect(IbtScanApi.selectOperatorId(rows, 'Theolus'), isNull);
    });

    test('no match returns null', () {
      expect(IbtScanApi.selectOperatorId(const [], 'Nobody'), isNull);
      expect(
        IbtScanApi.selectOperatorId(
          [row(id: 1, first: 'Other', last: 'Driver')],
          'Theolus',
        ),
        isNull,
      );
    });
  });
}
