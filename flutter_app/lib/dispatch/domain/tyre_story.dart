import '../dispatch_api.dart';
import '../models/dispatch_models.dart';
import '../models/slip_tyre.dart';

/// The complete story of a tyre: spec, CS/customer, invoice, current
/// location and scan history (who, when, where).
class TyreStory {
  const TyreStory({
    required this.tyre,
    this.slip,
    this.history = const [],
  });

  final SlipTyre tyre;
  final SlipDetail? slip;
  final List<TyreHistoryEntry> history;

  /// True when the scan history contains a DISPATCH DELIVERY entry — the
  /// tyre has left the warehouse.
  bool get hasDispatchDelivery =>
      history.any((h) => (h.workCellName ?? '').toUpperCase().contains('DISPATCH DELIVERY'));

  bool get isScrapWithHistory => tyre.isScrap ||
      history.any(
        (h) =>
            (h.workCellName ?? '').toUpperCase().contains('REJECT'),
      );
}

/// Resolves a tyre story from a slip number, serial or UID. Read-only.
class TyreStoryUsecase {
  const TyreStoryUsecase();

  Future<TyreStory?> bySlipNumber(int slipNumber) async {
    final slip = await DispatchApi.fetchSlipWithNumber(slipNumber);
    if (slip == null) return null;

    SlipTyre? tyre;
    if (slip.csId != null) {
      final csTyres = await DispatchApi.fetchTyreByCsId(slip.csId);
      for (final t in csTyres) {
        if (t.idSlip == slip.idSlip) {
          tyre = t;
          break;
        }
      }
    }
    tyre ??= SlipTyre(
      idSlip: slip.idSlip,
      slipNumber: slipNumber,
      invoiceNumber: slip.invoiceNumber,
      rejectAccepted: slip.rejectAccepted,
    );

    final history = slip.idSlip == null
        ? const <TyreHistoryEntry>[]
        : _newestFirst(await DispatchApi.fetchTyreHistory(slip.idSlip!));

    return TyreStory(tyre: tyre, slip: slip, history: history);
  }

  /// Slip number (the operator's "cab number") or job-number fallback.
  Future<TyreStory?> bySlipOrJobNumber(int number) async {
    final bySlip = await bySlipNumber(number);
    if (bySlip != null) return bySlip;
    final serial = await DispatchApi.fetchSerialByJobNumber(number);
    if (serial == null || serial.isEmpty) return null;
    return bySerial(serial);
  }

  Future<TyreStory?> bySerial(String serial) async {
    final tyre = await DispatchApi.fetchTyreBySerial(serial);
    if (tyre == null) return null;
    final slipNumber = tyre.slipNumber;
    if (slipNumber != null) {
      final story = await bySlipNumber(slipNumber);
      if (story != null) return story;
    }
    return TyreStory(tyre: tyre);
  }

  Future<TyreStory?> byUid(String uid) async {
    final tyre = await DispatchApi.fetchTyreByUid(uid);
    if (tyre == null) return null;
    final history = tyre.idSlip == null
        ? const <TyreHistoryEntry>[]
        : _newestFirst(await DispatchApi.fetchTyreHistory(tyre.idSlip!));
    return TyreStory(tyre: tyre, history: history);
  }

  /// Most recent activity first. No cap — the whole story stays visible.
  static List<TyreHistoryEntry> _newestFirst(List<TyreHistoryEntry> history) {
    final sorted = List<TyreHistoryEntry>.of(history);
    sorted.sort((a, b) {
      final aTime = a.newestTimestamp ?? '';
      final bTime = b.newestTimestamp ?? '';
      return bTime.compareTo(aTime);
    });
    return sorted;
  }
}
