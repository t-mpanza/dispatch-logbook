import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { ArrowLeft, ChevronDown, ChevronUp, Trash2 } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { deleteEntry, getEntry, updateEntry, allTags } from "@/lib/db";
import type { Attachment, Entry, Trip } from "@/lib/types";
import { CaptureBar } from "@/components/CaptureBar";
import { VoiceRecorder } from "@/components/VoiceRecorder";
import { Lightbox } from "@/components/Lightbox";
import { CounterPanel } from "@/components/CounterPanel";
import { CounterProgress } from "@/components/CounterProgress";
import { EventLog } from "@/components/EventLog";
import { FloatingNoteBar } from "@/components/FloatingNoteBar";
import { TagsInput } from "@/components/TagsInput";

import { syncTripsToLoadingSheet } from "@/lib/loading-presets";
import { fmtDayLabel, fmtTime, uid } from "@/lib/format";

export const Route = createFileRoute("/entry/$id")({
  head: () => ({ meta: [{ title: "Entry — Dispatch Diary" }] }),
  component: EntryPage,
});

function TripDetailsSection({ entry, onUpdate }: { entry: Entry, onUpdate: (reg: string, driver: string) => void }) {
  const [open, setOpen] = useState(false);
  const sheetTrip = entry.loadingSheetTrips?.find(t => !t.isManual);
  const [reg, setReg] = useState(sheetTrip?.reg || "");
  const [driver, setDriver] = useState(sheetTrip?.driverName || "");
  
  useEffect(() => {
    setReg(sheetTrip?.reg || "");
    setDriver(sheetTrip?.driverName || "");
  }, [sheetTrip?.reg, sheetTrip?.driverName]);

  return (
    <div className="mt-3 pt-3 border-t border-white/[0.08]">
      <button 
        onClick={() => setOpen(!open)}
        className="flex items-center gap-2 text-xs font-semibold text-white/50 hover:text-white w-full transition-colors ios-press py-1"
      >
        <span className="flex-1 text-left uppercase tracking-widest text-[10px] font-bold">Trip Details</span>
        <span className="font-mono text-xs text-white/80 font-bold">{entry.title || "NLS"}</span>
        {open ? <ChevronUp size={14} className="text-white/60" /> : <ChevronDown size={14} className="text-white/60" />}
      </button>
      
      {open && (
        <div className="mt-3 space-y-3 animate-fade-in-scale">
          <div>
            <label className="text-[10px] uppercase font-bold text-white/50 block mb-1 tracking-wider">Registration (Reg)</label>
            <input 
              value={reg} 
              onChange={e => setReg(e.target.value.toUpperCase())}
              onBlur={() => onUpdate(reg, driver)}
              placeholder="e.g. MN05XNGP"
              className="w-full bg-black/30 border border-white/[0.12] rounded-xl px-3 py-2 text-xs font-mono font-bold uppercase text-white outline-none focus:border-primary-glow shadow-inner"
            />
          </div>
          <div>
            <label className="text-[10px] uppercase font-bold text-white/50 block mb-1 tracking-wider">Driver Name</label>
            <input 
              value={driver} 
              onChange={e => setDriver(e.target.value)}
              onBlur={() => onUpdate(reg, driver)}
              placeholder="e.g. Neil"
              className="w-full bg-black/30 border border-white/[0.12] rounded-xl px-3 py-2 text-xs font-semibold text-white outline-none focus:border-primary-glow shadow-inner"
            />
          </div>
        </div>
      )}
    </div>
  );
}


function EntryPage() {
  const { id } = Route.useParams();
  const navigate = useNavigate();
  const qc = useQueryClient();
  const { data: entry, isLoading } = useQuery({
    queryKey: ["entry", id],
    queryFn: () => getEntry(id),
  });
  const { data: tagSuggestions = [] } = useQuery({
    queryKey: ["tags"],
    queryFn: allTags,
  });

  const [recording, setRecording] = useState(false);
  const [lightboxId, setLightboxId] = useState<string | null>(null);
  const [title, setTitle] = useState("");
  const [tags, setTags] = useState<string[]>([]);
  const [detailsOpen, setDetailsOpen] = useState(false);

  const scrollRef = useRef<HTMLDivElement>(null);
  const itemsCount =
    (entry?.notes?.length ?? 0) +
    (entry?.attachments?.length ?? 0) +
    (entry?.trips?.length ?? 0) +
    (entry?.loadingSheetTrips?.length ?? 0);
  const prevCount = useRef(itemsCount);

  useEffect(() => {
    if (entry) {
      setTitle(entry.title);
      setTags(entry.tags);
    }
  }, [entry?.id]);

  useEffect(() => {
    if (scrollRef.current) {
      const isFirstLoad = prevCount.current === 0 && itemsCount > 0;
      setTimeout(() => {
        scrollRef.current?.scrollIntoView({
          behavior: isFirstLoad ? "auto" : "smooth",
          block: "end",
        });
      }, 50);
      prevCount.current = itemsCount;
    }
  }, [itemsCount]);

  if (isLoading) return <div className="p-6 text-sm text-muted-foreground">Loading…</div>;
  if (!entry) {
    return (
      <div className="p-6">
        <p className="text-sm text-muted-foreground">Entry not found.</p>
        <button onClick={() => navigate({ to: "/" })} className="mt-3 underline text-primary-glow text-sm">
          Back to today
        </button>
      </div>
    );
  }

  async function persist(updater: (e: Entry) => Entry) {
    if (!entry) return;
    const next = updater({ ...entry });
    await updateEntry(next);
    qc.invalidateQueries({ queryKey: ["entry", id] });
    qc.invalidateQueries({ queryKey: ["entries"] });
    qc.invalidateQueries({ queryKey: ["tags"] });
  }

  async function handleUpdateEntry(updatedEntry: Entry) {
    await updateEntry(updatedEntry);
    qc.invalidateQueries({ queryKey: ["entry", id] });
    qc.invalidateQueries({ queryKey: ["entries"] });
    qc.invalidateQueries({ queryKey: ["tags"] });
  }

  async function addAttachment(a: Attachment) {
    await persist((e) => ({ ...e, attachments: [...e.attachments, a] }));
    setRecording(false);
  }

  async function removeAttachment(aid: string) {
    await persist((e) => ({ ...e, attachments: e.attachments.filter((a) => a.id !== aid) }));
  }

  async function addNote(text: string) {
    await persist((e) => ({ ...e, notes: [...e.notes, { id: uid(), text, createdAt: Date.now() }] }));
  }

  async function removeNote(nid: string) {
    await persist((e) => ({ ...e, notes: e.notes.filter((n) => n.id !== nid) }));
  }

  async function saveHeader() {
    await persist((e) => ({ ...e, title: title.trim() || "Untitled", tags }));
  }

  async function onDelete() {
    if (!confirm("Delete this entry permanently?")) return;
    await deleteEntry(entry!.id);
    navigate({ to: "/" });
  }

  const isCounterSession =
    Array.isArray(entry.trips) || Array.isArray(entry.loadingSheetTrips);
  const trips = entry.trips ?? [];
  const totalScanned = trips.reduce((n, t) => n + t.count, 0);
  const totalManual = trips.reduce((n, t) => n + (t.rejected ?? 0), 0);
  const grandTotal = totalScanned + totalManual;

  async function handleCounterChange(nextTrips: Trip[]) {
    await persist((e) => {
      const updatedSheetTrips = syncTripsToLoadingSheet(e, nextTrips);
      return {
        ...e,
        trips: nextTrips,
        loadingSheetTrips: updatedSheetTrips,
      };
    });
  }

  return (
    <div className="min-h-screen bg-transparent max-w-4xl mx-auto pb-28">
      {/* ── Header ─────────────────────────────────── */}
      <header className="sticky top-0 z-30 ios-glass border-b border-white/[0.1] pt-[env(safe-area-inset-top)] shadow-md">
        <div className="flex items-center gap-3 px-4 py-3">
          <button
            onClick={() => navigate({ to: "/" })}
            className="h-9 w-9 rounded-full bg-white/[0.06] border border-white/[0.1] grid place-items-center hover:bg-white/[0.12] ios-press shrink-0 text-white"
          >
            <ArrowLeft size={18} />
          </button>

          <div className="flex-1 min-w-0">
            <input
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              onBlur={saveHeader}
              className="w-full bg-transparent text-sm font-mono font-bold uppercase tracking-wider outline-none truncate text-white"
            />
            <p className="text-[10px] text-white/50 tabular-nums">
              {fmtDayLabel(entry.createdAt)} · {fmtTime(entry.createdAt)}
            </p>
          </div>

          {isCounterSession && (
            <button
              onClick={() => setDetailsOpen((o) => !o)}
              className="h-8 w-8 rounded-full bg-white/[0.06] border border-white/[0.1] grid place-items-center text-white/60 hover:text-white ios-press"
              aria-label="Toggle details"
            >
              {detailsOpen ? <ChevronUp size={16} /> : <ChevronDown size={16} />}
            </button>
          )}

          <button
            onClick={onDelete}
            className="h-9 w-9 rounded-full bg-rose-500/10 border border-rose-500/20 grid place-items-center text-rose-400 hover:bg-rose-500/20 ios-press shrink-0"
            aria-label="Delete entry"
          >
            <Trash2 size={16} />
          </button>
        </div>

        {/* Collapsible tags */}
        {(!isCounterSession || detailsOpen) && (
          <div className="px-4 pb-3">
            <TagsInput
              value={tags}
              onChange={(t) => {
                setTags(t);
                persist((e) => ({ ...e, tags: t }));
              }}
              suggestions={tagSuggestions}
            />
          </div>
        )}
      </header>

      {/* ── Scrollable content ─────────────────────────────── */}
      <div className="px-4 pt-4 space-y-4">
        {/* Counter Progress & Scanned Tyre Counter Zone */}
        {isCounterSession && (
          <div className="ios-glass-card p-3 sm:p-4 space-y-3 shadow-xl">
            <CounterProgress
              total={grandTotal}
              tripCount={trips.length}
              expectedTotal={entry.expectedTotal}
              onSetExpected={(n) => persist((e) => ({ ...e, expectedTotal: n }))}
            />
            <CounterPanel
              trips={trips}
              onChange={handleCounterChange}
              onAttachment={addAttachment}
            />
            <TripDetailsSection 
              entry={entry}
              onUpdate={(reg, driverName) => persist((e) => {
                const sheetTrips = e.loadingSheetTrips ?? [];
                const idx = sheetTrips.findIndex(t => !t.isManual);
                if (idx >= 0) {
                  const updated = [...sheetTrips];
                  updated[idx] = { ...updated[idx], reg, driverName };
                  return { ...e, loadingSheetTrips: updated };
                }
                return e;
              })}
            />
          </div>
        )}



        {/* Add counter (standard entries only) */}
        {!isCounterSession && (
          <button
            onClick={() => persist((e) => ({ ...e, trips: [], loadingSheetTrips: [] }))}
            className="w-full rounded-xl bg-surface border border-dashed border-border py-3 text-sm text-muted-foreground hover:border-primary/50 hover:text-foreground transition-colors"
          >
            + Add tyre counter & loading sheet to this entry
          </button>
        )}

        {/* Voice recording UI */}
        {recording && <VoiceRecorder onSave={addAttachment} onCancel={() => setRecording(false)} />}

        {/* Event log */}
        <div>
          <p className="text-[10px] uppercase tracking-widest font-bold text-muted-foreground mb-3">
            Event Log
          </p>
          <EventLog
            notes={entry.notes}
            attachments={entry.attachments}
            trips={trips}
            onRemoveNote={removeNote}
            onRemoveAttachment={removeAttachment}
            onRemoveTrip={(tid) =>
              persist((e) => {
                const nextTrips = (e.trips ?? []).filter((t) => t.id !== tid);
                const updatedSheetTrips = syncTripsToLoadingSheet(e, nextTrips);
                return { ...e, trips: nextTrips, loadingSheetTrips: updatedSheetTrips };
              })
            }
            onOpenImage={(aid) => setLightboxId(aid)}
          />
        </div>

        {/* Invisible anchor for auto-scroll */}
        <div ref={scrollRef} className="h-4" />
      </div>

      {/* ── Floating note input at the bottom ──────────── */}
      <FloatingNoteBar
        onAdd={addNote}
        onAttachment={addAttachment}
        onStartVoice={() => setRecording(true)}
      />

      {lightboxId && (
        <Lightbox
          attachments={entry.attachments}
          startId={lightboxId}
          onClose={() => setLightboxId(null)}
        />
      )}
    </div>
  );
}
