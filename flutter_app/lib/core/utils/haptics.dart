import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum HapticType { light, medium, heavy, success, error }

/// App-wide haptic feedback.
///
/// UI taps keep Flutter's built-in impacts (subtle by design). The ERROR
/// verdict is different: it must be FELT in a noisy bay, and Flutter's
/// impacts are unreliable on Android — every [HapticFeedback] method
/// funnels into `performHapticFeedback`, which the OS silently drops when
/// the device's "touch feedback" setting is off (stacked impacts just
/// coalesce into nothing).
///
/// So [error] goes through the `dispatch_diary/haptics` channel straight
/// to the system Vibrator (MainActivity.kt): three hard pulses at full
/// amplitude. Only the master Vibration setting can silence that (the
/// VIBRATE permission is already declared in the manifest). Non-Android
/// platforms fall back to stacked heavy impacts.
class AppHaptics {
  AppHaptics._();

  static const MethodChannel _channel = MethodChannel('dispatch_diary/haptics');

  static bool get _usesVibrator =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static void trigger(HapticType type) {
    switch (type) {
      case HapticType.light:
        HapticFeedback.lightImpact();
        break;
      case HapticType.medium:
        HapticFeedback.mediumImpact();
        break;
      case HapticType.heavy:
        HapticFeedback.heavyImpact();
        break;
      case HapticType.success:
        HapticFeedback.mediumImpact();
        break;
      case HapticType.error:
        error();
        break;
    }
  }

  static void light() => trigger(HapticType.light);
  static void medium() => trigger(HapticType.medium);
  static void heavy() => trigger(HapticType.heavy);
  static void success() => trigger(HapticType.success);

  /// The unmissable "WRONG" rumble: a triple pulse on the system Vibrator.
  static void error() {
    if (_usesVibrator) {
      unawaited(_invoke('vibrateError'));
    } else {
      HapticFeedback.heavyImpact();
      HapticFeedback.heavyImpact();
      HapticFeedback.heavyImpact();
    }
  }

  static Future<void> _invoke(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } catch (_) {
      // Haptics are best-effort — a missing channel must never crash a scan.
    }
  }
}
