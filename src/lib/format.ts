import { format, startOfWeek, endOfWeek, getWeek } from "date-fns";

export const dayKey = (d: Date | number) => format(d, "yyyy-MM-dd");
export const monthKey = (d: Date | number) => format(d, "yyyy-MM");
export const yearKey = (d: Date | number) => format(d, "yyyy");

export const fmtTime = (d: Date | number) => format(d, "HH:mm");
export const fmtDayLabel = (d: Date | number) => format(d, "EEEE, d MMM");
export const fmtShortDay = (d: Date | number) => format(d, "EEE d");
export const fmtMonth = (d: Date | number) => format(d, "MMMM yyyy");

export function weekRangeLabel(d: Date) {
  const s = startOfWeek(d, { weekStartsOn: 1 });
  const e = endOfWeek(d, { weekStartsOn: 1 });
  return `${format(s, "d MMM")} – ${format(e, "d MMM")}`;
}

export const weekNumber = (d: Date) => getWeek(d, { weekStartsOn: 1 });

export function uid() {
  return Math.random().toString(36).slice(2) + Date.now().toString(36);
}

export function formatDuration(ms: number) {
  const s = Math.floor(ms / 1000);
  const m = Math.floor(s / 60);
  const r = s % 60;
  return `${m}:${r.toString().padStart(2, "0")}`;
}

export function formatBytes(n: number) {
  if (n < 1024) return `${n} B`;
  if (n < 1024 * 1024) return `${(n / 1024).toFixed(1)} KB`;
  return `${(n / (1024 * 1024)).toFixed(1)} MB`;
}
