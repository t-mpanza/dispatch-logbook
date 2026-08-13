# Milestone 1: Despatch Loading Sheet Compliance System — Technical Investigation Report

**Author**: Explorer 1  
**Target Milestone**: Milestone 1 (Despatch Loading Sheet Compliance System)  
**Date**: 2026-08-13  
**Status**: Investigation Complete

---

## Executive Summary

This investigation analyzes the existing data models, IndexedDB persistence layer, and requirements for the **Digital "DESPATCH LOADING SHEET" Compliance System** (Milestone 1).
Currently, the codebase contains base types (`Trip`, `Entry`, `Attachment`) in `src/lib/types.ts` and IndexedDB helpers in `src/lib/db.ts`. The preset module `src/lib/loading-presets.ts` does not yet exist.

This report defines the exact type contracts, database schema extensions, preset manager design, daily `STOCKS [i]` counter logic, `NLH` auto-fill rules, and Despatcher Name saved preference logic required for implementation.

---

## 1. `LoadingSheetTrip` Data Model & Structure

### Existing State vs Proposed Contract

Currently, `src/lib/types.ts` defines a simple `Trip` interface:

```ts
export interface Trip {
  id: string;
  count: number;
  rejected?: number;
  note?: string;
  createdAt: number;
}
```

To support full compliance loading sheet requirements (Reg, Driver Name, Trip ID, Start/Finish times, Duration, Quantity Loaded, Rejected count, Notes, Standalone Manual flag), `src/lib/types.ts` must be extended with `PresetKey` and `LoadingSheetTrip`.

### Interface Definitions (`src/lib/types.ts`)

```ts
export type PresetKey = "DBN" | "NLS" | "BLOEM" | "PLK" | "STOCKS" | "NLH" | "TIREPOINT" | "CUSTOM";

export interface LoadingSheetTrip {
  id: string;
  reg: string; // Truck registration plate (e.g. "MN05XNGP")
  driverName: string; // Driver name (e.g. "Neil")
  tripId: string; // Trip ID preset or custom text (e.g. "STOCKS 1", "NLH", "DBN")
  presetKey?: PresetKey; // Optional key indicating preset used
  startTime?: number; // Epoch timestamp ms of 1st scan
  finishTime?: number; // Epoch timestamp ms of last scan
  durationMinutes?: number; // Auto-calculated duration (finishTime - startTime) in minutes
  quantityLoaded: number; // Tyres loaded count
  rejectedCount?: number; // Tyres rejected count
  note?: string; // Optional notes / slip info
  isManual?: boolean; // True if standalone manual truck entry bypassing scanner
  createdAt: number; // Creation timestamp ms
}
```

### Updates to `Entry` Type

`Entry` in `src/lib/types.ts` should be updated to support `loadingSheetTrips`:

```ts
export interface Entry {
  id: string;
  title: string;
  tags: string[];
  notes: NoteBlock[];
  attachments: Attachment[];
  trips?: Trip[]; // Legacy/simple counter trips
  loadingSheetTrips?: LoadingSheetTrip[]; // Compliance sheet trips
  expectedTotal?: number;
  createdAt: number;
  updatedAt: number;
  dayKey: string;
  monthKey: string;
  yearKey: string;
}
```

---

## 2. Preset Manager Architecture (`src/lib/loading-presets.ts`)

A dedicated preset manager module `src/lib/loading-presets.ts` must be created.

### Preset Configurations

The 7 compliance presets plus Custom option are defined as:

```ts
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
```

### Return Contract (`PresetFillResult`)

```ts
export interface PresetFillResult {
  presetKey: PresetKey;
  tripId: string;
  driverName?: string;
  reg?: string;
}
```

---

## 3. `STOCKS [i]` Daily Auto-Incrementing Counter Logic

### Requirements

- Selecting `STOCKS` generates `STOCKS 1`, `STOCKS 2`, `STOCKS 3`...
- Counter auto-increments with each selection on the same day.
- Counter **resets at midnight (00:00)** every day.

### Detailed State & Algorithm Specification

1. **Persistence Mechanism**:
   - Store counter state in `localStorage` under key `dispatch_stocks_counter`.
   - Data structure: `{ dateKey: string; count: number }` (e.g. `{ dateKey: "2026-08-13", count: 2 }`).

2. **Algorithm Steps**:

   ```ts
   export function getNextStocksTripId(
     todayDayKey: string,
     existingTrips: LoadingSheetTrip[] = [],
   ): string {
     // Step A: Inspect existing trips on today's sheet for highest STOCKS index
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

     // Step B: Check stored state in localStorage
     let storedCount = 0;
     try {
       const raw = localStorage.getItem("dispatch_stocks_counter");
       if (raw) {
         const parsed = JSON.parse(raw);
         if (parsed.dateKey === todayDayKey && typeof parsed.count === "number") {
           storedCount = parsed.count;
         }
       }
     } catch (e) {
       console.error("Error reading STOCKS counter:", e);
     }

     // Step C: Determine next index (higher of stored vs sheet existing + 1)
     const nextIndex = Math.max(maxExisting, storedCount) + 1;

     // Step D: Update stored state
     try {
       localStorage.setItem(
         "dispatch_stocks_counter",
         JSON.stringify({ dateKey: todayDayKey, count: nextIndex }),
       );
     } catch (e) {
       console.error("Error saving STOCKS counter:", e);
     }

     return `STOCKS ${nextIndex}`;
   }
   ```

3. **Midnight Reset Guarantee**:
   Because `todayDayKey` changes at midnight (e.g. from `2026-08-13` to `2026-08-14`), any stored counter from the previous day is discarded, automatically resetting the starting count to 1 for the new date.

---

## 4. `NLH` Preset Auto-Filling Logic

### Requirements

- Selecting `NLH` preset automatically populates:
  - **Driver Name**: `Neil`
  - **Reg**: `MN05XNGP`
  - **Trip ID**: `NLH`

### Implementation Logic in `getPresetFill`

```ts
export function getPresetFill(
  key: PresetKey,
  context?: { dayKey: string; existingTrips?: LoadingSheetTrip[] },
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
```

---

## 5. Despatcher Name Saved Preference Logic

### Requirements

- Header displays Date and Despatcher Name.
- Despatcher Name must be editable and saved as a user preference across app reloads and browser sessions.

### Persistence Strategy (`src/lib/db.ts`)

We specify a dual-tier persistence layer:

1. `localStorage` key `dispatch_despatcher_name` for instant synchronous initial render without flicker.
2. IndexedDB `settings` objectStore for full offline persistence and sync compatibility.

### Database Schema Upgrade in `src/lib/db.ts`

Upgrade `DB_VERSION` from `1` to `2` or create `settings` store on upgrade:

```ts
if (!db.objectStoreNames.contains("settings")) {
  db.createObjectStore("settings");
}
```

### Helper Functions in `src/lib/db.ts`

```ts
const DESPATCHER_NAME_KEY = "dispatch_despatcher_name";

export async function getDespatcherName(): Promise<string> {
  if (typeof window !== "undefined") {
    const local = localStorage.getItem(DESPATCHER_NAME_KEY);
    if (local !== null) return local;
  }
  try {
    const db = await getDB();
    const val = await db.get("settings", "despatcherName");
    return val ?? "";
  } catch {
    return "";
  }
}

export async function saveDespatcherName(name: string): Promise<void> {
  const trimmed = name.trim();
  if (typeof window !== "undefined") {
    localStorage.setItem(DESPATCHER_NAME_KEY, trimmed);
  }
  try {
    const db = await getDB();
    await db.put("settings", trimmed, "despatcherName");
  } catch (e) {
    console.error("Failed to save despatcher name to IndexedDB:", e);
  }
}
```

---

## Summary of Proposed Code Additions & Files

| File                         | Proposed Modification / Creation                                                                          |
| ---------------------------- | --------------------------------------------------------------------------------------------------------- |
| `src/lib/types.ts`           | Add `PresetKey`, `LoadingSheetTrip`, update `Entry` interface                                             |
| `src/lib/db.ts`              | Add `settings` store, `getDespatcherName()`, `saveDespatcherName()`                                       |
| `src/lib/loading-presets.ts` | **NEW FILE**: `LOADING_PRESETS`, `getNextStocksTripId()`, `getPresetFill()`, `calculateDurationMinutes()` |

---

## Verification & Independent Test Plan

1. **Preset & Auto-Fill Verification**:
   - Verify selecting `NLH` returns driver `Neil` and reg `MN05XNGP`.
   - Verify selecting route presets (`DBN`, `NLS`, `BLOEM`, `PLK`, `TIREPOINT`) sets `tripId` matching preset key.
2. **`STOCKS` Counter Verification**:
   - Call `getNextStocksTripId("2026-08-13", [])` -> expected `"STOCKS 1"`.
   - Call again -> expected `"STOCKS 2"`.
   - Call with different date `getNextStocksTripId("2026-08-14", [])` -> expected `"STOCKS 1"` (midnight reset verified).
3. **Despatcher Name Preference Verification**:
   - Save name `"John Doe"` via `saveDespatcherName`.
   - Reload / call `getDespatcherName()` -> expected `"John Doe"`.
