import { createFileRoute } from "@tanstack/react-router";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { ChevronLeft, ChevronRight, Calendar as CalendarIcon, FileText } from "lucide-react";
import { AppShell } from "@/components/AppShell";
import { LoadingSheet } from "@/components/LoadingSheet";
import { allEntries, updateEntry, createEntry } from "@/lib/db";
import { dayKey, uid } from "@/lib/format";
import { syncTripsToLoadingSheet } from "@/lib/loading-presets";
import type { Entry, LoadingSheetTrip } from "@/lib/types";
import { parseISO, addDays, format } from "date-fns";

export const Route = createFileRoute("/loading-sheet")({
  head: () => ({ meta: [{ title: "Loading Sheet — Dispatch Diary" }] }),
  component: LoadingSheetPage,
});

function LoadingSheetPage() {
  const qc = useQueryClient();
  const [selectedDate, setSelectedDate] = useState<string>(dayKey(Date.now()));

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

  const handleUpdateEntry = async (updatedEntry: Entry) => {
    await updateEntry(updatedEntry);
    qc.invalidateQueries({ queryKey: ["entries"] });
    qc.invalidateQueries({ queryKey: ["entry", updatedEntry.id] });
  };

  const handleCreateTruckLoad = async (tripData: LoadingSheetTrip) => {
    const entryId = uid();
    const now = Date.now();
    const startMs = tripData.startTime || now;
    const finishMs = tripData.finishTime || (startMs + 30 * 60 * 1000);
    const qty = tripData.quantityLoaded || 0;

    const fullTrip: LoadingSheetTrip = {
      ...tripData,
      id: tripData.id || uid(),
      entryId: entryId,
      createdAt: startMs,
    };

    // Create a real Entry for the day so it shows in the daily log and can hold media
    const newEntry: Entry = {
      id: entryId,
      title: fullTrip.tripId || "Truck Load",
      tags: ["truck-load", fullTrip.presetKey?.toLowerCase() || "custom"].filter(Boolean),
      notes: [],
      attachments: [],
      trips: qty > 0 ? [{ id: uid(), count: qty, createdAt: finishMs }] : [],
      loadingSheetTrips: [fullTrip],
      createdAt: startMs,
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
    // 1. If entry already has loadingSheetTrips saved, preserve those user edits (canonical editor)
    const existingAutoTrips = (e.loadingSheetTrips || [])
      .filter((t) => !t.isManual)
      .map((t) => ({ ...t, entryId: t.entryId || e.id }));

    if (existingAutoTrips.length > 0) {
      return [...acc, ...existingAutoTrips];
    }

    // 2. Only if no loadingSheetTrips exist yet, auto-generate initial row from counter trips
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
      {/* ── HEADER ────────────────────────────────────────────────────────── */}
      <header className="px-5 pt-8 pb-4">
        <div className="flex items-center gap-2 text-xs uppercase tracking-[0.2em] text-primary-glow font-medium">
          <FileText size={15} />
          <span>Daily Compliance</span>
        </div>
        <h1 className="mt-1 text-2xl font-bold tracking-tight">Despatch Loading Sheet</h1>
        <p className="mt-1 text-xs text-muted-foreground">
          View, edit, and export all truck loads for any date.
        </p>

        {/* ── DATE SELECTION BAR ────────────────────────────────────────── */}
        <div className="mt-4 flex items-center justify-between bg-surface border border-border rounded-xl p-2 shadow-xs">
          <button
            onClick={() => handleDateChange(-1)}
            className="h-8 w-8 rounded-lg grid place-items-center hover:bg-muted active:scale-95 text-foreground transition-colors"
            title="Previous Day"
          >
            <ChevronLeft size={18} />
          </button>

          <div className="flex items-center gap-2">
            <CalendarIcon size={15} className="text-primary-glow" />
            <input
              type="date"
              value={selectedDate}
              onChange={(e) => e.target.value && setSelectedDate(e.target.value)}
              className="bg-transparent text-sm font-semibold font-mono outline-none text-foreground cursor-pointer"
            />
            {selectedDate === dayKey(Date.now()) && (
              <span className="text-[10px] uppercase font-bold bg-primary/20 text-primary-glow px-2 py-0.5 rounded-full">
                Today
              </span>
            )}
          </div>

          <button
            onClick={() => handleDateChange(1)}
            className="h-8 w-8 rounded-lg grid place-items-center hover:bg-muted active:scale-95 text-foreground transition-colors"
            title="Next Day"
          >
            <ChevronRight size={18} />
          </button>
        </div>
      </header>

      {/* ── MAIN CONTENT ─────────────────────────────────────────────────── */}
      <div className="px-5 pb-20">
        {isLoading ? (
          <p className="text-sm text-muted-foreground py-6 text-center">Loading daily sheet…</p>
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
    </AppShell>
  );
}
