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
  Layers,
  Edit3,
  AlertTriangle,
  BadgeCheck,
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
  onCreateTruckLoad?: (tripData: LoadingSheetTrip) => void | Promise<void>;
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

export function LoadingSheet({
  entry,
  onUpdateEntry,
  onCreateTruckLoad,
}: LoadingSheetProps) {
  const [despatcherName, setDespatcherName] = useState<string>("Theolus");
  const [shareFeedback, setShareFeedback] = useState<string | null>(null);
  const [showReportModal, setShowReportModal] = useState<boolean>(false);
  const [showAddModal, setShowAddModal] = useState<boolean>(false);
  const [editingTripIndex, setEditingTripIndex] = useState<number | null>(null);

  // Add Truck Load Form State
  const [addPreset, setAddPreset] = useState<PresetKey>("STOCKS");
  const [addTripId, setAddTripId] = useState<string>("");
  const [addReg, setAddReg] = useState<string>("");
  const [addDriver, setAddDriver] = useState<string>("");
  const [addQty, setAddQty] = useState<number>(0);
  const [addStartTimeStr, setAddStartTimeStr] = useState<string>(msToTimeString(Date.now()));
  const [addFinishTimeStr, setAddFinishTimeStr] = useState<string>(
    msToTimeString(Date.now() + 30 * 60 * 1000),
  );

  // Edit Truck Load Form State
  const [editPreset, setEditPreset] = useState<PresetKey>("CUSTOM");
  const [editTripId, setEditTripId] = useState<string>("");
  const [editReg, setEditReg] = useState<string>("");
  const [editDriver, setEditDriver] = useState<string>("");
  const [editQty, setEditQty] = useState<number>(0);
  const [editStartTimeStr, setEditStartTimeStr] = useState<string>("");
  const [editFinishTimeStr, setEditFinishTimeStr] = useState<string>("");

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

  const handleOpenAddModal = () => {
    const defaultPreset: PresetKey = "STOCKS";
    const fill = getPresetFill(defaultPreset, {
      dayKey: entry.dayKey,
      existingTrips: rawTrips,
    });
    setAddPreset(defaultPreset);
    setAddTripId(fill.tripId);
    setAddReg(fill.reg || "");
    setAddDriver(fill.driverName || "");
    setAddQty(0);
    const now = Date.now();
    setAddStartTimeStr(msToTimeString(now));
    setAddFinishTimeStr(msToTimeString(now + 30 * 60 * 1000));
    setShowAddModal(true);
  };

  const handleAddPresetChange = (preset: PresetKey) => {
    setAddPreset(preset);
    const fill = getPresetFill(preset, {
      dayKey: entry.dayKey,
      existingTrips: rawTrips,
    });
    setAddTripId(fill.tripId);
    if (fill.reg) setAddReg(fill.reg);
    if (fill.driverName) setAddDriver(fill.driverName);
  };

  const handleSubmitAddTruck = async (e: React.FormEvent) => {
    e.preventDefault();
    const baseDate = entry.createdAt || Date.now();
    const startMs = timeStringToMs(addStartTimeStr, baseDate) || Date.now();
    const finishMs = timeStringToMs(addFinishTimeStr, baseDate) || startMs + 30 * 60 * 1000;
    const duration = calculateDurationMinutes(startMs, finishMs);

    const trip: LoadingSheetTrip = {
      id: uid(),
      entryId: entry.id,
      reg: addReg.trim().toUpperCase(),
      driverName: addDriver.trim(),
      tripId: addTripId.trim() || addPreset,
      presetKey: addPreset,
      startTime: startMs,
      finishTime: finishMs,
      durationMinutes: duration,
      quantityLoaded: Math.max(0, addQty),
      isManual: false,
      createdAt: startMs,
    };

    if (onCreateTruckLoad) {
      await onCreateTruckLoad(trip);
    } else {
      updateTrips([...rawTrips, trip]);
    }

    setShowAddModal(false);
  };

  const handleOpenEditModal = (idx: number) => {
    const trip = rawTrips[idx];
    if (!trip) return;
    setEditingTripIndex(idx);
    setEditPreset(trip.presetKey || "CUSTOM");
    setEditTripId(trip.tripId || "");
    setEditReg(trip.reg || "");
    setEditDriver(trip.driverName || "");
    setEditQty(trip.quantityLoaded || 0);
    setEditStartTimeStr(msToTimeString(trip.startTime));
    setEditFinishTimeStr(msToTimeString(trip.finishTime));
  };

  const handleEditPresetChange = (preset: PresetKey) => {
    setEditPreset(preset);
    const fill = getPresetFill(preset, {
      dayKey: entry.dayKey,
      existingTrips: rawTrips,
    });
    setEditTripId(fill.tripId);
    if (fill.reg) setEditReg(fill.reg);
    if (fill.driverName) setEditDriver(fill.driverName);
  };

  const handleSaveEditModal = (e: React.FormEvent) => {
    e.preventDefault();
    if (editingTripIndex === null) return;
    const current = [...rawTrips];
    const existing = current[editingTripIndex];
    if (!existing) return;

    const baseDate = existing.createdAt || entry.createdAt || Date.now();
    const startMs = timeStringToMs(editStartTimeStr, baseDate);
    const finishMs = timeStringToMs(editFinishTimeStr, baseDate);
    const duration = calculateDurationMinutes(startMs, finishMs);

    current[editingTripIndex] = {
      ...existing,
      presetKey: editPreset,
      tripId: editTripId.trim() || editPreset,
      reg: editReg.trim().toUpperCase(),
      driverName: editDriver.trim(),
      quantityLoaded: Math.max(0, editQty),
      startTime: startMs,
      finishTime: finishMs,
      durationMinutes: duration,
    };

    updateTrips(current);
    setEditingTripIndex(null);
  };

  const handleDeleteRow = (index: number) => {
    const current = rawTrips.filter((_, i) => i !== index);
    updateTrips(current);
    if (editingTripIndex === index) {
      setEditingTripIndex(null);
    }
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
            onClick={handleOpenAddModal}
            className="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-xl text-xs font-bold bg-primary text-primary-foreground hover:bg-primary/90 active:scale-95 transition-all shadow-xs"
          >
            <Plus size={15} />
            <span>+ Add Truck Load</span>
          </button>
        </div>
      </div>

      {/* ── MINIMIZED SUMMARY CARDS LIST (Clean, High Legibility, Tap to Edit) ── */}
      <div className="space-y-2.5">
        {rawTrips.length === 0 ? (
          <div className="py-12 text-center text-muted-foreground text-xs bg-surface border border-dashed border-border rounded-2xl p-6">
            <Truck size={36} className="mx-auto mb-2.5 text-muted-foreground/30" />
            <p className="font-bold text-foreground text-sm">No truck loads logged for this date</p>
            <p className="text-xs text-muted-foreground mt-1 max-w-xs mx-auto">
              Tap "+ Add Truck Load" to record a truck trip or start scanning in the counter.
            </p>
            <button
              onClick={handleOpenAddModal}
              className="inline-flex items-center gap-1.5 mt-4 px-4 py-2.5 rounded-xl text-xs font-bold bg-primary text-primary-foreground shadow-sm"
            >
              <Plus size={14} /> Add First Truck Load
            </button>
          </div>
        ) : (
          rawTrips.map((trip, idx) => {
            const hasReg = Boolean(trip.reg && trip.reg.trim());
            const hasDriver = Boolean(trip.driverName && trip.driverName.trim());
            const durationMins = calculateDurationMinutes(trip.startTime, trip.finishTime);
            const timeRange = trip.startTime || trip.finishTime
              ? `${formatTimeHHmm(trip.startTime)} → ${formatTimeHHmm(trip.finishTime)}`
              : "No timing";

            return (
              <div
                key={trip.id || idx}
                onClick={() => handleOpenEditModal(idx)}
                className="group relative bg-surface border border-border hover:border-primary/50 rounded-2xl p-4 transition-all shadow-xs cursor-pointer active:scale-[0.99] space-y-2.5"
              >
                {/* Row Header: Number, Trip ID, Tyres count, Edit Button */}
                <div className="flex items-center justify-between gap-3">
                  <div className="flex items-center gap-2 min-w-0">
                    <span className="h-6 w-6 rounded-full bg-muted font-mono font-bold text-xs grid place-items-center text-muted-foreground shrink-0">
                      {idx + 1}
                    </span>
                    <h3 className="font-mono text-sm font-black tracking-wide uppercase text-foreground truncate">
                      {trip.tripId || `TRIP ${idx + 1}`}
                    </h3>
                  </div>

                  <div className="flex items-center gap-2 shrink-0">
                    <span className="px-2.5 py-1 rounded-lg bg-primary/15 border border-primary/30 text-primary-glow font-mono font-black text-xs tabular-nums">
                      {trip.quantityLoaded || 0} tyres
                    </span>

                    <button
                      type="button"
                      onClick={(e) => {
                        e.stopPropagation();
                        handleOpenEditModal(idx);
                      }}
                      className="h-8 px-2.5 rounded-xl bg-surface-elevated border border-border text-foreground hover:border-primary/50 text-xs font-bold flex items-center gap-1 transition-all"
                    >
                      <Edit3 size={13} className="text-primary-glow" />
                      <span>Edit</span>
                    </button>
                  </div>
                </div>

                {/* Status Badges & Details Row */}
                <div className="flex items-center gap-2 text-xs flex-wrap">
                  {/* Reg Badge */}
                  {hasReg ? (
                    <span className="inline-flex items-center gap-1 font-mono font-bold text-xs px-2.5 py-1 rounded-lg bg-surface-elevated border border-border text-foreground">
                      <Truck size={12} className="text-primary-glow" />
                      {trip.reg}
                    </span>
                  ) : (
                    <span className="inline-flex items-center gap-1 text-[11px] font-semibold px-2 py-0.5 rounded-lg bg-amber-500/10 border border-amber-500/20 text-amber-400">
                      <AlertTriangle size={11} /> No Reg
                    </span>
                  )}

                  {/* Driver Badge */}
                  {hasDriver ? (
                    <span className="inline-flex items-center gap-1 font-medium text-xs px-2.5 py-1 rounded-lg bg-surface-elevated border border-border text-foreground">
                      <User size={12} className="text-primary-glow" />
                      {trip.driverName}
                    </span>
                  ) : (
                    <span className="inline-flex items-center gap-1 text-[11px] font-semibold px-2 py-0.5 rounded-lg bg-amber-500/10 border border-amber-500/20 text-amber-400">
                      <AlertTriangle size={11} /> No Driver
                    </span>
                  )}

                  {/* Time & Duration */}
                  <span className="inline-flex items-center gap-1 font-mono text-[11px] text-muted-foreground ml-auto">
                    <Clock size={11} />
                    {timeRange}
                    <span className="font-bold text-foreground bg-muted px-1.5 py-0.5 rounded">
                      {durationMins}m
                    </span>
                  </span>
                </div>
              </div>
            );
          })
        )}
      </div>

      {/* ── EDIT TRUCK LOAD MODAL ────────────────────────────────────────── */}
      {editingTripIndex !== null && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-background/80 backdrop-blur-md animate-fade-in"
          onClick={() => setEditingTripIndex(null)}
        >
          <div
            className="w-full max-w-md bg-surface border border-border rounded-3xl p-5 sm:p-6 shadow-2xl animate-scale-up"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-center justify-between pb-3.5 border-b border-border">
              <div className="flex items-center gap-2.5">
                <div className="h-9 w-9 rounded-xl bg-primary/10 border border-primary/20 grid place-items-center text-primary-glow">
                  <Edit3 size={18} />
                </div>
                <div>
                  <h3 className="text-base font-bold text-foreground">Edit Truck Load</h3>
                  <p className="text-xs text-muted-foreground">Modify details, quantity and timing</p>
                </div>
              </div>

              <button
                onClick={() => setEditingTripIndex(null)}
                className="h-8 w-8 rounded-full bg-muted grid place-items-center text-muted-foreground hover:text-foreground active:scale-95 transition-all"
              >
                <X size={16} />
              </button>
            </div>

            <form onSubmit={handleSaveEditModal} className="mt-4 space-y-3.5 text-xs">
              {/* Preset Selector */}
              <div>
                <label className="text-[10px] uppercase font-bold text-muted-foreground block mb-1">
                  Preset / Destination
                </label>
                <div className="grid grid-cols-4 gap-1.5">
                  {LOADING_PRESETS.map((p) => (
                    <button
                      key={p.key}
                      type="button"
                      onClick={() => handleEditPresetChange(p.key)}
                      className={`py-2 px-1 rounded-xl text-xs font-bold border transition-all text-center truncate ${
                        editPreset === p.key
                          ? "bg-primary text-primary-foreground border-primary shadow-xs"
                          : "bg-surface-elevated border-border text-muted-foreground hover:text-foreground"
                      }`}
                    >
                      {p.label.replace(" [i]", "")}
                    </button>
                  ))}
                </div>
              </div>

              {/* Trip ID & Reg */}
              <div className="grid grid-cols-2 gap-2.5">
                <div>
                  <label className="text-[10px] uppercase font-bold text-muted-foreground block mb-1">
                    Trip ID
                  </label>
                  <input
                    type="text"
                    value={editTripId}
                    onChange={(e) => setEditTripId(e.target.value)}
                    placeholder="e.g. STOCKS 1"
                    required
                    className="w-full bg-background border border-border rounded-xl px-3 py-2 text-xs font-semibold outline-none focus:border-primary-glow"
                  />
                </div>

                <div>
                  <label className="text-[10px] uppercase font-bold text-muted-foreground block mb-1">
                    Reg Plate
                  </label>
                  <input
                    type="text"
                    value={editReg}
                    onChange={(e) => setEditReg(e.target.value.toUpperCase())}
                    placeholder="e.g. MN05XNGP"
                    className="w-full bg-background border border-border rounded-xl px-3 py-2 text-xs font-mono font-bold uppercase outline-none focus:border-primary-glow"
                  />
                </div>
              </div>

              {/* Driver & Quantity */}
              <div className="grid grid-cols-2 gap-2.5">
                <div>
                  <label className="text-[10px] uppercase font-bold text-muted-foreground block mb-1">
                    Driver Name
                  </label>
                  <input
                    type="text"
                    value={editDriver}
                    onChange={(e) => setEditDriver(e.target.value)}
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
                      type="button"
                      onClick={() => setEditQty(Math.max(0, editQty - 1))}
                      className="h-8 w-8 rounded-lg bg-surface-elevated border border-border text-foreground font-black text-sm flex items-center justify-center shrink-0 active:scale-95"
                    >
                      -
                    </button>
                    <input
                      type="number"
                      min="0"
                      value={editQty}
                      onChange={(e) => setEditQty(Math.max(0, parseInt(e.target.value, 10) || 0))}
                      className="w-full bg-background border border-border rounded-lg px-2 py-1.5 text-sm font-mono font-black text-center text-primary-glow outline-none focus:border-primary-glow"
                    />
                    <button
                      type="button"
                      onClick={() => setEditQty(editQty + 1)}
                      className="h-8 w-8 rounded-lg bg-surface-elevated border border-border text-foreground font-black text-sm flex items-center justify-center shrink-0 active:scale-95"
                    >
                      +
                    </button>
                  </div>
                </div>
              </div>

              {/* Timings */}
              <div className="grid grid-cols-2 gap-2.5">
                <div>
                  <label className="text-[10px] uppercase font-bold text-muted-foreground block mb-1">
                    Start Time
                  </label>
                  <input
                    type="time"
                    value={editStartTimeStr}
                    onChange={(e) => setEditStartTimeStr(e.target.value)}
                    className="w-full bg-background border border-border rounded-xl px-3 py-2 text-xs font-mono font-bold outline-none focus:border-primary-glow"
                  />
                </div>

                <div>
                  <label className="text-[10px] uppercase font-bold text-muted-foreground block mb-1">
                    Finish Time
                  </label>
                  <input
                    type="time"
                    value={editFinishTimeStr}
                    onChange={(e) => setEditFinishTimeStr(e.target.value)}
                    className="w-full bg-background border border-border rounded-xl px-3 py-2 text-xs font-mono font-bold outline-none focus:border-primary-glow"
                  />
                </div>
              </div>

              {/* Modal Actions */}
              <div className="flex items-center justify-between gap-2 pt-3 border-t border-border mt-4">
                <button
                  type="button"
                  onClick={() => handleDeleteRow(editingTripIndex)}
                  className="px-3 py-2.5 rounded-xl text-destructive hover:bg-destructive/10 text-xs font-bold flex items-center gap-1.5 transition-all"
                >
                  <Trash2 size={14} /> Delete
                </button>

                <div className="flex items-center gap-2">
                  <button
                    type="button"
                    onClick={() => setEditingTripIndex(null)}
                    className="px-4 py-2.5 rounded-xl border border-border text-xs font-semibold hover:bg-muted active:scale-95 transition-all"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    className="px-5 py-2.5 rounded-xl bg-primary text-primary-foreground font-bold text-xs hover:bg-primary/90 active:scale-95 transition-all shadow-sm"
                  >
                    Save Changes
                  </button>
                </div>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ── ADD TRUCK LOAD MODAL ─────────────────────────────────────────── */}
      {showAddModal && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-background/80 backdrop-blur-md animate-fade-in"
          onClick={() => setShowAddModal(false)}
        >
          <div
            className="w-full max-w-md bg-surface border border-border rounded-3xl p-5 sm:p-6 shadow-2xl animate-scale-up"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-center justify-between pb-3.5 border-b border-border">
              <div className="flex items-center gap-2.5">
                <div className="h-9 w-9 rounded-xl bg-primary/10 border border-primary/20 grid place-items-center text-primary-glow">
                  <Truck size={18} />
                </div>
                <div>
                  <h3 className="text-base font-bold text-foreground">Add Truck Load</h3>
                  <p className="text-xs text-muted-foreground">Creates a trip on the sheet and daily log</p>
                </div>
              </div>

              <button
                onClick={() => setShowAddModal(false)}
                className="h-8 w-8 rounded-full bg-muted grid place-items-center text-muted-foreground hover:text-foreground active:scale-95 transition-all"
              >
                <X size={16} />
              </button>
            </div>

            <form onSubmit={handleSubmitAddTruck} className="mt-4 space-y-3.5 text-xs">
              {/* Preset Selector */}
              <div>
                <label className="text-[10px] uppercase font-bold text-muted-foreground block mb-1">
                  Preset / Destination
                </label>
                <div className="grid grid-cols-4 gap-1.5">
                  {LOADING_PRESETS.map((p) => (
                    <button
                      key={p.key}
                      type="button"
                      onClick={() => handleAddPresetChange(p.key)}
                      className={`py-2 px-1 rounded-xl text-xs font-bold border transition-all text-center truncate ${
                        addPreset === p.key
                          ? "bg-primary text-primary-foreground border-primary shadow-xs"
                          : "bg-surface-elevated border-border text-muted-foreground hover:text-foreground"
                      }`}
                    >
                      {p.label.replace(" [i]", "")}
                    </button>
                  ))}
                </div>
              </div>

              {/* Trip ID & Reg */}
              <div className="grid grid-cols-2 gap-2.5">
                <div>
                  <label className="text-[10px] uppercase font-bold text-muted-foreground block mb-1">
                    Trip ID
                  </label>
                  <input
                    type="text"
                    value={addTripId}
                    onChange={(e) => setAddTripId(e.target.value)}
                    placeholder="e.g. STOCKS 1"
                    required
                    className="w-full bg-background border border-border rounded-xl px-3 py-2 text-xs font-semibold outline-none focus:border-primary-glow"
                  />
                </div>

                <div>
                  <label className="text-[10px] uppercase font-bold text-muted-foreground block mb-1">
                    Reg Plate
                  </label>
                  <input
                    type="text"
                    value={addReg}
                    onChange={(e) => setAddReg(e.target.value.toUpperCase())}
                    placeholder="e.g. MN05XNGP"
                    className="w-full bg-background border border-border rounded-xl px-3 py-2 text-xs font-mono font-bold uppercase outline-none focus:border-primary-glow"
                  />
                </div>
              </div>

              {/* Driver & Quantity */}
              <div className="grid grid-cols-2 gap-2.5">
                <div>
                  <label className="text-[10px] uppercase font-bold text-muted-foreground block mb-1">
                    Driver Name
                  </label>
                  <input
                    type="text"
                    value={addDriver}
                    onChange={(e) => setAddDriver(e.target.value)}
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
                      type="button"
                      onClick={() => setAddQty(Math.max(0, addQty - 1))}
                      className="h-8 w-8 rounded-lg bg-surface-elevated border border-border text-foreground font-black text-sm flex items-center justify-center shrink-0 active:scale-95"
                    >
                      -
                    </button>
                    <input
                      type="number"
                      min="0"
                      value={addQty}
                      onChange={(e) => setAddQty(Math.max(0, parseInt(e.target.value, 10) || 0))}
                      className="w-full bg-background border border-border rounded-lg px-2 py-1.5 text-sm font-mono font-black text-center text-primary-glow outline-none focus:border-primary-glow"
                    />
                    <button
                      type="button"
                      onClick={() => setAddQty(addQty + 1)}
                      className="h-8 w-8 rounded-lg bg-surface-elevated border border-border text-foreground font-black text-sm flex items-center justify-center shrink-0 active:scale-95"
                    >
                      +
                    </button>
                  </div>
                </div>
              </div>

              {/* Timings */}
              <div className="grid grid-cols-2 gap-2.5">
                <div>
                  <label className="text-[10px] uppercase font-bold text-muted-foreground block mb-1">
                    Start Time
                  </label>
                  <input
                    type="time"
                    value={addStartTimeStr}
                    onChange={(e) => setAddStartTimeStr(e.target.value)}
                    className="w-full bg-background border border-border rounded-xl px-3 py-2 text-xs font-mono font-bold outline-none focus:border-primary-glow"
                  />
                </div>

                <div>
                  <label className="text-[10px] uppercase font-bold text-muted-foreground block mb-1">
                    Finish Time
                  </label>
                  <input
                    type="time"
                    value={addFinishTimeStr}
                    onChange={(e) => setAddFinishTimeStr(e.target.value)}
                    className="w-full bg-background border border-border rounded-xl px-3 py-2 text-xs font-mono font-bold outline-none focus:border-primary-glow"
                  />
                </div>
              </div>

              {/* Modal Submit & Cancel */}
              <div className="flex items-center justify-end gap-2 pt-3 border-t border-border mt-4">
                <button
                  type="button"
                  onClick={() => setShowAddModal(false)}
                  className="px-4 py-2.5 rounded-xl border border-border text-xs font-semibold hover:bg-muted active:scale-95 transition-all"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-5 py-2.5 rounded-xl bg-primary text-primary-foreground font-bold text-xs hover:bg-primary/90 active:scale-95 transition-all shadow-sm flex items-center gap-1.5"
                >
                  <Plus size={14} /> Add Truck Load
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

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
