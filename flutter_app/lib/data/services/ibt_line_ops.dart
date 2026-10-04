import '../../core/utils/id_generator.dart';
import '../models/ibt_manifest.dart';
import '../models/loading_sheet_trip.dart';

/// Result of applying a delta to a single IBT line item.
class IbtLineDeltaResult {
  final LoadingSheetTrip trip; // Fully-updated trip (docs + totals)
  final IbtLineItem line; // The updated line item
  final int appliedDelta; // What actually got applied (after clamping)
  final bool wasClamped; // True when the manifest target capped the delta
  final bool completed; // True when this change completes the line
  final bool uncompleted; // True when this change moved a done line back

  const IbtLineDeltaResult({
    required this.trip,
    required this.line,
    required this.appliedDelta,
    required this.wasClamped,
    required this.completed,
    required this.uncompleted,
  });
}

/// Pure, shared IBT line-item tally engine.
///
/// Every quantity change — stepper tap, quick pill, fill, keypad edit, or
/// undo — flows through here so the manifest cap, the per-line history and
/// the cross-trip totals behave identically everywhere.
class IbtLineOps {
  /// Apply [delta] (positive or negative) to the given line.
  ///
  /// The manifest target is a hard limit: the delta is clamped so the line
  /// can never exceed [IbtLineItem.targetTotal]. The clamped change is
  /// appended to the line's history so operators can always see (and undo)
  /// what they just added.
  static IbtLineDeltaResult applyDelta({
    required LoadingSheetTrip trip,
    required String documentNo,
    required String lineItemId,
    required int delta,
    int? nowMs,
  }) {
    final docs = [...?trip.ibtDocuments];
    final docIdx = docs.indexWhere(
      (d) => d.documentNo.toUpperCase() == documentNo.toUpperCase(),
    );
    if (docIdx < 0) {
      throw ArgumentError('IBT document not found on trip: $documentNo');
    }

    final doc = docs[docIdx];
    final lines = [...doc.lineItems];
    final lineIdx = lines.indexWhere((l) => l.id == lineItemId);
    if (lineIdx < 0) {
      throw ArgumentError('IBT line item not found: $lineItemId');
    }

    final line = lines[lineIdx];
    final wasComplete = line.isComplete;
    var applied = delta;

    if (applied > 0 && line.loadedQuantity + applied > line.targetTotal) {
      applied = line.targetTotal - line.loadedQuantity;
    }
    if (applied < 0 && line.loadedQuantity + applied < 0) {
      applied = -line.loadedQuantity;
    }

    final wasClamped = applied != delta;
    final newQty = line.loadedQuantity + applied;
    final at = nowMs ?? DateTime.now().millisecondsSinceEpoch;

    final updatedLine = line.copyWith(
      loadedQuantity: newQty,
      history: [...line.history, IbtLineEvent(id: IdGenerator.generate(), delta: applied, at: at)],
    );
    lines[lineIdx] = updatedLine;

    final updatedDoc = doc.copyWith(lineItems: lines);
    docs[docIdx] = updatedDoc;

    final totalLoaded = docs.fold<int>(0, (s, d) => s + d.loadedTotal);
    final updatedTrip = trip.copyWith(
      ibtDocuments: docs,
      quantityLoaded: totalLoaded,
      startTime: trip.startTime ?? at,
      finishTime: at,
    );

    return IbtLineDeltaResult(
      trip: updatedTrip,
      line: updatedLine,
      appliedDelta: applied,
      wasClamped: wasClamped,
      completed: !wasComplete && updatedLine.isComplete,
      uncompleted: wasComplete && !updatedLine.isComplete,
    );
  }

  /// Set an absolute quantity for a line (keypad entry / edit). Clamps to
  /// the manifest target and logs the effective delta in the history.
  static IbtLineDeltaResult setQuantity({
    required LoadingSheetTrip trip,
    required String documentNo,
    required String lineItemId,
    required int newQuantity,
    int? nowMs,
  }) {
    final docs = [...?trip.ibtDocuments];
    final docIdx = docs.indexWhere(
      (d) => d.documentNo.toUpperCase() == documentNo.toUpperCase(),
    );
    if (docIdx < 0) {
      throw ArgumentError('IBT document not found on trip: $documentNo');
    }
    final line = docs[docIdx].lineItems.firstWhere(
      (l) => l.id == lineItemId,
      orElse: () => throw ArgumentError(
        'IBT line item not found: $lineItemId',
      ),
    );
    return applyDelta(
      trip: trip,
      documentNo: documentNo,
      lineItemId: lineItemId,
      delta: newQuantity - line.loadedQuantity,
      nowMs: nowMs,
    );
  }

  /// Revert the most recent change on a line (undo last).
  /// Returns null when there is nothing to undo.
  static IbtLineDeltaResult? undoLast({
    required LoadingSheetTrip trip,
    required String documentNo,
    required String lineItemId,
    int? nowMs,
  }) {
    final docs = [...?trip.ibtDocuments];
    final docIdx = docs.indexWhere(
      (d) => d.documentNo.toUpperCase() == documentNo.toUpperCase(),
    );
    if (docIdx < 0) return null;
    final line = docs[docIdx].lineItems.firstWhere(
      (l) => l.id == lineItemId,
      orElse: () => throw ArgumentError(
        'IBT line item not found: $lineItemId',
      ),
    );
    final last = line.lastEvent;
    if (last == null) return null;
    return applyDelta(
      trip: trip,
      documentNo: documentNo,
      lineItemId: lineItemId,
      delta: -last.delta,
      nowMs: nowMs,
    );
  }

  /// Undo ONE specific historical batch (identified by its event id).
  /// The compensating change is appended to the history so every correction
  /// stays fully auditable. Returns null when the event no longer exists.
  static IbtLineDeltaResult? undoBatch({
    required LoadingSheetTrip trip,
    required String documentNo,
    required String lineItemId,
    required String eventId,
    int? nowMs,
  }) {
    final docs = [...?trip.ibtDocuments];
    final docIdx = docs.indexWhere(
      (d) => d.documentNo.toUpperCase() == documentNo.toUpperCase(),
    );
    if (docIdx < 0) return null;
    final line = docs[docIdx].lineItems.firstWhere(
      (l) => l.id == lineItemId,
      orElse: () => throw ArgumentError(
        'IBT line item not found: $lineItemId',
      ),
    );
    IbtLineEvent? event;
    for (final e in line.history) {
      if (e.id == eventId) {
        event = e;
        break;
      }
    }
    if (event == null) return null;
    return applyDelta(
      trip: trip,
      documentNo: documentNo,
      lineItemId: lineItemId,
      delta: -event.delta,
      nowMs: nowMs,
    );
  }
}
