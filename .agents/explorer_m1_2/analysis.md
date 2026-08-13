# Investigation Report: Despatch Loading Sheet Compliance UI & Integration

**Target Component**: `src/components/LoadingSheet.tsx`  
**Target Routes**: `src/routes/entry.$id.tsx`, `src/routes/counter.tsx`  
**Milestone**: Milestone 1 — Despatch Loading Sheet Compliance System  
**Author**: Explorer 2  
**Date**: 2026-08-13

---

## 1. Executive Summary

This investigation analyzes the UI requirements, existing route structures, and component architecture for the **Despatch Loading Sheet Compliance System** (Milestone 1, Requirement §R1). Currently, the codebase has counter primitives (`CounterPanel.tsx`, `CounterProgress.tsx`) and entry detail screens (`entry.$id.tsx`), but lacks a dedicated compliance loading sheet component (`src/components/LoadingSheet.tsx`).

This report provides exact technical specs, state design, component hierarchy, line-level code references, and implementation recommendations for `LoadingSheet.tsx` and its integration into `src/routes/entry.$id.tsx` and `src/routes/counter.tsx`.

---

## 2. Investigation Findings by Requirement Area

### 2.1 Header: Date & Despatcher Name (Editable + Saved Preference)

- **Current Implementation**:
  - `src/routes/entry.$id.tsx` lines 129–138 render entry title, `fmtDayLabel(entry.createdAt)`, and `fmtTime(entry.createdAt)`.
  - There is currently no global or local state storing the Despatcher Name preference across sessions.
- **UI Requirements**:
  - **Date Display**: Display the sheet's operational date (e.g. `fmtDayLabel(dateMs)` / `YYYY-MM-DD`).
  - **Despatcher Name Input**: Prominent input field in the header (e.g. "Despatcher: [ ]").
  - **Persistence Logic**:
    - Load initial name from `localStorage.getItem("despatch_diary_despatcher_name")` (or IndexedDB settings store).
    - Auto-save on input change/blur: `localStorage.setItem("despatch_diary_despatcher_name", name)`.
    - Provide `despatcherName` prop / state to export functions (`export-pdf.ts` and `export-whatsapp.ts`).

### 2.2 Active Columns Architecture

The digital loading sheet table must present exactly 7 active columns:

| #   | Column Name             | Source / Calculation   | Interactivity & Logic                                                                                                                                                                                                                                                                                                                                                                                                                 |
| --- | ----------------------- | ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | `Reg`                   | `trip.reg`             | Editable text input. Auto-uppercase transform (`MN05XNGP`). Default empty or auto-filled via preset.                                                                                                                                                                                                                                                                                                                                  |
| 2   | `Driver Name`           | `trip.driverName`      | Editable text input (e.g. "Neil"). Default empty or auto-filled via preset.                                                                                                                                                                                                                                                                                                                                                           |
| 3   | `Trip ID`               | `trip.tripId`          | Dropdown selector with options: `DBN`, `NLS`, `BLOEM`, `PLK`, `STOCKS`, `NLH`, `TIREPOINT`, `CUSTOM`. <br>• **`STOCKS` trigger**: Auto-calculates daily sequence index `[i]` (e.g. `STOCKS 1`, `STOCKS 2`...) based on existing trips today, resetting at midnight. <br>• **`NLH` trigger**: Auto-fills `driverName = "Neil"` and `reg = "MN05XNGP"`. <br>• **`CUSTOM` trigger**: Reveals free-text input field for custom trip code. |
| 4   | `Loading Start Time`    | `trip.startTime`       | Auto-populated from 1st scan timestamp (`HH:mm`), editable formatted time picker/input.                                                                                                                                                                                                                                                                                                                                               |
| 5   | `Loading Finished Time` | `trip.finishTime`      | Auto-populated from last scan timestamp (`HH:mm`), editable formatted time picker/input.                                                                                                                                                                                                                                                                                                                                              |
| 6   | `Minutes`               | `trip.durationMinutes` | Auto-calculated duration in minutes: <br>`Math.max(0, Math.round((finishTime - startTime) / 60000))`. Read-only calculated badge; updates dynamically if times are modified.                                                                                                                                                                                                                                                          |
| 7   | `Quantity Loaded`       | `trip.quantityLoaded`  | Auto-calculated count of tyres loaded in session/trip (`count`), editable numeric input.                                                                                                                                                                                                                                                                                                                                              |

### 2.3 Explicit Omission Verification

- **Requirement**: Explicitly omit legacy fields: `Arrival Time`, `Departure Time`, `Pressure Check`, and PSI footer warning banner.
- **Audit of Existing Codebase**:
  - `src/components/EventLog.tsx`, `src/components/CounterPanel.tsx`, and `src/routes/entry.$id.tsx` do NOT contain legacy references to arrival/departure or pressure checks.
  - New compliance component `src/components/LoadingSheet.tsx` must be constructed with clean table markup containing only the 7 active columns.
  - PDF & WhatsApp exporters must omit arrival/departure/PSI banners.

### 2.4 Summary Footer: Auto-Summed Totals

- **Footer UI Structure**:
  - Summary row pinned to bottom of table card.
  - **`TOTAL TYRES LOADED`**: Sum of `quantityLoaded` across all rows for the sheet:
    $$\text{Total Quantity} = \sum_{i=1}^{N} \text{trip}_i.\text{quantityLoaded}$$
  - **`TOTAL LOADING TIME`**: Sum of `durationMinutes` across all rows:
    $$\text{Total Duration} = \sum_{i=1}^{N} \text{trip}_i.\text{durationMinutes}$$
- **Styling**: Large, high-visibility tabular numbers, glowing text (`text-primary-glow font-bold tabular-nums`).

### 2.5 Standalone Manual Truck Rows

- **Requirement**: Allow adding manual truck rows directly to the daily sheet without initiating a full scanner session (ideal for quick 2–4 tyre loads).
- **UI Action**: Button `+ Add Standalone Truck Row` below the table.
- **Row Behavior**:
  - Appends a new `LoadingSheetTrip` item with `isManual: true`.
  - Auto-initializes `startTime` and `finishTime` to current timestamp `Date.now()`.
  - Default `quantityLoaded: 2` (editable).
  - Preset selector enabled for instant auto-filling (e.g. selecting `NLH` or `STOCKS`).
  - Seamlessly included in summary footer calculations (`TOTAL TYRES LOADED` & `TOTAL LOADING TIME`).

---

## 3. Integration Plan for Existing Route Pages

### 3.1 `src/routes/entry.$id.tsx`

- **Current state**: Rendered counter via `CounterPanel` (lines 172–186) and log via `EventLog` (lines 206–221).
- **Integration**:
  - Embed `<LoadingSheet />` inside counter sessions (`isCounterSession === true`).
  - Pass `entry.trips` mapped to `LoadingSheetTrip[]`.
  - Include export toolbar above or below the sheet: `Export PDF` (calls `generatePDFReport`) & `Share WhatsApp` (calls `formatWhatsAppShareText`).

### 3.2 `src/routes/counter.tsx`

- **Current state**: Lists counter sessions and allows starting new sessions.
- **Integration**:
  - Add quick action button on session cards to view digital loading sheet directly.
  - Render aggregated daily summary numbers (`TOTAL TYRES LOADED`, `TOTAL LOADING TIME`) on today's counter card.

---

## 4. Verification & Testing Matrix

| Requirement            | Test Method                        | Expected Outcome                                                 |
| ---------------------- | ---------------------------------- | ---------------------------------------------------------------- |
| Header Despatcher Name | Edit input, refresh page           | Name persists in local storage & auto-populates                  |
| `NLH` Preset           | Select `NLH` from dropdown         | Driver auto-fills `Neil`, Reg auto-fills `MN05XNGP`              |
| `STOCKS` Preset        | Select `STOCKS`                    | Trip ID sets to `STOCKS 1`, next trip sets to `STOCKS 2`         |
| Duration Minutes       | Modify Start / Finish time         | `Minutes` column auto-updates duration                           |
| Omitted Fields         | Inspect DOM & UI                   | No Arrival, Departure, Pressure Check, or PSI banner present     |
| Footer Summary         | Add multiple trips                 | Footer correctly sums tyres loaded and aggregate loading minutes |
| Manual Row             | Click `+ Add Standalone Truck Row` | Row added, editable, included in totals                          |

---
