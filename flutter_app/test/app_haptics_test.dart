import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dispatch_diary/core/utils/haptics.dart';

/// The error verdict must reach the Vibrator channel on Android and fall
/// back to impacts elsewhere — this pins the routing contract with
/// MainActivity.kt ('dispatch_diary/haptics' → 'vibrateError').
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  test('error() hits the vibrator channel on Android', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AppHaptics.error();
    expect(calls, ['vibrateError']);
    debugDefaultTargetPlatformOverride = null;
  });

  test('error() falls back to impacts off Android (no channel call)', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    AppHaptics.error();
    expect(calls, isEmpty);
    debugDefaultTargetPlatformOverride = null;
  });

  test('error() never throws when the channel is missing', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    // Unhandled channels resolve to null; _invoke swallows exceptions too.
    expect(AppHaptics.error, returnsNormally);
    debugDefaultTargetPlatformOverride = null;
  });

  test('success stays a soft impact — UI taps are not buzzes', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AppHaptics.success();
    expect(calls, isEmpty);
    debugDefaultTargetPlatformOverride = null;
  });
}
