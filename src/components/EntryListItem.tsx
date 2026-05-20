import { Link } from "@tanstack/react-router";
import { Image as ImageIcon, Mic, Paperclip, Truck, Video } from "lucide-react";
import type { Entry } from "@/lib/types";
import { fmtTime } from "@/lib/format";

export function EntryListItem({ entry }: { entry: Entry }) {
  const counts = {
    audio: entry.attachments.filter((a) => a.kind === "audio").length,
    image: entry.attachments.filter((a) => a.kind === "image").length,
    video: entry.attachments.filter((a) => a.kind === "video").length,
    file: entry.attachments.filter((a) => a.kind === "file").length,
  };
  const trips = entry.trips;
  const tripTotal = trips?.reduce((n, t) => n + t.count, 0) ?? 0;

  const preview = entry.notes[0]?.text;

  return (
    <Link
      to="/entry/$id"
      params={{ id: entry.id }}
      className="block rounded-xl bg-surface border border-border p-4 hover:border-primary/40 transition-colors"
    >
      <div className="flex items-start justify-between gap-3">
        <h3 className="font-mono text-sm font-semibold tracking-wider uppercase text-foreground truncate">
          {entry.title}
        </h3>
        <span className="text-xs text-muted-foreground shrink-0 tabular-nums">
          {fmtTime(entry.createdAt)}
        </span>
      </div>
      {preview && (
        <p className="mt-1.5 text-sm text-muted-foreground line-clamp-2">{preview}</p>
      )}
      <div className="mt-2.5 flex items-center gap-3 text-xs text-muted-foreground flex-wrap">
        {Array.isArray(trips) && (
          <span className="flex items-center gap-1 text-primary-glow font-semibold tabular-nums">
            <Truck size={12} /> {tripTotal}
          </span>
        )}
        {counts.audio > 0 && (
          <span className="flex items-center gap-1">
            <Mic size={12} /> {counts.audio}
          </span>
        )}
        {counts.image > 0 && (
          <span className="flex items-center gap-1">
            <ImageIcon size={12} /> {counts.image}
          </span>
        )}
        {counts.video > 0 && (
          <span className="flex items-center gap-1">
            <Video size={12} /> {counts.video}
          </span>
        )}
        {counts.file > 0 && (
          <span className="flex items-center gap-1">
            <Paperclip size={12} /> {counts.file}
          </span>
        )}
        {entry.tags.length > 0 && (
          <span className="ml-auto truncate text-primary-glow">
            {entry.tags.map((t) => `#${t}`).join(" ")}
          </span>
        )}
      </div>
    </Link>
  );
}
