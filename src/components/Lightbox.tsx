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
  const touchStartTime = useRef<number>(0);
  const [dragX, setDragX] = useState(0);
  const [dragY, setDragY] = useState(0);
  const [isDragging, setIsDragging] = useState(false);
  const [isDismissing, setIsDismissing] = useState(false);

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

  // Touch handlers with instant downward swipe-to-dismiss physics
  const handleTouchStart = (e: TouchEvent) => {
    if (e.touches.length === 1) {
      touchStartX.current = e.touches[0].clientX;
      touchStartY.current = e.touches[0].clientY;
      touchStartTime.current = Date.now();
      setIsDragging(true);
    }
  };

  const handleTouchMove = (e: TouchEvent) => {
    if (touchStartX.current === null || touchStartY.current === null) return;
    const currentX = e.touches[0].clientX;
    const currentY = e.touches[0].clientY;
    const diffX = currentX - touchStartX.current;
    const diffY = currentY - touchStartY.current;

    // Prioritize downward swipe to exit if moving downwards
    if (diffY > 5) {
      setDragY(diffY);
      setDragX(diffX * 0.3); // dampen horizontal jitter while pulling down
    } else if (Math.abs(diffX) > Math.abs(diffY)) {
      setDragX(diffX);
      setDragY(0);
    } else if (diffY < 0) {
      // Small resistance when pulling up
      setDragY(diffY * 0.3);
      setDragX(0);
    }
  };

  const handleTouchEnd = () => {
    if (touchStartX.current === null || touchStartY.current === null) return;
    const elapsed = Math.max(1, Date.now() - touchStartTime.current);
    const vy = dragY / elapsed; // velocity in px/ms

    // Swipe down to dismiss threshold: > 60px or fast downward flick
    if (dragY > 60 || vy > 0.4) {
      vibrate("medium");
      setIsDismissing(true);
      setTimeout(onClose, 150);
      return;
    }

    // Horizontal swipe for next/previous image
    if (dragX < -60 && idx < images.length - 1) {
      vibrate("light");
      setIdx((i) => i + 1);
    } else if (dragX > 60 && idx > 0) {
      vibrate("light");
      setIdx((i) => i - 1);
    }

    touchStartX.current = null;
    touchStartY.current = null;
    setDragX(0);
    setDragY(0);
    setIsDragging(false);
  };

  if (!current) return null;

  const bgAlpha = Math.max(0.1, 0.95 - (dragY > 0 ? dragY / 400 : 0));
  const scale = dragY > 0 ? Math.max(0.65, 1 - dragY / 600) : 1;

  return (
    <div
      className="fixed inset-0 z-[100] backdrop-blur-2xl flex flex-col select-none transition-colors duration-150"
      style={{
        backgroundColor: `rgba(0, 0, 0, ${isDismissing ? 0 : bgAlpha})`,
        touchAction: "none",
      }}
      onTouchStart={handleTouchStart}
      onTouchMove={handleTouchMove}
      onTouchEnd={handleTouchEnd}
    >
      {/* Header controls */}
      <div 
        className="flex items-center justify-between px-4 py-3 text-white z-10 transition-opacity"
        style={{ opacity: dragY > 20 ? Math.max(0, 1 - dragY / 100) : 1 }}
      >
        <button
          onClick={() => {
            vibrate("light");
            onClose();
          }}
          className="h-10 w-10 rounded-full bg-white/15 grid place-items-center hover:bg-white/25 active:scale-90 transition-transform"
          aria-label="Close"
        >
          <X size={20} />
        </button>
        <span className="text-xs font-mono font-bold tracking-wider tabular-nums bg-white/15 px-3 py-1 rounded-full text-white/90">
          {idx + 1} / {images.length}
        </span>
        <a
          href={url}
          download={current.name ?? `photo-${current.id}.jpg`}
          onClick={() => vibrate("light")}
          className="h-10 w-10 rounded-full bg-white/15 grid place-items-center hover:bg-white/25 active:scale-90 transition-transform"
          aria-label="Download"
        >
          <Download size={18} />
        </a>
      </div>

      {/* Main Image container with silky smooth drag physics */}
      <div
        className="flex-1 overflow-hidden grid place-items-center px-4"
        style={{ touchAction: "none" }}
        onClick={onClose}
      >
        {url && (
          <div
            className="w-full h-full flex items-center justify-center pointer-events-none"
            style={{
              transform: `translate(${dragX}px, ${dragY}px) scale(${scale})`,
              transition: isDragging ? "none" : "transform 0.22s cubic-bezier(0.16, 1, 0.3, 1)",
            }}
          >
            <img
              src={url}
              alt={current.name ?? "photo"}
              className="max-w-full max-h-full object-contain select-none rounded-2xl shadow-2xl pointer-events-auto"
              draggable={false}
              onClick={(e) => e.stopPropagation()}
            />
          </div>
        )}
      </div>

      {/* Bottom pagination & navigation */}
      {images.length > 1 && (
        <div 
          className="flex items-center justify-between px-6 py-4 pb-[max(1.2rem,env(safe-area-inset-bottom))] z-10 transition-opacity"
          style={{ opacity: dragY > 20 ? Math.max(0, 1 - dragY / 100) : 1 }}
        >
          <button
            onClick={() => {
              vibrate("light");
              setIdx((i) => Math.max(0, i - 1));
            }}
            disabled={idx === 0}
            className="h-12 w-12 rounded-full bg-white/15 text-white grid place-items-center disabled:opacity-20 hover:bg-white/25 active:scale-90 transition-all shadow-lg"
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
                  i === idx ? "w-5 bg-blue-400 shadow-[0_0_8px_rgba(96,165,250,0.8)]" : "w-1.5 bg-white/30"
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
            className="h-12 w-12 rounded-full bg-white/15 text-white grid place-items-center disabled:opacity-20 hover:bg-white/25 active:scale-90 transition-all shadow-lg"
            aria-label="Next"
          >
            <ChevronRight size={24} />
          </button>
        </div>
      )}
    </div>
  );
}
