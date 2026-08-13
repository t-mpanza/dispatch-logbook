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

export function triggerHaptic(type: HapticType = "light"): void {
  const pattern = HAPTIC_PATTERNS[type] ?? 10;
  lastHapticTriggered = {
    type,
    pattern,
    timestamp: Date.now(),
  };

  if (typeof navigator !== "undefined" && typeof navigator.vibrate === "function") {
    try {
      navigator.vibrate(pattern);
    } catch {
      // Ignore vibration errors on unsupported environments
    }
  }
}
