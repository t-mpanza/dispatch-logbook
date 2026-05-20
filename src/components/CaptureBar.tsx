import { Camera, Mic, Paperclip, Video } from "lucide-react";
import { useRef, useState } from "react";
import type { Attachment } from "@/lib/types";
import { uid } from "@/lib/format";
import { downscaleImage, getImageDimensions } from "@/lib/image";
import { InAppCamera } from "./InAppCamera";

interface Props {
  onAttachment: (a: Attachment) => void;
  onStartVoice: () => void;
  disabled?: boolean;
}

export function CaptureBar({ onAttachment, onStartVoice, disabled }: Props) {
  const photoRef = useRef<HTMLInputElement>(null);
  const videoRef = useRef<HTMLInputElement>(null);
  const fileRef = useRef<HTMLInputElement>(null);
  const [processing, setProcessing] = useState(false);
  const [showCamera, setShowCamera] = useState(false);

  async function handleImage(e: React.ChangeEvent<HTMLInputElement>) {
    const files = e.target.files;
    if (!files) return;
    setProcessing(true);
    try {
      for (const f of Array.from(files)) {
        // Downscale BEFORE we hand it to the entry. This is the fix for
        // the "low memory / page reload" crash when capturing photos.
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
        // Let the event loop breathe between large files
        await new Promise((r) => setTimeout(r, 0));
      }
    } finally {
      setProcessing(false);
      e.target.value = "";
    }
  }

  const handleOther =
    (fallbackKind: Exclude<Attachment["kind"], "image">) =>
    async (e: React.ChangeEvent<HTMLInputElement>) => {
      const files = e.target.files;
      if (!files) return;
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
            continue;
          }

          let kind: Attachment["kind"] = fallbackKind;
          if (type.startsWith("video/")) {
            kind = "video";
          } else if (type.startsWith("audio/")) {
            kind = "audio";
          } else {
            kind = "file";
          }

          onAttachment({
            id: uid(),
            kind,
            blob: f,
            mime: f.type || "application/octet-stream",
            name: f.name,
            createdAt: Date.now(),
          });
        }
      } finally {
        setProcessing(false);
        e.target.value = "";
      }
    };

  const busy = disabled || processing;

  return (
    <div className="space-y-2">
      <div className="grid grid-cols-4 gap-2">
        <CapBtn label="Voice" icon={<Mic size={20} />} onClick={onStartVoice} disabled={busy} accent />
        <CapBtn
          label="Photo"
          icon={<Camera size={20} />}
          onClick={() => setShowCamera(true)}
          disabled={busy}
        />
        <CapBtn
          label="Video"
          icon={<Video size={20} />}
          onClick={() => videoRef.current?.click()}
          disabled={busy}
        />
        <CapBtn
          label="File"
          icon={<Paperclip size={20} />}
          onClick={() => fileRef.current?.click()}
          disabled={busy}
        />
      </div>
      {processing && (
        <p className="text-[11px] text-primary-glow text-center">Processing photo…</p>
      )}

      <input
        ref={photoRef}
        type="file"
        accept="image/*"
        capture="environment"
        multiple
        className="hidden"
        onChange={handleImage}
      />
      <input
        ref={videoRef}
        type="file"
        accept="video/*"
        capture="environment"
        className="hidden"
        onChange={handleOther("video")}
      />
      <input
        ref={fileRef}
        type="file"
        multiple
        className="hidden"
        onChange={handleOther("file")}
      />

      {showCamera && (
        <InAppCamera
          onCapture={async (blob) => {
            setShowCamera(false);
            setProcessing(true);
            try {
              const dims = await getImageDimensions(blob);
              onAttachment({
                id: uid(),
                kind: "image",
                blob,
                mime: blob.type || "image/jpeg",
                name: `camera-${Date.now()}.jpg`,
                width: dims?.width,
                height: dims?.height,
                createdAt: Date.now(),
              });
            } finally {
              setProcessing(false);
            }
          }}
          onClose={() => setShowCamera(false)}
          onFallback={() => {
            setShowCamera(false);
            // Request system camera
            setTimeout(() => {
              photoRef.current?.click();
            }, 100);
          }}
        />
      )}
    </div>
  );
}

function CapBtn({
  label,
  icon,
  onClick,
  disabled,
  accent,
}: {
  label: string;
  icon: React.ReactNode;
  onClick: () => void;
  disabled?: boolean;
  accent?: boolean;
}) {
  return (
    <button
      onClick={onClick}
      disabled={disabled}
      className={`flex flex-col items-center justify-center gap-1.5 rounded-xl py-3.5 border transition-all active:scale-95 disabled:opacity-40 ${
        accent
          ? "bg-[image:var(--gradient-primary)] text-primary-foreground border-transparent shadow-[var(--shadow-glow)]"
          : "bg-surface-elevated border-border text-foreground hover:border-primary/50"
      }`}
    >
      {icon}
      <span className="text-[11px] font-medium">{label}</span>
    </button>
  );
}
