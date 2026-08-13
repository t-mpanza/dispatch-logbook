import {
  LOADING_PRESETS,
  getPresetFill,
  getNextStocksTripId,
  calculateDurationMinutes,
  calculateLoadingSheetTotals,
} from "./loading-presets";
import { formatWhatsAppShareText } from "./export-whatsapp";
import type { Entry, LoadingSheetTrip } from "./types";

// Mock localStorage for node environment if needed
if (typeof window === "undefined" || !window.localStorage) {
  const storage: Record<string, string> = {};
  (globalThis as any).localStorage = {
    getItem: (key: string) => storage[key] ?? null,
    setItem: (key: string, val: string) => {
      storage[key] = val;
    },
    removeItem: (key: string) => {
      delete storage[key];
    },
    clear: () => {
      Object.keys(storage).forEach((k) => delete storage[k]);
    },
  };
}

export function runComplianceUnitTests(): { passed: boolean; log: string[] } {
  const log: string[] = [];
  let passed = true;

  function assert(condition: boolean, message: string) {
    if (condition) {
      log.push(`[PASS] ${message}`);
    } else {
      passed = false;
      log.push(`[FAIL] ${message}`);
    }
  }

  log.push("=== RUNNING MILESTONE 1 COMPLIANCE TESTS ===");

  // Test 1: NLH Preset Auto-Fill
  const nlhResult = getPresetFill("NLH");
  assert(nlhResult.presetKey === "NLH", "NLH presetKey is NLH");
  assert(nlhResult.tripId === "NLH", "NLH tripId is NLH");
  assert(nlhResult.driverName === "Neil", "NLH driverName auto-fills 'Neil'");
  assert(nlhResult.reg === "MN05XNGP", "NLH reg auto-fills 'MN05XNGP'");

  // Test 2: Route Presets
  const dbnResult = getPresetFill("DBN");
  assert(dbnResult.tripId === "DBN", "DBN preset sets tripId to DBN");
  const plkResult = getPresetFill("PLK");
  assert(plkResult.tripId === "PLK", "PLK preset sets tripId to PLK");

  // Test 3: STOCKS Counter Auto-Increment
  const todayKey = "2026-08-13";
  localStorage.removeItem("dispatch_stocks_counter");
  const s1 = getNextStocksTripId(todayKey, []);
  assert(s1 === "STOCKS 1", `First STOCKS trip is 'STOCKS 1' (got: ${s1})`);

  const existingTrips: LoadingSheetTrip[] = [
    {
      id: "1",
      reg: "MN05XNGP",
      driverName: "Neil",
      tripId: "STOCKS 1",
      quantityLoaded: 120,
      createdAt: Date.now(),
    },
  ];
  const s2 = getNextStocksTripId(todayKey, existingTrips);
  assert(s2 === "STOCKS 2", `Second STOCKS trip is 'STOCKS 2' (got: ${s2})`);

  // Test 4: Midnight Reset on STOCKS Counter
  const tomorrowKey = "2026-08-14";
  const sTomorrow = getNextStocksTripId(tomorrowKey, []);
  assert(
    sTomorrow === "STOCKS 1",
    `STOCKS resets to 'STOCKS 1' after midnight reset (got: ${sTomorrow})`,
  );

  // Test 5: Duration Minutes Calculation
  const startMs = new Date("2026-08-13T08:00:00Z").getTime();
  const finishMs = new Date("2026-08-13T08:45:00Z").getTime();
  const duration = calculateDurationMinutes(startMs, finishMs);
  assert(duration === 45, `Duration calculation is 45 mins (got: ${duration})`);

  // Test 6: Summary Totals Calculation
  const tripsTest: LoadingSheetTrip[] = [
    {
      id: "t1",
      reg: "CA12345",
      driverName: "Sipho",
      tripId: "DBN",
      startTime: startMs,
      finishTime: finishMs,
      durationMinutes: 45,
      quantityLoaded: 100,
      createdAt: Date.now(),
    },
    {
      id: "t2",
      reg: "MN05XNGP",
      driverName: "Neil",
      tripId: "NLH",
      durationMinutes: 30,
      quantityLoaded: 150,
      createdAt: Date.now(),
    },
  ];
  const totals = calculateLoadingSheetTotals(tripsTest);
  assert(
    totals.totalTyresLoaded === 250,
    `TOTAL TYRES LOADED sum is 250 (got: ${totals.totalTyresLoaded})`,
  );
  assert(
    totals.totalLoadingTimeMinutes === 75,
    `TOTAL LOADING TIME sum is 75 mins (got: ${totals.totalLoadingTimeMinutes})`,
  );

  // Test 7: WhatsApp Share Text Formatting
  const mockEntry: Entry = {
    id: "entry1",
    title: "Tyre count",
    tags: ["tyres"],
    notes: [],
    attachments: [],
    loadingSheetTrips: tripsTest,
    createdAt: Date.now(),
    updatedAt: Date.now(),
    dayKey: "2026-08-13",
    monthKey: "2026-08",
    yearKey: "2026",
  };
  const waText = formatWhatsAppShareText(mockEntry, "John Doe");
  assert(waText.includes("DESPATCH LOADING SHEET"), "WhatsApp share text includes header");
  assert(waText.includes("John Doe"), "WhatsApp share text includes despatcher name");
  assert(waText.includes("250 tyres"), "WhatsApp share text includes correct total tyres");
  assert(waText.includes("75 mins"), "WhatsApp share text includes correct total loading time");

  log.push(passed ? "=== ALL TESTS PASSED SUCCESSFULLY ===" : "=== SOME TESTS FAILED ===");
  return { passed, log };
}

// Auto-run when executed directly
if (
  typeof process !== "undefined" &&
  (process.env.NODE_ENV === "test" || process.argv[1]?.includes("loading-presets.test"))
) {
  const res = runComplianceUnitTests();
  console.log(res.log.join("\n"));
  if (!res.passed) process.exit(1);
}
