import 'package:flutter_test/flutter_test.dart';
import 'package:dispatch_diary/dispatch/models/json_helpers.dart';

void main() {
  group('json helpers — defensive parsing', () {
    test('jsonInt accepts int, num and numeric strings', () {
      expect(jsonInt(42), 42);
      expect(jsonInt(42.9), 42);
      expect(jsonInt('42'), 42);
      expect(jsonInt('  7 '), 7);
      expect(jsonInt('abc'), isNull);
      expect(jsonInt(null), isNull);
    });

    test('jsonString accepts strings and stringifies numbers', () {
      expect(jsonString('abc'), 'abc');
      expect(jsonString(42), '42');
      expect(jsonString(null), isNull);
    });

    test('jsonMapField accepts maps and single-element list wrappers', () {
      expect(jsonMapField({'a': 1}), {'a': 1});
      expect(jsonMapField([{'a': 1}]), {'a': 1});
      expect(jsonMapField([{'a': 1}, {'b': 2}]), {'a': 1});
      expect(jsonMapField('nope'), const {});
      expect(jsonMapField(null), const {});
    });

    test('jsonMapList tolerates non-lists and filters non-maps', () {
      expect(jsonMapList(null), isEmpty);
      expect(jsonMapList('x'), isEmpty);
      expect(jsonMapList([1, 2]), isEmpty);
      expect(
        jsonMapList([
          {'a': 1},
          2,
          {'b': 3},
        ]),
        [
          {'a': 1},
          {'b': 3},
        ],
      );
    });

    test('or-fallbacks never throw', () {
      expect(jsonStringOr(null, 'x'), 'x');
      expect(jsonIntOr('nope', 9), 9);
      expect(jsonIntOr(5, 9), 5);
    });
  });
}
