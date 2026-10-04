/// Scrap (failed-tyre) detection — verified against the live backend.
///
/// A tyre is a scrap when ANY of the following holds:
/// 1. `reject_accepted = 2` on the slip row (the reliable flag),
/// 2. the scan history contains a rejects-flow work cell
///    (`REJECT INSPECTOR`, `REJECT EXIT`, `REJECT RETURN`),
/// 3. the backend `dump` flag is 1,
/// 4. a visible code contains `DUD` (older convention).
class ScrapMarker {
  ScrapMarker._();

  /// True when any of the codes contains `DUD` (case-insensitive).
  static bool hasDudCode(Iterable<String?> codes) {
    for (final code in codes) {
      if (code != null && code.toUpperCase().contains('DUD')) return true;
    }
    return false;
  }

  /// True when a scan-history work-cell name belongs to the rejects flow.
  static bool cellMarksReject(String? cell) {
    return cell != null && cell.toUpperCase().contains('REJECT');
  }

  static bool isScrap({
    String? serial,
    String? pattern,
    String? size,
    String? casingCode,
    int? dump,
    int? rejectAccepted,
    Iterable<String?> historyCells = const [],
  }) {
    if ((dump ?? 0) == 1) return true;
    if ((rejectAccepted ?? 0) == 2) return true;
    if (hasDudCode([serial, pattern, size, casingCode])) return true;
    for (final cell in historyCells) {
      if (cellMarksReject(cell)) return true;
    }
    return false;
  }
}
