import 'package:flutter/services.dart';

enum HapticType { light, medium, heavy, success, error }

class AppHaptics {
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
        // A loud, unmissable "wrong" rumble: three stacked heavy pulses.
        // The bay is noisy — errors must be FELT, not just heard.
        HapticFeedback.heavyImpact();
        HapticFeedback.heavyImpact();
        HapticFeedback.heavyImpact();
        break;
    }
  }

  static void light() => trigger(HapticType.light);
  static void medium() => trigger(HapticType.medium);
  static void heavy() => trigger(HapticType.heavy);
  static void success() => trigger(HapticType.success);
  static void error() => trigger(HapticType.error);
}
