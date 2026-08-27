import { useState, useEffect } from "react";
import {
  FileText,
  Printer,
  Share2,
  Plus,
  Trash2,
  Truck,
  User,
  Calendar,
  Check,
  Clock,
  X,
  ChevronDown,
  Hash,
  Layers,
} from "lucide-react";
import type { Entry, LoadingSheetTrip, PresetKey } from "@/lib/types";
import {
  LOADING_PRESETS,
  getPresetFill,
  calculateDurationMinutes,
  calculateLoadingSheetTotals,
} from "@/lib/loading-presets";
import { getDespatcherName, saveDespatcherName } from "@/lib/db";
import { generatePDFReport, formatTimeHHmm } from "@/lib/export-pdf";
import { formatWhatsAppShareText, shareWhatsAppText } from "@/lib/export-whatsapp";
import { fmtDayLabel, uid } from "@/lib/format";

export interface LoadingSheetProps {
  entry: Entry;
  onUpdateEntry: (updatedEntry: Entry) => void | Promise<void>;
}

function msToTimeString(ms?: number): string {
  if (!ms) return "";
  const d = new Date(ms);
  const hours = String(d.getHours()).padStart(2, "0");
  const mins = String(d.getMinutes()).padStart(2, "0");
  return `${hours}:${mins}`;
}

function timeStringToMs(timeStr: string, baseDateMs: number): number | undefined {
  if (!timeStr) return undefined;
  const parts = timeStr.split(":");
  if (parts.length !== 2) return undefined;
  const hours = parseInt(parts[0], 10);
  const mins = parseInt(parts[1], 10);
  if (isNaN(hours) || isNaN(mins)) return undefined;

  const d = new Date(baseDateMs);
  d.setHours(hours, mins, 0, 0);
  return d.getTime();
}

export function LoadingSheet({ entry, onUpdateEntry }: LoadingSheetProps) {
  const [despatcherName, setDespatcherName] = useState<string>("Theolus");
  const [shareFeedback, setShareFeedback] = useState<string | null>(null);
  const [showReportModal, setShowReportModal] = useState<boolean>(false);

  useEffect(() => {
    getDespatcherName().then((savedName) => {
      if (savedName && savedName.trim()) {
        setDespatcherName(savedName.trim());
      } else {
        setDespatcherName("Theolus");
      }
    });
  }, []);

  const rawTrips = entry.loadingSheetTrips ?? [];

  const handleDespatcherChange = (val: string) => {
    setDespatcherName(val);
    saveDespatcherName(val);
  };

  const updateTrips = (nextTrips: LoadingSheetTrip[]) => {
    onUpdateEntry({
      ...entry,
      loadingSheetTrips: nextTrips,
    });
  };

  const handlePresetSelect = (index: number, key: PresetKey) => {
    const current = [...rawTrips];
    const fill = getPresetFill(key, {
      dayKey: entry.dayKey,
      existingTrips: current,
    });

    const updatedTrip: LoadingSheetTrip = {
      ...current[index],
      presetKey: key,
      tripId: fill.tripId,
      ...(fill.driverName ? { driverName: fill.driverName } : {}),
      ...(fill.reg ? { reg: fill.reg } : {}),
    };

    current[index] = updatedTrip;
    updateTrips(current);
  };

  const handleRowChange = (
    index: number,
    field: keyof LoadingSheetTrip,
    value: any,
  ) => {
    const current = [...rawTrips];
    const trip = { ...current[index] };

    if (field === "reg" && typeof value === "string") {
      trip.reg = value.toUpperCase();
    } else if (field === "startTime") {
      const ms = timeStringToMs(value, trip.createdAt || entry.createdAt);
      trip.startTime = ms;
      trip.durationMinutes = calculateDurationMinutes(trip.startTime, trip.finishTime);
    } else if (field === "finishTime") {
      const ms = timeStringToMs(value, trip.createdAt || entry.createdAt);
      trip.finishTime = ms;
      trip.durationMinutes = calculateDurationMinutes(trip.startTime, trip.finishTime);
    } else {
      (trip as any)[field] = value;
      if (field === "quantityLoaded") {
        trip.quantityLoaded = Math.max(0, parseInt(value, 10) || 0);
      }
    }

    current[index] = trip;
    updateTrips(current);
  };

  const handleAddManualRow = () => {
    const now = Date.now();
    const newTrip: LoadingSheetTrip = {
      id: uid(),
      entryId: entry.id,
      reg: "",
      driverName: "",
      tripId: "STOCKS 1",
      presetKey: "STOCKS",
      startTime: now,
      finishTime: now + 30 * 60 * 1000,
      durationMinutes: 30,
      quantityLoaded: 0,
      isManual: true,
      createdAt: now,
    };
    const fill = getPresetFill("STOCKS", {
      dayKey: entry.dayKey,
      existingTrips: rawTrips,
    });
    newTrip.tripId = fill.tripId;
    updateTrips([...rawTrips, newTrip]);
  };

  const handleDeleteRow = (index: number) => {
    const current = rawTrips.filter((_, i) => i !== index);
    updateTrips(current);
  };

  const totals = calculateLoadingSheetTotals(rawTrips);
  const totalMins = totals.totalLoadingTimeMinutes;
  const hours = Math.floor(totalMins / 60);
  const mins = totalMins % 60;
  const timeFormatted =
    hours > 0 ? `${hours}h ${mins}m (${totalMins}m)` : `${totalMins} mins`;

  const handlePrintPDF = () => {
    generatePDFReport(entry, despatcherName || "Theolus");
  };

  const handleShareWhatsApp = async () => {
    const text = formatWhatsAppShareText(entry, despatcherName || "Theolus");
    const res = await shareWhatsAppText(text);
    if (res.copied) {
      setShareFeedback("Copied to clipboard!");
      setTimeout(() => setShareFeedback(null), 3000);
    }
  };

  return (
    <div className="space-y-4">
      {/* ── KPI / SUMMARY STATS BANNER ───────────────────────────────────── */}
      <div className="grid grid-cols-3 gap-2 sm:gap-4 bg-surface-elevated border border-border/80 rounded-2xl p-3.5 sm:p-4 shadow-sm">
        <div className="flex flex-col">
          <span className="text-[10px] sm:text-xs font-bold uppercase tracking-wider text-muted-foreground flex items-center gap-1">
            <Truck size={13} className="text-primary-glow" /> Trucks
          </span>
          <span className="mt-1 text-lg sm:text-2xl font-black font-mono text-foreground">
            {rawTrips.length}
          </span>
        </div>

        <div className="flex flex-col border-x border-border/60 px-2 sm:px-4">
          <span className="text-[10px] sm:text-xs font-bold uppercase tracking-wider text-muted-foreground flex items-center gap-1">
            <Clock size={13} className="text-primary-glow" /> Total Time
          </span>
          <span className="mt-1 text-sm sm:text-lg font-bold font-mono text-foreground truncate">
            {timeFormatted}
          </span>
        </div>

        <div className="flex flex-col text-right sm:text-left">
          <span className="text-[10px] sm:text-xs font-bold uppercase tracking-wider text-muted-foreground flex items-center justify-end sm:justify-start gap-1">
            <Layers size={13} className="text-primary-glow" /> Tyres
          </span>
          <span className="mt-1 text-lg sm:text-2xl font-black font-mono text-primary-glow">
            {totals.totalTyresLoaded}
          </span>
        </div>
      </div>

      {/* ── HEADER & TOOLBAR ─────────────────────────────────────────────── */}
      <div className="bg-surface border border-border rounded-2xl p-4 sm:p-5 shadow-sm space-y-4">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
          <div className="flex items-center gap-3">
            <div className="h-10 w-10 rounded-xl bg-primary/10 border border-primary/20 grid place-items-center text-primary-glow shrink-0">
              <Truck size={20} />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h2 className="text-base font-bold tracking-tight text-foreground">
                  Truck Loading Log
                </h2>
                <span className="text-[10px] font-bold uppercase px-2 py-0.5 rounded-full bg-muted text-muted-foreground">
                  Compliance
                </span>
              </div>
              <p className="text-xs text-muted-foreground mt-0.5">
                {fmtDayLabel(entry.createdAt)} · <span className="font-mono">{entry.dayKey}</span>
              </p>
            </div>
          </div>

          <div className="flex items-center gap-2 bg-background border border-border rounded-xl px-3 py-2 shadow-xs">
            <User size={15} className="text-primary-glow shrink-0" />
            <span className="text-xs font-medium text-muted-foreground shrink-0">Despatcher:</span>
            <input
              type="text"
              value={despatcherName}
              onChange={(e) => handleDespatcherChange(e.target.value)}
              placeholder="Theolus"
              className="bg-transparent text-xs font-bold outline-none w-28 text-foreground"
            />
          </div>
        </div>

        {/* Action Buttons */}
        <div className="flex flex-wrap items-center justify-between gap-2 pt-3 border-t border-border/60">
          <div className="flex items-center gap-2">
            <button
              onClick={() => setShowReportModal(true)}
              className="inline-flex items-center gap-1.5 px-3 py-2 rounded-xl text-xs font-semibold bg-surface-elevated border border-border text-foreground hover:border-primary/50 active:scale-95 transition-all shadow-xs"
            >
              <Printer size={15} className="text-primary-glow" />
              <span>Preview & Print PDF</span>
            </button>
            <button
              onClick={handleShareWhatsApp}
              className="inline-flex items-center gap-1.5 px-3 py-2 rounded-xl text-xs font-semibold bg-emerald-600/15 border border-emerald-600/30 text-emerald-500 hover:bg-emerald-600/25 active:scale-95 transition-all shadow-xs"
            >
              <Share2 size={15} />
              <span>Share WhatsApp</span>
            </button>
            {shareFeedback && (
              <span className="text-xs text-emerald-500 font-medium flex items-center gap-1 animate-fade-in">
                <Check size={13} /> {shareFeedback}
              </span>
            )}
          </div>

          <button
            onClick={handleAddManualRow}
            className="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-xl text-xs font-bold bg-primary text-primary-foreground hover:bg-primary/90 active:scale-95 transition-all shadow-xs"
          >
            <Plus size={15} />
            <span>+ Add Truck Load</span>
          </button>
        </div>
      </div>

      {/* ── MOBILE CARDS LAYOUT (Ultra-Clean, High Readability) ──────────── */}
      <div className="block sm:hidden space-y-3">
        {rawTrips.length === 0 ? (
          <div className="py-10 text-center text-muted-foreground text-xs bg-surface border border-dashed border-border rounded-2xl p-6">
            <Truck size={32} className="mx-auto mb-2 text-muted-foreground/40" />
            <p className="font-semibold text-foreground">No truck loads recorded yet</p>
            <p className="text-[11px] text-muted-foreground mt-1">
              Add a new truck load or record scans in the counter.
            </p>
            <button
              onClick={handleAddManualRow}
              className="inline-flex items-center gap-1.5 mt-4 px-4 py-2 rounded-xl text-xs font-bold bg-primary text-primary-foreground"
            >
              <Plus size={14} /> Add First Truck
            </button>
          </div>
        ) : (
          rawTrips.map((trip, idx) => {
            const currentPreset = trip.presetKey ?? "CUSTOM";
            const calculatedMins = calculateDurationMinutes(trip.startTime, trip.finishTime);

            return (
              <div
                key={trip.id || idx}
                className="bg-surface border border-border rounded-2xl p-4 space-y-3.5 shadow-xs"
              >
                {/* Card Top: Number, Reg & Preset */}
                <div className="flex items-center justify-between gap-2 border-b border-border/50 pb-3">
                  <div className="flex items-center gap-2">
                    <span className="h-6 w-6 rounded-full bg-muted grid place-items-center text-xs font-bold font-mono text-muted-foreground">
                      {idx + 1}
                    </span>
                    <input
                      type="text"
                      value={trip.reg || ""}
                      onChange={(e) => handleRowChange(idx, "reg", e.target.value)}
                      placeholder="REG PLATE"
                      className="bg-background border border-border rounded-xl px-2.5 py-1.5 text-xs font-mono font-black uppercase text-foreground outline-none focus:border-primary-glow w-32 tracking-wider"
                    />
                  </div>

                  <div className="flex items-center gap-1.5">
                    <select
                      value={currentPreset}
                      onChange={(e) => handlePresetSelect(idx, e.target.value as PresetKey)}
                      className="bg-background border border-border rounded-xl px-2 py-1.5 text-xs font-bold text-foreground outline-none focus:border-primary-glow"
                    >
                      {LOADING_PRESETS.map((p) => (
                        <option key={p.key} value={p.key}>
                          {p.label}
                        </option>
                      ))}
                    </select>

                    <button
                      onClick={() => handleDeleteRow(idx)}
                      className="h-8 w-8 rounded-lg grid place-items-center text-muted-foreground hover:text-destructive hover:bg-destructive/10 transition-colors"
                      title="Delete truck row"
                    >
                      <Trash2 size={15} />
                    </button>
                  </div>
                </div>

                {/* Custom Trip ID if needed */}
                {(currentPreset === "CUSTOM" ||
                  !LOADING_PRESETS.some((p) => p.key === currentPreset)) && (
                  <div>
                    <label className="text-[10px] uppercase font-bold text-muted-foreground block mb-1">
                      Trip ID
                    </label>
                    <input
                      type="text"
                      value={trip.tripId || ""}
                      onChange={(e) => handleRowChange(idx, "tripId", e.target.value)}
                      placeholder="e.g. STOCKS 2, NLH, DBN"
                      className="w-full bg-background border border-border rounded-xl px-3 py-2 text-xs font-semibold outline-none focus:border-primary-glow"
                    />
                  </div>
                )}

                {/* Driver Name & Quantity Loaded */}
                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="text-[10px] uppercase font-bold text-muted-foreground block mb-1">
                      Driver Name
                    </label>
                    <input
                      type="text"
                      value={trip.driverName || ""}
                      onChange={(e) => handleRowChange(idx, "driverName", e.target.value)}
                      placeholder="e.g. Neil"
                      className="w-full bg-background border border-border rounded-xl px-3 py-2 text-xs font-semibold outline-none focus:border-primary-glow"
                    />
                  </div>

                  <div>
                    <label className="text-[10px] uppercase font-bold text-muted-foreground block mb-1">
                      Tyres Loaded
                    </label>
                    <div className="flex items-center gap-1.5">
                      <button
                        onClick={() =>
                          handleRowChange(
                            idx,
                            "quantityLoaded",
                            Math.max(0, (trip.quantityLoaded || 0) - 1),
                          )
                        }
                        className="h-8 w-8 rounded-lg bg-surface-elevated border border-border text-foreground font-black text-sm flex items-center justify-center shrink-0 active:scale-95"
                      >
                        -
                      </button>
                      <input
                        type="number"
                        min="0"
                        value={trip.quantityLoaded}
                        onChange={(e) => handleRowChange(idx, "quantityLoaded", e.target.value)}
                        className="w-full bg-background border border-border rounded-lg px-2 py-1.5 text-sm font-mono font-black text-center text-primary-glow outline-none focus:border-primary-glow"
                      />
                      <button
                        onClick={() =>
                          handleRowChange(
                            idx,
                            "quantityLoaded",
                            (trip.quantityLoaded || 0) + 1,
                          )
                        }
                        className="h-8 w-8 rounded-lg bg-surface-elevated border border-border text-foreground font-black text-sm flex items-center justify-center shrink-0 active:scale-95"
                      >
                        +
                      </button>
                    </div>
                  </div>
                </div>

                {/* Load Timings (Start → Finish = Duration) */}
                <div className="bg-background/80 border border-border rounded-xl p-2.5 flex items-center justify-between gap-2">
                  <div className="flex items-center gap-2">
                    <Clock size={14} className="text-primary-glow shrink-0" />
                    <div className="flex items-center gap-1.5">
                      <div className="flex flex-col">
                        <span className="text-[9px] uppercase font-bold text-muted-foreground">Start</span>
                        <input
                          type="time"
                          value={msToTimeString(trip.startTime)}
                          onChange={(e) => handleRowChange(idx, "startTime", e.target.value)}
                          className="bg-surface border border-border rounded-lg px-2 py-1 text-xs font-mono font-bold outline-none"
                        />
                      </div>
                      <span className="text-muted-foreground text-xs mt-3">→</span>
                      <div className="flex flex-col">
                        <span className="text-[9px] uppercase font-bold text-muted-foreground">Finish</span>
                        <input
                          type="time"
                          value={msToTimeString(trip.finishTime)}
                          onChange={(e) => handleRowChange(idx, "finishTime", e.target.value)}
                          className="bg-surface border border-border rounded-lg px-2 py-1 text-xs font-mono font-bold outline-none"
                        />
                      </div>
                    </div>
                  </div>

                  <div className="flex flex-col items-end">
                    <span className="text-[9px] uppercase font-bold text-muted-foreground">Duration</span>
                    <span className="bg-primary/15 border border-primary/30 text-primary-glow font-mono font-black px-2 py-1 rounded-lg text-xs">
                      {calculatedMins}m
                    </span>
                  </div>
                </div>
              </div>
            );
          })
        )}
      </div>

      {/* ── DESKTOP TABLE LAYOUT (Tablets & Desktops) ────────────────────── */}
      <div className="hidden sm:block bg-surface border border-border rounded-2xl overflow-hidden shadow-sm">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs border-collapse">
            <thead>
              <tr className="border-b border-border bg-muted/40 text-muted-foreground font-bold uppercase tracking-wider text-[11px]">
                <th className="py-3 px-3.5 min-w-[120px]">Reg Plate</th>
                <th className="py-3 px-3.5 min-w-[130px]">Driver Name</th>
                <th className="py-3 px-3.5 min-w-[160px]">Trip ID / Preset</th>
                <th className="py-3 px-3 text-center min-w-[110px]">Start Time</th>
                <th className="py-3 px-3 text-center min-w-[110px]">Finish Time</th>
                <th className="py-3 px-3 text-center min-w-[90px]">Duration</th>
                <th className="py-3 px-3.5 text-right min-w-[120px]">Tyres Loaded</th>
                <th className="py-3 px-2 w-10 text-center"></th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border/60">
              {rawTrips.length === 0 ? (
                <tr>
                  <td colSpan={8} className="py-10 text-center text-muted-foreground text-xs">
                    No loading sheet trips recorded yet. Click{" "}
                    <span className="font-semibold text-foreground">"+ Add Truck Load"</span> to add
                    one.
                  </td>
                </tr>
              ) : (
                rawTrips.map((trip, idx) => {
                  const currentPreset = trip.presetKey ?? "CUSTOM";
                  const calculatedMins = calculateDurationMinutes(trip.startTime, trip.finishTime);

                  return (
                    <tr key={trip.id || idx} className="hover:bg-muted/10 transition-colors">
                      <td className="py-2.5 px-3.5">
                        <input
                          type="text"
                          value={trip.reg || ""}
                          onChange={(e) => handleRowChange(idx, "reg", e.target.value)}
                          placeholder="MN05XNGP"
                          className="w-full bg-background border border-border rounded-lg px-2.5 py-1.5 text-xs font-mono font-bold uppercase text-foreground outline-none focus:border-primary-glow"
                        />
                      </td>

                      <td className="py-2.5 px-3.5">
                        <input
                          type="text"
                          value={trip.driverName || ""}
                          onChange={(e) => handleRowChange(idx, "driverName", e.target.value)}
                          placeholder="Neil"
                          className="w-full bg-background border border-border rounded-lg px-2.5 py-1.5 text-xs font-medium outline-none focus:border-primary-glow"
                        />
                      </td>

                      <td className="py-2.5 px-3.5">
                        <div className="flex items-center gap-1.5">
                          <select
                            value={currentPreset}
                            onChange={(e) => handlePresetSelect(idx, e.target.value as PresetKey)}
                            className="bg-background border border-border rounded-lg px-2 py-1.5 text-xs font-semibold outline-none focus:border-primary-glow"
                          >
                            {LOADING_PRESETS.map((p) => (
                              <option key={p.key} value={p.key}>
                                {p.label}
                              </option>
                            ))}
                          </select>
                          {(currentPreset === "CUSTOM" ||
                            !LOADING_PRESETS.some((p) => p.key === currentPreset)) && (
                            <input
                              type="text"
                              value={trip.tripId || ""}
                              onChange={(e) => handleRowChange(idx, "tripId", e.target.value)}
                              placeholder="Trip ID"
                              className="w-full bg-background border border-border rounded-lg px-2 py-1.5 text-xs font-semibold outline-none focus:border-primary-glow"
                            />
                          )}
                        </div>
                      </td>

                      <td className="py-2.5 px-3 text-center">
                        <input
                          type="time"
                          value={msToTimeString(trip.startTime)}
                          onChange={(e) => handleRowChange(idx, "startTime", e.target.value)}
                          className="bg-background border border-border rounded-lg px-2 py-1 text-xs font-mono font-bold text-center outline-none focus:border-primary-glow"
                        />
                      </td>

                      <td className="py-2.5 px-3 text-center">
                        <input
                          type="time"
                          value={msToTimeString(trip.finishTime)}
                          onChange={(e) => handleRowChange(idx, "finishTime", e.target.value)}
                          className="bg-background border border-border rounded-lg px-2 py-1 text-xs font-mono font-bold text-center outline-none focus:border-primary-glow"
                        />
                      </td>

                      <td className="py-2.5 px-3 text-center">
                        <span className="bg-primary/10 border border-primary/20 text-primary-glow px-2 py-1 rounded-md font-mono font-bold text-xs">
                          {calculatedMins}m
                        </span>
                      </td>

                      <td className="py-2.5 px-3.5 text-right">
                        <div className="flex items-center justify-end gap-1">
                          <button
                            onClick={() =>
                              handleRowChange(
                                idx,
                                "quantityLoaded",
                                Math.max(0, (trip.quantityLoaded || 0) - 1),
                              )
                            }
                            className="h-7 w-7 rounded-md bg-muted text-foreground font-bold flex items-center justify-center shrink-0 active:scale-95"
                          >
                            -
                          </button>
                          <input
                            type="number"
                            min="0"
                            value={trip.quantityLoaded}
                            onChange={(e) =>
                              handleRowChange(idx, "quantityLoaded", e.target.value)
                            }
                            className="w-16 bg-background border border-border rounded-md px-2 py-1 text-xs font-mono font-bold text-center text-primary-glow outline-none focus:border-primary-glow"
                          />
                          <button
                            onClick={() =>
                              handleRowChange(
                                idx,
                                "quantityLoaded",
                                (trip.quantityLoaded || 0) + 1,
                              )
                            }
                            className="h-7 w-7 rounded-md bg-muted text-foreground font-bold flex items-center justify-center shrink-0 active:scale-95"
                          >
                            +
                          </button>
                        </div>
                      </td>

                      <td className="py-2.5 px-2 text-center">
                        <button
                          onClick={() => handleDeleteRow(idx)}
                          className="text-muted-foreground hover:text-destructive p-1.5 rounded-lg hover:bg-destructive/10 transition-colors"
                          title="Delete truck"
                        >
                          <Trash2 size={14} />
                        </button>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* ── REPORT PREVIEW MODAL ─────────────────────────────────────────── */}
      {showReportModal && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-background/80 backdrop-blur-md animate-fade-in"
          onClick={() => setShowReportModal(false)}
        >
          <div
            className="w-full max-w-2xl bg-surface border border-border rounded-3xl p-5 sm:p-6 max-h-[90vh] flex flex-col shadow-2xl animate-scale-up"
            onClick={(e) => e.stopPropagation()}
          >
            {/* Modal Header */}
            <div className="flex items-center justify-between pb-4 border-b border-border">
              <div className="flex items-center gap-2.5">
                <div className="h-9 w-9 rounded-xl bg-primary/10 border border-primary/20 grid place-items-center text-primary-glow">
                  <FileText size={18} />
                </div>
                <div>
                  <h3 className="text-base font-bold text-foreground">Despatch Loading Report</h3>
                  <p className="text-xs text-muted-foreground">
                    {entry.dayKey} · Despatcher: {despatcherName}
                  </p>
                </div>
              </div>

              <button
                onClick={() => setShowReportModal(false)}
                className="h-8 w-8 rounded-full bg-muted grid place-items-center text-muted-foreground hover:text-foreground active:scale-95 transition-all"
              >
                <X size={16} />
              </button>
            </div>

            {/* Scrollable Document Preview Sheet */}
            <div className="flex-1 overflow-y-auto my-4 p-4 bg-white text-black rounded-2xl shadow-inner font-sans text-xs">
              <div className="border-b-2 border-black pb-3 mb-3 flex items-start justify-between">
                <div>
                  <h1 className="text-lg font-black tracking-wide uppercase">
                    Despatch Loading Sheet
                  </h1>
                  <p className="text-xs font-semibold text-gray-700">DATE: {entry.dayKey}</p>
                </div>
                <div className="text-right">
                  <p className="text-xs font-bold text-gray-900">
                    DESPATCHER: {despatcherName || "Theolus"}
                  </p>
                </div>
              </div>

              <table className="w-full border-collapse text-left text-xs mb-4">
                <thead>
                  <tr className="bg-gray-100 border border-black font-bold uppercase text-[11px]">
                    <th className="border border-black p-1.5">Reg</th>
                    <th className="border border-black p-1.5">Driver</th>
                    <th className="border border-black p-1.5">Trip ID</th>
                    <th className="border border-black p-1.5 text-center">Start</th>
                    <th className="border border-black p-1.5 text-center">Finish</th>
                    <th className="border border-black p-1.5 text-right">Mins</th>
                    <th className="border border-black p-1.5 text-right">Qty Loaded</th>
                  </tr>
                </thead>
                <tbody>
                  {rawTrips.length === 0 ? (
                    <tr>
                      <td colSpan={7} className="border border-black p-4 text-center text-gray-500">
                        No truck trips logged for this date.
                      </td>
                    </tr>
                  ) : (
                    rawTrips.map((t, i) => (
                      <tr key={t.id || i} className="border border-black">
                        <td className="border border-black p-1.5 font-bold uppercase font-mono">
                          {t.reg || "-"}
                        </td>
                        <td className="border border-black p-1.5">{t.driverName || "-"}</td>
                        <td className="border border-black p-1.5 font-semibold">
                          {t.tripId || "-"}
                        </td>
                        <td className="border border-black p-1.5 text-center font-mono">
                          {formatTimeHHmm(t.startTime)}
                        </td>
                        <td className="border border-black p-1.5 text-center font-mono">
                          {formatTimeHHmm(t.finishTime)}
                        </td>
                        <td className="border border-black p-1.5 text-right font-mono">
                          {t.durationMinutes ?? calculateDurationMinutes(t.startTime, t.finishTime)}m
                        </td>
                        <td className="border border-black p-1.5 text-right font-black font-mono">
                          {t.quantityLoaded}
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>

              <div className="border-t-2 border-black pt-2 flex items-center justify-between font-black text-xs">
                <span>TOTAL LOADING TIME: {timeFormatted}</span>
                <span>TOTAL TYRES LOADED: {totals.totalTyresLoaded}</span>
              </div>
            </div>

            {/* Modal Actions */}
            <div className="flex flex-wrap items-center justify-between gap-2 pt-2">
              <button
                onClick={() => setShowReportModal(false)}
                className="px-4 py-2.5 rounded-xl border border-border text-xs font-semibold hover:bg-muted active:scale-95 transition-all"
              >
                Close
              </button>

              <div className="flex items-center gap-2">
                <button
                  onClick={handleShareWhatsApp}
                  className="inline-flex items-center gap-1.5 px-4 py-2.5 rounded-xl text-xs font-bold bg-emerald-600/15 border border-emerald-600/30 text-emerald-500 hover:bg-emerald-600/25 active:scale-95 transition-all"
                >
                  <Share2 size={15} />
                  <span>Share WhatsApp</span>
                </button>

                <button
                  onClick={handlePrintPDF}
                  className="inline-flex items-center gap-1.5 px-5 py-2.5 rounded-xl text-xs font-bold bg-primary text-primary-foreground hover:bg-primary/90 active:scale-95 transition-all shadow-sm"
                >
                  <Printer size={15} />
                  <span>Print / Save PDF</span>
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
