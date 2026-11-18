import 'package:dispatch_diary/core/utils/scan_sounds.dart';
import 'package:dispatch_diary/dispatch/domain/multi_doc_scan_engine.dart';
import 'package:dispatch_diary/dispatch/domain/scan_feedback.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The head-down feedback contract: EVERY error verdict fires the system
/// vibrator (v3.8.1 pattern) + the loud error sound; success stays a soft
/// impact + chime. Binary, no third state.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  ScanSounds.enabled = false;

  const channel = MethodChannel('dispatch_diary/haptics');
  final calls = <String>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('success verdicts never touch the vibrator (soft chime only)', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    ScanFeedback.verdict(
      const AcceptedIntoDocument(documentNo: 'DIBT0179154'),
    );
    ScanFeedback.verdict(const AcceptedAsCash());
    expect(calls, isEmpty);
    debugDefaultTargetPlatformOverride = null;
  });

  test('every error verdict fires the vibrator', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final errorVerdicts = <MultiDocScanVerdict>[
      const AmbiguousDocument(['DIBT0179154', 'INV2392908']),
      const OffloadPrompt(),
      const OffloadPrompt(previousReg: 'MB75JMGP'),
      const DumpedTyre(),
      const UntoggleCashPrompt('IBT122773'),
      const Rejected('Not on this truck'),
    ];
    for (final v in errorVerdicts) {
      ScanFeedback.verdict(v);
      expect(
        calls,
        everyElement('vibrateError'),
        reason: '${v.runtimeType} must hit the vibrator',
      );
      calls.clear();
    }
    debugDefaultTargetPlatformOverride = null;
  });
}
