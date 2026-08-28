import { Haptics, ImpactStyle, NotificationType } from "@capacitor/haptics";
import { Capacitor } from "@capacitor/core";

export type HapticType = "light" | "medium" | "heavy" | "success" | "error";

export const HAPTIC_PATTERNS: Record<HapticType, number | number[]> = {
  light: 10,
  medium: 25,
  heavy: 50,
  success: [10, 30, 20],
  error: [50, 30, 50, 30, 50],
};

export let lastHapticTriggered: {
  type: HapticType;
  pattern: number | number[];
  timestamp: number;
} | null = null;

export async function triggerHaptic(type: HapticType = "light"): Promise<void> {
  const pattern = HAPTIC_PATTERNS[type] ?? 10;
  lastHapticTriggered = {
    type,
    pattern,
    timestamp: Date.now(),
  };

  // 1. Native Taptic Engine / Android Hardware Vibration
  if (Capacitor.isNativePlatform()) {
    try {
      if (type === "light") {
        await Haptics.impact({ style: ImpactStyle.Light });
        return;
      } else if (type === "medium") {
        await Haptics.impact({ style: ImpactStyle.Medium });
        return;
      } else if (type === "heavy") {
        await Haptics.impact({ style: ImpactStyle.Heavy });
        return;
      } else if (type === "success") {
        await Haptics.notification({ type: NotificationType.Success });
        return;
      } else if (type === "error") {
        await Haptics.notification({ type: NotificationType.Error });
        return;
      }
    } catch {
      // Graceful fallback to web API
    }
  }

  // 2. Web / PWA vibration fallback
  if (typeof navigator !== "undefined" && typeof navigator.vibrate === "function") {
    try {
      navigator.vibrate(pattern);
    } catch {
      // Ignore on unsupported browsers
    }
  }
}

export const vibrate = triggerHaptic;
