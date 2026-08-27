import { memo } from "react";
import { Link } from "@tanstack/react-router";
import { Image as ImageIcon, Mic, Paperclip, Truck, Video, User } from "lucide-react";
import type { Entry } from "@/lib/types";
import { fmtTime } from "@/lib/format";
import { getPresetBadgeClass } from "@/lib/loading-presets";
import { vibrate } from "@/lib/haptics";

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
  const badgeClass = getPresetBadgeClass(firstSheetTrip?.presetKey, entry.title);

  return (
    <Link
      to="/entry/$id"
      params={{ id: entry.id }}
      onClick={() => vibrate("light")}
      className="block rounded-2xl bg-surface border border-border/80 p-4 hover:border-primary/50 active:scale-[0.98] active:border-primary/70 transition-all shadow-xs hover:shadow-md"
    >
      <div className="flex items-start justify-between gap-3">
        <div className="flex items-center gap-2 min-w-0 flex-wrap">
          <span className={`text-[11px] font-mono font-bold uppercase px-2.5 py-0.5 rounded-lg border tracking-wider shrink-0 ${badgeClass}`}>
            {entry.title}
          </span>
          {firstSheetTrip?.reg && (
            <span className="text-[10px] font-mono font-bold uppercase px-2 py-0.5 rounded-md bg-muted/80 text-foreground border border-border/50 shrink-0">
              {firstSheetTrip.reg}
            </span>
          )}
          {firstSheetTrip?.driverName && (
            <span className="text-[10px] font-medium text-muted-foreground flex items-center gap-1 shrink-0">
              <User size={10} /> {firstSheetTrip.driverName}
            </span>
          )}
        </div>
        <span className="text-xs text-muted-foreground/80 shrink-0 font-mono tabular-nums">
          {fmtTime(entry.createdAt)}
        </span>
      </div>

      {preview && (
        <p className="mt-2 text-xs text-muted-foreground/90 line-clamp-2 leading-relaxed bg-background/40 p-2 rounded-lg border border-border/40 font-sans">
          {preview}
        </p>
      )}

      <div className="mt-3 flex items-center gap-2 text-xs flex-wrap">
        {(Array.isArray(trips) || Array.isArray(sheetTrips)) && (
          <span className="flex items-center gap-1.5 px-2.5 py-0.5 rounded-lg bg-primary/15 text-primary-glow font-bold font-mono text-[11px] tabular-nums border border-primary/25">
            <Truck size={12} /> {tripTotal} tyres
          </span>
        )}

        {counts.image > 0 && (
          <span className="flex items-center gap-1 px-2 py-0.5 rounded-lg bg-emerald-500/15 text-emerald-400 font-semibold text-[11px] border border-emerald-500/20">
            <ImageIcon size={12} /> {counts.image} {counts.image === 1 ? "photo" : "photos"}
          </span>
        )}

        {counts.audio > 0 && (
          <span className="flex items-center gap-1 px-2 py-0.5 rounded-lg bg-violet-500/15 text-violet-400 font-semibold text-[11px] border border-violet-500/20">
            <Mic size={12} /> {counts.audio} voice
          </span>
        )}

        {counts.video > 0 && (
          <span className="flex items-center gap-1 px-2 py-0.5 rounded-lg bg-blue-500/15 text-blue-400 font-semibold text-[11px] border border-blue-500/20">
            <Video size={12} /> {counts.video} video
          </span>
        )}

        {counts.file > 0 && (
          <span className="flex items-center gap-1 px-2 py-0.5 rounded-lg bg-amber-500/15 text-amber-400 font-semibold text-[11px] border border-amber-500/20">
            <Paperclip size={12} /> {counts.file}
          </span>
        )}

        {entry.tags.length > 0 && (
          <span className="ml-auto truncate text-[11px] text-muted-foreground/70 font-mono">
            {entry.tags.map((t) => `#${t}`).join(" ")}
          </span>
        )}
      </div>
    </Link>
  );
});
