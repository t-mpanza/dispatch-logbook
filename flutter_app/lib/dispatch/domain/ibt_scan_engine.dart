import '../../data/models/ibt_manifest.dart';
import '../../data/models/loading_sheet_trip.dart';
import '../models/slip_tyre.dart';

/// Binary outcome — drives the sound. Exactly two sounds exist: correct
/// and wrong; the screen carries the precise reason.
enum ScanSound { success, error }

/// One evaluation of a tyre scan against a trip's IBT manifest.
sealed class ScanVerdict {
  const ScanVerdict();

  bool get isSuccess => false;
  ScanSound get sound => ScanSound.error;
  String get message;
}

final class ScanAccepted extends ScanVerdict {
  const ScanAccepted({
    required this.documentNo,
    required this.lineId,
    required this.line,
  });

  final String documentNo;
  final String lineId;
  final IbtLineItem line;

  @override
  bool get isSuccess => true;
  @override
  ScanSound get sound => ScanSound.success;
  @override
  String get message =>
      'LOADED — ${line.size ?? line.description} · $documentNo';
}

final class ScanRejected extends ScanVerdict {
  const ScanRejected(this.message);
  @override
  final String message;
}

/// Hardened IBT scan gate — mirrors the reference scanner's contract:
/// Client-Retread job gate → size_id+rubber_id match → capacity check.
class IbtScanEngine {
  IbtScanEngine._();

  static const String stockJob = 'Client Retread';

  static bool isStocksJob(String? job) =>
      job != null && job.trim().toUpperCase() == stockJob.toUpperCase();

  /// Evaluate a scanned tyre against the trip's IBT documents.
  ///
  /// [sessionUids] = uids already accepted in this session (no double
  /// counting); [operatorId] = the fixed operator's idFactory_Personnel.
  static ScanVerdict evaluate({
    required LoadingSheetTrip trip,
    required SlipTyre tyre,
    required Set<String> sessionUids,
    required int? operatorId,
  }) {
    if (operatorId == null) {
      return const ScanRejected('Operator not found — check connection');
    }

    final reg = trip.reg.trim();
    if (reg.isEmpty) {
      return const ScanRejected('Set the truck REG first');
    }

    final docs = trip.ibtDocuments;
    if (docs == null || docs.isEmpty) {
      return const ScanRejected('Attach an IBT first');
    }

    final uid = tyre.uid ?? '';
    if (uid.isNotEmpty && sessionUids.contains(uid)) {
      return const ScanRejected('Already counted this session');
    }

    if (tyre.isDump) {
      return const ScanRejected('This tyre is dumped');
    }

    if (!isStocksJob(tyre.job)) {
      return ScanRejected(
        'Not a stocks tyre — job is ${tyre.job ?? 'unknown'}',
      );
    }

    // Candidate lines: size_id + rubber_id must both match.
    final candidates = <(String, IbtLineItem)>[];
    for (final doc in docs) {
      for (final line in doc.lineItems) {
        if (line.sizeId != null &&
            line.rubberId != null &&
            line.sizeId == tyre.sizeId &&
            line.rubberId == tyre.rubberId) {
          candidates.add((doc.documentNo, line));
        }
      }
    }

    if (candidates.isEmpty) {
      final spec = [
        if (tyre.size != null && tyre.size!.isNotEmpty) tyre.size!,
        if (tyre.pattern != null && tyre.pattern!.isNotEmpty) tyre.pattern!,
      ].join(' · ');
      final ibtLabel = docs.map((d) => d.documentNo).join(', ');
      return ScanRejected(
        spec.isEmpty
            ? 'Not on IBT $ibtLabel'
            : '$spec isn\'t on IBT $ibtLabel',
      );
    }

    // Pick the matching line with the most remaining capacity.
    final withCapacity = candidates
        .where((c) => c.$2.loadedQuantity < c.$2.targetTotal)
        .toList();

    if (withCapacity.isEmpty) {
      final allComplete = docs.every((d) => d.isComplete);
      if (allComplete) {
        return const ScanRejected('IBT complete — every line is full');
      }
      final line = candidates.first.$2;
      return ScanRejected(
        'Line full — ${line.loadedQuantity}/${line.targetTotal}',
      );
    }

    withCapacity.sort(
      (a, b) =>
          (b.$2.targetTotal - b.$2.loadedQuantity)
              .compareTo(a.$2.targetTotal - a.$2.loadedQuantity),
    );
    final best = withCapacity.first;
    return ScanAccepted(
      documentNo: best.$1,
      lineId: best.$2.id,
      line: best.$2,
    );
  }
}
