import { useEffect, useState } from "react";
import { File as FileIcon, Trash2, Maximize2 } from "lucide-react";
import type { Attachment } from "@/lib/types";
import { formatBytes, formatDuration } from "@/lib/format";

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
    const u = URL.createObjectURL(attachment.blob);
    setUrl(u);
    return () => URL.revokeObjectURL(u);
  }, [attachment.blob]);

  const wrapper =
    "relative rounded-xl overflow-hidden bg-surface-elevated border border-border";

  return (
    <div className={wrapper}>
      {attachment.kind === "image" && url && (
        <button
          type="button"
          onClick={() => onOpenImage?.(attachment)}
          className="block w-full group"
        >
          <img
            src={url}
            alt={attachment.name ?? "photo"}
            loading="lazy"
            decoding="async"
            className="w-full max-h-80 object-cover"
          />
          <span className="absolute bottom-2 left-2 flex items-center gap-1 rounded-full bg-black/55 backdrop-blur text-white text-[10px] px-2 py-1 opacity-0 group-hover:opacity-100 transition-opacity">
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
            <p className="mt-1 text-xs text-muted-foreground">
              {formatDuration(attachment.durationMs)}
            </p>
          )}
        </div>
      )}
      {attachment.kind === "file" && url && (
        <a
          href={url}
          download={attachment.name ?? "file"}
          className="flex items-center gap-3 p-3 hover:bg-muted/40"
        >
          <div className="h-10 w-10 rounded-lg bg-primary/20 text-primary-glow grid place-items-center">
            <FileIcon size={18} />
          </div>
          <div className="min-w-0 flex-1">
            <p className="truncate text-sm font-medium">{attachment.name ?? "Attachment"}</p>
            <p className="text-xs text-muted-foreground">
              {formatBytes(attachment.blob.size)} · tap to download
            </p>
          </div>
        </a>
      )}
      {attachment.caption && (
        <p className="px-3 py-2 text-sm text-foreground/90 border-t border-border/50 leading-snug">
          {attachment.caption}
        </p>
      )}
      {onRemove && (
        <button
          onClick={onRemove}
          className="absolute top-2 right-2 h-8 w-8 rounded-full bg-black/60 backdrop-blur grid place-items-center text-white hover:bg-destructive transition-colors"
          aria-label="Remove attachment"
        >
          <Trash2 size={14} />
        </button>
      )}
    </div>
  );
}
