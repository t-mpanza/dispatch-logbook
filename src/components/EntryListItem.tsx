import { memo } from "react";
import { Link } from "@tanstack/react-router";
import { Image as ImageIcon, Mic, Paperclip, Truck, Video } from "lucide-react";
import type { Entry } from "@/lib/types";
import { fmtTime } from "@/lib/format";

export const EntryListItem = memo(function EntryListItem({ entry }: { entry: Entry }) {
  const atts = entry.attachments || [];
  const counts = {
    audio: atts.filter((a) => a.kind === "audio").length,
    image: atts.filter((a) => a.kind === "image" || a.kind === "photo").length,
    video: atts.filter((a) => a.kind === "video").length,
    file: atts.filter((a) => a.kind === "file").length,
  };
  const trips = entry.trips;
  const sheetTrips = entry.loadingSheetTrips;
  const tripTotal = trips?.reduce((n, t) => n + t.count + (t.rejected || 0), 0) ?? 
                    sheetTrips?.reduce((n, t) => n + (t.quantityLoaded || 0), 0) ?? 0;

  const realNotes = (entry.notes || []).filter(
    (n) =>
      n &&
      n.id !== "__meta_sheet__" &&
      typeof n.text === "string" &&
      !n.text.startsWith('{"loadingSheetTrips"') &&
      !n.text.startsWith('{"despatcherName"'),
  );
  const preview = realNotes[0]?.text;
  const firstSheetTrip = sheetTrips?.[0];

  return (
    <Link
      to="/entry/$id"
      params={{ id: entry.id }}
      className="block rounded-2xl bg-surface border border-border p-4 hover:border-primary/50 transition-all shadow-xs"
    >
      <div className="flex items-start justify-between gap-3">
        <div className="flex items-center gap-2 min-w-0">
          <h3 className="font-mono text-sm font-bold tracking-wider uppercase text-foreground truncate">
            {entry.title}
          </h3>
          {firstSheetTrip?.reg && (
            <span className="text-[10px] font-mono font-bold uppercase px-2 py-0.5 rounded-md bg-muted text-muted-foreground shrink-0">
              {firstSheetTrip.reg}
            </span>
          )}
        </div>
        <span className="text-xs text-muted-foreground shrink-0 font-mono tabular-nums">
          {fmtTime(entry.createdAt)}
        </span>
      </div>

      {preview && <p className="mt-1.5 text-xs text-muted-foreground line-clamp-2">{preview}</p>}

      <div className="mt-3 flex items-center gap-2 text-xs flex-wrap">
        {(Array.isArray(trips) || Array.isArray(sheetTrips)) && (
          <span className="flex items-center gap-1.5 px-2 py-0.5 rounded-lg bg-primary/15 text-primary-glow font-bold font-mono text-[11px] tabular-nums">
            <Truck size={12} /> {tripTotal} tyres
          </span>
        )}

        {counts.image > 0 && (
          <span className="flex items-center gap-1 px-2 py-0.5 rounded-lg bg-emerald-500/15 text-emerald-400 font-semibold text-[11px]">
            <ImageIcon size={12} /> {counts.image} {counts.image === 1 ? "photo" : "photos"}
          </span>
        )}

        {counts.audio > 0 && (
          <span className="flex items-center gap-1 px-2 py-0.5 rounded-lg bg-violet-500/15 text-violet-400 font-semibold text-[11px]">
            <Mic size={12} /> {counts.audio} voice
          </span>
        )}

        {counts.video > 0 && (
          <span className="flex items-center gap-1 px-2 py-0.5 rounded-lg bg-blue-500/15 text-blue-400 font-semibold text-[11px]">
            <Video size={12} /> {counts.video} video
          </span>
        )}

        {counts.file > 0 && (
          <span className="flex items-center gap-1 px-2 py-0.5 rounded-lg bg-amber-500/15 text-amber-400 font-semibold text-[11px]">
            <Paperclip size={12} /> {counts.file}
          </span>
        )}

        {entry.tags.length > 0 && (
          <span className="ml-auto truncate text-[11px] text-muted-foreground font-mono">
            {entry.tags.map((t) => `#${t}`).join(" ")}
          </span>
        )}
      </div>
    </Link>
  );
});
