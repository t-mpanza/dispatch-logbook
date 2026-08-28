import { createFileRoute } from "@tanstack/react-router";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useState, useRef } from "react";
import { ChevronLeft, ChevronRight, Calendar as CalendarIcon, FileText } from "lucide-react";
import { AppShell } from "@/components/AppShell";
import { LoadingSheet } from "@/components/LoadingSheet";
import { PullToRefresh } from "@/components/PullToRefresh";
import { allEntries, updateEntry } from "@/lib/db";
import { dayKey, uid } from "@/lib/format";
import { syncTripsToLoadingSheet, calculateDurationMinutes } from "@/lib/loading-presets";
import { syncNow } from "@/lib/sync";
import type { Entry, LoadingSheetTrip } from "@/lib/types";
import { parseISO, addDays, format } from "date-fns";
import { vibrate } from "@/lib/haptics";

export const Route = createFileRoute("/loading-sheet")({
  head: () => ({ meta: [{ title: "Loading Sheet — Dispatch Diary" }] }),
  component: LoadingSheetPage,
});

function LoadingSheetPage() {
  const qc = useQueryClient();
  const [selectedDate, setSelectedDate] = useState<string>(dayKey(Date.now()));

  const touchStartX = useRef(0);
  const touchStartY = useRef(0);

  const { data: entries = [], isLoading } = useQuery({
    queryKey: ["entries", "all"],
    queryFn: allEntries,
  });

  // Find all entries logged on the selected date
  const dayEntries = entries.filter((e) => e.dayKey === selectedDate);
  const primaryEntry = dayEntries.find((e) => (e.loadingSheetTrips && e.loadingSheetTrips.length > 0) || (e.trips && e.trips.length > 0)) || dayEntries[0];

  const handleDateChange = (offsetDays: number) => {
    try {
      const parsed = parseISO(selectedDate);
      const nextDate = addDays(parsed, offsetDays);
      setSelectedDate(format(nextDate, "yyyy-MM-dd"));
    } catch {
      setSelectedDate(dayKey(Date.now()));
    }
  };

  const handleDateTouchStart = (e: React.TouchEvent) => {
    touchStartX.current = e.touches[0].clientX;
    touchStartY.current = e.touches[0].clientY;
  };

  const handleDateTouchEnd = (e: React.TouchEvent) => {
    const deltaX = e.changedTouches[0].clientX - touchStartX.current;
    const deltaY = e.changedTouches[0].clientY - touchStartY.current;

    // Swipe horizontally with minimum 45px displacement and mostly horizontal
    if (Math.abs(deltaX) > 45 && Math.abs(deltaX) > Math.abs(deltaY) * 1.5) {
      if (deltaX < 0) {
        // Swiped Left -> Next day
        vibrate("light");
        handleDateChange(1);
      } else {
        // Swiped Right -> Previous day
        vibrate("light");
        handleDateChange(-1);
      }
    }
  };

  const handleUpdateEntry = async (updatedEntry: Entry) => {
    await updateEntry(updatedEntry);
    qc.invalidateQueries({ queryKey: ["entries"] });
    qc.invalidateQueries({ queryKey: ["entry", updatedEntry.id] });
  };

  const handleCreateTruckLoad = async (tripData: LoadingSheetTrip) => {
    const entryId = uid();
    const now = Date.now();
    const startMs = tripData.startTime;
    const finishMs = tripData.finishTime;
    const duration = (startMs && finishMs) ? calculateDurationMinutes(startMs, finishMs) : undefined;
    const qty = tripData.quantityLoaded || 0;

    const fullTrip: LoadingSheetTrip = {
      ...tripData,
      id: tripData.id || uid(),
      entryId: entryId,
      startTime: startMs,
      finishTime: finishMs,
      durationMinutes: duration,
      createdAt: startMs || now,
    };

    const newEntry: Entry = {
      id: entryId,
      title: fullTrip.tripId || "Truck Load",
      tags: ["truck-load", fullTrip.presetKey?.toLowerCase() || "custom"].filter(Boolean),
      notes: [],
      attachments: [],
      trips: qty > 0 ? [{ id: uid(), count: qty, createdAt: finishMs || startMs || now }] : [],
      loadingSheetTrips: [fullTrip],
      createdAt: startMs || now,
      updatedAt: now,
      dayKey: selectedDate,
      monthKey: selectedDate.slice(0, 7),
      yearKey: selectedDate.slice(0, 4),
    };

    await updateEntry(newEntry);
    qc.invalidateQueries({ queryKey: ["entries"] });
    qc.invalidateQueries({ queryKey: ["entry", entryId] });
  };

  // Build unified loading sheet trips for the selected date
  const autoTrips: LoadingSheetTrip[] = dayEntries.reduce((acc, e) => {
    const existingAutoTrips = (e.loadingSheetTrips || [])
      .filter((t) => !t.isManual)
      .map((t) => ({ ...t, entryId: t.entryId || e.id }));

    if (existingAutoTrips.length > 0) {
      return [...acc, ...existingAutoTrips];
    }

    if (Array.isArray(e.trips) && e.trips.length > 0) {
      const synced = syncTripsToLoadingSheet(e, e.trips);
      return [
        ...acc,
        ...synced
          .filter((t) => !t.isManual)
          .map((t) => ({ ...t, entryId: e.id })),
      ];
    }
    return acc;
  }, [] as LoadingSheetTrip[]);

  const manualTrips = dayEntries.flatMap(
    (e) => (e.loadingSheetTrips?.filter((t) => t.isManual) || []).map((t) => ({ ...t, entryId: t.entryId || e.id }))
  );
  const combinedTrips = [...autoTrips.sort((a, b) => (a.startTime || 0) - (b.startTime || 0)), ...manualTrips];

  const combinedEntry: Entry = primaryEntry ? {
    ...primaryEntry,
    dayKey: selectedDate,
    loadingSheetTrips: combinedTrips,
  } : {
    id: `temp-${selectedDate}`,
    title: `DESPATCH LOADING SHEET - ${selectedDate}`,
    tags: ["loading-sheet"],
    notes: [],
    attachments: [],
    loadingSheetTrips: combinedTrips,
    createdAt: parseISO(selectedDate).getTime() || Date.now(),
    updatedAt: Date.now(),
    dayKey: selectedDate,
    monthKey: selectedDate.slice(0, 7),
    yearKey: selectedDate.slice(0, 4),
  };

  return (
    <AppShell>
      <PullToRefresh onRefresh={async () => { await syncNow(qc); }}>
        {/* ── HEADER ────────────────────────────────────────────────────────── */}
        <header className="px-5 pt-[max(2.25rem,env(safe-area-inset-top))] pb-3">
          <div className="flex items-center gap-1.5 text-[11px] uppercase tracking-[0.2em] text-primary-glow font-bold">
            <FileText size={14} />
            <span>Daily Compliance</span>
          </div>
          <h1 className="mt-0.5 text-3xl font-extrabold tracking-tight text-slate-100 font-sans">Despatch Loading Sheet</h1>
          <p className="mt-1 text-xs text-slate-400 font-medium">
            Swipe left/right to change date, edit, or export truck loads.
          </p>

          {/* ── iOS Glass Date Selection Bar with Swipe Gestures ─────────── */}
          <div
            onTouchStart={handleDateTouchStart}
            onTouchEnd={handleDateTouchEnd}
            className="mt-3.5 flex items-center justify-between ios-glass p-2 rounded-2xl shadow-lg select-none"
          >
            <button
              onClick={() => {
                vibrate("light");
                handleDateChange(-1);
              }}
              className="h-8 w-8 rounded-xl bg-white/[0.06] border border-white/[0.1] grid place-items-center hover:bg-white/[0.12] active:scale-90 text-slate-100 transition-all"
              title="Previous Day (or swipe right)"
            >
              <ChevronLeft size={18} />
            </button>

            <div className="flex items-center gap-2">
              <CalendarIcon size={15} className="text-primary-glow" />
              <input
                type="date"
                value={selectedDate}
                onChange={(e) => e.target.value && setSelectedDate(e.target.value)}
                className="bg-transparent text-xs font-bold font-mono outline-none text-slate-100 cursor-pointer"
              />
              {selectedDate === dayKey(Date.now()) && (
                <span className="text-[10px] uppercase font-bold bg-blue-500/15 border border-blue-500/30 text-blue-400 px-2 py-0.5 rounded-full font-mono">
                  Today
                </span>
              )}
            </div>

            <button
              onClick={() => {
                vibrate("light");
                handleDateChange(1);
              }}
              className="h-8 w-8 rounded-xl bg-white/[0.06] border border-white/[0.1] grid place-items-center hover:bg-white/[0.12] active:scale-90 text-slate-100 transition-all"
              title="Next Day (or swipe left)"
            >
              <ChevronRight size={18} />
            </button>
          </div>
        </header>

        {/* ── MAIN CONTENT ─────────────────────────────────────────────────── */}
        <div className="px-5 pb-20">
          {isLoading ? (
            <p className="text-xs text-slate-500 py-8 text-center font-mono">Loading daily sheet…</p>
          ) : (
            <div className="space-y-4">
              <LoadingSheet
                entry={combinedEntry}
                onCreateTruckLoad={handleCreateTruckLoad}
                onUpdateEntry={async (updated) => {
                  const updatedTrips = updated.loadingSheetTrips ?? [];
                  const newManualTrips = updatedTrips.filter(t => t.isManual);
                  
                  if (!primaryEntry) {
                    return;
                  }
                  
                  // Distribute updated trips back to their owning entries
                  for (const e of dayEntries) {
                    const entryTrips = updatedTrips.filter(t => t.entryId === e.id && !t.isManual);
                    const tripsToSave = e.id === primaryEntry.id ? [...entryTrips, ...newManualTrips] : entryTrips;
                    
                    if (JSON.stringify(e.loadingSheetTrips || []) !== JSON.stringify(tripsToSave)) {
                      await handleUpdateEntry({ ...e, loadingSheetTrips: tripsToSave });
                    }
                  }
                }}
              />
            </div>
          )}
        </div>
      </PullToRefresh>
    </AppShell>
  );
}
