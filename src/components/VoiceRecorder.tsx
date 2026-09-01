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
      vibrate("medium");
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
      <div className="fixed bottom-0 left-1/2 -translate-x-1/2 w-full max-w-md z-50 px-3 pb-[max(0.75rem,env(safe-area-inset-bottom))] animate-sheet-slide-up">
        <div className="rounded-3xl ios-glass-elevated border border-rose-500/30 p-4 text-xs text-rose-300 shadow-2xl flex items-center justify-between">
          <div>
            <p className="font-bold">Microphone Error</p>
            <p className="text-[11px] opacity-80">{error}</p>
          </div>
          <button
            onClick={onCancel}
            className="h-8 px-3 rounded-full bg-white/10 hover:bg-white/20 text-white font-bold"
          >
            Dismiss
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="fixed bottom-0 left-1/2 -translate-x-1/2 w-full max-w-md z-50 px-3 pb-[max(0.75rem,env(safe-area-inset-bottom))] animate-sheet-slide-up">
      <div className="flex items-center justify-between gap-3 rounded-3xl ios-glass-dock px-4 py-3 shadow-2xl border border-rose-500/30">
        {/* Pulsing indicator + Duration */}
        <div className="flex items-center gap-2.5">
          <div className="relative flex items-center justify-center">
            <span className="animate-ping absolute inline-flex h-4 w-4 rounded-full bg-rose-400 opacity-75" />
            <span className="relative inline-flex rounded-full h-3 w-3 bg-rose-500" />
          </div>
          <span className="font-mono text-base font-black tabular-nums text-slate-900 dark:text-slate-100">
            {formatDuration(elapsed)}
          </span>

          {/* Animated audio frequency equalizer bars */}
          <div className="flex items-center gap-0.5 h-4 ml-1">
            {[12, 18, 8, 22, 14, 20, 10].map((h, i) => (
              <span
                key={i}
                className="w-1 bg-rose-500 rounded-full animate-pulse"
                style={{
                  height: `${h}px`,
                  animationDuration: `${0.4 + (i % 4) * 0.15}s`,
                }}
              />
            ))}
          </div>
        </div>

        {/* Action buttons */}
        <div className="flex items-center gap-2">
          <button
            onClick={() => {
              vibrate("light");
              onCancel();
            }}
            className="h-9 w-9 rounded-full bg-slate-200/70 dark:bg-white/[0.08] hover:bg-slate-300 dark:hover:bg-white/[0.15] text-slate-600 dark:text-slate-300 grid place-items-center ios-press"
            aria-label="Cancel recording"
            title="Cancel"
          >
            <X size={16} />
          </button>

          <button
            onClick={() => {
              vibrate("success");
              stop(false);
            }}
            disabled={!recording}
            className="h-10 px-4 rounded-full bg-rose-600 hover:bg-rose-500 text-white font-bold text-xs flex items-center gap-2 shadow-[0_4px_16px_rgba(225,29,72,0.4)] disabled:opacity-50 ios-press"
            aria-label="Stop and save recording"
          >
            <Square size={13} fill="currentColor" />
            <span>Done</span>
          </button>
        </div>
      </div>
    </div>
  );
}
