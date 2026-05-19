import { Camera, Mic, Paperclip, Video } from "lucide-react";
import { useRef } from "react";
import type { Attachment } from "@/lib/types";
import { uid } from "@/lib/format";

interface Props {
  onAttachment: (a: Attachment) => void;
  onStartVoice: () => void;
  disabled?: boolean;
}

export function CaptureBar({ onAttachment, onStartVoice, disabled }: Props) {
  const photoRef = useRef<HTMLInputElement>(null);
  const videoRef = useRef<HTMLInputElement>(null);
  const fileRef = useRef<HTMLInputElement>(null);

  const handle = (kind: Attachment["kind"]) => (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = e.target.files;
    if (!files) return;
    Array.from(files).forEach((f) => {
      onAttachment({
        id: uid(),
        kind,
        blob: f,
        mime: f.type,
        name: f.name,
        createdAt: Date.now(),
      });
    });
    e.target.value = "";
  };

  return (
    <div className="grid grid-cols-4 gap-2">
      <CapBtn label="Voice" icon={<Mic size={20} />} onClick={onStartVoice} disabled={disabled} accent />
      <CapBtn
        label="Photo"
        icon={<Camera size={20} />}
        onClick={() => photoRef.current?.click()}
        disabled={disabled}
      />
      <CapBtn
        label="Video"
        icon={<Video size={20} />}
        onClick={() => videoRef.current?.click()}
        disabled={disabled}
      />
      <CapBtn
        label="File"
        icon={<Paperclip size={20} />}
        onClick={() => fileRef.current?.click()}
        disabled={disabled}
      />

      <input
        ref={photoRef}
        type="file"
        accept="image/*"
        capture="environment"
        multiple
        className="hidden"
        onChange={handle("image")}
      />
      <input
        ref={videoRef}
        type="file"
        accept="video/*"
        capture="environment"
        className="hidden"
        onChange={handle("video")}
      />
      <input
        ref={fileRef}
        type="file"
        multiple
        className="hidden"
        onChange={handle("file")}
      />
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
