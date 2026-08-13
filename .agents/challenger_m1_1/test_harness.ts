import {
  getNextStocksTripId,
  getPresetFill,
  resolvePreset,
  calculateDurationMinutes,
  calculateLoadingSheetTotals,
  resetStocksCounter,
  LOADING_PRESETS,
  PRESET_KEYS,
} from "../../src/lib/loading-presets.ts";
import type { LoadingSheetTrip } from "../../src/lib/types.ts";

// Mock LocalStorage Implementation for Node environment
class MockLocalStorage implements Storage {
  private store: Map<string, string> = new Map();

  get length(): number {
    return this.store.size;
  }

  clear(): void {
    this.store.clear();
  }

  getItem(key: string): string | null {
    return this.store.has(key) ? this.store.get(key)! : null;
  }

  setItem(key: string, value: string): void {
    this.store.set(key, String(value));
  }

  removeItem(key: string): void {
    this.store.delete(key);
  }

  key(index: number): string | null {
    const keys = Array.from(this.store.keys());
    return keys[index] ?? null;
  }
}

function setupMockWindow() {
  const mockStorage = new MockLocalStorage();
  const mockWin = {
    localStorage: mockStorage,
  };
  (globalThis as any).window = mockWin;
  (globalThis as any).localStorage = mockStorage;
  return mockStorage;
}

function removeMockWindow() {
  delete (globalThis as any).window;
  delete (globalThis as any).localStorage;
}

interface TestResult {
  name: string;
  category: string;
  passed: boolean;
  details: string;
}

const results: TestResult[] = [];

function assert(condition: boolean, category: string, name: string, details: string) {
  if (!condition) {
    results.push({ name, category, passed: false, details: `FAILED: ${details}` });
  } else {
    results.push({ name, category, passed: true, details });
  }
}

// ==========================================
// TEST SUITE 1: STOCKS Auto-Increment Logic (Same Day)
// ==========================================
function testStocksAutoIncrementSameDay() {
  const category = "STOCKS Auto-Increment (Same Day)";
  const storage = setupMockWindow();
  storage.clear();

  const today = "2026-08-13";

  // 1.1 First call on empty storage
  const id1 = getNextStocksTripId(today, []);
  assert(id1 === "STOCKS 1", category, "First call initial index", `Got: ${id1}`);

  // Check localStorage state
  const raw1 = storage.getItem("dispatch_stocks_counter");
  assert(
    raw1 !== null && JSON.parse(raw1).count === 1 && JSON.parse(raw1).dateKey === today,
    category,
    "LocalStorage updated on first call",
    `Raw: ${raw1}`,
  );

  // 1.2 Sequential calls on same day without existingTrips
  const id2 = getNextStocksTripId(today, []);
  assert(id2 === "STOCKS 2", category, "Second call auto-increment", `Got: ${id2}`);

  const id3 = getNextStocksTripId(today, []);
  assert(id3 === "STOCKS 3", category, "Third call auto-increment", `Got: ${id3}`);

  // 1.3 Call with existingTrips containing STOCKS 1 and STOCKS 5
  const existingTrips: LoadingSheetTrip[] = [
    {
      id: "1",
      reg: "ABC",
      driverName: "John",
      tripId: "STOCKS 1",
      quantityLoaded: 10,
      createdAt: Date.now(),
    },
    {
      id: "2",
      reg: "XYZ",
      driverName: "Jane",
      tripId: "STOCKS 5",
      quantityLoaded: 20,
      createdAt: Date.now(),
    },
  ];
  const id4 = getNextStocksTripId(today, existingTrips);
  // Stored count was 3, but max existing is 5, so next should be max(5, 3) + 1 = 6
  assert(id4 === "STOCKS 6", category, "Respect higher index in existingTrips", `Got: ${id4}`);

  // 1.4 Sequential call after max existing
  const id5 = getNextStocksTripId(today, []);
  assert(id5 === "STOCKS 7", category, "Sequential call after max existing jump", `Got: ${id5}`);

  // 1.5 Case insensitivity in tripId regex check
  const mixedCaseTrips: LoadingSheetTrip[] = [
    {
      id: "3",
      reg: "123",
      driverName: "Bob",
      tripId: "stocks 12",
      quantityLoaded: 5,
      createdAt: Date.now(),
    },
  ];
  const id6 = getNextStocksTripId(today, mixedCaseTrips);
  // Stored count was 7, max existing is 12, so next should be 13
  assert(id6 === "STOCKS 13", category, "Case-insensitive STOCKS regex matching", `Got: ${id6}`);

  // 1.6 Integration via getPresetFill
  const fill1 = getPresetFill("STOCKS", { dayKey: today });
  assert(
    fill1.presetKey === "STOCKS" && fill1.tripId === "STOCKS 14",
    category,
    "getPresetFill STOCKS",
    `Got: ${JSON.stringify(fill1)}`,
  );

  // 1.7 Integration via resolvePreset
  const resolved1 = resolvePreset("STOCKS", undefined, { dateStr: today });
  assert(
    resolved1.presetKey === "STOCKS" && resolved1.tripId === "STOCKS 15",
    category,
    "resolvePreset STOCKS auto",
    `Got: ${JSON.stringify(resolved1)}`,
  );

  // 1.8 resolvePreset with explicit currentCount option
  const resolvedExplicit = resolvePreset("STOCKS", undefined, { currentCount: 99 });
  assert(
    resolvedExplicit.presetKey === "STOCKS" && resolvedExplicit.tripId === "STOCKS 99",
    category,
    "resolvePreset explicit currentCount",
    `Got: ${JSON.stringify(resolvedExplicit)}`,
  );

  // 1.9 SSR / No window environment
  removeMockWindow();
  const ssrId = getNextStocksTripId(today, []);
  assert(ssrId === "STOCKS 1", category, "SSR / No Window fallback", `Got: ${ssrId}`);
}

// ==========================================
// TEST SUITE 2: STOCKS Midnight Reset (Date Key Change)
// ==========================================
function testStocksMidnightReset() {
  const category = "STOCKS Midnight Reset";
  const storage = setupMockWindow();
  storage.clear();

  const day1 = "2026-08-13";
  const day2 = "2026-08-14";

  // Build counter on Day 1
  getNextStocksTripId(day1, []); // STOCKS 1
  getNextStocksTripId(day1, []); // STOCKS 2
  const day1Last = getNextStocksTripId(day1, []); // STOCKS 3
  assert(day1Last === "STOCKS 3", category, "Day 1 reached STOCKS 3", `Got: ${day1Last}`);

  // Switch to Day 2 with empty existing trips
  const day2First = getNextStocksTripId(day2, []);
  assert(
    day2First === "STOCKS 1",
    category,
    "Midnight date change resets counter to STOCKS 1",
    `Got: ${day2First}`,
  );

  // Check stored state in localStorage
  const rawDay2 = storage.getItem("dispatch_stocks_counter");
  const parsedDay2 = JSON.parse(rawDay2 || "{}");
  assert(
    parsedDay2.dateKey === day2 && parsedDay2.count === 1,
    category,
    "LocalStorage updated with new dateKey and count 1",
    `Got: ${rawDay2}`,
  );

  // Subsequent call on Day 2
  const day2Second = getNextStocksTripId(day2, []);
  assert(
    day2Second === "STOCKS 2",
    category,
    "Day 2 second call increments to STOCKS 2",
    `Got: ${day2Second}`,
  );

  // Year transition test
  const yearEnd = "2026-12-31";
  const newYear = "2027-01-01";
  getNextStocksTripId(yearEnd, []);
  getNextStocksTripId(yearEnd, []); // count = 2
  const newYearFirst = getNextStocksTripId(newYear, []);
  assert(
    newYearFirst === "STOCKS 1",
    category,
    "New year transition resets counter to STOCKS 1",
    `Got: ${newYearFirst}`,
  );

  // Explicit reset via resetStocksCounter()
  getNextStocksTripId(newYear, []); // count = 2
  resetStocksCounter();
  assert(
    storage.getItem("dispatch_stocks_counter") === null,
    category,
    "resetStocksCounter clears localStorage key",
    "Item removed",
  );

  const afterManualReset = getNextStocksTripId(newYear, []);
  assert(
    afterManualReset === "STOCKS 1",
    category,
    "After resetStocksCounter, next trip ID is STOCKS 1",
    `Got: ${afterManualReset}`,
  );
}

// ==========================================
// TEST SUITE 3: NLH Preset Auto-Fill
// ==========================================
function testNlhPresetAutoFill() {
  const category = "NLH Preset Auto-Fill";

  // 3.1 Verify LOADING_PRESETS array entry
  const nlhPreset = LOADING_PRESETS.find((p) => p.key === "NLH");
  assert(
    nlhPreset !== undefined &&
      nlhPreset.label === "NLH" &&
      nlhPreset.defaultDriver === "Neil" &&
      nlhPreset.defaultReg === "MN05XNGP",
    category,
    "LOADING_PRESETS configuration for NLH",
    `Got: ${JSON.stringify(nlhPreset)}`,
  );

  // 3.2 getPresetFill("NLH")
  const fill = getPresetFill("NLH");
  assert(
    fill.presetKey === "NLH" &&
      fill.tripId === "NLH" &&
      fill.driverName === "Neil" &&
      fill.reg === "MN05XNGP",
    category,
    "getPresetFill('NLH') returns correct Driver and Reg",
    `Got: ${JSON.stringify(fill)}`,
  );

  // 3.3 resolvePreset("NLH")
  const resolved = resolvePreset("NLH");
  assert(
    resolved.presetKey === "NLH" &&
      resolved.tripId === "NLH" &&
      resolved.driverName === "Neil" &&
      resolved.reg === "MN05XNGP",
    category,
    "resolvePreset('NLH') returns correct Driver and Reg",
    `Got: ${JSON.stringify(resolved)}`,
  );

  // 3.4 Verify non-NLH presets do NOT have default driver/reg populated unintentionally
  const dbnFill = getPresetFill("DBN");
  assert(
    dbnFill.driverName === undefined && dbnFill.reg === undefined && dbnFill.tripId === "DBN",
    category,
    "Other presets (e.g. DBN) do not leak driver or reg",
    `Got: ${JSON.stringify(dbnFill)}`,
  );
}

// ==========================================
// TEST SUITE 4: Duration Calculations & Edge Cases
// ==========================================
function testDurationCalculations() {
  const category = "Duration Calculations";

  // 4.1 Same start and finish time
  const now = 1700000000000;
  const durSame = calculateDurationMinutes(now, now);
  assert(durSame === 0, category, "Same start and finish time returns 0", `Got: ${durSame}`);

  // 4.2 Finish before start time
  const start = 1700000000000;
  const finishBefore = 1699999000000;
  const durInverted = calculateDurationMinutes(start, finishBefore);
  assert(durInverted === 0, category, "Finish before start returns 0", `Got: ${durInverted}`);

  // 4.3 Missing / undefined / null / zero timestamps
  assert(
    calculateDurationMinutes(undefined, now) === 0,
    category,
    "Undefined start time returns 0",
    "start undefined",
  );
  assert(
    calculateDurationMinutes(now, undefined) === 0,
    category,
    "Undefined finish time returns 0",
    "finish undefined",
  );
  assert(calculateDurationMinutes(0, now) === 0, category, "Zero start time returns 0", "start 0");
  assert(
    calculateDurationMinutes(now, 0) === 0,
    category,
    "Zero finish time returns 0",
    "finish 0",
  );

  // 4.4 Sub-minute rounding edge cases
  const t0 = 100000;
  // 29.999 seconds (29,999 ms) -> rounds to 0
  const dur29s = calculateDurationMinutes(t0, t0 + 29999);
  assert(dur29s === 0, category, "29,999 ms (29.999s) rounds down to 0 min", `Got: ${dur29s}`);

  // 30.000 seconds (30,000 ms) -> Math.round(30000/60000) = Math.round(0.5) = 1
  const dur30s = calculateDurationMinutes(t0, t0 + 30000);
  assert(dur30s === 1, category, "30,000 ms (30s) rounds up to 1 min", `Got: ${dur30s}`);

  // 89,999 ms -> Math.round(1.4999) = 1 min
  const dur89s = calculateDurationMinutes(t0, t0 + 89999);
  assert(dur89s === 1, category, "89,999 ms (1.499 min) rounds to 1 min", `Got: ${dur89s}`);

  // 90,000 ms -> Math.round(1.5) = 2 min
  const dur90s = calculateDurationMinutes(t0, t0 + 90000);
  assert(dur90s === 2, category, "90,000 ms (1.5 min) rounds to 2 min", `Got: ${dur90s}`);

  // 4.5 Multi-hour durations
  const oneHourMs = 60 * 60 * 1000;
  assert(
    calculateDurationMinutes(t0, t0 + oneHourMs) === 60,
    category,
    "1 hour duration -> 60 min",
    "1 hour",
  );
  assert(
    calculateDurationMinutes(t0, t0 + 2.5 * oneHourMs) === 150,
    category,
    "2.5 hours duration -> 150 min",
    "2.5 hours",
  );
  assert(
    calculateDurationMinutes(t0, t0 + 24 * oneHourMs) === 1440,
    category,
    "24 hours duration -> 1440 min",
    "24 hours",
  );
  assert(
    calculateDurationMinutes(t0, t0 + 100 * oneHourMs) === 6000,
    category,
    "100 hours duration -> 6000 min",
    "100 hours",
  );

  // 4.6 calculateLoadingSheetTotals integration
  const mockTrips: LoadingSheetTrip[] = [
    {
      id: "t1",
      reg: "MN05XNGP",
      driverName: "Neil",
      tripId: "NLH",
      quantityLoaded: 50,
      startTime: t0,
      finishTime: t0 + 30 * 60 * 1000, // 30 mins
      createdAt: Date.now(),
    },
    {
      id: "t2",
      reg: "ABC",
      driverName: "Bob",
      tripId: "STOCKS 1",
      quantityLoaded: 25,
      durationMinutes: 45, // explicit duration overridden
      startTime: t0,
      finishTime: t0 + 10 * 60 * 1000, // ignored because durationMinutes is provided
      createdAt: Date.now(),
    },
    {
      id: "t3",
      reg: "XYZ",
      driverName: "Alice",
      tripId: "DBN",
      quantityLoaded: -5, // edge case: negative qty
      startTime: t0,
      finishTime: t0 - 1000, // finish before start -> 0 min
      createdAt: Date.now(),
    },
  ];

  const totals = calculateLoadingSheetTotals(mockTrips);
  // Tyres: 50 + 25 + max(0, -5) = 75
  assert(
    totals.totalTyresLoaded === 75,
    category,
    "Loading sheet total tyres loaded calculation",
    `Got: ${totals.totalTyresLoaded}`,
  );
  // Duration: 30 + 45 + 0 = 75
  assert(
    totals.totalLoadingTimeMinutes === 75,
    category,
    "Loading sheet total duration minutes calculation",
    `Got: ${totals.totalLoadingTimeMinutes}`,
  );
}

// ==========================================
// TEST SUITE 5: Adversarial & Fuzz Tests
// ==========================================
function testAdversarialScenarios() {
  const category = "Adversarial Stress Testing";
  const storage = setupMockWindow();

  // 5.1 Corrupted JSON in localStorage
  storage.setItem("dispatch_stocks_counter", "INVALID_JSON{");
  const idAfterCorrupt = getNextStocksTripId("2026-08-13", []);
  assert(
    idAfterCorrupt === "STOCKS 1",
    category,
    "Gracefully handles corrupt JSON in localStorage",
    `Got: ${idAfterCorrupt}`,
  );

  // 5.2 Malformed parsed JSON (primitive or unexpected structure)
  storage.setItem(
    "dispatch_stocks_counter",
    JSON.stringify({ dateKey: "2026-08-13", count: "NOT_A_NUMBER" }),
  );
  const idAfterBadCount = getNextStocksTripId("2026-08-13", []);
  assert(
    idAfterBadCount === "STOCKS 1",
    category,
    "Gracefully handles string count in localStorage",
    `Got: ${idAfterBadCount}`,
  );

  // 5.3 Stress test: 1,000 sequential calls on same day
  storage.clear();
  let lastId = "";
  for (let i = 0; i < 1000; i++) {
    lastId = getNextStocksTripId("2026-08-13", []);
  }
  assert(
    lastId === "STOCKS 1000",
    category,
    "Stress test: 1,000 sequential calls increment to STOCKS 1000",
    `Got: ${lastId}`,
  );

  // 5.4 Extreme timestamps in calculateDurationMinutes
  const hugeStart = 1e14;
  const hugeFinish = 1e14 + 60000;
  assert(
    calculateDurationMinutes(hugeStart, hugeFinish) === 1,
    category,
    "Handles large epoch timestamps",
    "1 min",
  );
}

// Run all test suites
console.log("==================================================");
console.log("  DESPATCH LOADING SHEET COMPLIANCE TEST HARNESS  ");
console.log("==================================================");

testStocksAutoIncrementSameDay();
testStocksMidnightReset();
testNlhPresetAutoFill();
testDurationCalculations();
testAdversarialScenarios();

let passedCount = 0;
let failedCount = 0;

for (const res of results) {
  const statusStr = res.passed ? "[PASS]" : "[FAIL]";
  console.log(`${statusStr} [${res.category}] ${res.name} -> ${res.details}`);
  if (res.passed) passedCount++;
  else failedCount++;
}

console.log("==================================================");
console.log(`TOTAL TESTS: ${results.length} | PASSED: ${passedCount} | FAILED: ${failedCount}`);
console.log("==================================================");

if (failedCount > 0) {
  process.exit(1);
} else {
  process.exit(0);
}
