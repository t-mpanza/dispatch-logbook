import { useEffect, useRef, useState, type TouchEvent } from "react";
import { ChevronLeft, ChevronRight, X, Download } from "lucide-react";
import type { Attachment } from "@/lib/types";
import { supabase } from "@/lib/supabase";
import { vibrate } from "@/lib/haptics";

interface Props {
  attachments: Attachment[];
  startId: string;
  onClose: () => void;
}

export function Lightbox({ attachments, startId, onClose }: Props) {
  const images = attachments.filter(
    (a) => a.kind === "image" || a.kind === "photo"
  );
  const startIdx = Math.max(
    0,
    images.findIndex((a) => a.id === startId)
  );
  const [idx, setIdx] = useState(startIdx);
  const [url, setUrl] = useState<string>("");

  // Touch gesture state
  const touchStartX = useRef<number | null>(null);
  const touchStartY = useRef<number | null>(null);
  const [dragX, setDragX] = useState(0);
  const [dragY, setDragY] = useState(0);
  const [isSwiping, setIsSwiping] = useState(false);

  const current = images[idx];

  useEffect(() => {
    if (!current) return;
    let active = true;

    if (current.blob) {
      const u = URL.createObjectURL(current.blob);
      setUrl(u);
      return () => {
        active = false;
        URL.revokeObjectURL(u);
      };
    } else if (current.url) {
      setUrl(current.url);
    } else if (current.dataUrl) {
      setUrl(current.dataUrl);
    } else if (current.downloadUrl) {
      setUrl(current.downloadUrl);
    } else if (current.storagePath) {
      supabase.storage
        .from("attachments")
        .createSignedUrl(current.storagePath, 86400 * 30)
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
  }, [current?.id, current?.blob, current?.url, current?.dataUrl, current?.downloadUrl, current?.storagePath]);

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

  // Touch handlers for horizontal swipe and vertical dismiss
  const handleTouchStart = (e: TouchEvent) => {
    if (e.touches.length === 1) {
      touchStartX.current = e.touches[0].clientX;
      touchStartY.current = e.touches[0].clientY;
      setIsSwiping(true);
    }
  };

  const handleTouchMove = (e: TouchEvent) => {
    if (touchStartX.current === null || touchStartY.current === null) return;
    const currentX = e.touches[0].clientX;
    const currentY = e.touches[0].clientY;
    const diffX = currentX - touchStartX.current;
    const diffY = currentY - touchStartY.current;

    // Favor horizontal swipe or downward dismiss
    if (Math.abs(diffX) > Math.abs(diffY)) {
      setDragX(diffX);
      setDragY(0);
    } else if (diffY > 0) {
      setDragY(diffY);
      setDragX(0);
    }
  };

  const handleTouchEnd = () => {
    if (touchStartX.current === null) return;

    // Horizontal swipe threshold: 50px
    if (dragX < -50 && idx < images.length - 1) {
      vibrate("light");
      setIdx((i) => i + 1);
    } else if (dragX > 50 && idx > 0) {
      vibrate("light");
      setIdx((i) => i - 1);
    } else if (dragY > 100) {
      // Pull down to dismiss threshold: 100px
      vibrate("medium");
      onClose();
    }

    touchStartX.current = null;
    touchStartY.current = null;
    setDragX(0);
    setDragY(0);
    setIsSwiping(false);
  };

  if (!current) return null;

  return (
    <div
      className="fixed inset-0 z-[100] bg-black/95 backdrop-blur-xl flex flex-col transition-opacity duration-200 select-none"
      onTouchStart={handleTouchStart}
      onTouchMove={handleTouchMove}
      onTouchEnd={handleTouchEnd}
    >
      {/* Header controls */}
      <div className="flex items-center justify-between px-4 py-3 text-white z-10">
        <button
          onClick={() => {
            vibrate("light");
            onClose();
          }}
          className="h-10 w-10 rounded-full bg-white/10 grid place-items-center hover:bg-white/20 active:scale-90 transition-transform"
          aria-label="Close"
        >
          <X size={20} />
        </button>
        <span className="text-xs font-mono font-bold tracking-wider tabular-nums bg-white/10 px-3 py-1 rounded-full text-white/90">
          {idx + 1} / {images.length}
        </span>
        <a
          href={url}
          download={current.name ?? `photo-${current.id}.jpg`}
          onClick={() => vibrate("light")}
          className="h-10 w-10 rounded-full bg-white/10 grid place-items-center hover:bg-white/20 active:scale-90 transition-transform"
          aria-label="Download"
        >
          <Download size={18} />
        </a>
      </div>

      {/* Main Image container with live drag physics */}
      <div
        className="flex-1 overflow-hidden grid place-items-center px-4"
        style={{ touchAction: "pan-y pinch-zoom" }}
        onClick={onClose}
      >
        {url && (
          <div
            className="w-full h-full flex items-center justify-center transition-transform"
            style={{
              transform: `translate(${dragX}px, ${dragY}px) scale(${dragY > 0 ? Math.max(0.8, 1 - dragY / 500) : 1})`,
              transition: isSwiping && (dragX !== 0 || dragY !== 0) ? "none" : "transform 0.25s cubic-bezier(0.16, 1, 0.3, 1)",
            }}
          >
            <img
              src={url}
              alt={current.name ?? "photo"}
              className="max-w-full max-h-full object-contain select-none rounded-xl shadow-2xl"
              onClick={(e) => e.stopPropagation()}
              draggable={false}
            />
          </div>
        )}
      </div>

      {/* Bottom pagination & navigation */}
      {images.length > 1 && (
        <div className="flex items-center justify-between px-6 py-4 pb-[max(1.2rem,env(safe-area-inset-bottom))] z-10">
          <button
            onClick={() => {
              vibrate("light");
              setIdx((i) => Math.max(0, i - 1));
            }}
            disabled={idx === 0}
            className="h-12 w-12 rounded-full bg-white/10 text-white grid place-items-center disabled:opacity-20 hover:bg-white/20 active:scale-90 transition-all shadow-lg"
            aria-label="Previous"
          >
            <ChevronLeft size={24} />
          </button>

          {/* Swipe hint dots */}
          <div className="flex gap-1.5 items-center">
            {images.slice(0, 10).map((_, i) => (
              <div
                key={i}
                className={`h-1.5 rounded-full transition-all ${
                  i === idx ? "w-5 bg-primary-glow" : "w-1.5 bg-white/30"
                }`}
              />
            ))}
          </div>

          <button
            onClick={() => {
              vibrate("light");
              setIdx((i) => Math.min(images.length - 1, i + 1));
            }}
            disabled={idx === images.length - 1}
            className="h-12 w-12 rounded-full bg-white/10 text-white grid place-items-center disabled:opacity-20 hover:bg-white/20 active:scale-90 transition-all shadow-lg"
            aria-label="Next"
          >
            <ChevronRight size={24} />
          </button>
        </div>
      )}
    </div>
  );
}
