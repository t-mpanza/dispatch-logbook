import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { ArrowLeft, Bell, Trash2 } from "lucide-react";
import { useEffect, useState } from "react";
import {
  addReminder,
  deleteEntry,
  deleteReminder,
  getEntry,
  remindersForEntry,
  updateEntry,
  allTags,
} from "@/lib/db";
import type { Attachment, Entry, Trip } from "@/lib/types";
import { CaptureBar } from "@/components/CaptureBar";
import { VoiceRecorder } from "@/components/VoiceRecorder";
import { AttachmentView } from "@/components/AttachmentView";
import { Lightbox } from "@/components/Lightbox";
import { CounterPanel } from "@/components/CounterPanel";
import { TagsInput } from "@/components/TagsInput";
import { fmtDayLabel, fmtTime, uid } from "@/lib/format";
import { requestNotificationPermission, rescheduleAll } from "@/lib/reminders";

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
  const { data: reminders = [] } = useQuery({
    queryKey: ["reminders", id],
    queryFn: () => remindersForEntry(id),
  });
  const { data: tagSuggestions = [] } = useQuery({ queryKey: ["tags"], queryFn: allTags });

  const [recording, setRecording] = useState(false);
  const [noteDraft, setNoteDraft] = useState("");
  const [showReminder, setShowReminder] = useState(false);
  const [lightboxId, setLightboxId] = useState<string | null>(null);

  // local edit buffer for title/tags
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

  async function addAttachment(a: Attachment) {
    await persist((e) => ({ ...e, attachments: [...e.attachments, a] }));
    setRecording(false);
  }

  async function removeAttachment(aid: string) {
    await persist((e) => ({ ...e, attachments: e.attachments.filter((a) => a.id !== aid) }));
  }

  async function addNote() {
    const text = noteDraft.trim();
    if (!text) return;
    setNoteDraft("");
    await persist((e) => ({
      ...e,
      notes: [...e.notes, { id: uid(), text, createdAt: Date.now() }],
    }));
  }

  async function saveHeader() {
    await persist((e) => ({ ...e, title: title.trim() || "Untitled", tags }));
  }

  async function onDelete() {
    if (!confirm("Delete this entry permanently?")) return;
    await deleteEntry(entry!.id);
    navigate({ to: "/" });
  }

  // Combined timeline: notes + attachments + trips sorted by createdAt
  const timeline = [
    ...entry.notes.map((n) => ({ type: "note" as const, at: n.createdAt, data: n })),
    ...entry.attachments.map((a) => ({ type: "att" as const, at: a.createdAt, data: a })),
    ...(entry.trips || []).map((t) => ({ type: "trip" as const, at: t.createdAt, data: t })),
  ].sort((a, b) => a.at - b.at);

  return (
    <div className="min-h-screen bg-background max-w-md mx-auto pb-6">
      <header className="sticky top-0 z-30 bg-background/85 backdrop-blur-xl border-b border-border">
        <div className="flex items-center justify-between px-4 py-3">
          <button
            onClick={() => navigate({ to: "/" })}
            className="h-9 w-9 rounded-full grid place-items-center hover:bg-muted"
          >
            <ArrowLeft size={18} />
          </button>
          <span className="text-xs text-muted-foreground">
            {fmtDayLabel(entry.createdAt)} · {fmtTime(entry.createdAt)}
          </span>
          <button
            onClick={onDelete}
            className="h-9 w-9 rounded-full grid place-items-center hover:bg-destructive/20 text-muted-foreground hover:text-destructive"
            aria-label="Delete entry"
          >
            <Trash2 size={16} />
          </button>
        </div>
      </header>

      <div className="px-5 pt-4 space-y-5">
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

        {/* Capture bar */}
        {recording ? (
          <VoiceRecorder onSave={addAttachment} onCancel={() => setRecording(false)} />
        ) : (
          <CaptureBar onAttachment={addAttachment} onStartVoice={() => setRecording(true)} />
        )}

        {/* Trip counter */}
        {Array.isArray(entry.trips) ? (
          <CounterPanel
            trips={entry.trips}
            onChange={(next: Trip[]) => persist((e) => ({ ...e, trips: next }))}
            onAttachment={addAttachment}
          />
        ) : (
          <button
            onClick={() => persist((e) => ({ ...e, trips: [] }))}
            className="w-full rounded-xl bg-surface border border-dashed border-border py-3 text-sm text-muted-foreground hover:border-primary/50 hover:text-foreground transition-colors"
          >
            + Add trip counter to this entry
          </button>
        )}

        {/* Quick note input */}
        <div className="rounded-xl bg-surface border border-border p-3">
          <textarea
            value={noteDraft}
            onChange={(e) => setNoteDraft(e.target.value)}
            placeholder="Type a quick note…"
            rows={2}
            className="w-full bg-transparent outline-none text-sm resize-none placeholder:text-muted-foreground"
          />
          <div className="flex justify-end">
            <button
              onClick={addNote}
              disabled={!noteDraft.trim()}
              className="px-4 py-1.5 rounded-full bg-primary text-primary-foreground text-sm font-medium disabled:opacity-40"
            >
              Add note
            </button>
          </div>
        </div>

        {/* Reminders */}
        <div className="rounded-xl bg-surface border border-border p-3">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2 text-sm">
              <Bell size={14} className="text-primary-glow" />
              <span className="font-medium">Reminders</span>
              <span className="text-xs text-muted-foreground">({reminders.length})</span>
            </div>
            <button
              onClick={() => setShowReminder((s) => !s)}
              className="text-xs text-primary-glow"
            >
              {showReminder ? "Cancel" : "+ Add"}
            </button>
          </div>

          {showReminder && (
            <ReminderForm
              entryId={entry.id}
              onCreated={() => {
                setShowReminder(false);
                qc.invalidateQueries({ queryKey: ["reminders", id] });
                void rescheduleAll();
              }}
            />
          )}

          {reminders.length > 0 && (
            <ul className="mt-2 space-y-1.5">
              {reminders
                .sort((a, b) => a.at - b.at)
                .map((r) => (
                  <li
                    key={r.id}
                    className="flex items-center justify-between gap-2 rounded-lg bg-muted/40 px-3 py-2 text-xs"
                  >
                    <div className="min-w-0">
                      <p className={`truncate ${r.done ? "line-through text-muted-foreground" : ""}`}>
                        {r.text}
                      </p>
                      <p className="text-[10px] text-muted-foreground tabular-nums">
                        {new Date(r.at).toLocaleString()}
                      </p>
                    </div>
                    <button
                      onClick={async () => {
                        await deleteReminder(r.id);
                        qc.invalidateQueries({ queryKey: ["reminders", id] });
                      }}
                      className="text-muted-foreground hover:text-destructive"
                    >
                      <Trash2 size={12} />
                    </button>
                  </li>
                ))}
            </ul>
          )}
        </div>

        {/* Timeline */}
        <div>
          <h3 className="text-[11px] uppercase tracking-wider text-muted-foreground font-medium mb-2">
            Timeline
          </h3>
          {timeline.length === 0 ? (
            <p className="text-sm text-muted-foreground">
              Nothing yet. Use the buttons above to add voice, photos, video, files or notes.
            </p>
          ) : (
            <ol className="space-y-3 border-l border-border pl-4">
              {timeline.map((item) => (
                <li key={`${item.type}-${item.data.id}`} className="relative">
                  <span className="absolute -left-[1.3rem] top-1.5 h-2 w-2 rounded-full bg-primary-glow" />
                  <p className="text-[10px] tabular-nums text-muted-foreground mb-1">
                    {fmtTime(item.at)}
                  </p>
                  {item.type === "note" ? (
                    <p className="rounded-xl bg-surface border border-border px-3 py-2 text-sm whitespace-pre-wrap">
                      {item.data.text}
                    </p>
                  ) : item.type === "trip" ? (
                    <div className="rounded-xl bg-surface-elevated border border-primary/20 px-3 py-2.5 text-sm flex items-center justify-between shadow-sm">
                      <div>
                        <div className="flex items-baseline gap-1.5 flex-wrap">
                          {item.data.count > 0 && (
                            <span className="font-bold tabular-nums text-primary-glow">
                              +{item.data.count} Scanned
                            </span>
                          )}
                          {item.data.rejected && item.data.rejected > 0 ? (
                            <span className="font-bold tabular-nums text-orange-400">
                              +{item.data.rejected} Manual
                            </span>
                          ) : null}
                        </div>
                        {item.data.note && (
                          <p className="text-xs text-muted-foreground mt-0.5">{item.data.note}</p>
                        )}
                      </div>
                      <div className="text-[10px] text-muted-foreground uppercase tracking-wider font-bold">
                        Trip
                      </div>
                    </div>
                  ) : (
                    <AttachmentView
                      attachment={item.data}
                      onRemove={() => removeAttachment(item.data.id)}
                      onOpenImage={(a) => setLightboxId(a.id)}
                    />
                  )}
                </li>
              ))}
            </ol>
          )}
        </div>
      </div>

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

function ReminderForm({
  entryId,
  onCreated,
}: {
  entryId: string;
  onCreated: () => void;
}) {
  const [text, setText] = useState("Follow up");
  const [when, setWhen] = useState(() => {
    const d = new Date(Date.now() + 60 * 60 * 1000);
    d.setSeconds(0, 0);
    // datetime-local needs YYYY-MM-DDTHH:mm
    const pad = (n: number) => n.toString().padStart(2, "0");
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
  });

  async function save() {
    await requestNotificationPermission();
    const at = new Date(when).getTime();
    await addReminder({ entryId, at, text: text.trim() || "Reminder" });
    onCreated();
  }

  return (
    <div className="mt-2 space-y-2">
      <input
        value={text}
        onChange={(e) => setText(e.target.value)}
        placeholder="Remind me to…"
        className="w-full rounded-lg bg-muted/40 px-3 py-2 text-sm outline-none border border-border focus:border-primary"
      />
      <input
        type="datetime-local"
        value={when}
        onChange={(e) => setWhen(e.target.value)}
        className="w-full rounded-lg bg-muted/40 px-3 py-2 text-sm outline-none border border-border focus:border-primary"
      />
      <button
        onClick={save}
        className="w-full rounded-lg bg-primary text-primary-foreground py-2 text-sm font-medium"
      >
        Set reminder
      </button>
      <p className="text-[10px] text-muted-foreground">
        Notifications fire only while the app is open. Keep this tab/window alive for them to trigger.
      </p>
    </div>
  );
}
