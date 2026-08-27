import type { Entry, LoadingSheetTrip } from "./types.ts";
import { calculateDurationMinutes, calculateLoadingSheetTotals } from "./loading-presets.ts";
import { format } from "date-fns";

export interface PDFExportData {
  title?: string;
  dateStr: string;
  despatcherName: string;
  trips: LoadingSheetTrip[];
  totalTyresLoaded: number;
  totalLoadingTimeMinutes: number;
  generatedAt: number;
}

export interface PDFInputTrip {
  id?: string;
  reg?: string;
  driverName?: string;
  tripId?: string;
  quantityLoaded?: number;
  count?: number;
  durationMinutes?: number;
  startTime?: number;
  finishTime?: number;
  createdAt?: number;
}

export interface PDFInputEntry {
  dayKey?: string;
  dateStr?: string;
  despatcherName?: string;
  loadingSheetTrips?: PDFInputTrip[];
  trips?: PDFInputTrip[];
  createdAt?: number;
}

export function formatTimeHHmm(epochMs?: number): string {
  if (!epochMs) return "-";
  try {
    return format(epochMs, "HH:mm");
  } catch {
    return "-";
  }
}

export function buildPDFReportData(
  entry?: any,
  despatcherNameParam?: string
): PDFExportData {
  const despatcherName = despatcherNameParam || entry?.despatcherName || "Theolus";
  const dateStr = entry?.dayKey || entry?.dateStr || new Date().toISOString().split("T")[0];
  const rawTrips: PDFInputTrip[] = entry?.loadingSheetTrips || entry?.trips || [];
  const trips: LoadingSheetTrip[] = rawTrips.map((t: PDFInputTrip, idx: number) => ({
    id: t.id || `t-${idx}`,
    reg: t.reg || "",
    driverName: t.driverName || "",
    tripId: t.tripId || `TRIP ${idx + 1}`,
    quantityLoaded: t.quantityLoaded ?? t.count ?? 0,
    durationMinutes: t.durationMinutes ?? calculateDurationMinutes(t.startTime, t.finishTime),
    createdAt: t.createdAt || Date.now(),
    ...(t.startTime !== undefined ? { startTime: t.startTime } : {}),
    ...(t.finishTime !== undefined ? { finishTime: t.finishTime } : {}),
  }));
  const totals = calculateLoadingSheetTotals(trips);

  return {
    title: "DESPATCH LOADING SHEET REPORT",
    dateStr,
    despatcherName,
    trips,
    totalTyresLoaded: totals.totalTyresLoaded,
    totalLoadingTimeMinutes: totals.totalLoadingTimeMinutes,
    generatedAt: Date.now(),
  };
}

export const buildPDFExportData = buildPDFReportData;

export async function generatePDFReport(
  entry: Entry,
  despatcherName: string
): Promise<void> {
  const data = buildPDFExportData(entry, despatcherName || "Theolus");
  const totals = calculateLoadingSheetTotals(data.trips);

  const hours = Math.floor(totals.totalLoadingTimeMinutes / 60);
  const mins = totals.totalLoadingTimeMinutes % 60;
  const timeFormatted =
    hours > 0
      ? `${hours}h ${mins}m (${totals.totalLoadingTimeMinutes} mins)`
      : `${totals.totalLoadingTimeMinutes} mins`;

  const existing = document.getElementById("printable-loading-sheet");
  if (existing) existing.remove();

  const printContainer = document.createElement("div");
  printContainer.id = "printable-loading-sheet";
  printContainer.className = "printable-loading-sheet-container";

  const tableRows = data.trips
    .map(
      (t: LoadingSheetTrip) => `
      <tr>
        <td style="border: 1px solid #000; padding: 6px 8px; font-weight: bold; text-transform: uppercase;">${t.reg || "-"}</td>
        <td style="border: 1px solid #000; padding: 6px 8px;">${t.driverName || "-"}</td>
        <td style="border: 1px solid #000; padding: 6px 8px; font-weight: 500;">${t.tripId || "-"}</td>
        <td style="border: 1px solid #000; padding: 6px 8px; text-align: center;">${formatTimeHHmm(t.startTime)}</td>
        <td style="border: 1px solid #000; padding: 6px 8px; text-align: center;">${formatTimeHHmm(t.finishTime)}</td>
        <td style="border: 1px solid #000; padding: 6px 8px; text-align: right;">${t.durationMinutes !== undefined ? t.durationMinutes : calculateDurationMinutes(t.startTime, t.finishTime)} mins</td>
        <td style="border: 1px solid #000; padding: 6px 8px; text-align: right; font-weight: bold;">${t.quantityLoaded}</td>
      </tr>
    `
    )
    .join("");

  printContainer.innerHTML = `
    <style>
      #printable-loading-sheet {
        display: none;
      }
      @media print {
        body * {
          visibility: hidden !important;
        }
        #printable-loading-sheet, #printable-loading-sheet * {
          visibility: visible !important;
          display: block !important;
        }
        #printable-loading-sheet {
          position: absolute !important;
          left: 0 !important;
          top: 0 !important;
          width: 100% !important;
          margin: 0 !important;
          padding: 20px !important;
          background: #ffffff !important;
          color: #000000 !important;
          font-family: Arial, sans-serif !important;
          font-size: 12px !important;
        }
        #printable-loading-sheet table {
          display: table !important;
        }
        #printable-loading-sheet thead {
          display: table-header-group !important;
        }
        #printable-loading-sheet tbody {
          display: table-row-group !important;
        }
        #printable-loading-sheet tr {
          display: table-row !important;
        }
        #printable-loading-sheet th, #printable-loading-sheet td {
          display: table-cell !important;
        }
      }
    </style>
    <div style="max-width: 800px; margin: 0 auto; background: #fff; color: #000; padding: 24px; font-family: Arial, sans-serif;">
      <div style="display: flex; justify-content: space-between; align-items: flex-start; border-bottom: 2px solid #000; padding-bottom: 12px; margin-bottom: 16px;">
        <div>
          <h1 style="font-size: 20px; font-weight: bold; margin: 0 0 4px 0; letter-spacing: 0.5px;">DESPATCH LOADING SHEET</h1>
          <p style="margin: 0; font-size: 13px; font-weight: 500;">DATE: ${data.dateStr}</p>
        </div>
        <div style="text-align: right;">
          <p style="margin: 0; font-size: 13px; font-weight: bold;">DESPATCHER: ${data.despatcherName || "Theolus"}</p>
        </div>
      </div>

      <table style="width: 100%; border-collapse: collapse; margin-bottom: 20px; font-size: 12px;">
        <thead>
          <tr style="background-color: #f0f0f0; border: 1px solid #000;">
            <th style="border: 1px solid #000; padding: 8px; text-align: left;">Reg</th>
            <th style="border: 1px solid #000; padding: 8px; text-align: left;">Driver Name</th>
            <th style="border: 1px solid #000; padding: 8px; text-align: left;">Trip ID</th>
            <th style="border: 1px solid #000; padding: 8px; text-align: center;">Loading Start</th>
            <th style="border: 1px solid #000; padding: 8px; text-align: center;">Loading Finished</th>
            <th style="border: 1px solid #000; padding: 8px; text-align: right;">Minutes</th>
            <th style="border: 1px solid #000; padding: 8px; text-align: right;">Quantity Loaded</th>
          </tr>
        </thead>
        <tbody>
          ${tableRows || `<tr><td colspan="7" style="border: 1px solid #000; padding: 16px; text-align: center;">No trips recorded.</td></tr>`}
        </tbody>
      </table>

      <div style="display: flex; justify-content: space-between; align-items: center; border-top: 2px solid #000; padding-top: 12px; font-weight: bold; font-size: 13px;">
        <div>
          <span>TOTAL LOADING TIME: ${timeFormatted}</span>
        </div>
        <div>
          <span>TOTAL TYRES LOADED: ${totals.totalTyresLoaded}</span>
        </div>
      </div>
    </div>
  `;

  document.body.appendChild(printContainer);

  const cleanup = () => {
    const el = document.getElementById("printable-loading-sheet");
    if (el) el.remove();
    window.removeEventListener("afterprint", cleanup);
  };
  window.addEventListener("afterprint", cleanup);

  setTimeout(() => {
    window.print();
    setTimeout(cleanup, 1000);
  }, 100);
}
