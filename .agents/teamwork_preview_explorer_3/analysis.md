# Codebase Analysis Report: Loading Sheet, Exports & Build/Test Tooling

**Agent**: `teamwork_preview_explorer_3` (Codebase Researcher)  
**Date**: 2026-08-13  
**Working Directory**: `/home/kiddow/Desktop/Work/Despatch Diary/.agents/teamwork_preview_explorer_3`  
**Project Root**: `/home/kiddow/Desktop/Work/Despatch Diary`

---

## Executive Summary

This investigation analyzed the existing Despatch Diary codebase across four primary domains:

1. **Loading Sheet & Trip Counting System**: Investigated `CounterPanel`, `CounterProgress`, `EventLog`, and related routes (`/counter`, `/entry/$id`). Identified existing fields, scanning vs. manual entry tabs, and missing compliance features (vehicle reg, driver name, presets like STOCKS/NLH, start/finish duration, footers).
2. **Export Functionality (PDF, Print, WhatsApp)**: Verified that **no export mechanism exists**. PDF generation libraries, print CSS/layouts (`@media print`), and WhatsApp text generators are entirely absent (corroborated by `docs/KNOWN_GAPS.md`).
3. **Tech Stack & Build Tooling**: Documented full stack (React 19, `@tanstack/react-start`, `@tanstack/react-router`, `@tanstack/react-query`, Tailwind v4, IndexedDB via `idb`, Supabase, Capacitor 8). Documented package manager (`bun`/`npm`), scripts, Vite config, ESLint 9 setup, and environment variables.
4. **Existing Test Suites**: Confirmed **zero unit, integration, or E2E tests** for the React application. The only existing test file is a default Capacitor Android boilerplate test (`ExampleUnitTest.java`).

---

## Section 1: Loading Sheet Implementation & Trip Log Components

### 1.1 Existing Architecture & File Mapping

| Component / File                     | Purpose & Responsibilities                                                                                              | Key Props / Exports                                                                           |
| ------------------------------------ | ----------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| `src/routes/counter.tsx`             | Dashboard route (`/counter`) for listing trip count sessions and starting new count sessions                            | Route definition, `startNew()` handler creating entry with `withCounter: true`                |
| `src/routes/entry.$id.tsx`           | Entry detail/editor route (`/entry/:id`). Renders sticky counter progress & counter panel when `entry.trips` is defined | `CounterProgress`, `CounterPanel`, sticky header, auto-scrolling event log, FAB note bar      |
| `src/components/CounterPanel.tsx`    | Counter controls with 2 tabs: **"Scanned"** and **"Manual (No-NFC)"**                                                   | `trips: Trip[]`, `onChange: (next: Trip[]) => void`, `onAttachment?: (a: Attachment) => void` |
| `src/components/CounterProgress.tsx` | Visual progress card showing running total vs. target (`expectedTotal`)                                                 | `total`, `tripCount`, `expectedTotal`, `onSetExpected`                                        |
| `src/components/EventLog.tsx`        | Unified timeline event log sorting notes, attachments, and trip chips chronologically                                   | `notes`, `attachments`, `trips`, deletion handlers                                            |
| `src/lib/types.ts`                   | Data models (`Trip`, `Entry`, `NoteBlock`, `Attachment`)                                                                | Data interfaces                                                                               |
| `src/lib/templates.ts`               | Preset quick templates for entry title creation                                                                         | `QUICK_TEMPLATES` array                                                                       |

### 1.2 Data Model Analysis (`src/lib/types.ts`)

```ts
export interface Trip {
  id: string;
  count: number; // Scanned / accepted tyre count
  rejected?: number; // Manual / No-NFC tyre count
  note?: string; // Slip reference e.g. "slip:text:123" or "slip:photo:id"
  createdAt: number; // Epoch timestamp ms
}

export interface Entry {
  id: string;
  title: string;
  tags: string[];
  notes: NoteBlock[];
  attachments: Attachment[];
  trips?: Trip[]; // undefined = no counter; [] = counter enabled
  expectedTotal?: number; // Target total set via CounterProgress
  createdAt: number;
  updatedAt: number;
  dayKey: string; // "YYYY-MM-DD"
  monthKey: string; // "YYYY-MM"
  yearKey: string; // "YYYY"
}
```

### 1.3 Feature Comparison: Existing Implementation vs. Despatched Requirements

| Requirement Domain | Existing Implementation                                                                                                                                                      | Gap / Missing Implementation                                                                                                                                                                                                                             |
| ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Header Fields**  | Editable entry title (monospace) + date & time (`fmtDayLabel`, `fmtTime`) in `entry.$id.tsx`.                                                                                | Missing **Despatcher Name** (saved user preference setting/field).                                                                                                                                                                                       |
| **Trip Columns**   | `count` (scanned), `rejected` (manual), `note` (slip text/photo), `createdAt`.                                                                                               | Missing: **Vehicle Reg (`Reg`)**, **Driver Name**, **Trip ID**, **Loading Start Time**, **Loading Finished Time**, **Minutes (duration)**, **Quantity Loaded**.                                                                                          |
| **Presets**        | Generic entry title templates in `src/lib/templates.ts` ("Tyre count", "Tyre issue", "Driver issue", "Invoice mismatch", "Missing stock", "Loading delay", "Damage report"). | Missing vehicle/route loading sheet presets specified in R1: **DBN**, **NLS**, **BLOEM**, **PLK**, **STOCKS [i]** (daily auto-incrementing counter resetting at midnight), **NLH** (auto-fills Driver: Neil & Reg: MN05XNGP), **TIREPOINT**, **Custom**. |
| **Manual Entry**   | Tab toggle in `CounterPanel.tsx`: `Manual (No-NFC)`. Accepts manual count, optional slip number text, or slip photo via `<InAppCamera>`.                                     | Missing standalone manual truck rows with Reg, Driver Name, Start/Finish duration, and quick-preset selectors.                                                                                                                                           |
| **Summary Footer** | `CounterProgress.tsx` shows total loaded count (`total`), target count (`expectedTotal`), remaining/over indicators, and progress bar.                                       | Missing: **TOTAL TYRES LOADED** & **TOTAL LOADING TIME** table summary footers.                                                                                                                                                                          |

---

## Section 2: Export Functionality (PDF, Print Layouts & WhatsApp Share)

### 2.1 PDF Generation Status

- **Status**: **0% Implemented (Completely Missing)**.
- **Evidence**:
  - `package.json` contains no PDF libraries (`jspdf`, `@react-pdf/renderer`, `html2pdf.js`, `pdfmake`, `print-js`).
  - Grep search for `pdf` across `src/` yielded no PDF export code or generators.
  - `docs/KNOWN_GAPS.md` line 116 explicitly documents: `P2 — No export/backup mechanism: All data is in IndexedDB on one device. No way to export entries as JSON, CSV, or PDF.`

### 2.2 Print Layouts & CSS Status

- **Status**: **0% Implemented**.
- **Evidence**:
  - `src/styles.css` contains no `@media print` rules.
  - No `window.print()` triggers exist in any component or route.

### 2.3 WhatsApp Share Text Generators Status

- **Status**: **0% Implemented**.
- **Evidence**:
  - Grep search for `whatsapp` or `share` across `src/` returned zero matching share utilities or text formatters.
  - No `whatsapp://send` links, `https://wa.me/` URLs, or `navigator.share` Web Share API invocations exist in the codebase.

---

## Section 3: Tech Stack & Build Tooling

### 3.1 Core Stack Specifications

| Layer                      | Library / Tool             | Version              | Notes                                                                                   |
| -------------------------- | -------------------------- | -------------------- | --------------------------------------------------------------------------------------- |
| **UI Framework**           | React                      | `^19.2.0`            | React 19 runtime with `react-dom`                                                       |
| **Meta-Framework**         | `@tanstack/react-start`    | `^1.167.50`          | Fullstack TanStack Start Vite plugin                                                    |
| **Routing**                | `@tanstack/react-router`   | `^1.168.25`          | File-based routing in `src/routes/` auto-generating `src/routeTree.gen.ts`              |
| **State / Data Fetching**  | `@tanstack/react-query`    | `^5.83.0`            | Query cache & invalidation engine                                                       |
| **Styling & UI**           | Tailwind CSS v4            | `^4.2.1`             | `@tailwindcss/vite` plugin, `tw-animate-css`, Radix UI primitives                       |
| **Local Database**         | IndexedDB via `idb`        | `^8.0.3`             | DB: `dispatch-diary` (v1), stores: `entries`, `reminders`                               |
| **Remote Database / Sync** | `@supabase/supabase-js`    | `^2.106.1`           | Supabase auth, storage (`attachments`), and table sync (`entries`, `entry_attachments`) |
| **Mobile Runtime**         | Capacitor 8                | `^8.3.4`             | `@capacitor/core`, `@capacitor/android`, `@capacitor/app`, `@capacitor/status-bar`      |
| **Icons & Date Utils**     | `lucide-react`, `date-fns` | `^0.575.0`, `^4.2.1` | Lucide icon set, date formatting & ISO week helpers                                     |

### 3.2 Package Manager & Scripts

- **Package Manager**: `bun` (primary lockfile `bun.lock`, `bunfig.toml`), npm fallback (`package-lock.json`).
- **NPM Scripts (`package.json`)**:
  - `npm run dev` -> `vite dev` (Starts local development server)
  - `npm run build` -> `vite build && cp dist/client/index.html dist/client/404.html` (Production build for GitHub Pages / static hosting)
  - `npm run build:dev` -> `vite build --mode development` (Development mode bundle build)
  - `npm run preview` -> `vite preview` (Preview production build output)
  - `npm run lint` -> `eslint .` (Runs ESLint across project)
  - `npm run format` -> `prettier --write .` (Runs Prettier code formatter)

### 3.3 Linting, Formatting & TypeScript Config

- **ESLint**: ESLint 9 flat config in `eslint.config.js` utilizing `typescript-eslint`, `eslint-plugin-react-hooks`, `eslint-plugin-react-refresh`, and `eslint-plugin-prettier`.
- **Prettier**: Configured via `.prettierrc` (`semi: true`, `singleQuote: false`, `tabWidth: 2`, `trailingComma: "all"`).
- **TypeScript**: TS 5.8 with `tsconfig.json` (`strict: true`, `target: ES2022`, `moduleResolution: Bundler`, path mapping `@/*` -> `./src/*`).

### 3.4 Environment & Build Configuration

- `.env.example` / `.env` variables:
  - `VITE_SUPABASE_URL`
  - `VITE_SUPABASE_PUBLISHABLE_KEY`
- `vite.config.ts`:
  - `base`: `process.env.GITHUB_PAGES ? "/dispatch-logbook/" : "/"`
  - `VitePWA`: `injectManifest` strategy with custom SW at `public/sw.js`.

---

## Section 4: Existing Test Suites

### 4.1 Test Suite Audit

| Category                | Present in Codebase? | Details / Findings                                                                                                                                                               |
| ----------------------- | -------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Frontend Unit Tests** | ❌ No                | 0 unit test files (`*.test.ts`, `*.test.tsx`, `*.spec.ts`) in `src/`. No test framework (`vitest`, `jest`) installed in `package.json`.                                          |
| **Integration Tests**   | ❌ No                | No component integration tests, API mocks (`msw`), or test utilities installed.                                                                                                  |
| **E2E Tests**           | ❌ No                | No Playwright, Cypress, or Selenium configurations or tests present.                                                                                                             |
| **Test Scripts**        | ❌ No                | `package.json` contains no `test` script.                                                                                                                                        |
| **Mobile Native Test**  | ⚠️ Partial           | 1 default Android Capacitor template file (`android/app/src/test/java/com/getcapacitor/myapp/ExampleUnitTest.java`) containing a basic JUnit assertion `assertEquals(4, 2 + 2)`. |

---

## Section 5: Recommendations & Proposed Architecture for Implementation

To prepare for subsequent implementation agents:

1. **Loading Sheet Compliance Schema**:
   - Extend `Trip` interface in `src/lib/types.ts`:
     ```ts
     export interface LoadingSheetTrip {
       id: string;
       reg: string; // Vehicle Registration e.g. "MN05XNGP"
       driverName: string; // Driver Name e.g. "Neil"
       tripId: string; // Preset/Trip ID e.g. "NLH", "STOCKS-1"
       startTime: number; // Loading Start Time (timestamp ms)
       finishTime?: number; // Loading Finish Time (timestamp ms)
       durationMinutes?: number; // Calculated duration in minutes
       quantityLoaded: number; // Tyre count
       presetKey?: string; // "DBN" | "NLS" | "BLOEM" | "PLK" | "STOCKS" | "NLH" | "TIREPOINT" | "CUSTOM"
       createdAt: number;
     }
     ```
   - Add `despatcherName?: string` to `Entry` or user preferences in `src/lib/types.ts`.
2. **Preset Registry & Auto-Increment Logic**:
   - Create `src/lib/loading-presets.ts` providing preset defaults:
     - `NLH`: Auto-fills `driverName: "Neil"` and `reg: "MN05XNGP"`.
     - `STOCKS`: Auto-increments daily counter (`STOCKS [1]`, `STOCKS [2]`), stored in IDB or local storage and reset at midnight.
     - `DBN`, `NLS`, `BLOEM`, `PLK`, `TIREPOINT`, `CUSTOM`.
3. **Export Engine**:
   - Install or integrate PDF generation (e.g. `html2pdf.js` or `@react-pdf/renderer` or native print stylesheet `@media print`).
   - Create `src/lib/export.ts` with:
     - `generateWhatsAppText(entry: Entry): string` (formats tabular markdown for WhatsApp sharing with `whatsapp://send?text=...` URI).
     - `generatePdfReport(entry: Entry): Promise<Blob>` (creates structured PDF containing header, table of trips, and totals summary footer).
4. **Test Harness Setup**:
   - Add `vitest` and `@testing-library/react` to `devDependencies` and add `"test": "vitest"` script to `package.json`.
