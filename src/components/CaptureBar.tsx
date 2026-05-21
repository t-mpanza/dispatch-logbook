import { Mic, Camera, Paperclip, X, Send } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import type { Attachment } from "@/lib/types";
import { uid } from "@/lib/format";
import { downscaleImage, getImageDimensions } from "@/lib/image";
import { InAppCamera } from "./InAppCamera";

interface Props {
  onAttachment: (a: Attachment) => void;
  onStartVoice: () => void;
  disabled?: boolean;
}

type PendingCapture = {
  blob: Blob;
  kind: "image" | "video";
  previewUrl: string;
};

export function CaptureBar({ onAttachment, onStartVoice, disabled }: Props) {
  const fileRef = useRef<HTMLInputElement>(null);
  const [cameraMode, setCameraMode] = useState<"photo" | "video" | null>(null);
  const [processing, setProcessing] = useState(false);
  const [pending, setPending] = useState<PendingCapture | null>(null);
  const [caption, setCaption] = useState("");

  // Clean up object URL when pending is cleared
  useEffect(() => {
    return () => {
      if (pending?.previewUrl) URL.revokeObjectURL(pending.previewUrl);
    };
  }, [pending?.previewUrl]);

  async function handlePhotoCapture(blob: Blob) {
    setCameraMode(null);
    setPending({ blob, kind: "image", previewUrl: URL.createObjectURL(blob) });
    setCaption("");
  }

  function handleVideoCapture(blob: Blob) {
    setCameraMode(null);
    setPending({ blob, kind: "video", previewUrl: URL.createObjectURL(blob) });
    setCaption("");
  }

  async function commitPending() {
    if (!pending) return;
    setProcessing(true);
    const cap = caption.trim() || undefined;
    try {
      if (pending.kind === "image") {
        const scaled = await downscaleImage(pending.blob, `photo-${Date.now()}.jpg`);
        const dims = await getImageDimensions(scaled);
        onAttachment({
          id: uid(), kind: "image", blob: scaled,
          mime: scaled.type || "image/jpeg", name: `photo-${Date.now()}.jpg`,
          caption: cap, width: dims?.width, height: dims?.height, createdAt: Date.now(),
        });
      } else {
        onAttachment({
          id: uid(), kind: "video", blob: pending.blob,
          mime: pending.blob.type || "video/webm", name: `video-${Date.now()}.webm`,
          caption: cap, createdAt: Date.now(),
        });
      }
    } finally {
      setPending(null);
      setCaption("");
      setProcessing(false);
    }
  }

  function discardPending() {
    if (pending?.previewUrl) URL.revokeObjectURL(pending.previewUrl);
    setPending(null);
    setCaption("");
  }

  async function handleFileInput(e: React.ChangeEvent<HTMLInputElement>) {
    const files = e.target.files;
    if (!files) return;
    setProcessing(true);
    try {
      for (const f of Array.from(files)) {
        const type = f.type || "";
        if (type.startsWith("image/")) {
          const blob = await downscaleImage(f, f.name);
          const dims = await getImageDimensions(blob);
          onAttachment({ id: uid(), kind: "image", blob, mime: blob.type || "image/jpeg", name: f.name, width: dims?.width, height: dims?.height, createdAt: Date.now() });
        } else {
          let kind: Attachment["kind"] = "file";
          if (type.startsWith("video/")) kind = "video";
          else if (type.startsWith("audio/")) kind = "audio";
          onAttachment({ id: uid(), kind, blob: f, mime: f.type || "application/octet-stream", name: f.name, createdAt: Date.now() });
        }
        await new Promise((r) => setTimeout(r, 0));
      }
    } finally {
      setProcessing(false);
      e.target.value = "";
    }
  }

  const busy = disabled || processing;

  return (
    <>
      {/* Capture strip */}
      <div className="flex items-center gap-2 rounded-2xl bg-surface border border-border px-3 py-2.5">
        <button
          onClick={onStartVoice}
          disabled={busy}
          className="flex flex-col items-center gap-1 flex-1 py-2 rounded-xl bg-[image:var(--gradient-primary)] text-primary-foreground border-transparent shadow-[var(--shadow-glow)] active:scale-95 disabled:opacity-40 transition-all"
        >
          <Mic size={18} />
          <span className="text-[10px] font-semibold">Voice</span>
        </button>

        <button
          onClick={() => setCameraMode("photo")}
          disabled={busy}
          className="flex flex-col items-center gap-1 flex-1 py-2 rounded-xl bg-surface-elevated border border-border text-foreground hover:border-primary/40 active:scale-95 disabled:opacity-40 transition-all"
        >
          <Camera size={18} />
          <span className="text-[10px] font-semibold">Camera</span>
        </button>

        <button
          onClick={() => setCameraMode("video")}
          disabled={busy}
          className="flex flex-col items-center gap-1 flex-1 py-2 rounded-xl bg-surface-elevated border border-border text-foreground hover:border-primary/40 active:scale-95 disabled:opacity-40 transition-all"
        >
          <Camera size={18} className="text-orange-400" />
          <span className="text-[10px] font-semibold text-orange-400">Video</span>
        </button>

        <button
          onClick={() => fileRef.current?.click()}
          disabled={busy}
          className="flex flex-col items-center gap-1 flex-1 py-2 rounded-xl bg-surface-elevated border border-border text-foreground hover:border-primary/40 active:scale-95 disabled:opacity-40 transition-all"
        >
          <Paperclip size={18} />
          <span className="text-[10px] font-semibold">File</span>
        </button>
      </div>

      {processing && (
        <p className="text-center text-[11px] text-primary-glow mt-1">Processing…</p>
      )}

      <input ref={fileRef} type="file" multiple className="hidden" onChange={handleFileInput} />

      {cameraMode && (
        <InAppCamera
          defaultMode={cameraMode}
          onCapture={handlePhotoCapture}
          onVideoCapture={handleVideoCapture}
          onClose={() => setCameraMode(null)}
        />
      )}

      {/* Caption preview overlay */}
      {pending && (
        <div className="fixed inset-0 z-50 bg-black flex flex-col">
          {/* Media preview */}
          <div className="flex-1 relative flex items-center justify-center bg-zinc-950 overflow-hidden">
            {pending.kind === "image" ? (
              <img
                src={pending.previewUrl}
                alt="Preview"
                className="max-w-full max-h-full object-contain"
              />
            ) : (
              <video
                src={pending.previewUrl}
                controls
                playsInline
                className="max-w-full max-h-full"
              />
            )}
            <button
              onClick={discardPending}
              className="absolute top-4 left-4 h-10 w-10 rounded-full bg-black/60 backdrop-blur text-white grid place-items-center hover:bg-black/80 active:scale-95"
            >
              <X size={20} />
            </button>
          </div>

          {/* Caption input bar */}
          <div className="bg-black/90 backdrop-blur-xl border-t border-white/10 px-4 pt-3 pb-[max(1.5rem,env(safe-area-inset-bottom))] space-y-3">
            <input
              value={caption}
              onChange={(e) => setCaption(e.target.value)}
              onKeyDown={(e) => e.key === "Enter" && commitPending()}
              placeholder="Add a caption… (optional)"
              autoFocus
              className="w-full rounded-xl bg-white/10 border border-white/20 px-4 py-3 text-white text-sm outline-none focus:border-white/50 placeholder:text-white/40"
            />
            <div className="flex gap-3">
              <button
                onClick={discardPending}
                className="flex-1 h-11 rounded-xl bg-white/10 text-white font-semibold text-sm active:scale-95 transition-all"
              >
                Discard
              </button>
              <button
                onClick={commitPending}
                disabled={processing}
                className="flex-[2] h-11 rounded-xl bg-primary text-primary-foreground font-bold text-sm flex items-center justify-center gap-2 active:scale-[0.98] disabled:opacity-50 transition-all shadow-[var(--shadow-glow)]"
              >
                <Send size={16} /> Add to log
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
