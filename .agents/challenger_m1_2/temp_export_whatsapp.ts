import type { Entry, LoadingSheetTrip } from "../../src/lib/types.ts";
import { calculateDurationMinutes, calculateLoadingSheetTotals } from "./temp_loading_presets.ts";
import { format } from "date-fns";

export function formatTimeHHmm(epochMs?: number): string {
  if (!epochMs) return "--:--";
  try {
    return format(epochMs, "HH:mm");
  } catch {
    return "--:--";
  }
}

export function formatWhatsAppShareText(entry: any, despatcherNameParam?: string): string {
  const despatcher = despatcherNameParam || entry?.despatcherName || "Despatcher";
  let dateStr = entry?.dayKey || entry?.dateStr;
  if (!dateStr && entry?.createdAt) {
    try {
      dateStr = new Date(entry.createdAt).toISOString().split("T")[0];
    } catch {
      dateStr = new Date().toISOString().split("T")[0];
    }
  }
  if (!dateStr) {
    dateStr = new Date().toISOString().split("T")[0];
  }

  let rawTrips = entry?.loadingSheetTrips || entry?.trips || [];
  let trips: LoadingSheetTrip[] = rawTrips.map((t: any, idx: number) => ({
    id: t.id || `t-${idx}`,
    reg: t.reg || "N/A",
    driverName: t.driverName || "N/A",
    tripId: t.tripId || `TRIP ${idx + 1}`,
    quantityLoaded: t.quantityLoaded ?? t.count ?? 0,
    durationMinutes: t.durationMinutes ?? calculateDurationMinutes(t.startTime, t.finishTime),
  }));

  const totals = calculateLoadingSheetTotals(trips);
  const hours = Math.floor(totals.totalLoadingTimeMinutes / 60);
  const mins = totals.totalLoadingTimeMinutes % 60;
  const timeFormatted =
    hours > 0
      ? `${totals.totalLoadingTimeMinutes} mins (${hours}h ${mins}m)`
      : `${totals.totalLoadingTimeMinutes} mins`;

  let lines: string[] = [];
  lines.push("📋 *DESPATCH LOADING SHEET*");
  lines.push(`📅 Date: ${dateStr}`);
  lines.push(`👤 Despatcher: ${despatcher}`);
  lines.push("");
  lines.push(`🚛 *LOADED TRIPS (${trips.length})*`);
  lines.push("----------------------------------");

  if (trips.length === 0) {
    lines.push("No loading trips recorded on this sheet.");
  } else {
    trips.forEach((t, i) => {
      const reg = t.reg || "N/A";
      const driver = t.driverName || "N/A";
      const tripId = t.tripId || "N/A";
      const mins = t.durationMinutes ?? calculateDurationMinutes(t.startTime, t.finishTime);

      lines.push(
        `${i + 1}. [${tripId}] ${reg} (${driver}) - ${t.quantityLoaded} tyres (${mins} mins)`,
      );
    });
  }

  lines.push("----------------------------------");
  lines.push("📊 *SUMMARY TOTALS*");
  lines.push(`📦 TOTAL TYRES LOADED: ${totals.totalTyresLoaded} tyres`);
  lines.push(`⏱️ TOTAL LOADING TIME: ${totals.totalLoadingTimeMinutes} mins`);

  return lines.join("\n");
}

export async function shareWhatsAppText(
  text: string,
): Promise<{ shared: boolean; copied: boolean }> {
  let copied = false;

  if (typeof navigator !== "undefined" && navigator.clipboard) {
    try {
      await navigator.clipboard.writeText(text);
      copied = true;
    } catch (err) {
      console.warn("Clipboard copy unavailable:", err);
    }
  }

  if (typeof navigator !== "undefined" && navigator.share) {
    try {
      await navigator.share({
        title: "Despatch Loading Sheet",
        text: text,
      });
      return { shared: true, copied };
    } catch (err) {
      // User cancelled or native share unavailable, proceed to url scheme
    }
  }

  if (typeof window !== "undefined") {
    const encoded = encodeURIComponent(text);
    const url = `https://api.whatsapp.com/send?text=${encoded}`;
    window.open(url, "_blank");
    return { shared: true, copied };
  }

  return { shared: false, copied };
}
