# Investigation & Requirements Analysis: Export Infrastructure (PDF & WhatsApp)

**Agent:** Explorer 3 (Milestone 1)  
**Target Files:** `src/lib/export-pdf.ts`, `src/lib/export-whatsapp.ts`  
**Project Root:** `/home/kiddow/Desktop/Work/Despatch Diary`  
**Date:** 2026-08-13

---

## 1. Executive Summary

Milestone 1 requires a digital **DESPATCH LOADING SHEET** compliance system with export capabilities:

1. **Printable PDF Loading Sheet Report**: Clean, high-contrast A4 print report containing sheet metadata (Date, Despatcher Name), exact required active table columns (`Reg`, `Driver Name`, `Trip ID`, `Loading Start Time`, `Loading Finished Time`, `Minutes`, `Quantity Loaded`), and summary footer totals (`TOTAL TYRES LOADED`, `TOTAL LOADING TIME`), while strictly omitting deprecated legacy fields (Arrival Time, Departure Time, Pressure Check, PSI warning banner).
2. **WhatsApp Formatted Text Share**: Structured WhatsApp markdown formatted message summarizing the day's despatch loading sheet or individual trip entry for instant messaging sharing via Web Share API or `whatsapp://` URL scheme.

Existing codebase analysis reveals:

- Neither `src/lib/export-pdf.ts` nor `src/lib/export-whatsapp.ts` currently exist in `src/lib/`. They must be created as new modules during implementation.
- `package.json` currently contains `@tanstack/react-router`, `@tanstack/react-query`, `lucide-react`, `date-fns`, and `tailwindcss` (v4). It does **NOT** contain `jspdf`, `jspdf-autotable`, `html2canvas`, or `html-pdf`.
- Export infrastructure should leverage native browser print capabilities (`window.print()` with styled `@media print` rules) and pure TypeScript string formatting for WhatsApp sharing to avoid heavy third-party bundle overhead while remaining 100% offline-ready.

---

## 2. Dependencies & Existing Codebase Analysis

### 2.1 Dependency Audit (`package.json`)

Inspection of `package.json` shows the following existing packages:

- **Date manipulation**: `date-fns` (v4.2.1) — ideal for formatting date labels, times, and duration calculations (`format`, `parseISO`).
- **Icons**: `lucide-react` (v0.575.0) — provides icons like `Printer`, `Share2`, `FileText`, `MessageSquare`, `Check`, `Copy`.
- **Styling**: `tailwindcss` (v4.2.1) with `@tailwindcss/vite` — CSS classes for layout, typography, print visibility control (`print:block`, `print:hidden`).
- **PDF libraries**: **None installed**. No `jspdf`, `pdfmake`, or `html2pdf.js` in `dependencies`.

### 2.2 Existing Utilities (`src/lib/format.ts`)

- `fmtDayLabel(d)`: Formats dates like `"Thursday, 13 Aug"`.
- `fmtTime(d)`: Formats timestamps like `"08:30"`.
- `dayKey(d)`: Generates `"yyyy-MM-dd"`.
- `formatDuration(ms)`: Formats milliseconds as `"MM:SS"`.

---

## 3. Requirement 1: Printable PDF Loading Sheet Report (`src/lib/export-pdf.ts`)

### 3.1 Document Layout & Structural Specifications

The printable loading sheet report must match exact compliance standards:

#### 1. Header Section

- **Document Title**: `DESPATCH LOADING SHEET` (Bold, uppercase, 18pt font).
- **Date**: Formatted date string (e.g. `2026-08-13` / `Thursday, 13 August 2026`).
- **Despatcher Name**: Name of despatcher (retrieved from user settings / localStorage, e.g. `John Doe`).
- **Sheet ID / Reference**: Entry ID or Title (e.g. `DAILY SHEET — 2026-08-13`).

#### 2. Active Table Columns (Exact 7 Columns)

| Column Name     | Field Key         | Source & Description                        | Format Example             |
| --------------- | ----------------- | ------------------------------------------- | -------------------------- |
| **Reg**         | `reg`             | Truck Registration Plate                    | `MN05XNGP`                 |
| **Driver Name** | `driverName`      | Driver Full Name                            | `Neil`                     |
| **Trip ID**     | `tripId`          | Preset or Custom Trip Identifier            | `STOCKS 1` / `NLH` / `DBN` |
| **Start**       | `startTime`       | Loading Start Time (1st scan timestamp)     | `08:15`                    |
| **Finish**      | `finishTime`      | Loading Finished Time (last scan timestamp) | `09:00`                    |
| **Minutes**     | `durationMinutes` | Calculated loading duration                 | `45 mins`                  |
| **Qty Loaded**  | `quantityLoaded`  | Total tyres loaded count                    | `120`                      |

#### 3. Deprecated / Removed Fields (STRICT COMPLIANCE)

- ❌ **Arrival Time**: Omitted.
- ❌ **Departure Time**: Omitted.
- ❌ **Pressure Check**: Omitted.
- ❌ **PSI Warning Banner**: Omitted.

#### 4. Summary Footer Section

- **TOTAL TYRES LOADED**: Auto-calculated sum of `quantityLoaded` across all trip rows on the sheet (e.g. `480`).
- **TOTAL LOADING TIME**: Aggregate sum of `durationMinutes` across all trip rows on the sheet (e.g. `180 mins` / `3 hrs 00 mins`).
- **Sign-off / Verification Line**: Signature line for Despatch Supervisor approval (clean professional touch).

---

### 3.2 Technical Generation Strategies: Native Print Engine vs jsPDF

We evaluated two potential architectures for `src/lib/export-pdf.ts`:

#### Strategy A: Native Browser Print Engine + Hidden DOM Print Document (RECOMMENDED)

- **Mechanism**: `generatePDFReport()` dynamically injects or renders a standard hidden HTML print container (`<div id="printable-loading-sheet">...</div>`), populates header, table rows, and footer totals, applies print-specific styling, triggers `window.print()`, and cleans up after printing.
- **Advantages**:
  - **Zero external dependencies**: No heavy PDF library needed.
  - **Native PDF Export**: All modern browsers (Desktop Chrome, Safari, Android Chrome, Edge) include a native "Save as PDF" destination in the print dialog.
  - **Crisp Typography & Layout**: High quality vector text, CSS grid/table layout, exact page boundaries, printable headers/footers via `@media print`.
  - **Full Offline Compatibility**: Works 100% offline inside standard web browsers and Capacitor PWA webview containers.

#### Strategy B: Programmatic PDF File Download (`jsPDF`)

- **Mechanism**: Imports `jspdf` and `jspdf-autotable` to manually build a binary PDF document in memory and trigger file download (`loading_sheet_2026-08-13.pdf`).
- **Advantages**: Directly triggers file download without opening browser print UI modal.
- **Disadvantages**:
  - Requires adding ~300KB `jspdf` and `jspdf-autotable` dependencies to `package.json`.
  - Manual cell coordinate math required for dynamic table rendering, custom headers, footers, and font styling.

#### Decision Recommendation

The primary implementation in `src/lib/export-pdf.ts` should use **Strategy A (Browser Native Print Engine)** as the zero-dependency, standard PDF export method, with a structured printable HTML template. If direct PDF binary downloading is strictly required without a print dialog, `jsPDF` can optionally be added as a dependency.

---

### 3.3 Print CSS Rules Specification (`@media print`)

```css
@media print {
  /* Hide standard web app UI elements */
  body * {
    visibility: hidden;
  }

  /* Show only the printable loading sheet container */
  #printable-loading-sheet,
  #printable-loading-sheet * {
    visibility: visible;
  }

  #printable-loading-sheet {
    position: absolute;
    left: 0;
    top: 0;
    width: 100%;
    margin: 0;
    padding: 15mm;
    background: #ffffff !important;
    color: #000000 !important;
    font-family: Arial, Helvetica, sans-serif;
  }

  @page {
    size: A4 portrait;
    margin: 10mm;
  }

  /* Table typography and borders */
  table.loading-sheet-table {
    width: 100%;
    border-collapse: collapse;
    margin-top: 15px;
    margin-bottom: 20px;
  }

  table.loading-sheet-table th,
  table.loading-sheet-table td {
    border: 1px solid #000000;
    padding: 6px 10px;
    font-size: 11pt;
    text-align: left;
  }

  table.loading-sheet-table th {
    background-color: #f0f0f0 !important;
    font-weight: bold;
    text-transform: uppercase;
    font-size: 10pt;
  }

  .summary-box {
    border: 2px solid #000000;
    padding: 12px;
    margin-top: 15px;
    background-color: #f9f9f9 !important;
    page-break-inside: avoid;
  }
}
```

---

## 4. Requirement 2: WhatsApp Formatted Text Share Message (`src/lib/export-whatsapp.ts`)

### 4.1 Daily Sheet Summary WhatsApp Format

```text
📋 *DESPATCH LOADING SHEET*
📅 *Date:* 2026-08-13
👤 *Despatcher:* John Doe

🚛 *LOADED TRIPS (4)*
----------------------------------
1. *Reg:* MN05XNGP | *Driver:* Neil
   └ *Trip ID:* NLH (STOCKS 1)
   └ *Time:* 08:15 - 09:00 (45 mins)
   └ *Qty:* 120 tyres

2. *Reg:* CA12345 | *Driver:* Sipho
   └ *Trip ID:* DBN
   └ *Time:* 09:15 - 10:30 (75 mins)
   └ *Qty:* 150 tyres

3. *Reg:* ND98765 | *Driver:* Michael
   └ *Trip ID:* BLOEM
   └ *Time:* 10:45 - 11:30 (45 mins)
   └ *Qty:* 90 tyres

4. *Reg:* CY54321 | *Driver:* David
   └ *Trip ID:* TIREPOINT
   └ *Time:* 12:00 - 12:20 (20 mins)
   └ *Qty:* 120 tyres
----------------------------------
📊 *SUMMARY TOTALS*
📦 *Total Tyres Loaded:* 480 tyres
⏱️ *Total Loading Time:* 180 mins (3 hrs 00 mins)
```

---

### 4.2 Single Trip WhatsApp Share Format

```text
🚚 *DESPATCH TRIP ENTRY*
📅 *Date:* 2026-08-13 | 👤 *Despatcher:* John Doe
🚛 *Reg:* MN05XNGP
👤 *Driver:* Neil
🔖 *Trip ID:* STOCKS 1
⏱️ *Time:* 08:15 - 09:00 (45 mins)
📦 *Qty Loaded:* 120 tyres
```

---

### 4.3 Sharing Execution Mechanism

In `src/lib/export-whatsapp.ts`:

1. `formatWhatsAppShareText(trips: LoadingSheetTrip[], despatcherName: string, dateStr: string): string`: Constructs structured markdown string.
2. `shareWhatsAppText(text: string): Promise<void>`:
   - **Step 1**: Tries `navigator.clipboard.writeText(text)` so message is immediately copied to clipboard.
   - **Step 2**: If `navigator.share` is supported (mobile devices / PWA), invokes `await navigator.share({ title: "Despatch Loading Sheet", text })`.
   - **Step 3**: Fallback: opens `https://api.whatsapp.com/send?text=${encodeURIComponent(text)}` in new browser window.

---

## 5. Interface Contracts & Proposed Code Implementation

### 5.1 `src/lib/export-pdf.ts` Proposed Implementation Sketch

```ts
import type { LoadingSheetTrip } from "./types";
import { format } from "date-fns";

export interface PDFExportData {
  title?: string;
  dateStr: string;
  despatcherName: string;
  trips: LoadingSheetTrip[];
}

export function generatePDFReport(data: PDFExportData): void {
  const { title = "DESPATCH LOADING SHEET", dateStr, despatcherName, trips } = data;

  const totalQty = trips.reduce((sum, t) => sum + (t.quantityLoaded || 0), 0);
  const totalMins = trips.reduce((sum, t) => sum + (t.durationMinutes || 0), 0);
  const hours = Math.floor(totalMins / 60);
  const mins = totalMins % 60;
  const timeFormatted = hours > 0 ? `${hours}h ${mins}m (${totalMins} mins)` : `${totalMins} mins`;

  // Remove existing print container if present
  const existing = document.getElementById("printable-loading-sheet");
  if (existing) existing.remove();

  const printContainer = document.createElement("div");
  printContainer.id = "printable-loading-sheet";
  printContainer.className = "hidden print:block";

  printContainer.innerHTML = `
    <div style="font-family: Arial, sans-serif; color: #000; padding: 20px;">
      <div style="display: flex; justify-content: space-between; align-items: flex-start; border-bottom: 2px solid #000; padding-bottom: 10px; margin-bottom: 15px;">
        <div>
          <h1 style="font-size: 20pt; margin: 0; font-weight: bold; text-transform: uppercase;">${title}</h1>
          <p style="margin: 4px 0 0 0; font-size: 10pt; color: #333;">Dispatch Compliance System</p>
        </div>
        <div style="text-align: right; font-size: 10pt;">
          <p style="margin: 0;"><strong>Date:</strong> ${dateStr}</p>
          <p style="margin: 3px 0 0 0;"><strong>Despatcher:</strong> ${despatcherName || "N/A"}</p>
        </div>
      </div>

      <table style="width: 100%; border-collapse: collapse; margin-top: 10px; font-size: 10pt;">
        <thead>
          <tr style="background-color: #f2f2f2;">
            <th style="border: 1px solid #000; padding: 8px; text-align: left;">Reg</th>
            <th style="border: 1px solid #000; padding: 8px; text-align: left;">Driver Name</th>
            <th style="border: 1px solid #000; padding: 8px; text-align: left;">Trip ID</th>
            <th style="border: 1px solid #000; padding: 8px; text-align: center;">Start</th>
            <th style="border: 1px solid #000; padding: 8px; text-align: center;">Finish</th>
            <th style="border: 1px solid #000; padding: 8px; text-align: right;">Minutes</th>
            <th style="border: 1px solid #000; padding: 8px; text-align: right;">Qty Loaded</th>
          </tr>
        </thead>
        <tbody>
          ${trips
            .map(
              (t) => `
            <tr>
              <td style="border: 1px solid #000; padding: 8px; font-weight: bold;">${t.reg || "-"}</td>
              <td style="border: 1px solid #000; padding: 8px;">${t.driverName || "-"}</td>
              <td style="border: 1px solid #000; padding: 8px;">${t.tripId || "-"}</td>
              <td style="border: 1px solid #000; padding: 8px; text-align: center;">${t.startTime ? format(t.startTime, "HH:mm") : "-"}</td>
              <td style="border: 1px solid #000; padding: 8px; text-align: center;">${t.finishTime ? format(t.finishTime, "HH:mm") : "-"}</td>
              <td style="border: 1px solid #000; padding: 8px; text-align: right;">${t.durationMinutes ?? "-"}</td>
              <td style="border: 1px solid #000; padding: 8px; text-align: right; font-weight: bold;">${t.quantityLoaded}</td>
            </tr>
          `,
            )
            .join("")}
        </tbody>
      </table>

      <div style="margin-top: 20px; border: 2px solid #000; padding: 12px; background-color: #fafafa; display: flex; justify-content: space-between; font-size: 11pt;">
        <div>
          <span><strong>TOTAL TRIPS:</strong> ${trips.length}</span>
        </div>
        <div>
          <span style="margin-right: 25px;"><strong>TOTAL LOADING TIME:</strong> ${timeFormatted}</span>
          <span><strong>TOTAL TYRES LOADED:</strong> ${totalQty}</span>
        </div>
      </div>

      <div style="margin-top: 40px; display: flex; justify-content: space-between; font-size: 9pt; color: #555;">
        <div>
          <p style="margin: 0;">Despatcher Signature: ______________________</p>
        </div>
        <div>
          <p style="margin: 0;">Generated: ${new Date().toLocaleString()}</p>
        </div>
      </div>
    </div>
  `;

  document.body.appendChild(printContainer);
  window.print();
}
```

---

### 5.2 `src/lib/export-whatsapp.ts` Proposed Implementation Sketch

```ts
import type { LoadingSheetTrip } from "./types";
import { format } from "date-fns";

export interface WhatsAppExportData {
  dateStr: string;
  despatcherName: string;
  trips: LoadingSheetTrip[];
}

export function formatWhatsAppShareText(data: WhatsAppExportData): string {
  const { dateStr, despatcherName, trips } = data;

  const totalQty = trips.reduce((sum, t) => sum + (t.quantityLoaded || 0), 0);
  const totalMins = trips.reduce((sum, t) => sum + (t.durationMinutes || 0), 0);
  const hours = Math.floor(totalMins / 60);
  const mins = totalMins % 60;
  const timeFormatted = hours > 0 ? `${totalMins} mins (${hours}h ${mins}m)` : `${totalMins} mins`;

  let lines: string[] = [];
  lines.push("📋 *DESPATCH LOADING SHEET*");
  lines.push(`📅 *Date:* ${dateStr}`);
  lines.push(`👤 *Despatcher:* ${despatcherName || "N/A"}`);
  lines.push("");
  lines.push(`🚛 *LOADED TRIPS (${trips.length})*`);
  lines.push("----------------------------------");

  trips.forEach((t, i) => {
    const startStr = t.startTime ? format(t.startTime, "HH:mm") : "--:--";
    const finishStr = t.finishTime ? format(t.finishTime, "HH:mm") : "--:--";
    const durStr = t.durationMinutes ? `${t.durationMinutes} mins` : "-";

    lines.push(`${i + 1}. *Reg:* ${t.reg || "N/A"} | *Driver:* ${t.driverName || "N/A"}`);
    lines.push(`   └ *Trip ID:* ${t.tripId || "N/A"}`);
    lines.push(`   └ *Time:* ${startStr} - ${finishStr} (${durStr})`);
    lines.push(`   └ *Qty:* ${t.quantityLoaded} tyres`);
    if (i < trips.length - 1) lines.push("");
  });

  lines.push("----------------------------------");
  lines.push("📊 *SUMMARY TOTALS*");
  lines.push(`📦 *Total Tyres Loaded:* ${totalQty} tyres`);
  lines.push(`⏱️ *Total Loading Time:* ${timeFormatted}`);

  return lines.join("\n");
}

export async function shareWhatsAppText(
  text: string,
): Promise<{ shared: boolean; copied: boolean }> {
  let copied = false;
  try {
    await navigator.clipboard.writeText(text);
    copied = true;
  } catch (err) {
    console.warn("Clipboard access unavailable:", err);
  }

  if (typeof navigator !== "undefined" && navigator.share) {
    try {
      await navigator.share({
        title: "Despatch Loading Sheet",
        text: text,
      });
      return { shared: true, copied };
    } catch (err) {
      // User cancelled or native share failed, fallback to url scheme
    }
  }

  const url = `https://api.whatsapp.com/send?text=${encodeURIComponent(text)}`;
  window.open(url, "_blank");
  return { shared: true, copied };
}
```

---

## 6. Verification & Test Plan

1. **PDF Report Formatting Verification**:
   - Verify all 7 active columns render in table header and rows: `Reg`, `Driver Name`, `Trip ID`, `Start`, `Finish`, `Minutes`, `Quantity Loaded`.
   - Verify header shows `Date` and `Despatcher Name`.
   - Verify summary footer displays correct auto-summed `TOTAL TYRES LOADED` and aggregate `TOTAL LOADING TIME`.
   - Invalidate if deprecated fields (Arrival, Departure, Pressure Check, PSI banner) appear anywhere on print layout.

2. **WhatsApp Text Share Formatting Verification**:
   - Verify string output contains WhatsApp bold syntax `*text*`, clean section separators, and accurate totals.
   - Test `shareWhatsAppText` behavior across desktop browsers, mobile devices, and Capacitor environment.

---
