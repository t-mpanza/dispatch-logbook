# Challenge Report — Milestone 1: Despatch Loading Sheet Compliance System

**Target File**: `src/lib/loading-presets.ts`  
**Test Harness Script**: `/home/kiddow/Desktop/Work/Despatch Diary/.agents/challenger_m1_1/test_harness.ts`  
**Date**: 2026-08-13  
**Status**: VERIFIED & PASSED (42/42 tests passed)

---

## Challenge Summary

**Overall risk assessment**: **LOW**

All four requested functional areas in `src/lib/loading-presets.ts` were empirically stress-tested using an adversarial Node/TypeScript test harness (`test_harness.ts` executed via `npx tsx`). The implementation handles all normal workflows, edge cases, date key transitions, and adversarial inputs (such as corrupted JSON storage and non-browser SSR contexts) without failure.

---

## Stress Test Results & Empirical Evidence

### 1. `STOCKS` Daily Counter Auto-Increment Logic

- **Requirement**: Verify auto-increment logic across multiple sequential calls on the same day.
- **Empirical Results**:
  - `getNextStocksTripId("2026-08-13", [])` on clean storage returned `"STOCKS 1"`.
  - Sequential calls returned `"STOCKS 2"`, `"STOCKS 3"`.
  - When `existingTrips` contained `STOCKS 1` and `STOCKS 5`, the function correctly resolved the next index to `Math.max(5, 3) + 1` -> `"STOCKS 6"`.
  - Case-insensitive regex matching handled `"stocks 12"` correctly -> returning `"STOCKS 13"`.
  - Integration with `getPresetFill` and `resolvePreset` correctly produced `"STOCKS 14"`, `"STOCKS 15"`.
  - Explicit count override in `resolvePreset("STOCKS", undefined, { currentCount: 99 })` correctly returned `"STOCKS 99"`.
  - Non-browser/SSR mode (`window` undefined) degraded gracefully to return `"STOCKS 1"`.
  - Stress test of 1,000 sequential calls on the same day incremented smoothly to `"STOCKS 1000"`.

### 2. `STOCKS` Daily Counter Midnight Reset

- **Requirement**: Verify midnight reset when the date key changes.
- **Empirical Results**:
  - After advancing counter to `"STOCKS 3"` on date `"2026-08-13"`, switching the date key to `"2026-08-14"` caused `getNextStocksTripId("2026-08-14", [])` to reset to `"STOCKS 1"`.
  - `localStorage` state was updated to `{"dateKey":"2026-08-14","count":1}`.
  - Subsequent calls on `"2026-08-14"` incremented to `"STOCKS 2"`, `"STOCKS 3"`.
  - Year rollover test (`"2026-12-31"` to `"2027-01-01"`) successfully reset to `"STOCKS 1"`.
  - Calling `resetStocksCounter()` purged the localStorage key, correctly resetting subsequent calls to `"STOCKS 1"`.

### 3. `NLH` Preset Auto-Fill

- **Requirement**: Verify `NLH` preset auto-fill returns Driver: `Neil` and Reg: `MN05XNGP`.
- **Empirical Results**:
  - `LOADING_PRESETS` array contains `{ key: "NLH", label: "NLH", defaultDriver: "Neil", defaultReg: "MN05XNGP" }`.
  - `getPresetFill("NLH")` returned `{ presetKey: "NLH", tripId: "NLH", driverName: "Neil", reg: "MN05XNGP" }`.
  - `resolvePreset("NLH")` returned `{ presetKey: "NLH", tripId: "NLH", driverName: "Neil", reg: "MN05XNGP" }`.
  - Verified that non-NLH presets (e.g. `DBN`, `NLS`, `BLOEM`, `PLK`) do not leak driver or reg attributes.

### 4. Duration Calculations (`calculateDurationMinutes`) & Sheet Totals

- **Requirement**: Verify duration calculations under edge cases (same start/finish time, finish before start, multi-hour durations).
- **Empirical Results**:
  - **Same start and finish time** (`startTime === finishTime`): returns `0`.
  - **Finish before start time** (`finishTime < startTime`): returns `0`.
  - **Undefined / missing / zero parameters**: returns `0`.
  - **Sub-minute millisecond rounding**:
    - `29,999 ms` (29.999s) -> `0` minutes.
    - `30,000 ms` (30.000s) -> `1` minute (`Math.round(30000 / 60000)` = 1).
    - `89,999 ms` (1.499 min) -> `1` minute.
    - `90,000 ms` (1.500 min) -> `2` minutes.
  - **Multi-hour durations**:
    - 1 hour (`3,600,000 ms`) -> `60` minutes.
    - 2.5 hours (`9,000,000 ms`) -> `150` minutes.
    - 24 hours (`86,400,000 ms`) -> `1440` minutes.
    - 100 hours (`360,000,000 ms`) -> `6000` minutes.
  - **`calculateLoadingSheetTotals` Integration**:
    - Correctly sums quantities (`50 + 25 + max(0, -5) = 75`).
    - Correctly calculates total duration, respecting explicit `durationMinutes` overrides when provided (`30 + 45 + 0 = 75` minutes).

### 5. Robustness & Fault Tolerance

- **Corrupted LocalStorage**: Setting `dispatch_stocks_counter` to `"INVALID_JSON{"` was safely caught without throwing, returning `"STOCKS 1"`.
- **Malformed Object**: Setting count to `"NOT_A_NUMBER"` fell back gracefully to `"STOCKS 1"`.

---

## Test Execution Command & Output Log

```bash
$ npx tsx .agents/challenger_m1_1/test_harness.ts
```

```
==================================================
  DESPATCH LOADING SHEET COMPLIANCE TEST HARNESS
==================================================
[PASS] [STOCKS Auto-Increment (Same Day)] First call initial index -> Got: STOCKS 1
[PASS] [STOCKS Auto-Increment (Same Day)] LocalStorage updated on first call -> Raw: {"dateKey":"2026-08-13","count":1}
[PASS] [STOCKS Auto-Increment (Same Day)] Second call auto-increment -> Got: STOCKS 2
[PASS] [STOCKS Auto-Increment (Same Day)] Third call auto-increment -> Got: STOCKS 3
[PASS] [STOCKS Auto-Increment (Same Day)] Respect higher index in existingTrips -> Got: STOCKS 6
[PASS] [STOCKS Auto-Increment (Same Day)] Sequential call after max existing jump -> Got: STOCKS 7
[PASS] [STOCKS Auto-Increment (Same Day)] Case-insensitive STOCKS regex matching -> Got: STOCKS 13
[PASS] [STOCKS Auto-Increment (Same Day)] getPresetFill STOCKS -> Got: {"presetKey":"STOCKS","tripId":"STOCKS 14"}
[PASS] [STOCKS Auto-Increment (Same Day)] resolvePreset STOCKS auto -> Got: {"presetKey":"STOCKS","tripId":"STOCKS 15"}
[PASS] [STOCKS Auto-Increment (Same Day)] resolvePreset explicit currentCount -> Got: {"presetKey":"STOCKS","tripId":"STOCKS 99"}
[PASS] [STOCKS Auto-Increment (Same Day)] SSR / No Window fallback -> Got: STOCKS 1
[PASS] [STOCKS Midnight Reset] Day 1 reached STOCKS 3 -> Got: STOCKS 3
[PASS] [STOCKS Midnight Reset] Midnight date change resets counter to STOCKS 1 -> Got: STOCKS 1
[PASS] [STOCKS Midnight Reset] LocalStorage updated with new dateKey and count 1 -> Got: {"dateKey":"2026-08-14","count":1}
[PASS] [STOCKS Midnight Reset] Day 2 second call increments to STOCKS 2 -> Got: STOCKS 2
[PASS] [STOCKS Midnight Reset] New year transition resets counter to STOCKS 1 -> Got: STOCKS 1
[PASS] [STOCKS Midnight Reset] resetStocksCounter clears localStorage key -> Item removed
[PASS] [STOCKS Midnight Reset] After resetStocksCounter, next trip ID is STOCKS 1 -> Got: STOCKS 1
[PASS] [NLH Preset Auto-Fill] LOADING_PRESETS configuration for NLH -> Got: {"key":"NLH","label":"NLH","defaultDriver":"Neil","defaultReg":"MN05XNGP"}
[PASS] [NLH Preset Auto-Fill] getPresetFill('NLH') returns correct Driver and Reg -> Got: {"presetKey":"NLH","tripId":"NLH","driverName":"Neil","reg":"MN05XNGP"}
[PASS] [NLH Preset Auto-Fill] resolvePreset('NLH') returns correct Driver and Reg -> Got: {"presetKey":"NLH","tripId":"NLH","driverName":"Neil","reg":"MN05XNGP"}
[PASS] [NLH Preset Auto-Fill] Other presets (e.g. DBN) do not leak driver or reg -> Got: {"presetKey":"DBN","tripId":"DBN"}
[PASS] [Duration Calculations] Same start and finish time returns 0 -> Got: 0
[PASS] [Duration Calculations] Finish before start returns 0 -> Got: 0
[PASS] [Duration Calculations] Undefined start time returns 0 -> start undefined
[PASS] [Duration Calculations] Undefined finish time returns 0 -> finish undefined
[PASS] [Duration Calculations] Zero start time returns 0 -> start 0
[PASS] [Duration Calculations] Zero finish time returns 0 -> finish 0
[PASS] [Duration Calculations] 29,999 ms (29.999s) rounds down to 0 min -> Got: 0
[PASS] [Duration Calculations] 30,000 ms (30s) rounds up to 1 min -> Got: 1
[PASS] [Duration Calculations] 89,999 ms (1.499 min) rounds to 1 min -> Got: 1
[PASS] [Duration Calculations] 90,000 ms (1.5 min) rounds to 2 min -> Got: 2
[PASS] [Duration Calculations] 1 hour duration -> 60 min -> 1 hour
[PASS] [Duration Calculations] 2.5 hours duration -> 150 min -> 2.5 hours
[PASS] [Duration Calculations] 24 hours duration -> 1440 min -> 24 hours
[PASS] [Duration Calculations] 100 hours duration -> 6000 min -> 100 hours
[PASS] [Duration Calculations] Loading sheet total tyres loaded calculation -> Got: 75
[PASS] [Duration Calculations] Loading sheet total duration minutes calculation -> Got: 75
[PASS] [Adversarial Stress Testing] Gracefully handles corrupt JSON in localStorage -> Got: STOCKS 1
[PASS] [Adversarial Stress Testing] Gracefully handles string count in localStorage -> Got: STOCKS 1
[PASS] [Adversarial Stress Testing] Stress test: 1,000 sequential calls increment to STOCKS 1000 -> Got: STOCKS 1000
[PASS] [Adversarial Stress Testing] Handles large epoch timestamps -> 1 min
==================================================
TOTAL TESTS: 42 | PASSED: 42 | FAILED: 0
==================================================
```

---

## Unchallenged Areas

- **IndexedDB persistence layer**: Tested pure logic functions in `src/lib/loading-presets.ts`. Storage layer binding is handled separately by database repositories.
