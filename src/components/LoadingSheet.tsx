import { useState, useEffect } from "react";
import {
  FileText,
  Printer,
  Share2,
  Plus,
  Trash2,
  Truck,
  User,
  Check,
  Clock,
  X,
  Layers,
  Edit3,
  AlertTriangle,
} from "lucide-react";
import type { Entry, LoadingSheetTrip, PresetKey } from "@/lib/types";
import {
  LOADING_PRESETS,
  getPresetFill,
  getPresetBadgeClass,
  calculateDurationMinutes,
  calculateLoadingSheetTotals,
} from "@/lib/loading-presets";
import { getDespatcherName, saveDespatcherName } from "@/lib/db";
import { generatePDFReport, formatTimeHHmm } from "@/lib/export-pdf";
import { formatWhatsAppShareText, shareWhatsAppText } from "@/lib/export-whatsapp";
import { fmtDayLabel, uid } from "@/lib/format";
import { vibrate } from "@/lib/haptics";

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
  if (!timeStr || !timeStr.trim()) return undefined;
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

  // Add Truck Load Form State (Timestamps empty by default)
  const [addPreset, setAddPreset] = useState<PresetKey>("STOCKS");
  const [addTripId, setAddTripId] = useState<string>("");
  const [addReg, setAddReg] = useState<string>("");
  const [addDriver, setAddDriver] = useState<string>("");
  const [addQty, setAddQty] = useState<number>(0);
  const [addStartTimeStr, setAddStartTimeStr] = useState<string>("");
  const [addFinishTimeStr, setAddFinishTimeStr] = useState<string>("");

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
    setAddStartTimeStr("");
    setAddFinishTimeStr("");
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
    const startMs = addStartTimeStr ? timeStringToMs(addStartTimeStr, baseDate) : undefined;
    const finishMs = addFinishTimeStr ? timeStringToMs(addFinishTimeStr, baseDate) : undefined;
    const duration = (startMs && finishMs) ? calculateDurationMinutes(startMs, finishMs) : undefined;

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
      createdAt: startMs || Date.now(),
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
    setEditStartTimeStr(trip.startTime ? msToTimeString(trip.startTime) : "");
    setEditFinishTimeStr(trip.finishTime ? msToTimeString(trip.finishTime) : "");
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
    const startMs = editStartTimeStr ? timeStringToMs(editStartTimeStr, baseDate) : undefined;
    const finishMs = editFinishTimeStr ? timeStringToMs(editFinishTimeStr, baseDate) : undefined;
    const duration = (startMs && finishMs) ? calculateDurationMinutes(startMs, finishMs) : undefined;

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
    totalMins > 0
      ? hours > 0
        ? `${hours}h ${mins}m (${totalMins}m)`
        : `${totalMins} mins`
      : "0 mins";

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
      <div className="grid grid-cols-3 gap-2 sm:gap-4 ios-glass-elevated p-4 shadow-xl">
        <div className="flex flex-col">
          <span className="text-[10px] sm:text-xs font-bold uppercase tracking-wider text-slate-400 flex items-center gap-1.5">
            <Truck size={13} className="text-primary-glow" /> Trucks
          </span>
          <span className="mt-1 text-xl sm:text-2xl font-black font-mono text-slate-100">
            {rawTrips.length}
          </span>
        </div>

        <div className="flex flex-col border-x border-white/[0.08] px-3 sm:px-4">
          <span className="text-[10px] sm:text-xs font-bold uppercase tracking-wider text-slate-400 flex items-center gap-1.5">
            <Clock size={13} className="text-primary-glow" /> Total Time
          </span>
          <span className="mt-1 text-sm sm:text-lg font-bold font-mono text-slate-200 truncate">
            {timeFormatted}
          </span>
        </div>

        <div className="flex flex-col text-right sm:text-left">
          <span className="text-[10px] sm:text-xs font-bold uppercase tracking-wider text-slate-400 flex items-center justify-end sm:justify-start gap-1.5">
            <Layers size={13} className="text-primary-glow" /> Tyres
          </span>
          <span className="mt-1 text-xl sm:text-2xl font-black font-mono text-blue-400">
            {totals.totalTyresLoaded}
          </span>
        </div>
      </div>

      {/* ── HEADER & TOOLBAR ─────────────────────────────────────────────── */}
      <div className="ios-glass-card p-4 sm:p-5 shadow-lg space-y-4">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
          <div className="flex items-center gap-3">
            <div className="h-10 w-10 rounded-2xl bg-blue-500/15 border border-blue-500/30 grid place-items-center text-blue-400 shrink-0 shadow-md">
              <Truck size={20} />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h2 className="text-base font-bold tracking-tight text-slate-100">
                  Truck Loading Log
                </h2>
                <span className="text-[10px] font-bold uppercase px-2 py-0.5 rounded-full bg-white/[0.06] border border-white/[0.1] text-slate-300">
                  Compliance
                </span>
              </div>
              <p className="text-xs text-slate-400 mt-0.5">
                {fmtDayLabel(entry.createdAt)} · <span className="font-mono text-slate-300">{entry.dayKey}</span>
              </p>
            </div>
          </div>

          <div className="flex items-center gap-2 bg-black/30 border border-white/[0.1] rounded-2xl px-3.5 py-2 shadow-inner">
            <User size={15} className="text-primary-glow shrink-0" />
            <span className="text-xs font-medium text-slate-400 shrink-0">Despatcher:</span>
            <input
              type="text"
              value={despatcherName}
              onChange={(e) => handleDespatcherChange(e.target.value)}
              placeholder="Theolus"
              className="bg-transparent text-xs font-bold outline-none w-28 text-slate-100 focus:text-primary-glow"
            />
          </div>
        </div>

        {/* Action Buttons */}
        <div className="flex flex-wrap items-center justify-between gap-2 pt-3 border-t border-white/[0.08]">
          <div className="flex items-center gap-2">
            <button
              onClick={() => {
                vibrate("light");
                setShowReportModal(true);
              }}
              className="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-xl text-xs font-semibold bg-white/[0.06] border border-white/[0.12] text-slate-200 hover:bg-white/[0.12] ios-press shadow-sm"
            >
              <Printer size={15} className="text-primary-glow" />
              <span>Preview & Print PDF</span>
            </button>
            <button
              onClick={() => {
                vibrate("light");
                handleShareWhatsApp();
              }}
              className="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-xl text-xs font-semibold bg-emerald-500/15 border border-emerald-500/30 text-emerald-400 hover:bg-emerald-500/25 ios-press shadow-sm"
            >
              <Share2 size={15} />
              <span>Share WhatsApp</span>
            </button>
            {shareFeedback && (
              <span className="text-xs text-emerald-400 font-medium flex items-center gap-1 animate-fade-in">
                <Check size={13} /> {shareFeedback}
              </span>
            )}
          </div>

          <button
            onClick={() => {
              vibrate("light");
              handleOpenAddModal();
            }}
            className="inline-flex items-center gap-1.5 px-4 py-2 rounded-xl text-xs font-bold bg-primary text-white hover:bg-primary/90 ios-press shadow-md"
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
            const hasTiming = Boolean(trip.startTime && trip.finishTime);
            const durationMins = hasTiming
              ? calculateDurationMinutes(trip.startTime, trip.finishTime)
              : 0;
            const timeRange = hasTiming
              ? `${formatTimeHHmm(trip.startTime)} → ${formatTimeHHmm(trip.finishTime)}`
              : "No timestamps";

            const badgeClass = getPresetBadgeClass(trip.presetKey, trip.tripId);

            return (
              <div
                key={trip.id || idx}
                onClick={() => {
                  vibrate("light");
                  handleOpenEditModal(idx);
                }}
                className="group relative ios-glass-card p-4 ios-press space-y-2.5 shadow-lg"
              >
                {/* Row Header: Number, Trip ID, Tyres count, Edit Button */}
                <div className="flex items-center justify-between gap-3">
                  <div className="flex items-center gap-2 min-w-0">
                    <span className="h-6 w-6 rounded-full bg-white/[0.06] font-mono font-bold text-xs grid place-items-center text-slate-300 shrink-0 border border-white/[0.08]">
                      {idx + 1}
                    </span>
                    <span className={`text-[11px] font-mono font-bold uppercase px-2.5 py-0.5 rounded-lg tracking-wider truncate shrink-0 ${badgeClass}`}>
                      {trip.tripId || `TRIP ${idx + 1}`}
                    </span>
                  </div>

                  <div className="flex items-center gap-2 shrink-0">
                    <span className="px-2.5 py-1 rounded-xl bg-blue-500/15 border border-blue-500/30 text-blue-400 font-mono font-black text-xs tabular-nums shadow-xs">
                      {trip.quantityLoaded || 0} tyres
                    </span>

                    <button
                      type="button"
                      onClick={(e) => {
                        e.stopPropagation();
                        vibrate("light");
                        handleOpenEditModal(idx);
                      }}
                      className="h-8 px-2.5 rounded-xl bg-white/[0.06] border border-white/[0.12] text-slate-200 hover:bg-white/[0.12] text-xs font-bold flex items-center gap-1.5 active:scale-90 transition-all shadow-xs"
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
                    <span className="inline-flex items-center gap-1 font-mono font-bold text-xs px-2.5 py-1 rounded-lg bg-white/[0.06] border border-white/[0.1] text-slate-200">
                      <Truck size={12} className="text-primary-glow" />
                      {trip.reg}
                    </span>
                  ) : (
                    <span className="inline-flex items-center gap-1 text-[11px] font-semibold px-2 py-0.5 rounded-lg bg-amber-500/12 border border-amber-500/25 text-amber-400">
                      <AlertTriangle size={11} /> No Reg
                    </span>
                  )}

                  {/* Driver Badge */}
                  {hasDriver ? (
                    <span className="inline-flex items-center gap-1 font-medium text-xs px-2.5 py-1 rounded-lg bg-white/[0.06] border border-white/[0.1] text-slate-200">
                      <User size={12} className="text-primary-glow" />
                      {trip.driverName}
                    </span>
                  ) : (
                    <span className="inline-flex items-center gap-1 text-[11px] font-semibold px-2 py-0.5 rounded-lg bg-amber-500/12 border border-amber-500/25 text-amber-400">
                      <AlertTriangle size={11} /> No Driver
                    </span>
                  )}

                  {/* Time & Duration */}
                  {hasTiming ? (
                    <span className="inline-flex items-center gap-1 font-mono text-[11px] text-slate-400 ml-auto bg-black/30 px-2.5 py-1 rounded-lg border border-white/[0.08]">
                      <Clock size={11} className="text-primary-glow" />
                      {timeRange}
                      <span className="font-bold text-slate-100 bg-white/[0.12] px-1.5 py-0.5 rounded ml-1">
                        {durationMins}m
                      </span>
                    </span>
                  ) : (
                    <span className="inline-flex items-center gap-1 text-[11px] text-slate-500 ml-auto">
                      <Clock size={11} /> No timestamps
                    </span>
                  )}
                </div>
              </div>
            );
          })
        )}
      </div>

      {/* ── EDIT TRUCK LOAD MODAL (iOS Bottom Sheet) ────────────────────── */}
      {editingTripIndex !== null && (
        <div
          className="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-0 sm:p-4 bg-black/65 backdrop-blur-md animate-fade-in"
          onClick={() => setEditingTripIndex(null)}
        >
          <div
            className="w-full max-w-md ios-glass-elevated rounded-t-[2.5rem] sm:rounded-3xl p-6 pb-[max(1.5rem,env(safe-area-inset-bottom))] shadow-2xl animate-sheet-slide-up max-h-[92vh] overflow-y-auto"
            onClick={(e) => e.stopPropagation()}
          >
            {/* iOS Grabber handle */}
            <div className="ios-grabber" />

            <div className="flex items-center justify-between pb-3.5 border-b border-white/[0.08]">
              <div className="flex items-center gap-2.5">
                <div className="h-9 w-9 rounded-2xl bg-blue-500/15 border border-blue-500/30 grid place-items-center text-blue-400 shadow-md">
                  <Edit3 size={18} />
                </div>
                <div>
                  <h3 className="text-base font-bold text-slate-100">Edit Truck Load</h3>
                  <p className="text-xs text-slate-400">Modify details, quantity and timing</p>
                </div>
              </div>

              <button
                onClick={() => setEditingTripIndex(null)}
                className="h-8 w-8 rounded-full bg-white/[0.06] grid place-items-center text-slate-400 hover:text-slate-200 active:scale-90 transition-all"
              >
                <X size={16} />
              </button>
            </div>

            <form onSubmit={handleSaveEditModal} className="mt-4 space-y-3.5 text-xs">
              {/* Preset Selector */}
              <div>
                <label className="text-[10px] uppercase font-bold text-slate-400 block mb-1.5 tracking-wider">
                  Preset / Destination
                </label>
                <div className="grid grid-cols-4 gap-1.5">
                  {LOADING_PRESETS.map((p) => (
                    <button
                      key={p.key}
                      type="button"
                      onClick={() => handleEditPresetChange(p.key)}
                      className={`py-2 px-1 rounded-xl text-xs font-bold border transition-all text-center truncate ios-press ${
                        editPreset === p.key
                          ? "bg-primary text-white border-primary shadow-md font-black"
                          : "bg-white/[0.04] border-white/[0.08] text-slate-400 hover:text-slate-200"
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
                  <label className="text-[10px] uppercase font-bold text-slate-400 block mb-1.5 tracking-wider">
                    Trip ID
                  </label>
                  <input
                    type="text"
                    value={editTripId}
                    onChange={(e) => setEditTripId(e.target.value)}
                    placeholder="e.g. STOCKS 1"
                    required
                    className="w-full bg-black/30 border border-white/[0.1] rounded-xl px-3 py-2 text-xs font-semibold text-slate-100 outline-none focus:border-primary-glow shadow-inner"
                  />
                </div>

                <div>
                  <label className="text-[10px] uppercase font-bold text-slate-400 block mb-1.5 tracking-wider">
                    Reg Plate
                  </label>
                  <input
                    type="text"
                    value={editReg}
                    onChange={(e) => setEditReg(e.target.value.toUpperCase())}
                    placeholder="e.g. MN05XNGP"
                    className="w-full bg-black/30 border border-white/[0.1] rounded-xl px-3 py-2 text-xs font-mono font-bold uppercase text-slate-100 outline-none focus:border-primary-glow shadow-inner"
                  />
                </div>
              </div>

              {/* Driver & Quantity */}
              <div className="grid grid-cols-2 gap-2.5">
                <div>
                  <label className="text-[10px] uppercase font-bold text-slate-400 block mb-1.5 tracking-wider">
                    Driver Name
                  </label>
                  <input
                    type="text"
                    value={editDriver}
                    onChange={(e) => setEditDriver(e.target.value)}
                    placeholder="e.g. Neil"
                    className="w-full bg-black/30 border border-white/[0.1] rounded-xl px-3 py-2 text-xs font-semibold text-slate-100 outline-none focus:border-primary-glow shadow-inner"
                  />
                </div>

                <div>
                  <label className="text-[10px] uppercase font-bold text-slate-400 block mb-1.5 tracking-wider">
                    Tyres Loaded
                  </label>
                  <div className="flex items-center gap-1.5">
                    <button
                      type="button"
                      onClick={() => setEditQty(Math.max(0, editQty - 1))}
                      className="h-8 w-8 rounded-xl bg-white/[0.06] border border-white/[0.12] text-slate-100 font-black text-sm flex items-center justify-center shrink-0 active:scale-90 shadow-sm"
                    >
                      -
                    </button>
                    <input
                      type="number"
                      min="0"
                      value={editQty}
                      onChange={(e) => setEditQty(Math.max(0, parseInt(e.target.value, 10) || 0))}
                      className="w-full bg-black/30 border border-white/[0.1] rounded-xl px-2 py-1.5 text-sm font-mono font-black text-center text-blue-400 outline-none focus:border-primary-glow shadow-inner"
                    />
                    <button
                      type="button"
                      onClick={() => setEditQty(editQty + 1)}
                      className="h-8 w-8 rounded-xl bg-white/[0.06] border border-white/[0.12] text-slate-100 font-black text-sm flex items-center justify-center shrink-0 active:scale-90 shadow-sm"
                    >
                      +
                    </button>
                  </div>
                </div>
              </div>

              {/* Timings */}
              <div className="grid grid-cols-2 gap-2.5">
                <div>
                  <div className="flex items-center justify-between mb-1.5">
                    <label className="text-[10px] uppercase font-bold text-slate-400 tracking-wider">
                      Start Time
                    </label>
                    {editStartTimeStr && (
                      <button
                        type="button"
                        onClick={() => setEditStartTimeStr("")}
                        className="text-[10px] text-slate-500 hover:text-rose-400 transition-colors"
                      >
                        Clear
                      </button>
                    )}
                  </div>
                  <input
                    type="time"
                    value={editStartTimeStr}
                    onChange={(e) => setEditStartTimeStr(e.target.value)}
                    className="w-full bg-black/30 border border-white/[0.1] rounded-xl px-3 py-2 text-xs font-mono font-bold text-slate-100 outline-none focus:border-primary-glow shadow-inner"
                  />
                </div>

                <div>
                  <div className="flex items-center justify-between mb-1.5">
                    <label className="text-[10px] uppercase font-bold text-slate-400 tracking-wider">
                      Finish Time
                    </label>
                    {editFinishTimeStr && (
                      <button
                        type="button"
                        onClick={() => setEditFinishTimeStr("")}
                        className="text-[10px] text-slate-500 hover:text-rose-400 transition-colors"
                      >
                        Clear
                      </button>
                    )}
                  </div>
                  <input
                    type="time"
                    value={editFinishTimeStr}
                    onChange={(e) => setEditFinishTimeStr(e.target.value)}
                    className="w-full bg-black/30 border border-white/[0.1] rounded-xl px-3 py-2 text-xs font-mono font-bold text-slate-100 outline-none focus:border-primary-glow shadow-inner"
                  />
                </div>
              </div>

              {/* Modal Actions */}
              <div className="flex items-center justify-between gap-2 pt-3 border-t border-white/[0.08] mt-4">
                <button
                  type="button"
                  onClick={() => handleDeleteRow(editingTripIndex)}
                  className="px-3 py-2.5 rounded-xl text-rose-400 hover:bg-rose-500/10 text-xs font-bold flex items-center gap-1.5 ios-press"
                >
                  <Trash2 size={14} /> Delete
                </button>

                <div className="flex items-center gap-2">
                  <button
                    type="button"
                    onClick={() => setEditingTripIndex(null)}
                    className="px-4 py-2.5 rounded-xl bg-white/[0.06] border border-white/[0.12] text-xs font-semibold text-slate-300 hover:bg-white/[0.12] ios-press"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    className="px-5 py-2.5 rounded-xl bg-primary text-white font-bold text-xs hover:bg-primary/90 ios-press shadow-md"
                  >
                    Save Changes
                  </button>
                </div>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ── ADD TRUCK LOAD MODAL (iOS Bottom Sheet) ────────────────────── */}
      {showAddModal && (
        <div
          className="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-0 sm:p-4 bg-black/65 backdrop-blur-md animate-fade-in"
          onClick={() => setShowAddModal(false)}
        >
          <div
            className="w-full max-w-md ios-glass-elevated rounded-t-[2.5rem] sm:rounded-3xl p-6 pb-[max(1.5rem,env(safe-area-inset-bottom))] shadow-2xl animate-sheet-slide-up max-h-[92vh] overflow-y-auto"
            onClick={(e) => e.stopPropagation()}
          >
            {/* iOS Grabber handle */}
            <div className="ios-grabber" />

            <div className="flex items-center justify-between pb-3.5 border-b border-white/[0.08]">
              <div className="flex items-center gap-2.5">
                <div className="h-9 w-9 rounded-2xl bg-blue-500/15 border border-blue-500/30 grid place-items-center text-blue-400 shadow-md">
                  <Truck size={18} />
                </div>
                <div>
                  <h3 className="text-base font-bold text-slate-100">Add Truck Load</h3>
                  <p className="text-xs text-slate-400">Creates a trip on the sheet and daily log</p>
                </div>
              </div>

              <button
                onClick={() => setShowAddModal(false)}
                className="h-8 w-8 rounded-full bg-white/[0.06] grid place-items-center text-slate-400 hover:text-slate-200 active:scale-90 transition-all"
              >
                <X size={16} />
              </button>
            </div>

            <form onSubmit={handleSubmitAddTruck} className="mt-4 space-y-3.5 text-xs">
              {/* Preset Selector */}
              <div>
                <label className="text-[10px] uppercase font-bold text-slate-400 block mb-1.5 tracking-wider">
                  Preset / Destination
                </label>
                <div className="grid grid-cols-4 gap-1.5">
                  {LOADING_PRESETS.map((p) => (
                    <button
                      key={p.key}
                      type="button"
                      onClick={() => handleAddPresetChange(p.key)}
                      className={`py-2 px-1 rounded-xl text-xs font-bold border transition-all text-center truncate ios-press ${
                        addPreset === p.key
                          ? "bg-primary text-white border-primary shadow-md font-black"
                          : "bg-white/[0.04] border-white/[0.08] text-slate-400 hover:text-slate-200"
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
                  <label className="text-[10px] uppercase font-bold text-slate-400 block mb-1.5 tracking-wider">
                    Trip ID
                  </label>
                  <input
                    type="text"
                    value={addTripId}
                    onChange={(e) => setAddTripId(e.target.value)}
                    placeholder="e.g. STOCKS 1"
                    required
                    className="w-full bg-black/30 border border-white/[0.1] rounded-xl px-3 py-2 text-xs font-semibold text-slate-100 outline-none focus:border-primary-glow shadow-inner"
                  />
                </div>

                <div>
                  <label className="text-[10px] uppercase font-bold text-slate-400 block mb-1.5 tracking-wider">
                    Reg Plate
                  </label>
                  <input
                    type="text"
                    value={addReg}
                    onChange={(e) => setAddReg(e.target.value.toUpperCase())}
                    placeholder="e.g. MN05XNGP"
                    className="w-full bg-black/30 border border-white/[0.1] rounded-xl px-3 py-2 text-xs font-mono font-bold uppercase text-slate-100 outline-none focus:border-primary-glow shadow-inner"
                  />
                </div>
              </div>

              {/* Driver & Quantity */}
              <div className="grid grid-cols-2 gap-2.5">
                <div>
                  <label className="text-[10px] uppercase font-bold text-slate-400 block mb-1.5 tracking-wider">
                    Driver Name
                  </label>
                  <input
                    type="text"
                    value={addDriver}
                    onChange={(e) => setAddDriver(e.target.value)}
                    placeholder="e.g. Neil"
                    className="w-full bg-black/30 border border-white/[0.1] rounded-xl px-3 py-2 text-xs font-semibold text-slate-100 outline-none focus:border-primary-glow shadow-inner"
                  />
                </div>

                <div>
                  <label className="text-[10px] uppercase font-bold text-slate-400 block mb-1.5 tracking-wider">
                    Tyres Loaded
                  </label>
                  <div className="flex items-center gap-1.5">
                    <button
                      type="button"
                      onClick={() => setAddQty(Math.max(0, addQty - 1))}
                      className="h-8 w-8 rounded-xl bg-white/[0.06] border border-white/[0.12] text-slate-100 font-black text-sm flex items-center justify-center shrink-0 active:scale-90 shadow-sm"
                    >
                      -
                    </button>
                    <input
                      type="number"
                      min="0"
                      value={addQty}
                      onChange={(e) => setAddQty(Math.max(0, parseInt(e.target.value, 10) || 0))}
                      className="w-full bg-black/30 border border-white/[0.1] rounded-xl px-2 py-1.5 text-sm font-mono font-black text-center text-blue-400 outline-none focus:border-primary-glow shadow-inner"
                    />
                    <button
                      type="button"
                      onClick={() => setAddQty(addQty + 1)}
                      className="h-8 w-8 rounded-xl bg-white/[0.06] border border-white/[0.12] text-slate-100 font-black text-sm flex items-center justify-center shrink-0 active:scale-90 shadow-sm"
                    >
                      +
                    </button>
                  </div>
                </div>
              </div>

              {/* Timings (Optional) */}
              <div className="grid grid-cols-2 gap-2.5">
                <div>
                  <div className="flex items-center justify-between mb-1.5">
                    <label className="text-[10px] uppercase font-bold text-slate-400 tracking-wider">
                      Start Time
                    </label>
                    {addStartTimeStr && (
                      <button
                        type="button"
                        onClick={() => setAddStartTimeStr("")}
                        className="text-[10px] text-slate-500 hover:text-rose-400 transition-colors"
                      >
                        Clear
                      </button>
                    )}
                  </div>
                  <input
                    type="time"
                    value={addStartTimeStr}
                    onChange={(e) => setAddStartTimeStr(e.target.value)}
                    className="w-full bg-black/30 border border-white/[0.1] rounded-xl px-3 py-2 text-xs font-mono font-bold text-slate-100 outline-none focus:border-primary-glow shadow-inner"
                  />
                </div>

                <div>
                  <div className="flex items-center justify-between mb-1.5">
                    <label className="text-[10px] uppercase font-bold text-slate-400 tracking-wider">
                      Finish Time
                    </label>
                    {addFinishTimeStr && (
                      <button
                        type="button"
                        onClick={() => setAddFinishTimeStr("")}
                        className="text-[10px] text-slate-500 hover:text-rose-400 transition-colors"
                      >
                        Clear
                      </button>
                    )}
                  </div>
                  <input
                    type="time"
                    value={addFinishTimeStr}
                    onChange={(e) => setAddFinishTimeStr(e.target.value)}
                    className="w-full bg-black/30 border border-white/[0.1] rounded-xl px-3 py-2 text-xs font-mono font-bold text-slate-100 outline-none focus:border-primary-glow shadow-inner"
                  />
                </div>
              </div>

              {/* Modal Submit & Cancel */}
              <div className="flex items-center justify-end gap-2 pt-3 border-t border-white/[0.08] mt-4">
                <button
                  type="button"
                  onClick={() => setShowAddModal(false)}
                  className="px-4 py-2.5 rounded-xl bg-white/[0.06] border border-white/[0.12] text-xs font-semibold text-slate-300 hover:bg-white/[0.12] ios-press"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-5 py-2.5 rounded-xl bg-primary text-white font-bold text-xs hover:bg-primary/90 ios-press shadow-md flex items-center gap-1.5"
                >
                  <Plus size={14} /> Add Truck Load
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ── REPORT PREVIEW MODAL (iOS Glass Bottom Sheet) ────────────── */}
      {showReportModal && (
        <div
          className="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-0 sm:p-4 bg-black/65 backdrop-blur-md animate-fade-in"
          onClick={() => setShowReportModal(false)}
        >
          <div
            className="w-full max-w-2xl ios-glass-elevated rounded-t-[2.5rem] sm:rounded-3xl p-5 sm:p-6 pb-[max(1.5rem,env(safe-area-inset-bottom))] max-h-[92vh] flex flex-col shadow-2xl animate-sheet-slide-up"
            onClick={(e) => e.stopPropagation()}
          >
            {/* iOS Grabber handle */}
            <div className="ios-grabber" />

            {/* Modal Header */}
            <div className="flex items-center justify-between pb-3.5 border-b border-white/[0.08]">
              <div className="flex items-center gap-2.5">
                <div className="h-9 w-9 rounded-2xl bg-blue-500/15 border border-blue-500/30 grid place-items-center text-blue-400 shadow-md">
                  <FileText size={18} />
                </div>
                <div>
                  <h3 className="text-base font-bold text-slate-100">Despatch Loading Report</h3>
                  <p className="text-xs text-slate-400">
                    {entry.dayKey} · Despatcher: {despatcherName}
                  </p>
                </div>
              </div>

              <button
                onClick={() => setShowReportModal(false)}
                className="h-8 w-8 rounded-full bg-white/[0.06] grid place-items-center text-slate-400 hover:text-slate-200 active:scale-90 transition-all"
              >
                <X size={16} />
              </button>
            </div>

            {/* Scrollable Document Preview Sheet */}
            <div className="flex-1 overflow-y-auto my-3.5 p-4 bg-white text-black rounded-2xl shadow-inner font-sans text-xs">
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
                          {t.startTime ? formatTimeHHmm(t.startTime) : "-"}
                        </td>
                        <td className="border border-black p-1.5 text-center font-mono">
                          {t.finishTime ? formatTimeHHmm(t.finishTime) : "-"}
                        </td>
                        <td className="border border-black p-1.5 text-right font-mono">
                          {t.durationMinutes !== undefined
                            ? `${t.durationMinutes}m`
                            : calculateDurationMinutes(t.startTime, t.finishTime) !== undefined
                              ? `${calculateDurationMinutes(t.startTime, t.finishTime)}m`
                              : "-"}
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
                className="px-4 py-2.5 rounded-xl bg-white/[0.06] border border-white/[0.12] text-xs font-semibold text-slate-300 hover:bg-white/[0.12] ios-press"
              >
                Close
              </button>

              <div className="flex items-center gap-2">
                <button
                  onClick={() => {
                    vibrate("light");
                    handleShareWhatsApp();
                  }}
                  className="inline-flex items-center gap-1.5 px-4 py-2.5 rounded-xl text-xs font-bold bg-emerald-500/15 border border-emerald-500/30 text-emerald-400 hover:bg-emerald-500/25 ios-press shadow-sm"
                >
                  <Share2 size={15} />
                  <span>Share WhatsApp</span>
                </button>

                <button
                  onClick={() => {
                    vibrate("light");
                    handlePrintPDF();
                  }}
                  className="inline-flex items-center gap-1.5 px-5 py-2.5 rounded-xl text-xs font-bold bg-primary text-white hover:bg-primary/90 ios-press shadow-md"
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
