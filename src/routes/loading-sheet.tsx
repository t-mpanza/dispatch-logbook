import { createFileRoute } from "@tanstack/react-router";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { ChevronLeft, ChevronRight, Calendar as CalendarIcon, FileText } from "lucide-react";
import { AppShell } from "@/components/AppShell";
import { LoadingSheet } from "@/components/LoadingSheet";
import { allEntries, updateEntry, createEntry } from "@/lib/db";
import { dayKey } from "@/lib/format";
import type { Entry } from "@/lib/types";
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

  const dayEntries = entries.filter((e) => e.dayKey === selectedDate);
  const primaryEntry = dayEntries.find((e) => Array.isArray(e.loadingSheetTrips) || Array.isArray(e.trips)) || dayEntries[0];

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

  const handleCreateDailySheet = async () => {
    const newEntry = await createEntry({
      title: `DESPATCH LOADING SHEET - ${selectedDate}`,
      tags: ["loading-sheet", "compliance"],
      withCounter: true,
    });
    await updateEntry({
      ...newEntry,
      dayKey: selectedDate,
      loadingSheetTrips: [],
    });
    qc.invalidateQueries({ queryKey: ["entries"] });
  };

  const combinedEntry: Entry = primaryEntry ? {
    ...primaryEntry,
    dayKey: selectedDate,
    loadingSheetTrips: dayEntries.reduce((acc, e) => {
      const trips = e.loadingSheetTrips ?? [];
      return [...acc, ...trips];
    }, [] as any[]),
  } : {
    id: `temp-${selectedDate}`,
    title: `DESPATCH LOADING SHEET - ${selectedDate}`,
    tags: ["loading-sheet"],
    notes: [],
    attachments: [],
    loadingSheetTrips: [],
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
              onUpdateEntry={async (updated) => {
                if (!primaryEntry) {
                  await handleCreateDailySheet();
                } else {
                  await handleUpdateEntry({
                    ...primaryEntry,
                    loadingSheetTrips: updated.loadingSheetTrips,
                  });
                }
              }}
            />
          </div>
        )}
      </div>
    </AppShell>
  );
}
