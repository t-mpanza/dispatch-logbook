import { Mic, Camera, Paperclip, X, Send, Video, File } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { createPortal } from "react-dom";
import type { Attachment } from "@/lib/types";
import { uid } from "@/lib/format";
import { downscaleImage, getImageDimensions } from "@/lib/image";
import { InAppCamera } from "./InAppCamera";
import { vibrate } from "@/lib/haptics";

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
  const [menuOpen, setMenuOpen] = useState(false);

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
    vibrate("success");
    setProcessing(true);
    const cap = caption.trim() || undefined;
    try {
      if (pending.kind === "image") {
        const scaled = await downscaleImage(pending.blob, `photo-${Date.now()}.jpg`);
        const dims = await getImageDimensions(scaled);
        onAttachment({
          id: uid(),
          kind: "image",
          blob: scaled,
          mime: scaled.type || "image/jpeg",
          name: `photo-${Date.now()}.jpg`,
          caption: cap,
          width: dims?.width,
          height: dims?.height,
          createdAt: Date.now(),
        });
      } else {
        onAttachment({
          id: uid(),
          kind: "video",
          blob: pending.blob,
          mime: pending.blob.type || "video/webm",
          name: `video-${Date.now()}.webm`,
          caption: cap,
          createdAt: Date.now(),
        });
      }
    } finally {
      setPending(null);
      setCaption("");
      setProcessing(false);
    }
  }

  function discardPending() {
    vibrate("light");
    if (pending?.previewUrl) URL.revokeObjectURL(pending.previewUrl);
    setPending(null);
    setCaption("");
  }

  async function handleFileInput(e: React.ChangeEvent<HTMLInputElement>) {
    const files = e.target.files;
    if (!files) return;
    vibrate("success");
    setProcessing(true);
    try {
      for (const f of Array.from(files)) {
        const type = f.type || "";
        if (type.startsWith("image/")) {
          const blob = await downscaleImage(f, f.name);
          const dims = await getImageDimensions(blob);
          onAttachment({
            id: uid(),
            kind: "image",
            blob,
            mime: blob.type || "image/jpeg",
            name: f.name,
            width: dims?.width,
            height: dims?.height,
            createdAt: Date.now(),
          });
        } else {
          let kind: Attachment["kind"] = "file";
          if (type.startsWith("video/")) kind = "video";
          else if (type.startsWith("audio/")) kind = "audio";
          onAttachment({
            id: uid(),
            kind,
            blob: f,
            mime: f.type || "application/octet-stream",
            name: f.name,
            createdAt: Date.now(),
          });
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
    <div className="relative">
      <button
        onClick={() => {
          vibrate("light");
          setMenuOpen(!menuOpen);
        }}
        disabled={busy}
        className={`h-9 w-9 shrink-0 rounded-full grid place-items-center transition-all ${
          menuOpen
            ? "bg-blue-600 text-white shadow-md"
            : "text-slate-400 hover:bg-white/[0.08] hover:text-slate-200"
        } disabled:opacity-40 ios-press`}
        aria-label="Add attachment"
      >
        <Paperclip
          size={18}
          className={menuOpen ? "rotate-45 transition-transform" : "transition-transform"}
        />
      </button>

      {/* Popover Menu */}
      {menuOpen && (
        <>
          <div className="fixed inset-0 z-40" onClick={() => setMenuOpen(false)} />
          <div className="absolute bottom-12 left-0 z-50 ios-glass-elevated border border-white/[0.1] rounded-2xl shadow-2xl p-2 flex flex-col gap-1 w-44 origin-bottom-left animate-fade-in-scale">
            <MenuBtn
              icon={<Mic size={16} />}
              label="Audio Note"
              color="text-emerald-400"
              bg="bg-emerald-500/15"
              onClick={() => {
                vibrate("light");
                setMenuOpen(false);
                onStartVoice();
              }}
            />
            <MenuBtn
              icon={<Camera size={16} />}
              label="Take Photo"
              color="text-blue-400"
              bg="bg-blue-500/15"
              onClick={() => {
                vibrate("light");
                setMenuOpen(false);
                setCameraMode("photo");
              }}
            />
            <MenuBtn
              icon={<Video size={16} />}
              label="Record Video"
              color="text-amber-400"
              bg="bg-amber-500/15"
              onClick={() => {
                vibrate("light");
                setMenuOpen(false);
                setCameraMode("video");
              }}
            />
            <MenuBtn
              icon={<File size={16} />}
              label="Attach File"
              color="text-slate-300"
              bg="bg-white/[0.08]"
              onClick={() => {
                vibrate("light");
                setMenuOpen(false);
                fileRef.current?.click();
              }}
            />
          </div>
        </>
      )}

      {processing && (
        <div className="absolute bottom-12 left-0 z-50 rounded-xl ios-glass-elevated border border-white/[0.1] px-3 py-1.5 shadow-lg text-[11px] text-blue-400 font-bold animate-pulse">
          Processing…
        </div>
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
      {pending &&
        createPortal(
          <div className="fixed inset-0 z-[60] bg-black flex flex-col animate-fade-in">
            <div className="flex-1 relative flex items-center justify-center bg-black/90 overflow-hidden">
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
                className="absolute top-4 left-4 h-10 w-10 rounded-full bg-white/[0.1] border border-white/[0.1] text-white grid place-items-center hover:bg-white/[0.2] ios-press"
              >
                <X size={20} />
              </button>
            </div>

            <div className="bg-[#0b0c12] border-t border-white/[0.1] px-4 pt-3 pb-[max(1.5rem,env(safe-area-inset-bottom))] space-y-3 shadow-2xl">
              <input
                value={caption}
                onChange={(e) => setCaption(e.target.value)}
                onKeyDown={(e) => e.key === "Enter" && commitPending()}
                placeholder="Add a caption… (optional)"
                autoFocus
                className="w-full rounded-xl bg-white/[0.06] border border-white/[0.1] px-4 py-3 text-slate-100 text-sm outline-none focus:border-blue-500 placeholder:text-slate-500 font-sans"
              />
              <div className="flex gap-3">
                <button
                  onClick={discardPending}
                  className="flex-1 h-11 rounded-xl bg-white/[0.06] border border-white/[0.1] text-slate-300 font-bold text-xs hover:bg-white/[0.12] ios-press"
                >
                  Discard
                </button>
                <button
                  onClick={commitPending}
                  disabled={processing}
                  className="flex-[2] h-11 rounded-xl bg-blue-600 hover:bg-blue-500 text-white font-bold text-xs flex items-center justify-center gap-2 ios-press disabled:opacity-50 shadow-[0_8px_25px_rgba(37,99,235,0.4)]"
                >
                  <Send size={15} /> Add to Log
                </button>
              </div>
            </div>
          </div>,
          document.body,
        )}
    </div>
  );
}

function MenuBtn({
  icon,
  label,
  onClick,
  color,
  bg,
}: {
  icon: React.ReactNode;
  label: string;
  onClick: () => void;
  color: string;
  bg: string;
}) {
  return (
    <button
      onClick={onClick}
      className="flex items-center gap-2.5 w-full p-2 rounded-xl hover:bg-white/[0.08] text-slate-200 ios-press"
    >
      <div className={`h-7 w-7 rounded-lg ${bg} ${color} grid place-items-center shrink-0`}>{icon}</div>
      <span className="text-xs font-bold truncate">{label}</span>
    </button>
  );
}
