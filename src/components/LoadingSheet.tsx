import { useState, useEffect } from "react";
import { Printer, Share2, Plus, Trash2, Truck, User, Calendar, Check, Clock, ChevronRight } from "lucide-react";
import type { Entry, LoadingSheetTrip, PresetKey } from "@/lib/types";
import {
  LOADING_PRESETS,
  getPresetFill,
  calculateDurationMinutes,
  calculateLoadingSheetTotals,
} from "@/lib/loading-presets";
import { getDespatcherName, saveDespatcherName } from "@/lib/db";
import { generatePDFReport } from "@/lib/export-pdf";
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
  const [editingTripId, setEditingTripId] = useState<string | null>(null);

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
    value: any
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
      reg: "",
      driverName: "",
      tripId: "STOCKS 1",
      presetKey: "STOCKS",
      startTime: now,
      finishTime: now,
      durationMinutes: 1,
      quantityLoaded: 2,
      isManual: true,
      createdAt: now,
    };
    const fill = getPresetFill("STOCKS", {
      dayKey: entry.dayKey,
      existingTrips: rawTrips,
    });
    newTrip.tripId = fill.tripId;
    updateTrips([...rawTrips, newTrip]);
    setEditingTripId(newTrip.id);
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
    <div className="rounded-2xl border border-border bg-card shadow-sm overflow-hidden text-card-foreground">
      {/* ── HEADER ────────────────────────────────────────────────────────── */}
      <div className="p-4 sm:p-5 border-b border-border bg-muted/30">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
          <div>
            <div className="flex items-center gap-2 text-xs font-semibold uppercase tracking-wider text-primary-glow">
              <Truck size={16} />
              <span>Despatch Loading Sheet</span>
            </div>
            <div className="flex items-center gap-2 mt-1 text-sm font-medium text-foreground">
              <Calendar size={14} className="text-muted-foreground" />
              <span>{fmtDayLabel(entry.createdAt)}</span>
              <span className="text-xs font-mono text-muted-foreground">({entry.dayKey})</span>
            </div>
          </div>

          <div className="flex items-center gap-2 bg-background/80 border border-border rounded-xl px-3 py-1.5 shadow-xs">
            <User size={15} className="text-primary-glow shrink-0" />
            <span className="text-xs font-medium text-muted-foreground shrink-0">
              Despatcher:
            </span>
            <input
              type="text"
              value={despatcherName}
              onChange={(e) => handleDespatcherChange(e.target.value)}
              placeholder="Theolus"
              className="bg-transparent text-sm font-semibold outline-none w-28 sm:w-36 text-foreground placeholder:text-muted-foreground/60"
            />
          </div>
        </div>

        {/* Action Bar Buttons */}
        <div className="flex flex-wrap items-center justify-between gap-2 mt-4 pt-3 border-t border-border/50">
          <div className="flex items-center gap-2">
            <button
              onClick={handlePrintPDF}
              className="inline-flex items-center gap-1.5 px-3 py-2 rounded-xl text-xs font-semibold bg-secondary text-secondary-foreground hover:bg-secondary/80 active:scale-95 transition-all shadow-xs"
            >
              <Printer size={15} />
              <span>PDF / Print</span>
            </button>
            <button
              onClick={handleShareWhatsApp}
              className="inline-flex items-center gap-1.5 px-3 py-2 rounded-xl text-xs font-semibold bg-emerald-600/15 text-emerald-500 hover:bg-emerald-600/25 active:scale-95 transition-all shadow-xs"
            >
              <Share2 size={15} />
              <span>WhatsApp Share</span>
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
            <Plus size={16} />
            <span>+ Add Truck Load</span>
          </button>
        </div>
      </div>

      {/* ── MOBILE CARD LAYOUT (Shown on small screens) ──────────────────── */}
      <div className="block sm:hidden p-3 space-y-3">
        {rawTrips.length === 0 ? (
          <div className="py-8 text-center text-muted-foreground text-xs bg-muted/20 rounded-xl p-4 border border-dashed border-border">
            No truck loads logged for today yet.
            <div className="mt-3">
              <button
                onClick={handleAddManualRow}
                className="inline-flex items-center gap-1.5 px-4 py-2 rounded-xl text-xs font-bold bg-primary text-primary-foreground"
              >
                <Plus size={14} /> + Add Truck Load
              </button>
            </div>
          </div>
        ) : (
          rawTrips.map((trip, idx) => {
            const currentPreset = trip.presetKey ?? "CUSTOM";
            const calculatedMins = calculateDurationMinutes(trip.startTime, trip.finishTime);

            return (
              <div
                key={trip.id || idx}
                className="rounded-xl border border-border bg-surface p-3.5 space-y-3 shadow-xs"
              >
                {/* Mobile Card Header */}
                <div className="flex items-center justify-between gap-2 border-b border-border/60 pb-2.5">
                  <div className="flex items-center gap-2 flex-1 min-w-0">
                    <span className="text-xs font-mono font-bold text-muted-foreground">
                      #{idx + 1}
                    </span>
                    <input
                      type="text"
                      value={trip.reg || ""}
                      onChange={(e) => handleRowChange(idx, "reg", e.target.value)}
                      placeholder="TRUCK REG"
                      className="bg-background border border-border rounded-lg px-2.5 py-1 text-sm font-mono font-black uppercase outline-none focus:border-primary w-32"
                    />
                  </div>

                  {/* Preset Selector */}
                  <select
                    value={currentPreset}
                    onChange={(e) => handlePresetSelect(idx, e.target.value as PresetKey)}
                    className="bg-background border border-border rounded-lg px-2 py-1 text-xs font-bold outline-none focus:border-primary"
                  >
                    {LOADING_PRESETS.map((p) => (
                      <option key={p.key} value={p.key}>
                        {p.label}
                      </option>
                    ))}
                  </select>

                  <button
                    onClick={() => handleDeleteRow(idx)}
                    className="text-muted-foreground hover:text-destructive p-1 rounded-lg hover:bg-destructive/10"
                    title="Delete truck"
                  >
                    <Trash2 size={15} />
                  </button>
                </div>

                {/* Custom Trip ID input if CUSTOM */}
                {(currentPreset === "CUSTOM" ||
                  !LOADING_PRESETS.some((p) => p.key === currentPreset)) && (
                  <div>
                    <input
                      type="text"
                      value={trip.tripId || ""}
                      onChange={(e) => handleRowChange(idx, "tripId", e.target.value)}
                      placeholder="Enter custom Trip ID..."
                      className="w-full bg-background border border-border rounded-lg px-2.5 py-1 text-xs outline-none focus:border-primary"
                    />
                  </div>
                )}

                {/* Driver Name & Tyres Grid */}
                <div className="grid grid-cols-2 gap-2">
                  <div>
                    <label className="text-[10px] uppercase font-bold text-muted-foreground block mb-1">
                      Driver Name
                    </label>
                    <input
                      type="text"
                      value={trip.driverName || ""}
                      onChange={(e) => handleRowChange(idx, "driverName", e.target.value)}
                      placeholder="Neil"
                      className="w-full bg-background border border-border rounded-lg px-2 py-1.5 text-xs outline-none focus:border-primary"
                    />
                  </div>

                  <div>
                    <label className="text-[10px] uppercase font-bold text-muted-foreground block mb-1">
                      Quantity Loaded
                    </label>
                    <div className="flex items-center gap-1">
                      <button
                        onClick={() =>
                          handleRowChange(
                            idx,
                            "quantityLoaded",
                            Math.max(0, (trip.quantityLoaded || 0) - 1)
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
                        onChange={(e) => handleRowChange(idx, "quantityLoaded", e.target.value)}
                        className="w-full bg-background border border-border rounded-md px-2 py-1 text-xs font-mono font-bold text-center outline-none focus:border-primary"
                      />
                      <button
                        onClick={() =>
                          handleRowChange(
                            idx,
                            "quantityLoaded",
                            (trip.quantityLoaded || 0) + 1
                          )
                        }
                        className="h-7 w-7 rounded-md bg-muted text-foreground font-bold flex items-center justify-center shrink-0 active:scale-95"
                      >
                        +
                      </button>
                    </div>
                  </div>
                </div>

                {/* Times & Duration Row */}
                <div className="flex items-center justify-between gap-2 bg-muted/30 border border-border/50 rounded-xl p-2 text-xs">
                  <div className="flex items-center gap-1.5">
                    <Clock size={13} className="text-muted-foreground shrink-0" />
                    <input
                      type="time"
                      value={msToTimeString(trip.startTime)}
                      onChange={(e) => handleRowChange(idx, "startTime", e.target.value)}
                      className="bg-background border border-border rounded-md px-1.5 py-0.5 text-xs font-mono outline-none"
                    />
                    <span className="text-muted-foreground">→</span>
                    <input
                      type="time"
                      value={msToTimeString(trip.finishTime)}
                      onChange={(e) => handleRowChange(idx, "finishTime", e.target.value)}
                      className="bg-background border border-border rounded-md px-1.5 py-0.5 text-xs font-mono outline-none"
                    />
                  </div>

                  <span className="bg-primary/15 text-primary-glow font-mono font-bold px-2 py-0.5 rounded-md text-[11px] shrink-0">
                    {calculatedMins}m
                  </span>
                </div>
              </div>
            );
          })
        )}
      </div>

      {/* ── DESKTOP TABLE LAYOUT (Shown on tablets/desktops) ────────────── */}
      <div className="hidden sm:block overflow-x-auto">
        <table className="w-full text-left text-xs border-collapse">
          <thead>
            <tr className="border-b border-border bg-muted/50 text-muted-foreground font-semibold uppercase tracking-wider text-[11px]">
              <th className="py-2.5 px-3 min-w-[110px]">Reg</th>
              <th className="py-2.5 px-3 min-w-[120px]">Driver Name</th>
              <th className="py-2.5 px-3 min-w-[150px]">Trip ID</th>
              <th className="py-2.5 px-3 min-w-[100px] text-center">Start Time</th>
              <th className="py-2.5 px-3 min-w-[100px] text-center">Finished Time</th>
              <th className="py-2.5 px-3 min-w-[80px] text-right">Minutes</th>
              <th className="py-2.5 px-3 min-w-[90px] text-right">Qty Loaded</th>
              <th className="py-2.5 px-2 w-10 text-center"></th>
            </tr>
          </thead>
          <tbody className="divide-y divide-border/60">
            {rawTrips.length === 0 ? (
              <tr>
                <td
                  colSpan={8}
                  className="py-8 text-center text-muted-foreground text-xs"
                >
                  No loading sheet trips recorded yet. Click{" "}
                  <span className="font-semibold text-foreground">
                    "+ Add Truck Load"
                  </span>{" "}
                  or scan tyres to add.
                </td>
              </tr>
            ) : (
              rawTrips.map((trip, idx) => {
                const currentPreset = trip.presetKey ?? "CUSTOM";
                const calculatedMins = calculateDurationMinutes(trip.startTime, trip.finishTime);

                return (
                  <tr
                    key={trip.id || idx}
                    className="hover:bg-muted/20 transition-colors group"
                  >
                    <td className="py-2 px-3">
                      <input
                        type="text"
                        value={trip.reg || ""}
                        onChange={(e) => handleRowChange(idx, "reg", e.target.value)}
                        placeholder="MN05XNGP"
                        className="w-full bg-background border border-border/70 rounded-md px-2 py-1 text-xs font-mono font-bold uppercase outline-none focus:border-primary focus:ring-1 focus:ring-primary"
                      />
                    </td>

                    <td className="py-2 px-3">
                      <input
                        type="text"
                        value={trip.driverName || ""}
                        onChange={(e) => handleRowChange(idx, "driverName", e.target.value)}
                        placeholder="Neil"
                        className="w-full bg-background border border-border/70 rounded-md px-2 py-1 text-xs outline-none focus:border-primary focus:ring-1 focus:ring-primary"
                      />
                    </td>

                    <td className="py-2 px-3">
                      <div className="flex flex-col gap-1">
                        <select
                          value={currentPreset}
                          onChange={(e) => handlePresetSelect(idx, e.target.value as PresetKey)}
                          className="w-full bg-background border border-border/70 rounded-md px-2 py-1 text-xs font-medium outline-none focus:border-primary focus:ring-1 focus:ring-primary"
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
                            placeholder="Custom Trip ID"
                            className="w-full bg-background border border-border/70 rounded-md px-2 py-1 text-xs outline-none focus:border-primary focus:ring-1 focus:ring-primary"
                          />
                        )}
                      </div>
                    </td>

                    <td className="py-2 px-3 text-center">
                      <input
                        type="time"
                        value={msToTimeString(trip.startTime)}
                        onChange={(e) => handleRowChange(idx, "startTime", e.target.value)}
                        className="bg-background border border-border/70 rounded-md px-1.5 py-1 text-xs font-mono text-center outline-none focus:border-primary focus:ring-1 focus:ring-primary"
                      />
                    </td>

                    <td className="py-2 px-3 text-center">
                      <input
                        type="time"
                        value={msToTimeString(trip.finishTime)}
                        onChange={(e) => handleRowChange(idx, "finishTime", e.target.value)}
                        className="bg-background border border-border/70 rounded-md px-1.5 py-1 text-xs font-mono text-center outline-none focus:border-primary focus:ring-1 focus:ring-primary"
                      />
                    </td>

                    <td className="py-2 px-3 text-right">
                      <span className="inline-block bg-muted px-2 py-1 rounded-md font-mono font-semibold text-xs tabular-nums text-foreground">
                        {calculatedMins}m
                      </span>
                    </td>

                    <td className="py-2 px-3 text-right">
                      <input
                        type="number"
                        min="0"
                        value={trip.quantityLoaded}
                        onChange={(e) => handleRowChange(idx, "quantityLoaded", e.target.value)}
                        className="w-16 bg-background border border-border/70 rounded-md px-2 py-1 text-xs font-mono font-bold text-right outline-none focus:border-primary focus:ring-1 focus:ring-primary"
                      />
                    </td>

                    <td className="py-2 px-2 text-center">
                      <button
                        onClick={() => handleDeleteRow(idx)}
                        className="text-muted-foreground hover:text-destructive p-1 rounded-md hover:bg-destructive/10 transition-colors"
                        title="Delete row"
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

      {/* ── SUMMARY FOOTER ────────────────────────────────────────────────── */}
      <div className="p-4 bg-muted/40 border-t border-border flex flex-col sm:flex-row items-center justify-between gap-3">
        <div className="text-xs text-muted-foreground">
          Showing <span className="font-semibold text-foreground">{rawTrips.length}</span>{" "}
          {rawTrips.length === 1 ? "truck" : "trucks"} loaded
        </div>

        <div className="flex flex-wrap items-center gap-4 text-sm w-full sm:w-auto justify-between sm:justify-end">
          <div className="flex items-center gap-2">
            <span className="text-xs uppercase font-bold text-muted-foreground tracking-wider">
              Total Time:
            </span>
            <span className="font-mono font-bold text-sm text-foreground tabular-nums">
              {timeFormatted}
            </span>
          </div>

          <div className="flex items-center gap-2 bg-background border border-border rounded-xl px-3 py-1 shadow-xs">
            <span className="text-xs uppercase font-bold text-muted-foreground tracking-wider">
              Total Tyres:
            </span>
            <span className="font-mono font-black text-base text-primary-glow tabular-nums">
              {totals.totalTyresLoaded}
            </span>
          </div>
        </div>
      </div>
    </div>
  );
}
