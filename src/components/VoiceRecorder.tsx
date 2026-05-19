import { useEffect, useRef, useState } from "react";
import { Mic, Square, X } from "lucide-react";
import { formatDuration, uid } from "@/lib/format";
import type { Attachment } from "@/lib/types";

export function VoiceRecorder({
  onSave,
  onCancel,
}: {
  onSave: (a: Attachment) => void;
  onCancel: () => void;
}) {
  const [recording, setRecording] = useState(false);
  const [elapsed, setElapsed] = useState(0);
  const [error, setError] = useState<string | null>(null);
  const recRef = useRef<MediaRecorder | null>(null);
  const chunksRef = useRef<Blob[]>([]);
  const startRef = useRef<number>(0);
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);

  useEffect(() => {
    start();
    return () => {
      stop(true);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function start() {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const mime = MediaRecorder.isTypeSupported("audio/webm") ? "audio/webm" : "";
      const rec = new MediaRecorder(stream, mime ? { mimeType: mime } : undefined);
      chunksRef.current = [];
      rec.ondataavailable = (e) => {
        if (e.data.size) chunksRef.current.push(e.data);
      };
      rec.onstop = () => {
        stream.getTracks().forEach((t) => t.stop());
        const blob = new Blob(chunksRef.current, { type: chunksRef.current[0]?.type || "audio/webm" });
        const duration = Date.now() - startRef.current;
        const att: Attachment = {
          id: uid(),
          kind: "audio",
          blob,
          mime: blob.type,
          durationMs: duration,
          createdAt: Date.now(),
        };
        onSave(att);
      };
      recRef.current = rec;
      rec.start();
      startRef.current = Date.now();
      setRecording(true);
      timerRef.current = setInterval(() => {
        setElapsed(Date.now() - startRef.current);
      }, 200);
    } catch (e) {
      setError((e as Error).message || "Microphone unavailable");
    }
  }

  function stop(cancel = false) {
    if (timerRef.current) {
      clearInterval(timerRef.current);
      timerRef.current = null;
    }
    const rec = recRef.current;
    if (rec && rec.state !== "inactive") {
      if (cancel) {
        rec.onstop = () => {
          rec.stream.getTracks().forEach((t) => t.stop());
        };
      }
      rec.stop();
    }
    setRecording(false);
  }

  if (error) {
    return (
      <div className="rounded-xl bg-destructive/15 p-4 text-sm text-destructive-foreground">
        <p className="font-medium">{error}</p>
        <button onClick={onCancel} className="mt-2 underline">
          Close
        </button>
      </div>
    );
  }

  return (
    <div className="rounded-2xl bg-surface-elevated p-5 border border-border shadow-[var(--shadow-elevated)]">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <span
            className={`h-3 w-3 rounded-full ${
              recording ? "bg-destructive animate-pulse" : "bg-muted-foreground"
            }`}
          />
          <span className="font-mono text-lg tabular-nums">{formatDuration(elapsed)}</span>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={onCancel}
            className="h-10 w-10 rounded-full bg-muted hover:bg-muted/70 grid place-items-center"
            aria-label="Cancel recording"
          >
            <X size={18} />
          </button>
          <button
            onClick={() => stop(false)}
            disabled={!recording}
            className="h-12 px-5 rounded-full bg-primary text-primary-foreground font-medium flex items-center gap-2 shadow-[var(--shadow-glow)] disabled:opacity-50"
          >
            <Square size={16} fill="currentColor" /> Stop & save
          </button>
        </div>
      </div>
      <p className="mt-3 text-xs text-muted-foreground flex items-center gap-2">
        <Mic size={12} /> Recording from your microphone — stored on this device only.
      </p>
    </div>
  );
}
