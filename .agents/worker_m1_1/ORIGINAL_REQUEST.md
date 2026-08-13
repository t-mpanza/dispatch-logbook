## 2026-08-13T20:11:36Z

You are Worker 1 for Milestone 1: Despatch Loading Sheet Compliance System.
Your Working Directory: /home/kiddow/Desktop/Work/Despatch Diary/.agents/worker_m1_1
Project Root: /home/kiddow/Desktop/Work/Despatch Diary
Parent Orchestrator ID: ec0a910a-8eaf-4f59-928b-45156306fe9f

Read investigation reports before starting implementation:

- /home/kiddow/Desktop/Work/Despatch Diary/PROJECT.md
- /home/kiddow/Desktop/Work/Despatch Diary/.agents/sub_orch_milestone_1/SCOPE.md
- /home/kiddow/Desktop/Work/Despatch Diary/.agents/explorer_m1_1/analysis.md
- /home/kiddow/Desktop/Work/Despatch Diary/.agents/explorer_m1_2/analysis.md
- /home/kiddow/Desktop/Work/Despatch Diary/.agents/explorer_m1_3/analysis.md

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Your Tasks:

1. Data Model & Presets (`src/lib/types.ts`, `src/lib/loading-presets.ts`, `src/lib/db.ts`):
   - Update `src/lib/types.ts`: Add `PresetKey`, `LoadingSheetTrip`, update `Entry` interface with `loadingSheetTrips?: LoadingSheetTrip[]`.
   - Create `src/lib/loading-presets.ts`: Implement `LOADING_PRESETS`, `getNextStocksTripId()` (STOCKS auto-increment with midnight reset), `getPresetFill()` (NLH auto-fills Neil / MN05XNGP), `calculateDurationMinutes()`.
   - Update `src/lib/db.ts`: Add IndexedDB `settings` store and `getDespatcherName()`, `saveDespatcherName()` with dual-tier fallback to localStorage.

2. Compliance Loading Sheet UI & Integration (`src/components/LoadingSheet.tsx`, `src/routes/entry.$id.tsx`, `src/routes/counter.tsx`):
   - Create `src/components/LoadingSheet.tsx`:
     - Header: Date display, Despatcher Name input (editable + auto-saved preference).
     - 7 Active Columns: Reg (auto-uppercase), Driver Name, Trip ID (presets DBN, NLS, BLOEM, PLK, STOCKS daily counter, NLH auto-fill, TIREPOINT, CUSTOM text), Loading Start Time (auto/editable), Loading Finished Time (auto/editable), Minutes (auto-calculated duration), Quantity Loaded (auto/editable count).
     - Explicit Omissions: DO NOT render Arrival Time, Departure Time, Pressure Check, or PSI warning banner.
     - Summary Footer: TOTAL TYRES LOADED (summed count), TOTAL LOADING TIME (summed duration in minutes).
     - Standalone Manual Rows: `+ Add Standalone Truck Row` button to append manual truck rows (`isManual: true`) directly on daily sheet.
   - Integrate `LoadingSheet` into `src/routes/entry.$id.tsx` and `src/routes/counter.tsx`. Include PDF & WhatsApp action buttons.

3. PDF & WhatsApp Exports (`src/lib/export-pdf.ts`, `src/lib/export-whatsapp.ts`):
   - Create `src/lib/export-pdf.ts`: `generatePDFReport()` generating printable HTML loading sheet container with `@media print` CSS rules and triggering `window.print()`.
   - Create `src/lib/export-whatsapp.ts`: `formatWhatsAppShareText()` formatting structured markdown share string and `shareWhatsAppText()` handling clipboard and Web Share API / WhatsApp link sharing.

4. Build & Verification:
   - Run typecheck / build (`npm run build` or `npx tsc`) and any unit tests (`npm test` or `vitest` / `jest` if available). Ensure zero build or runtime errors.

Write handoff report to `/home/kiddow/Desktop/Work/Despatch Diary/.agents/worker_m1_1/handoff.md` with full details of changes, build logs, and test results, then send completion message to orchestrator.
