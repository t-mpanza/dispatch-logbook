import { useEffect, useRef, useState } from "react";
import { createPortal } from "react-dom";
import { Camera, FlipHorizontal2, Video, X } from "lucide-react";
import { toast } from "sonner";

interface Props {
  defaultMode?: "photo" | "video";
  onCapture: (blob: Blob) => void;
  onVideoCapture?: (blob: Blob) => void;
  onClose: () => void;
}

export function InAppCamera({
  defaultMode = "photo",
  onCapture,
  onVideoCapture,
  onClose,
}: Props) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const recorderRef = useRef<MediaRecorder | null>(null);
  const chunksRef = useRef<Blob[]>([]);

  const [facingMode, setFacingMode] = useState<"environment" | "user">("environment");
  const [hasMultipleCameras, setHasMultipleCameras] = useState(false);
  const [initializing, setInitializing] = useState(true);
  const [mode, setMode] = useState<"photo" | "video">(defaultMode);
  const [recording, setRecording] = useState(false);
  const [recSeconds, setRecSeconds] = useState(0);

  // Enumerate cameras once
  useEffect(() => {
    navigator.mediaDevices
      .enumerateDevices()
      .then((devices) => {
        setHasMultipleCameras(
          devices.filter((d) => d.kind === "videoinput").length > 1,
        );
      })
      .catch(() => {});
  }, []);

  // Start / restart stream
  useEffect(() => {
    let cancelled = false;
    setInitializing(true);

    navigator.mediaDevices
      .getUserMedia({
        video: {
          facingMode: { ideal: facingMode },
          width: { ideal: 1280 },
          height: { ideal: 720 },
        },
        audio: mode === "video",
      })
      .then((s) => {
        if (cancelled) {
          s.getTracks().forEach((t) => t.stop());
          return;
        }
        streamRef.current?.getTracks().forEach((t) => t.stop());
        streamRef.current = s;
        if (videoRef.current) videoRef.current.srcObject = s;
        setInitializing(false);
      })
      .catch((err) => {
        console.error("Camera error:", err);
        if (!cancelled) {
          toast.error("Camera access failed.");
          onClose();
        }
      });

    return () => {
      cancelled = true;
      streamRef.current?.getTracks().forEach((t) => t.stop());
      streamRef.current = null;
    };
  }, [facingMode, mode, onClose]);

  // Recording timer
  useEffect(() => {
    if (!recording) { setRecSeconds(0); return; }
    const id = setInterval(() => setRecSeconds((s) => s + 1), 1000);
    return () => clearInterval(id);
  }, [recording]);

  async function capturePhoto() {
    const video = videoRef.current;
    const stream = streamRef.current;
    if (!video || !stream) return;

    // Fast path: Hardware-accelerated ImageCapture API (supported in Android WebView)
    try {
      const track = stream.getVideoTracks()[0];
      // @ts-ignore - ImageCapture is not in standard TS DOM lib
      if (typeof ImageCapture !== "undefined") {
        // @ts-ignore
        const imageCapture = new ImageCapture(track);
        const blob = await imageCapture.takePhoto();
        stream.getTracks().forEach((t) => t.stop());
        streamRef.current = null;
        onCapture(blob);
        return;
      }
    } catch (err) {
      console.warn("ImageCapture failed, falling back to canvas", err);
    }

    // Slow path: Canvas rendering fallback
    if (!video.videoWidth) return;
    const canvas = document.createElement("canvas");
    canvas.width = video.videoWidth;
    canvas.height = video.videoHeight;
    canvas.getContext("2d")?.drawImage(video, 0, 0);

    canvas.toBlob(
      (blob) => {
        if (blob) {
          stream.getTracks().forEach((t) => t.stop());
          streamRef.current = null;
          onCapture(blob);
        } else {
          toast.error("Failed to capture photo.");
        }
      },
      "image/jpeg",
      0.88,
    );
  }

  function toggleRecording() {
    if (recording) {
      recorderRef.current?.stop();
      recorderRef.current = null;
      setRecording(false);
    } else {
      const stream = streamRef.current;
      if (!stream) return;
      chunksRef.current = [];

      const mimeType = MediaRecorder.isTypeSupported("video/webm;codecs=h264")
        ? "video/webm;codecs=h264"
        : MediaRecorder.isTypeSupported("video/webm;codecs=vp8")
        ? "video/webm;codecs=vp8"
        : "video/webm";

      const mr = new MediaRecorder(stream, { mimeType });
      mr.ondataavailable = (e) => {
        if (e.data.size > 0) chunksRef.current.push(e.data);
      };
      mr.onstop = () => {
        const blob = new Blob(chunksRef.current, { type: mimeType.split(";")[0] });
        stream.getTracks().forEach((t) => t.stop());
        streamRef.current = null;
        onVideoCapture?.(blob);
        onClose();
      };
      mr.start();
      recorderRef.current = mr;
      setRecording(true);
    }
  }

  function fmtSec(s: number) {
    const m = Math.floor(s / 60);
    const sec = s % 60;
    return `${m}:${sec.toString().padStart(2, "0")}`;
  }

  return createPortal(
    <div className="fixed inset-0 z-50 bg-black flex flex-col">
      {/* Top bar */}
      <div className="flex items-center justify-between px-4 py-3 bg-gradient-to-b from-black/70 to-transparent">
        <button
          onClick={() => {
            recorderRef.current?.stop();
            streamRef.current?.getTracks().forEach((t) => t.stop());
            onClose();
          }}
          className="h-10 w-10 rounded-full bg-white/10 grid place-items-center hover:bg-white/20 active:scale-95 transition-all text-white"
          aria-label="Close"
        >
          <X size={20} />
        </button>

        {/* Mode toggle */}
        <div className="flex rounded-full bg-white/10 border border-white/20 p-0.5 gap-0.5">
          {(["photo", "video"] as const).map((m) => (
            <button
              key={m}
              onClick={() => {
                if (recording) return; // can't switch while recording
                setMode(m);
              }}
              className={`flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-bold uppercase tracking-wider transition-all ${
                mode === m
                  ? "bg-white text-black"
                  : "text-white/70 hover:text-white"
              }`}
            >
              {m === "photo" ? <Camera size={12} /> : <Video size={12} />}
              {m}
            </button>
          ))}
        </div>

        <div className="w-10" />
      </div>

      {/* Viewfinder */}
      <div className="flex-1 relative overflow-hidden bg-zinc-950">
        {initializing && (
          <div className="absolute inset-0 flex flex-col items-center justify-center text-white gap-2">
            <Camera size={32} className="animate-pulse text-primary-glow" />
            <span className="text-sm text-zinc-400">Starting camera…</span>
          </div>
        )}
        <video
          ref={videoRef}
          playsInline
          autoPlay
          muted
          className={`w-full h-full object-cover transition-opacity duration-300 ${
            initializing ? "opacity-0" : "opacity-100"
          }`}
        />
        {/* Recording indicator */}
        {recording && (
          <div className="absolute top-4 left-1/2 -translate-x-1/2 flex items-center gap-2 rounded-full bg-black/60 border border-red-500/50 px-3 py-1.5">
            <span className="h-2 w-2 rounded-full bg-red-500 animate-pulse" />
            <span className="text-white text-sm font-bold tabular-nums">
              {fmtSec(recSeconds)}
            </span>
          </div>
        )}
      </div>

      {/* Bottom controls */}
      <div className="px-6 py-6 pb-[max(1.5rem,env(safe-area-inset-bottom))] bg-gradient-to-t from-black/80 to-transparent flex items-center justify-center gap-12">
        {/* Flip camera */}
        {hasMultipleCameras ? (
          <button
            onClick={() =>
              setFacingMode((p) => (p === "environment" ? "user" : "environment"))
            }
            disabled={initializing || recording}
            className="h-12 w-12 rounded-full bg-white/10 text-white grid place-items-center hover:bg-white/20 active:scale-95 transition-all disabled:opacity-40"
            aria-label="Flip camera"
          >
            <FlipHorizontal2 size={22} />
          </button>
        ) : (
          <div className="w-12" />
        )}

        {/* Shutter */}
        <button
          onClick={mode === "photo" ? capturePhoto : toggleRecording}
          disabled={initializing}
          aria-label={mode === "photo" ? "Capture photo" : recording ? "Stop recording" : "Start recording"}
          className={`h-20 w-20 rounded-full border-4 transition-all active:scale-90 flex items-center justify-center ${
            recording
              ? "border-red-500 bg-red-500/30 hover:bg-red-500/50"
              : "border-white bg-white/25 hover:bg-white/40"
          } disabled:opacity-40`}
        >
          {recording ? (
            <div className="h-7 w-7 rounded-md bg-red-500" />
          ) : mode === "video" ? (
            <div className="h-12 w-12 rounded-full bg-red-500" />
          ) : (
            <div className="h-14 w-14 rounded-full bg-white shadow-lg" />
          )}
        </button>

        <div className="w-12" />
      </div>
    </div>,
    document.body
  );
}
