/// Document streams accepted by the backend.
enum DocumentStream {
  inv('INV', 'Invoice'),
  dibt('DIBT', 'DIBT'),
  ibt('IBT', 'IBT'),
  amsInv('AMS', 'AMS'),
  rejects('REJ', 'Rejects');

  const DocumentStream(this.code, this.label);

  final String code;
  final String label;
}

/// Smart document-number parsing for staging.
///
/// The operator picks the stream chip (INV/DIBT/IBT/AMS) as the default.
/// Typing `2392908` yields `INV2392908` under the INV chip; typing a full
/// prefixed number (`DIBT0179154`) overrides the chip — the prefix wins.
class DocumentNumberParser {
  DocumentNumberParser._();

  static const Map<String, DocumentStream> _prefixStreams = {
    'INV': DocumentStream.inv,
    'DIBT': DocumentStream.dibt,
    'IBT': DocumentStream.ibt,
    'AMS': DocumentStream.amsInv,
    'REJ': DocumentStream.rejects,
  };

  /// Canonical document number for [input] given the selected [fallback]
  /// stream chip. Returns `(stream, number)` — the number carries the
  /// prefix (e.g. `INV2392908`), which is what the backend expects.
  static (DocumentStream, String)? parse(
    String input,
    DocumentStream fallback,
  ) {
    final trimmed = input.trim().toUpperCase();
    if (trimmed.isEmpty) return null;
    for (final entry in _prefixStreams.entries) {
      if (trimmed.startsWith(entry.key)) {
        return (entry.value, trimmed);
      }
    }
    if (fallback == DocumentStream.rejects) {
      return (DocumentStream.rejects, 'SCRAPS');
    }
    return (fallback, '${fallback.code}$trimmed');
  }
}
