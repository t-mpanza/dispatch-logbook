import type { LoadingSheetTrip, PresetFillResult, PresetKey } from "../../src/lib/types.ts";
import { dayKey } from "../../src/lib/format.ts";

export interface PresetConfig {
  key: PresetKey;
  label: string;
  defaultDriver?: string;
  defaultReg?: string;
  isDynamic?: boolean;
}

export const LOADING_PRESETS: PresetConfig[] = [
  { key: "DBN", label: "DBN" },
  { key: "NLS", label: "NLS" },
  { key: "BLOEM", label: "BLOEM" },
  { key: "PLK", label: "PLK" },
  { key: "STOCKS", label: "STOCKS [i]", isDynamic: true },
  { key: "NLH", label: "NLH", defaultDriver: "Neil", defaultReg: "MN05XNGP" },
  { key: "TIREPOINT", label: "TIREPOINT" },
  { key: "CUSTOM", label: "Custom" },
];

export const PRESET_KEYS: PresetKey[] = LOADING_PRESETS.map((p) => p.key);

const STOCKS_STORAGE_KEY = "dispatch_stocks_counter";
let inMemoryStocksState = { dateKey: "", count: 0 };

export function resetStocksCounter(): void {
  inMemoryStocksState = { dateKey: "", count: 0 };
  if (typeof window !== "undefined" && window.localStorage) {
    try {
      localStorage.removeItem(STOCKS_STORAGE_KEY);
    } catch {}
  }
}

export function getNextStocksTripId(
  todayDayKey: string,
  existingTrips: LoadingSheetTrip[] = [],
): string {
  // Step A: Check existing trips on today's sheet for highest STOCKS index
  let maxExisting = 0;
  const stocksRegex = /^STOCKS\s+(\d+)$/i;

  for (const trip of existingTrips) {
    if (trip.tripId) {
      const match = trip.tripId.match(stocksRegex);
      if (match) {
        const num = parseInt(match[1], 10);
        if (!isNaN(num) && num > maxExisting) {
          maxExisting = num;
        }
      }
    }
  }

  // Step B: Check stored counter state
  let storedCount = 0;
  if (typeof window !== "undefined" && window.localStorage) {
    try {
      const raw = localStorage.getItem(STOCKS_STORAGE_KEY);
      if (raw) {
        const parsed = JSON.parse(raw);
        if (parsed && parsed.dateKey === todayDayKey && typeof parsed.count === "number") {
          storedCount = parsed.count;
        }
      }
    } catch (e) {
      console.error("Error reading STOCKS counter state:", e);
    }
  }

  if (inMemoryStocksState.dateKey !== todayDayKey) {
    inMemoryStocksState = { dateKey: todayDayKey, count: 0 };
  }
  storedCount = Math.max(storedCount, inMemoryStocksState.count);

  // Step C: Determine next index (higher of maxExisting vs storedCount + 1)
  const nextIndex = Math.max(maxExisting, storedCount) + 1;
  inMemoryStocksState.count = nextIndex;

  // Step D: Persist next index state
  if (typeof window !== "undefined" && window.localStorage) {
    try {
      localStorage.setItem(
        STOCKS_STORAGE_KEY,
        JSON.stringify({ dateKey: todayDayKey, count: nextIndex }),
      );
    } catch (e) {
      console.error("Error saving STOCKS counter state:", e);
    }
  }

  return `STOCKS ${nextIndex}`;
}

export function getPresetFill(
  key: PresetKey,
  context?: { dayKey?: string; existingTrips?: LoadingSheetTrip[] },
): PresetFillResult {
  const todayKey = context?.dayKey ?? dayKey(Date.now());
  const existing = context?.existingTrips ?? [];

  switch (key) {
    case "NLH":
      return {
        presetKey: "NLH",
        tripId: "NLH",
        driverName: "Neil",
        reg: "MN05XNGP",
      };
    case "STOCKS":
      return {
        presetKey: "STOCKS",
        tripId: getNextStocksTripId(todayKey, existing),
      };
    case "CUSTOM":
      return {
        presetKey: "CUSTOM",
        tripId: "",
      };
    default:
      return {
        presetKey: key,
        tripId: key,
      };
  }
}

export function resolvePreset(
  presetKey: PresetKey,
  customText?: string,
  options?: { dateStr?: string; currentCount?: number },
): PresetFillResult {
  if (presetKey === "STOCKS" && options?.currentCount !== undefined) {
    return {
      presetKey: "STOCKS",
      tripId: `STOCKS ${options.currentCount}`,
    };
  }
  if (presetKey === "CUSTOM" && customText !== undefined) {
    return {
      presetKey: "CUSTOM",
      tripId: customText.trim() || "CUSTOM",
    };
  }
  return getPresetFill(presetKey, { dayKey: options?.dateStr });
}

export function calculateDurationMinutes(startTime?: number, finishTime?: number): number {
  if (!startTime || !finishTime || finishTime < startTime) {
    return 0;
  }
  const diffMs = finishTime - startTime;
  return Math.max(0, Math.round(diffMs / (1000 * 60)));
}

export function calculateLoadingSheetTotals(trips: LoadingSheetTrip[]): {
  totalTyresLoaded: number;
  totalLoadingTimeMinutes: number;
} {
  let totalTyresLoaded = 0;
  let totalLoadingTimeMinutes = 0;

  for (const trip of trips) {
    const qty = Math.max(0, trip.quantityLoaded || 0);
    totalTyresLoaded += qty;

    const duration =
      trip.durationMinutes !== undefined
        ? Math.max(0, trip.durationMinutes)
        : calculateDurationMinutes(trip.startTime, trip.finishTime);

    totalLoadingTimeMinutes += duration;
  }

  return {
    totalTyresLoaded,
    totalLoadingTimeMinutes,
  };
}
