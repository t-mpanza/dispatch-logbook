import '../models/slip_tyre.dart';

/// Binary outcome for sounds — correct vs everything wrong.
enum ScrapScanSound { success, error }

sealed class ScrapScanVerdict {
  const ScrapScanVerdict();

  bool get isSuccess => false;
  ScrapScanSound get sound => ScrapScanSound.error;
  String get message;
}

final class ScrapScanAccepted extends ScrapScanVerdict {
  const ScrapScanAccepted();

  @override
  bool get isSuccess => true;
  @override
  ScrapScanSound get sound => ScrapScanSound.success;
  @override
  String get message => 'LOADED — SCRAPS';
}

final class ScrapScanRejected extends ScrapScanVerdict {
  const ScrapScanRejected(this.message);
  @override
  final String message;
}

/// The scrap run-out gate — mirrors the reference app's rejects stream:
/// a scrap tyre must carry `reject_accepted == 1`. No target, no manifest:
/// whatever valid scrap scans, counts.
class ScrapScanEngine {
  ScrapScanEngine._();

  /// A tyre qualifies as a scrap when its slip row says
  /// `reject_accepted == 1` (the rejects-stream check from the reference
  /// scanner — `ScrapNotAccepted` otherwise).
  static bool isScrapTyre(SlipTyre tyre) => tyre.isRejectAccepted;

  static ScrapScanVerdict evaluate({
    required SlipTyre tyre,
    required Set<String> sessionUids,
    required int? operatorId,
    required String registration,
  }) {
    if (operatorId == null) {
      return const ScrapScanRejected('Operator not found');
    }
    if (registration.trim().isEmpty) {
      return const ScrapScanRejected('Set the truck REG first');
    }
    final uid = tyre.uid ?? '';
    if (uid.isNotEmpty && sessionUids.contains(uid)) {
      return const ScrapScanRejected('Already counted this session');
    }
    if (tyre.isDump) {
      return const ScrapScanRejected('This tyre is dumped');
    }
    if (!isScrapTyre(tyre)) {
      return const ScrapScanRejected(
        'Not a scrap — reject flag is missing',
      );
    }
    return const ScrapScanAccepted();
  }
}
