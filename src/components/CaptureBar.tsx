import { Mic, Camera, Video, Paperclip } from "lucide-react";
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
  const fileRef = useRef<HTMLInputElement>(null);
  const [cameraMode, setCameraMode] = useState<"photo" | "video" | null>(null);
  const [processing, setProcessing] = useState(false);

  async function handlePhotoCapture(blob: Blob) {
    setCameraMode(null);
    setProcessing(true);
    try {
      const scaled = await downscaleImage(blob, `photo-${Date.now()}.jpg`);
      const dims = await getImageDimensions(scaled);
      onAttachment({
        id: uid(),
        kind: "image",
        blob: scaled,
        mime: scaled.type || "image/jpeg",
        name: `photo-${Date.now()}.jpg`,
        width: dims?.width,
        height: dims?.height,
        createdAt: Date.now(),
      });
    } finally {
      setProcessing(false);
    }
  }

  function handleVideoCapture(blob: Blob) {
    setCameraMode(null);
    onAttachment({
      id: uid(),
      kind: "video",
      blob,
      mime: blob.type || "video/webm",
      name: `video-${Date.now()}.webm`,
      createdAt: Date.now(),
    });
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
    <div>
      <div className="grid grid-cols-4 gap-2">
        <CapBtn
          label="Voice"
          icon={<Mic size={20} />}
          onClick={onStartVoice}
          disabled={busy}
          accent
        />
        <CapBtn
          label="Camera"
          icon={<Camera size={20} />}
          onClick={() => setCameraMode("photo")}
          disabled={busy}
        />
        <CapBtn
          label="Video"
          icon={<Video size={20} />}
          onClick={() => setCameraMode("video")}
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
        <p className="mt-1.5 text-center text-[11px] text-primary-glow">
          Processing…
        </p>
      )}

      {/* File-only input — no capture attribute (no system camera) */}
      <input
        ref={fileRef}
        type="file"
        multiple
        className="hidden"
        onChange={handleFileInput}
      />

      {/* In-app camera for both photo and video */}
      {cameraMode && (
        <InAppCamera
          defaultMode={cameraMode}
          onCapture={handlePhotoCapture}
          onVideoCapture={handleVideoCapture}
          onClose={() => setCameraMode(null)}
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
