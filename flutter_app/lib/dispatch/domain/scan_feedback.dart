import '../../core/utils/haptics.dart';
import '../../core/utils/scan_sounds.dart';
import 'multi_doc_scan_engine.dart';

/// The head-down feedback contract (D17): binary, loud-when-wrong.
///
/// Every scan verdict maps to exactly one of two feedbacks — correct
/// (chime + soft impact) or wrong (loud WAV + the triple-pulse system
/// vibrator from v3.8.1). This is the ONLY place verdicts turn into
/// sound/haptics, so every new screen inherits the same contract.
class ScanFeedback {
  ScanFeedback._();

  static void correct() {
    ScanSounds.success();
    AppHaptics.success();
  }

  static void wrong() {
    ScanSounds.error();
    AppHaptics.error();
  }

  /// Verdict-aware: success verdicts chime, everything else — ambiguity,
  /// offload prompts, collisions, dumps, untoggle prompts, rejections —
  /// fails LOUD (the eyes-on-screen summons).
  static void verdict(MultiDocScanVerdict verdict) {
    if (verdict.isSuccess) {
      correct();
    } else {
      wrong();
    }
  }
}
