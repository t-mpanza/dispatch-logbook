import { useMemo } from "react";
import { Trash2 } from "lucide-react";
import type { Attachment, NoteBlock, Trip } from "@/lib/types";
import { AttachmentView } from "./AttachmentView";
import { fmtTime } from "@/lib/format";

// ─── Types ────────────────────────────────────────────────────────────────────

type TripGroup = { type: "trip-group"; trips: Trip[]; at: number };
type NoteItem = { type: "note"; data: NoteBlock; at: number };
type AttItem = { type: "att"; data: Attachment; at: number };
type LogItem = TripGroup | NoteItem | AttItem;

// ─── Log builder ──────────────────────────────────────────────────────────────

function buildLog(
  notes: NoteBlock[],
  attachments: Attachment[],
  trips: Trip[],
): LogItem[] {
  const raw = [
    ...notes.map((n) => ({ type: "note" as const, at: n.createdAt, data: n })),
    ...attachments.map((a) => ({
      type: "att" as const,
      at: a.createdAt,
      data: a,
    })),
    ...trips.map((t) => ({ type: "trip" as const, at: t.createdAt, data: t })),
  ].sort((a, b) => a.at - b.at);

  const result: LogItem[] = [];
  for (const item of raw) {
    if (item.type === "trip") {
      const last = result[result.length - 1];
      if (last?.type === "trip-group") {
        last.trips.push(item.data as Trip);
      } else {
        result.push({ type: "trip-group", trips: [item.data as Trip], at: item.at });
      }
    } else if (item.type === "note") {
      result.push({ type: "note", data: item.data as NoteBlock, at: item.at });
    } else {
      result.push({ type: "att", data: item.data as Attachment, at: item.at });
    }
  }
  return result;
}

// ─── Slip note parser ─────────────────────────────────────────────────────────

function parseSlipNote(note?: string): { photoId?: string; text?: string } {
  if (!note) return {};
  if (note.startsWith("slip:photo:")) return { photoId: note.slice(11) };
  if (note.startsWith("slip:text:")) return { text: note.slice(10) };
  return { text: note };
}

// ─── Main component ───────────────────────────────────────────────────────────

interface Props {
  notes: NoteBlock[];
  attachments: Attachment[];
  trips: Trip[];
  onRemoveNote: (id: string) => void;
  onRemoveAttachment: (id: string) => void;
  onRemoveTrip: (id: string) => void;
  onOpenImage: (id: string) => void;
}

export function EventLog({
  notes,
  attachments,
  trips,
  onRemoveNote,
  onRemoveAttachment,
  onRemoveTrip,
  onOpenImage,
}: Props) {
  const items = useMemo(
    () => buildLog(notes, attachments, trips),
    [notes, attachments, trips],
  );

  if (items.length === 0) {
    return (
      <p className="py-6 text-center text-sm text-muted-foreground">
        Nothing logged yet. Use the buttons above to add media, voice or notes.
      </p>
    );
  }

  return (
    <div className="space-y-3">
      {items.map((item, idx) => {
        if (item.type === "trip-group") {
          return (
            <TripGroupRow
              key={`tg-${item.at}-${idx}`}
              trips={item.trips}
              attachments={attachments}
              onRemove={onRemoveTrip}
            />
          );
        }
        if (item.type === "note") {
          return (
            <NoteRow
              key={item.data.id}
              note={item.data}
              onRemove={() => onRemoveNote(item.data.id)}
            />
          );
        }
        return (
          <AttachmentView
            key={item.data.id}
            attachment={item.data}
            onRemove={() => onRemoveAttachment(item.data.id)}
            onOpenImage={(a) => onOpenImage(a.id)}
          />
        );
      })}
    </div>
  );
}

// ─── Trip group ───────────────────────────────────────────────────────────────

function TripGroupRow({
  trips,
  attachments,
  onRemove,
}: {
  trips: Trip[];
  attachments: Attachment[];
  onRemove: (id: string) => void;
}) {
  return (
    <div className="flex flex-wrap items-center gap-x-1.5 gap-y-2 py-1">
      {trips.map((t, i) => (
        <span key={t.id} className="contents">
          {i > 0 && (
            <span className="text-[10px] font-bold text-muted-foreground/30">
              ─
            </span>
          )}
          <TripChip trip={t} attachments={attachments} onRemove={onRemove} />
        </span>
      ))}
    </div>
  );
}

function TripChip({
  trip,
  attachments,
  onRemove,
}: {
  trip: Trip;
  attachments: Attachment[];
  onRemove: (id: string) => void;
}) {
  const isScanned = trip.count > 0;
  const isManual = (trip.rejected ?? 0) > 0;
  const { photoId, text: slipText } = parseSlipNote(trip.note);
  const hasSlipPhoto = photoId
    ? attachments.some((a) => a.id === photoId)
    : false;

  const colorCls = isScanned
    ? "bg-primary/10 text-primary-glow border-primary/30"
    : "bg-orange-500/10 text-orange-400 border-orange-500/30";

  return (
    <div className="group flex items-center gap-1">
      <div
        className={`flex items-center gap-1 rounded-full border py-1 pl-2.5 pr-1.5 text-sm font-bold transition-all ${colorCls}`}
      >
        <span>
          {isScanned && `+${trip.count}`}
          {isManual && `+${trip.rejected}`}
        </span>
        {hasSlipPhoto && (
          <span className="text-[10px] opacity-60">📷</span>
        )}
        {slipText && !hasSlipPhoto && (
          <span className="max-w-[72px] truncate text-[10px] font-normal opacity-60">
            {slipText}
          </span>
        )}
        <button
          onClick={() => onRemove(trip.id)}
          className="ml-0.5 opacity-0 transition-opacity group-hover:opacity-100 text-muted-foreground hover:text-destructive"
          aria-label="Remove log"
        >
          <Trash2 size={11} />
        </button>
      </div>
      <span className="text-[10px] tabular-nums text-muted-foreground/40">
        {fmtTime(trip.createdAt)}
      </span>
    </div>
  );
}

// ─── Note row ─────────────────────────────────────────────────────────────────

function NoteRow({
  note,
  onRemove,
}: {
  note: NoteBlock;
  onRemove: () => void;
}) {
  return (
    <div className="group flex items-start gap-2">
      <p className="flex-1 rounded-xl border border-border bg-surface px-3 py-2 text-sm whitespace-pre-wrap">
        {note.text}
      </p>
      <button
        onClick={onRemove}
        className="mt-1 h-8 w-8 shrink-0 rounded-lg grid place-items-center text-muted-foreground/40 opacity-0 transition-all group-hover:opacity-100 hover:bg-destructive/10 hover:text-destructive"
        aria-label="Remove note"
      >
        <Trash2 size={14} />
      </button>
    </div>
  );
}
