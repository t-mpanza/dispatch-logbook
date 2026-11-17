import '../../data/models/ibt_manifest.dart';
import '../../data/models/staged_document.dart';
import '../models/slip_tyre.dart';
import 'document_number.dart' show DocumentStream;
import 'ibt_scan_engine.dart' show ScanSound, IbtScanEngine;

/// The multi-document routing engine — the head-down scanning brain
/// (decisions D2–D7, D9, D17 in docs/mvp-tracking.md).
///
/// Every staged document on the truck is live at once; a scan routes by
/// precedence. Anything the engine cannot decide with certainty FAILS
/// LOUD (error sound + hard haptic): silence + chime means the tyre went
/// exactly where it belongs.
sealed class MultiDocScanVerdict {
  const MultiDocScanVerdict();

  bool get isSuccess => false;
  ScanSound get sound => ScanSound.error;
  String get message;
}

/// Routed into a staged document (membership or IBT line fit).
final class AcceptedIntoDocument extends MultiDocScanVerdict {
  const AcceptedIntoDocument({
    required this.documentNo,
    this.lineId,
    this.line,
  });

  final String documentNo;
  final String? lineId;
  final IbtLineItem? line;

  @override
  bool get isSuccess => true;
  @override
  ScanSound get sound => ScanSound.success;
  @override
  String get message =>
      'LOADED — ${line != null ? '${line!.description} · ' : ''}$documentNo';
}

/// Cash mode is armed and nothing claimed the tyre (D7).
final class AcceptedAsCash extends MultiDocScanVerdict {
  const AcceptedAsCash();

  @override
  bool get isSuccess => true;
  @override
  ScanSound get sound => ScanSound.success;
  @override
  String get message => 'LOADED — CASH';
}

/// The tyre is on TWO staged documents — the only interrupt (D4).
final class AmbiguousDocument extends MultiDocScanVerdict {
  const AmbiguousDocument(this.documentNos);

  final List<String> documentNos;

  @override
  String get message => 'On ${documentNos.join(' and ')} — apply to both?';
}

/// Already on OUR truck — show the offload yes/no window (D5).
final class OffloadPrompt extends MultiDocScanVerdict {
  const OffloadPrompt({this.previousReg});

  final String? previousReg;

  @override
  String get message => 'OFFLOAD? — already on this truck';
}

/// Loaded on ANOTHER truck — never steal (D3).
final class Collision extends MultiDocScanVerdict {
  const Collision(this.previousReg);

  final String previousReg;

  @override
  String get message => 'On another truck — $previousReg';
}

/// dump == 1 blocks in every mode, always loud (D6).
final class DumpedTyre extends MultiDocScanVerdict {
  const DumpedTyre();

  @override
  String get message => 'This tyre is dumped';
}

/// Cash armed, but the tyre belongs to a staged document — fail loud and
/// prompt the untoggle (D7).
final class UntoggleCashPrompt extends MultiDocScanVerdict {
  const UntoggleCashPrompt(this.documentNo);

  final String documentNo;

  @override
  String get message => 'On $documentNo — untoggle cash?';
}

/// Guard failure or the tyre simply is not on this truck.
final class Rejected extends MultiDocScanVerdict {
  const Rejected(this.message);

  @override
  final String message;
}

class MultiDocScanEngine {
  MultiDocScanEngine._();

  /// [stagedDocs] = every document cached on the truck; [cashArmed] =
  /// the cash toggle state; [sessionUids] = uids accepted this session.
  static MultiDocScanVerdict evaluate({
    required List<StagedDocument> stagedDocs,
    required SlipTyre tyre,
    required Set<String> sessionUids,
    required bool cashArmed,
    required int? operatorId,
    required String registration,
  }) {
    if (operatorId == null) {
      return const Rejected('Operator not found');
    }
    final reg = registration.trim().toUpperCase();
    if (reg.isEmpty) {
      return const Rejected('Set the truck REG first');
    }

    // D6 — dump blocks in every mode, before anything else.
    if (tyre.isDump) {
      return const DumpedTyre();
    }

    final uid = tyre.uid ?? '';

    // D5 — a re-scan of something we already accepted this session is
    // the offload gesture.
    if (uid.isNotEmpty && sessionUids.contains(uid)) {
      return const OffloadPrompt();
    }

    // Loaded state across the staged manifests: own truck → offload
    // window; another truck → collision.
    final loadedState = _findLoadedState(stagedDocs, tyre);
    if (loadedState != null) {
      final prev = (loadedState.$1 ?? '').trim().toUpperCase();
      if (prev.isNotEmpty && prev != reg) {
        return Collision(loadedState.$1!);
      }
      return OffloadPrompt(previousReg: loadedState.$1);
    }

    if (cashArmed) {
      return _cashMode(stagedDocs, tyre);
    }

    return _autoMode(stagedDocs, tyre, uid);
  }

  /// Cash armed (D7): membership OR IBT fit fails loud with the untoggle
  /// prompt; anything else counts as cash.
  static MultiDocScanVerdict _cashMode(
    List<StagedDocument> stagedDocs,
    SlipTyre tyre,
  ) {
    final onDoc = _docsContaining(stagedDocs, tyre);
    if (onDoc.isNotEmpty) {
      return UntoggleCashPrompt(onDoc.first.documentNo);
    }
    final ibtFit = _firstIbtFit(stagedDocs, tyre, requireCapacity: false);
    if (ibtFit != null) {
      return UntoggleCashPrompt(ibtFit.$1.documentNo);
    }
    return const AcceptedAsCash();
  }

  /// Automatic routing (D3): exact membership across ALL staged
  /// manifests first, IBT classification second, loud rejection last.
  static MultiDocScanVerdict _autoMode(
    List<StagedDocument> stagedDocs,
    SlipTyre tyre,
    String uid,
  ) {
    final onDocs = _docsContaining(stagedDocs, tyre);
    if (onDocs.length == 1) {
      return AcceptedIntoDocument(documentNo: onDocs.single.documentNo);
    }
    if (onDocs.length > 1) {
      // D4 — the one genuine ambiguity: same tyre on two documents.
      return AmbiguousDocument(
        onDocs.map((d) => d.documentNo).toList(growable: false),
      );
    }

    // No manifest membership — IBT classification (first line first,
    // spill to the next when full).
    if (IbtScanEngine.isStocksJob(tyre.job)) {
      final fit = _firstIbtFit(stagedDocs, tyre, requireCapacity: true);
      if (fit != null) {
        return AcceptedIntoDocument(
          documentNo: fit.$1.documentNo,
          lineId: fit.$2.id,
          line: fit.$2,
        );
      }
      final anyMatchingLine = _firstIbtFit(
        stagedDocs,
        tyre,
        requireCapacity: false,
      );
      if (anyMatchingLine != null) {
        return Rejected(
          'IBT full — ${anyMatchingLine.$2.description} '
          '${anyMatchingLine.$2.loadedQuantity}/${anyMatchingLine.$2.targetTotal}',
        );
      }
    }

    return Rejected('Not on this truck');
  }

  /// Staged manifests that contain the tyre — by uid, or by slip number
  /// when the uid is unknown (D9). IBT documents carry no slips.
  static List<StagedDocument> _docsContaining(
    List<StagedDocument> stagedDocs,
    SlipTyre tyre,
  ) {
    final uid = tyre.uid ?? '';
    final slip = tyre.slipNumber;
    return [
      for (final d in stagedDocs)
        if (d.stream != DocumentStream.ibt &&
            ((uid.isNotEmpty && d.containsUid(uid)) ||
                (slip != null && d.containsSlip(slip))))
          d,
    ];
  }

  /// First IBT line that fits the tyre (job gate assumed by the caller
  /// where needed), walking documents then lines IN MANIFEST ORDER —
  /// first line first, spill to the next when full (D3).
  static (StagedDocument, IbtLineItem)? _firstIbtFit(
    List<StagedDocument> stagedDocs,
    SlipTyre tyre, {
    required bool requireCapacity,
  }) {
    for (final doc in stagedDocs) {
      if (!doc.isIbt) continue;
      for (final line in doc.lineItems) {
        if (line.sizeId == null ||
            line.rubberId == null ||
            line.sizeId != tyre.sizeId ||
            line.rubberId != tyre.rubberId) {
          continue;
        }
        if (!requireCapacity || line.loadedQuantity < line.targetTotal) {
          return (doc, line);
        }
      }
    }
    return null;
  }

  static (String?, int?)? _findLoadedState(
    List<StagedDocument> stagedDocs,
    SlipTyre tyre,
  ) {
    final uid = tyre.uid ?? '';
    final slip = tyre.slipNumber;
    for (final doc in stagedDocs) {
      for (final s in doc.slips) {
        final same = (uid.isNotEmpty && s.uid == uid) ||
            (slip != null && s.slipNumber == slip);
        if (same && s.isLoaded) {
          return (s.previousReg, s.slipNumber);
        }
      }
    }
    return null;
  }
}
