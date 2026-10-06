import '../../data/models/ibt_manifest.dart';

/// One search hit with its match strength — lower rank = better match.
class IbtSearchHit {
  final IbtLineItem line;
  final int rank;

  const IbtSearchHit(this.line, this.rank);
}

/// Smart IBT line search — the star feature.
///
/// Matches tokens against size, pattern (rubber), RCS code and description,
/// case-insensitively. Ranking:
///   0 = size token exact match
///   1 = size starts-with
///   2 = pattern exact / starts-with
///   3 = any other contains match
class IbtSearch {
  IbtSearch._();

  static bool matches(IbtLineItem line, String query) {
    if (query.trim().isEmpty) return true;
    final q = query.trim().toLowerCase();
    final haystacks = [
      (line.size ?? '').toLowerCase(),
      (line.rubber ?? '').toLowerCase(),
      (line.rcsCode ?? '').toLowerCase(),
      line.description.toLowerCase(),
    ];
    return haystacks.any((h) => h.contains(q));
  }

  static int rankFor(IbtLineItem line, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return 99;
    final size = (line.size ?? '').toLowerCase();
    final rubber = (line.rubber ?? '').toLowerCase();
    if (size == q) return 0;
    if (size.startsWith(q)) return 1;
    if (rubber == q) return 2;
    if (rubber.startsWith(q)) return 2;
    return 3;
  }

  /// Filters + ranks lines. [patternFilter] (optional) restricts to a
  /// specific rubber pattern; text query and pattern filter combine (AND).
  static List<IbtSearchHit> search(
    List<IbtLineItem> lines, {
    String query = '',
    String? patternFilter,
  }) {
    final q = query.trim();
    final hits = <IbtSearchHit>[];
    for (final line in lines) {
      if (patternFilter != null &&
          (line.rubber ?? '').toUpperCase() != patternFilter.toUpperCase()) {
        continue;
      }
      if (!matches(line, q)) continue;
      hits.add(IbtSearchHit(line, rankFor(line, q)));
    }
    hits.sort((a, b) {
      final byRank = a.rank.compareTo(b.rank);
      if (byRank != 0) return byRank;
      // Keep manifest order for ties.
      return lines.indexOf(a.line).compareTo(lines.indexOf(b.line));
    });
    return hits;
  }

  /// Distinct patterns present in the lines (order of first appearance),
  /// as (pattern, count) pairs.
  static List<(String, int)> patternCounts(List<IbtLineItem> lines) {
    final counts = <String, int>{};
    final order = <String>[];
    for (final line in lines) {
      final p = (line.rubber ?? '').trim().toUpperCase();
      if (p.isEmpty) continue;
      if (!counts.containsKey(p)) {
        order.add(p);
        counts[p] = 0;
      }
      counts[p] = counts[p]! + 1;
    }
    return [for (final p in order) (p, counts[p]!)];
  }
}
