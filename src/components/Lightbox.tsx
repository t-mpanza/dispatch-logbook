import { useEffect, useState } from "react";
import { ChevronLeft, ChevronRight, X, Download } from "lucide-react";
import type { Attachment } from "@/lib/types";

interface Props {
  attachments: Attachment[];
  startId: string;
  onClose: () => void;
}

export function Lightbox({ attachments, startId, onClose }: Props) {
  const images = attachments.filter((a) => a.kind === "image");
  const startIdx = Math.max(0, images.findIndex((a) => a.id === startId));
  const [idx, setIdx] = useState(startIdx);
  const [url, setUrl] = useState<string>("");

  const current = images[idx];

  useEffect(() => {
    if (!current) return;
    const u = URL.createObjectURL(current.blob);
    setUrl(u);
    return () => URL.revokeObjectURL(u);
  }, [current?.id]);

  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if (e.key === "Escape") onClose();
      if (e.key === "ArrowLeft") setIdx((i) => Math.max(0, i - 1));
      if (e.key === "ArrowRight") setIdx((i) => Math.min(images.length - 1, i + 1));
    }
    window.addEventListener("keydown", onKey);
    document.body.style.overflow = "hidden";
    return () => {
      window.removeEventListener("keydown", onKey);
      document.body.style.overflow = "";
    };
  }, [images.length, onClose]);

  if (!current) return null;

  return (
    <div className="fixed inset-0 z-[100] bg-black/95 backdrop-blur-md flex flex-col">
      <div className="flex items-center justify-between px-4 py-3 text-white">
        <button
          onClick={onClose}
          className="h-10 w-10 rounded-full bg-white/10 grid place-items-center hover:bg-white/20"
          aria-label="Close"
        >
          <X size={20} />
        </button>
        <span className="text-xs tabular-nums text-white/70">
          {idx + 1} / {images.length}
        </span>
        <a
          href={url}
          download={current.name ?? `photo-${current.id}.jpg`}
          className="h-10 w-10 rounded-full bg-white/10 grid place-items-center hover:bg-white/20"
          aria-label="Download"
        >
          <Download size={18} />
        </a>
      </div>

      <div
        className="flex-1 overflow-auto grid place-items-center px-2"
        style={{ touchAction: "pinch-zoom" }}
        onClick={onClose}
      >
        {url && (
          <img
            src={url}
            alt={current.name ?? "photo"}
            className="max-w-full max-h-full object-contain select-none"
            onClick={(e) => e.stopPropagation()}
            draggable={false}
          />
        )}
      </div>

      {images.length > 1 && (
        <div className="flex items-center justify-between px-4 py-4 pb-[max(1rem,env(safe-area-inset-bottom))]">
          <button
            onClick={() => setIdx((i) => Math.max(0, i - 1))}
            disabled={idx === 0}
            className="h-12 w-12 rounded-full bg-white/10 text-white grid place-items-center disabled:opacity-30 hover:bg-white/20"
            aria-label="Previous"
          >
            <ChevronLeft size={22} />
          </button>
          <button
            onClick={() => setIdx((i) => Math.min(images.length - 1, i + 1))}
            disabled={idx === images.length - 1}
            className="h-12 w-12 rounded-full bg-white/10 text-white grid place-items-center disabled:opacity-30 hover:bg-white/20"
            aria-label="Next"
          >
            <ChevronRight size={22} />
          </button>
        </div>
      )}
    </div>
  );
}
