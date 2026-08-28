import { useEffect, useState } from "react";
import { File as FileIcon, Trash2, Maximize2 } from "lucide-react";
import type { Attachment } from "@/lib/types";
import { formatBytes, formatDuration } from "@/lib/format";
import { supabase } from "@/lib/supabase";
import { vibrate } from "@/lib/haptics";

export function AttachmentView({
  attachment,
  onRemove,
  onOpenImage,
}: {
  attachment: Attachment;
  onRemove?: () => void;
  onOpenImage?: (a: Attachment) => void;
}) {
  const [url, setUrl] = useState<string>("");

  useEffect(() => {
    let active = true;

    if (attachment.blob) {
      const u = URL.createObjectURL(attachment.blob);
      setUrl(u);
      return () => {
        active = false;
        URL.revokeObjectURL(u);
      };
    } else if (attachment.url) {
      setUrl(attachment.url);
    } else if (attachment.dataUrl) {
      setUrl(attachment.dataUrl);
    } else if (attachment.downloadUrl) {
      setUrl(attachment.downloadUrl);
    } else if (attachment.storagePath) {
      supabase.storage
        .from("attachments")
        .createSignedUrl(attachment.storagePath, 86400 * 30)
        .then(({ data }) => {
          if (active && data?.signedUrl) {
            setUrl(data.signedUrl);
          }
        })
        .catch(console.error);
    }

    return () => {
      active = false;
    };
  }, [
    attachment.id,
    attachment.blob,
    attachment.url,
    attachment.dataUrl,
    attachment.downloadUrl,
    attachment.storagePath,
  ]);

  const isImage = attachment.kind === "image" || attachment.kind === "photo";
  const wrapper = "relative rounded-2xl overflow-hidden ios-glass-card shadow-lg";

  return (
    <div className={wrapper}>
      {isImage && url && (
        <button
          type="button"
          onClick={() => {
            vibrate("light");
            onOpenImage?.(attachment);
          }}
          className="block w-full group relative"
        >
          <img
            src={url}
            alt={attachment.name ?? "photo"}
            loading="lazy"
            decoding="async"
            className="w-full max-h-80 object-cover"
          />
          <span className="absolute bottom-2 left-2 flex items-center gap-1 rounded-full bg-black/60 backdrop-blur-md text-white text-[10px] font-bold px-2.5 py-1 opacity-0 group-hover:opacity-100 transition-opacity">
            <Maximize2 size={11} /> Tap to view
          </span>
        </button>
      )}
      {attachment.kind === "video" && url && (
        <video
          src={url}
          controls
          playsInline
          preload="metadata"
          className="w-full max-h-80 bg-black"
        />
      )}
      {attachment.kind === "audio" && url && (
        <div className="p-3">
          <audio src={url} controls preload="metadata" className="w-full" />
          {attachment.durationMs != null && (
            <p className="mt-1 text-xs text-slate-400 font-mono">
              {formatDuration(attachment.durationMs)}
            </p>
          )}
        </div>
      )}
      {attachment.kind === "file" && url && (
        <a
          href={url}
          download={attachment.name ?? "file"}
          onClick={() => vibrate("light")}
          className="flex items-center gap-3 p-3.5 hover:bg-white/[0.06] transition-colors"
        >
          <div className="h-10 w-10 rounded-xl bg-blue-500/15 text-blue-400 border border-blue-500/30 grid place-items-center shrink-0">
            <FileIcon size={18} />
          </div>
          <div className="min-w-0 flex-1">
            <p className="truncate text-xs font-bold text-slate-100">{attachment.name ?? "Attachment"}</p>
            <p className="text-[11px] text-slate-400 font-mono mt-0.5">
              {attachment.blob ? formatBytes(attachment.blob.size) : "0 B"} · tap to download
            </p>
          </div>
        </a>
      )}
      {attachment.caption && (
        <p className="px-3.5 py-2.5 text-xs text-slate-200 border-t border-white/[0.08] leading-relaxed font-sans bg-black/20">
          {attachment.caption}
        </p>
      )}
      {onRemove && (
        <button
          onClick={() => {
            vibrate("light");
            onRemove();
          }}
          className="absolute top-2 right-2 h-8 w-8 rounded-full bg-black/60 backdrop-blur-md grid place-items-center text-slate-300 hover:text-rose-400 hover:bg-rose-500/20 transition-all shadow-md"
          aria-label="Remove attachment"
        >
          <Trash2 size={14} />
        </button>
      )}
    </div>
  );
}
