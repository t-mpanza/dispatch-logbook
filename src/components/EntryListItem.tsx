import { memo } from "react";
import { Link, useNavigate } from "@tanstack/react-router";
import { useQueryClient } from "@tanstack/react-query";
import { Image as ImageIcon, Mic, Paperclip, Truck, Video, User, ChevronRight, Trash2, Share2, Edit3 } from "lucide-react";
import type { Entry } from "@/lib/types";
import { fmtTime } from "@/lib/format";
import { getPresetBadgeClass } from "@/lib/loading-presets";
import { deleteEntry } from "@/lib/db";
import { vibrate } from "@/lib/haptics";
import { SwipeableItem, type SwipeAction } from "./SwipeableItem";
import { formatWhatsAppShareText, shareWhatsAppText } from "@/lib/export-whatsapp";

export const EntryListItem = memo(function EntryListItem({ entry }: { entry: Entry }) {
  const navigate = useNavigate();
  const qc = useQueryClient();

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

  const handleDelete = async () => {
    if (!confirm(`Delete "${entry.title}"?`)) return;
    vibrate("error");
    await deleteEntry(entry.id);
    qc.invalidateQueries({ queryKey: ["entries"] });
  };

  const handleShare = () => {
    vibrate("light");
    const text = formatWhatsAppShareText(entry);
    shareWhatsAppText(text);
  };

  const rightActions: SwipeAction[] = [
    {
      id: "share",
      label: "Share",
      icon: <Share2 size={16} />,
      color: "bg-emerald-600/90 text-white",
      onClick: handleShare,
    },
    {
      id: "delete",
      label: "Delete",
      icon: <Trash2 size={16} />,
      color: "bg-rose-600/90 text-white",
      onClick: handleDelete,
    },
  ];

  const leftActions: SwipeAction[] = [
    {
      id: "edit",
      label: "Open",
      icon: <Edit3 size={16} />,
      color: "bg-blue-600/90 text-white",
      onClick: () => navigate({ to: "/entry/$id", params: { id: entry.id } }),
    },
  ];

  return (
    <SwipeableItem leftActions={leftActions} rightActions={rightActions}>
      <Link
        to="/entry/$id"
        params={{ id: entry.id }}
        onClick={() => vibrate("light")}
        className="block ios-glass-card p-4 ios-press group transition-all shadow-md"
      >
        <div className="flex items-start justify-between gap-3">
          <div className="flex items-center gap-2 min-w-0 flex-wrap">
            <span className={`text-[11px] font-mono font-bold uppercase px-2.5 py-0.5 rounded-lg tracking-wider shrink-0 ${badgeClass}`}>
              {entry.title}
            </span>
            {firstSheetTrip?.reg && (
              <span className="text-[10px] font-mono font-bold uppercase px-2 py-0.5 rounded-md bg-slate-100 dark:bg-white/[0.06] text-slate-800 dark:text-slate-200 border border-slate-200 dark:border-white/[0.1] shrink-0">
                {firstSheetTrip.reg}
              </span>
            )}
            {firstSheetTrip?.driverName && (
              <span className="text-[10px] font-medium text-slate-500 dark:text-slate-400 flex items-center gap-1 shrink-0">
                <User size={10} className="text-slate-400 dark:text-slate-500" /> {firstSheetTrip.driverName}
              </span>
            )}
          </div>

          <div className="flex items-center gap-1.5 shrink-0">
            <span className="text-xs text-slate-500 dark:text-slate-400 font-mono tabular-nums">
              {fmtTime(entry.createdAt)}
            </span>
            <ChevronRight size={14} className="text-slate-400 dark:text-slate-500 group-hover:text-slate-700 dark:group-hover:text-slate-300 group-hover:translate-x-0.5 transition-all" />
          </div>
        </div>

        {preview && (
          <p className="mt-2 text-xs text-slate-700 dark:text-slate-300 line-clamp-2 leading-relaxed bg-slate-50 dark:bg-black/25 p-2.5 rounded-xl border border-slate-200 dark:border-white/[0.06] font-sans">
            {preview}
          </p>
        )}

        <div className="mt-3 flex items-center gap-2 text-xs flex-wrap">
          {(Array.isArray(trips) || Array.isArray(sheetTrips)) && (
            <span className="flex items-center gap-1.5 px-2.5 py-0.5 rounded-lg bg-blue-500/15 text-blue-600 dark:text-blue-400 font-bold font-mono text-[11px] tabular-nums border border-blue-500/30">
              <Truck size={12} /> {tripTotal} tyres
            </span>
          )}

          {counts.image > 0 && (
            <span className="flex items-center gap-1 px-2.5 py-0.5 rounded-lg bg-emerald-500/12 text-emerald-600 dark:text-emerald-400 font-semibold text-[11px] border border-emerald-500/25">
              <ImageIcon size={12} /> {counts.image} {counts.image === 1 ? "photo" : "photos"}
            </span>
          )}

          {counts.audio > 0 && (
            <span className="flex items-center gap-1 px-2.5 py-0.5 rounded-lg bg-indigo-500/12 text-indigo-600 dark:text-indigo-300 font-semibold text-[11px] border border-indigo-500/25">
              <Mic size={12} /> {counts.audio} voice
            </span>
          )}

          {counts.video > 0 && (
            <span className="flex items-center gap-1 px-2.5 py-0.5 rounded-lg bg-cyan-500/12 text-cyan-700 dark:text-cyan-300 font-semibold text-[11px] border border-cyan-500/25">
              <Video size={12} /> {counts.video} video
            </span>
          )}

          {counts.file > 0 && (
            <span className="flex items-center gap-1 px-2.5 py-0.5 rounded-lg bg-amber-500/12 text-amber-700 dark:text-amber-400 font-semibold text-[11px] border border-amber-500/25">
              <Paperclip size={12} /> {counts.file}
            </span>
          )}

          {entry.tags.length > 0 && (
            <span className="ml-auto truncate text-[11px] text-slate-400 dark:text-slate-500 font-mono">
              {entry.tags.map((t) => `#${t}`).join(" ")}
            </span>
          )}
        </div>
      </Link>
    </SwipeableItem>
  );
});
