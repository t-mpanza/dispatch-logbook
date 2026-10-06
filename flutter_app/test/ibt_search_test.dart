import 'package:flutter_test/flutter_test.dart';
import 'package:dispatch_diary/data/models/ibt_manifest.dart';
import 'package:dispatch_diary/dispatch/domain/ibt_search.dart';

IbtLineItem _line({
  required String id,
  String size = '315/80R22.5',
  String? rubber,
  String? rcs,
  String description = '',
}) {
  return IbtLineItem(
    id: id,
    description: description.isEmpty ? '$size ${rubber ?? ''}'.trim() : description,
    rcsCode: rcs,
    size: size,
    rubber: rubber,
    targetTotal: 10,
  );
}

void main() {
  group('IbtSearch — the star feature', () {
    final lines = [
      _line(id: 'l1', size: '12R22.5', rubber: 'M38', rcs: 'RCS097'),
      _line(id: 'l2', size: '315/80R22.5', rubber: 'M100', rcs: 'RCS527'),
      _line(id: 'l3', size: '315/80R22.5', rubber: 'M38', rcs: 'RCS037'),
      _line(id: 'l4', size: '315/80R22.5', rubber: 'M43', rcs: 'RCS039'),
      _line(id: 'l5', size: '315/80R22.5', rubber: 'M90L', rcs: 'RCS317'),
      _line(id: 'l6', size: '11R22.5', rubber: 'MM84', rcs: 'RCS791'),
    ];

    test('size search ranks exact/prefix matches first', () {
      final hits = IbtSearch.search(lines, query: '12R');
      expect(hits.map((h) => h.line.id).toList(), ['l1']);
    });

    test('pattern search finds all lines with that pattern', () {
      final hits = IbtSearch.search(lines, query: 'm38');
      expect(hits.map((h) => h.line.id).toList(), ['l1', 'l3']);
    });

    test('rcs search matches rcs codes', () {
      final hits = IbtSearch.search(lines, query: 'RCS037');
      expect(hits.map((h) => h.line.id).toList(), ['l3']);
    });

    test('description search matches too', () {
      final linesWithDesc = [
        ...lines,
        _line(
          id: 'l7',
          size: '12R22.5',
          rubber: 'RD2+',
          description: '12R22.5 RD2+ STOCK RETREAD',
        ),
      ];
      final hits = IbtSearch.search(linesWithDesc, query: 'RETREAD');
      expect(hits.map((h) => h.line.id).toList(), ['l7']);
    });

    test('size prefix ranks above pattern contains', () {
      final hits = IbtSearch.search(lines, query: '315');
      expect(hits.first.line.id, 'l2'); // 315/80R22.5 M100 — first 315 in order
      expect(hits.every((h) => (h.line.size ?? '').contains('315')), isTrue);
    });

    test('empty query returns everything in manifest order', () {
      final hits = IbtSearch.search(lines);
      expect(hits.map((h) => h.line.id).toList(),
          ['l1', 'l2', 'l3', 'l4', 'l5', 'l6']);
    });

    test('pattern filter and text query combine (AND)', () {
      final hits = IbtSearch.search(lines, query: '315', patternFilter: 'M38');
      expect(hits.map((h) => h.line.id).toList(), ['l3']);
    });

    test('patternCounts returns first-appearance order with counts', () {
      final counts = IbtSearch.patternCounts(lines);
      expect(counts, [('M38', 2), ('M100', 1), ('M43', 1), ('M90L', 1), ('MM84', 1)]);
    });

    test('patternCounts skips lines without patterns', () {
      final counts = IbtSearch.patternCounts([
        _line(id: 'a', rubber: null),
        _line(id: 'b', rubber: 'M38'),
      ]);
      expect(counts, [('M38', 1)]);
    });

    test('no matches returns empty', () {
      expect(IbtSearch.search(lines, query: 'zzzz'), isEmpty);
    });

    test('case and whitespace insensitive', () {
      final hits = IbtSearch.search(lines, query: '  M90L ');
      expect(hits.map((h) => h.line.id).toList(), ['l5']);
    });
  });
}
