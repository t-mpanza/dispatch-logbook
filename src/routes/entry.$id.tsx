import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { ArrowLeft, Trash2 } from "lucide-react";
import { useEffect, useState } from "react";
import {
  deleteEntry,
  getEntry,
  updateEntry,
  allTags,
} from "@/lib/db";
import type { Attachment, Entry, Trip } from "@/lib/types";
import { CaptureBar } from "@/components/CaptureBar";
import { VoiceRecorder } from "@/components/VoiceRecorder";
import { Lightbox } from "@/components/Lightbox";
import { CounterPanel } from "@/components/CounterPanel";
import { CounterProgress } from "@/components/CounterProgress";
import { EventLog } from "@/components/EventLog";
import { FloatingNoteBar } from "@/components/FloatingNoteBar";
import { TagsInput } from "@/components/TagsInput";
import { fmtDayLabel, fmtTime, uid } from "@/lib/format";

export const Route = createFileRoute("/entry/$id")({
  head: () => ({ meta: [{ title: "Entry — Dispatch Diary" }] }),
  component: EntryPage,
});

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

  useEffect(() => {
    if (entry) {
      setTitle(entry.title);
      setTags(entry.tags);
    }
  }, [entry?.id]);

  if (isLoading) {
    return <div className="p-6 text-sm text-muted-foreground">Loading…</div>;
  }
  if (!entry) {
    return (
      <div className="p-6">
        <p className="text-sm text-muted-foreground">Entry not found.</p>
        <button
          onClick={() => navigate({ to: "/" })}
          className="mt-3 underline text-primary-glow text-sm"
        >
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

  async function addAttachment(a: Attachment) {
    await persist((e) => ({ ...e, attachments: [...e.attachments, a] }));
    setRecording(false);
  }

  async function removeAttachment(aid: string) {
    await persist((e) => ({
      ...e,
      attachments: e.attachments.filter((a) => a.id !== aid),
    }));
  }

  async function addNote(text: string) {
    await persist((e) => ({
      ...e,
      notes: [...e.notes, { id: uid(), text, createdAt: Date.now() }],
    }));
  }

  async function removeNote(nid: string) {
    await persist((e) => ({
      ...e,
      notes: e.notes.filter((n) => n.id !== nid),
    }));
  }

  async function saveHeader() {
    await persist((e) => ({
      ...e,
      title: title.trim() || "Untitled",
      tags,
    }));
  }

  async function onDelete() {
    if (!confirm("Delete this entry permanently?")) return;
    await deleteEntry(entry!.id);
    navigate({ to: "/" });
  }

  const trips = entry.trips ?? [];
  const totalScanned = trips.reduce((n, t) => n + t.count, 0);
  const totalManual = trips.reduce((n, t) => n + (t.rejected ?? 0), 0);
  const grandTotal = totalScanned + totalManual;
  const isCounterSession = Array.isArray(entry.trips);

  return (
    <div className="min-h-screen bg-background max-w-md mx-auto pb-32">
      {/* Sticky header */}
      <header className="sticky top-0 z-30 bg-background/85 backdrop-blur-xl border-b border-border">
        <div className="flex items-center justify-between px-4 py-3">
          <button
            onClick={() => navigate({ to: "/" })}
            className="h-9 w-9 rounded-full grid place-items-center hover:bg-muted active:scale-95"
          >
            <ArrowLeft size={18} />
          </button>
          <span className="text-xs text-muted-foreground">
            {fmtDayLabel(entry.createdAt)} · {fmtTime(entry.createdAt)}
          </span>
          <button
            onClick={onDelete}
            className="h-9 w-9 rounded-full grid place-items-center hover:bg-destructive/20 text-muted-foreground hover:text-destructive active:scale-95"
            aria-label="Delete entry"
          >
            <Trash2 size={16} />
          </button>
        </div>
      </header>

      <div className="px-4 pt-4 space-y-4">
        {/* Title */}
        <input
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          onBlur={saveHeader}
          className="w-full bg-transparent text-xl font-mono uppercase tracking-wider outline-none border-b border-border focus:border-primary py-2"
        />

        {/* Tags */}
        <div className="rounded-xl bg-surface border border-border p-3">
          <TagsInput
            value={tags}
            onChange={(t) => {
              setTags(t);
              persist((e) => ({ ...e, tags: t }));
            }}
            suggestions={tagSuggestions}
          />
        </div>

        {/* Counter session: progress + input strip */}
        {isCounterSession && (
          <>
            <CounterProgress
              total={grandTotal}
              tripCount={trips.length}
              expectedTotal={entry.expectedTotal}
              onSetExpected={(n) =>
                persist((e) => ({ ...e, expectedTotal: n }))
              }
            />
            <CounterPanel
              trips={trips}
              onChange={(next: Trip[]) =>
                persist((e) => ({ ...e, trips: next }))
              }
              onAttachment={addAttachment}
            />
          </>
        )}

        {/* Add counter to standard entry */}
        {!isCounterSession && (
          <button
            onClick={() => persist((e) => ({ ...e, trips: [] }))}
            className="w-full rounded-xl bg-surface border border-dashed border-border py-3 text-sm text-muted-foreground hover:border-primary/50 hover:text-foreground transition-colors"
          >
            + Add tyre counter to this entry
          </button>
        )}

        {/* Capture bar */}
        {recording ? (
          <VoiceRecorder
            onSave={addAttachment}
            onCancel={() => setRecording(false)}
          />
        ) : (
          <CaptureBar
            onAttachment={addAttachment}
            onStartVoice={() => setRecording(true)}
          />
        )}

        {/* Unified event log */}
        <div>
          <h3 className="text-[10px] uppercase tracking-wider text-muted-foreground font-bold mb-3">
            Event Log
          </h3>
          <EventLog
            notes={entry.notes}
            attachments={entry.attachments}
            trips={trips}
            onRemoveNote={removeNote}
            onRemoveAttachment={removeAttachment}
            onRemoveTrip={(tid) =>
              persist((e) => ({
                ...e,
                trips: (e.trips ?? []).filter((t) => t.id !== tid),
              }))
            }
            onOpenImage={(aid) => setLightboxId(aid)}
          />
        </div>
      </div>

      {/* Floating note input */}
      <FloatingNoteBar onAdd={addNote} />

      {/* Lightbox */}
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
