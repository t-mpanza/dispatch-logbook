import { useEffect, useRef, useState } from "react";
import { Mic, Square, X } from "lucide-react";
import { formatDuration, uid } from "@/lib/format";
import type { Attachment } from "@/lib/types";
import { vibrate } from "@/lib/haptics";

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
        const blob = new Blob(chunksRef.current, {
          type: chunksRef.current[0]?.type || "audio/webm",
        });
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
      <div className="rounded-2xl bg-rose-500/15 border border-rose-500/30 p-4 text-xs text-rose-300">
        <p className="font-bold">{error}</p>
        <button onClick={onCancel} className="mt-2 underline text-white">
          Close
        </button>
      </div>
    );
  }

  return (
    <div className="ios-glass-card p-5 border border-white/[0.1] shadow-2xl space-y-3 animate-fade-in-scale">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <span
            className={`h-3 w-3 rounded-full ${
              recording ? "bg-rose-500 animate-pulse shadow-[0_0_10px_rgba(244,63,94,0.8)]" : "bg-slate-500"
            }`}
          />
          <span className="font-mono text-xl font-bold tabular-nums text-slate-100">{formatDuration(elapsed)}</span>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={() => {
              vibrate("light");
              onCancel();
            }}
            className="h-10 w-10 rounded-full bg-white/[0.06] border border-white/[0.1] hover:bg-white/[0.12] text-slate-300 grid place-items-center ios-press"
            aria-label="Cancel recording"
          >
            <X size={18} />
          </button>
          <button
            onClick={() => {
              vibrate("success");
              stop(false);
            }}
            disabled={!recording}
            className="h-11 px-5 rounded-full bg-blue-600 hover:bg-blue-500 text-white font-bold text-xs flex items-center gap-2 shadow-[0_8px_25px_rgba(37,99,235,0.4)] disabled:opacity-50 ios-press"
          >
            <Square size={14} fill="currentColor" /> Stop & Save
          </button>
        </div>
      </div>
      <p className="text-xs text-slate-400 flex items-center gap-1.5 font-medium">
        <Mic size={13} className="text-blue-400" /> Recording audio memo — stored securely on this device.
      </p>
    </div>
  );
}
