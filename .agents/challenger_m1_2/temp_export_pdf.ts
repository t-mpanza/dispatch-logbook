import type { Entry, LoadingSheetTrip } from "../../src/lib/types.ts";
import { calculateDurationMinutes, calculateLoadingSheetTotals } from "./temp_loading_presets.ts";
import { format } from "date-fns";

export interface PDFExportData {
  title?: string;
  dateStr: string;
  despatcherName: string;
  trips: LoadingSheetTrip[];
}

export function formatTimeHHmm(epochMs?: number): string {
  if (!epochMs) return "-";
  try {
    return format(epochMs, "HH:mm");
  } catch {
    return "-";
  }
}

export function buildPDFReportData(entry: any, despatcherNameParam?: string): any {
  const despatcherName = despatcherNameParam || entry?.despatcherName || "Despatcher";
  const dateStr = entry?.dayKey || entry?.dateStr || new Date().toISOString().split("T")[0];
  const rawTrips = entry?.loadingSheetTrips || entry?.trips || [];
  const trips: LoadingSheetTrip[] = rawTrips.map((t: any, idx: number) => ({
    id: t.id || `t-${idx}`,
    reg: t.reg || "",
    driverName: t.driverName || "",
    tripId: t.tripId || `TRIP ${idx + 1}`,
    quantityLoaded: t.quantityLoaded ?? t.count ?? 0,
    durationMinutes: t.durationMinutes ?? calculateDurationMinutes(t.startTime, t.finishTime),
    createdAt: t.createdAt || Date.now(),
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

export async function generatePDFReport(entry: Entry, despatcherName: string): Promise<void> {
  const data = buildPDFExportData(entry, despatcherName);
  const totals = calculateLoadingSheetTotals(data.trips);

  const hours = Math.floor(totals.totalLoadingTimeMinutes / 60);
  const mins = totals.totalLoadingTimeMinutes % 60;
  const timeFormatted =
    hours > 0
      ? `${hours}h ${mins}m (${totals.totalLoadingTimeMinutes} mins)`
      : `${totals.totalLoadingTimeMinutes} mins`;

  // Remove any previously rendered print container
  const existing = document.getElementById("printable-loading-sheet");
  if (existing) existing.remove();

  const printContainer = document.createElement("div");
  printContainer.id = "printable-loading-sheet";
  printContainer.className = "printable-loading-sheet-container";

  // Build 7-column active table rows with explicit omission of Arrival/Departure/Pressure/PSI
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
    `,
    )
    .join("");

  printContainer.innerHTML = `
    <style>
      @media print {
        body * {
          visibility: hidden !important;
        }
        #printable-loading-sheet, #printable-loading-sheet * {
          visibility: visible !important;
        }
        #printable-loading-sheet {
          position: absolute !important;
          left: 0 !important;
          top: 0 !important;
          width: 100% !important;
          margin: 0 !important;
          padding: 10mm 15mm !important;
          background: #ffffff !important;
          color: #000000 !important;
          font-family: Arial, Helvetica, sans-serif !important;
        }
        @page {
          size: A4 portrait;
          margin: 10mm;
        }
      }
      @media screen {
        #printable-loading-sheet {
          display: none;
        }
      }
    </style>

    <div style="font-family: Arial, sans-serif; color: #000; padding: 10px;">
      <div style="display: flex; justify-content: space-between; align-items: flex-start; border-bottom: 2px solid #000; padding-bottom: 8px; margin-bottom: 12px;">
        <div>
          <h1 style="font-size: 18pt; margin: 0; font-weight: bold; text-transform: uppercase; letter-spacing: 0.5px;">${data.title}</h1>
          <p style="margin: 3px 0 0 0; font-size: 9pt; color: #333;">Dispatch Compliance & Loading System</p>
        </div>
        <div style="text-align: right; font-size: 10pt;">
          <p style="margin: 0;"><strong>Date:</strong> ${data.dateStr}</p>
          <p style="margin: 3px 0 0 0;"><strong>Despatcher:</strong> ${data.despatcherName}</p>
        </div>
      </div>

      <table style="width: 100%; border-collapse: collapse; margin-top: 10px; font-size: 10pt; font-family: Arial, sans-serif;">
        <thead>
          <tr style="background-color: #f2f2f2;">
            <th style="border: 1px solid #000; padding: 7px 8px; text-align: left; font-size: 9pt; text-transform: uppercase;">Reg</th>
            <th style="border: 1px solid #000; padding: 7px 8px; text-align: left; font-size: 9pt; text-transform: uppercase;">Driver Name</th>
            <th style="border: 1px solid #000; padding: 7px 8px; text-align: left; font-size: 9pt; text-transform: uppercase;">Trip ID</th>
            <th style="border: 1px solid #000; padding: 7px 8px; text-align: center; font-size: 9pt; text-transform: uppercase;">Start Time</th>
            <th style="border: 1px solid #000; padding: 7px 8px; text-align: center; font-size: 9pt; text-transform: uppercase;">Finished Time</th>
            <th style="border: 1px solid #000; padding: 7px 8px; text-align: right; font-size: 9pt; text-transform: uppercase;">Minutes</th>
            <th style="border: 1px solid #000; padding: 7px 8px; text-align: right; font-size: 9pt; text-transform: uppercase;">Quantity Loaded</th>
          </tr>
        </thead>
        <tbody>
          ${tableRows.length > 0 ? tableRows : '<tr><td colspan="7" style="border: 1px solid #000; padding: 12px; text-align: center; color: #666;">No trips recorded on this sheet.</td></tr>'}
        </tbody>
      </table>

      <div style="margin-top: 16px; border: 2px solid #000; padding: 10px 14px; background-color: #fafafa; display: flex; justify-content: space-between; font-size: 11pt;">
        <div>
          <span><strong>TOTAL TRIPS:</strong> ${data.trips.length}</span>
        </div>
        <div>
          <span style="margin-right: 25px;"><strong>TOTAL LOADING TIME:</strong> ${timeFormatted}</span>
          <span><strong>TOTAL TYRES LOADED:</strong> ${totals.totalTyresLoaded}</span>
        </div>
      </div>

      <div style="margin-top: 40px; display: flex; justify-content: space-between; font-size: 9pt; color: #444;">
        <div>
          <p style="margin: 0;">Despatcher Signature: ___________________________</p>
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
