import { useEffect, useRef, useState } from "react";
import { Camera, X, RefreshCw } from "lucide-react";
import { toast } from "sonner";

interface Props {
  onCapture: (blob: Blob) => void;
  onClose: () => void;
  onFallback: () => void;
}

export function InAppCamera({ onCapture, onClose, onFallback }: Props) {
  const videoRef = useRef<HTMLVideoElement>(null);
  // Use a ref — never stale in effect cleanup, no re-render on change
  const streamRef = useRef<MediaStream | null>(null);
  const [facingMode, setFacingMode] = useState<"environment" | "user">("environment");
  const [hasMultipleCameras, setHasMultipleCameras] = useState(false);
  const [initializing, setInitializing] = useState(true);

  // Check for multiple cameras once on mount
  useEffect(() => {
    navigator.mediaDevices
      .enumerateDevices()
      .then((devices) => {
        const videoDevices = devices.filter((d) => d.kind === "videoinput");
        setHasMultipleCameras(videoDevices.length > 1);
      })
      .catch((err) => {
        console.warn("Could not enumerate devices:", err);
      });
  }, []);

  // Start/restart camera stream. Cleanup always stops the current stream —
  // whether triggered by facingMode change or component unmount. No stale closure.
  useEffect(() => {
    let cancelled = false;
    setInitializing(true);

    navigator.mediaDevices
      .getUserMedia({
        video: { facingMode: { ideal: facingMode }, width: { ideal: 1920 }, height: { ideal: 1080 } },
        audio: false,
      })
      .then((s) => {
        if (cancelled) {
          // Effect was superseded (facingMode changed) or component unmounted —
          // stop the stream we just got, don't use it
          s.getTracks().forEach((t) => t.stop());
          return;
        }
        // Stop the previous stream before assigning the new one
        streamRef.current?.getTracks().forEach((t) => t.stop());
        streamRef.current = s;
        if (videoRef.current) {
          videoRef.current.srcObject = s;
        }
        setInitializing(false);
      })
      .catch((err) => {
        console.error("Camera access error:", err);
        if (!cancelled) {
          toast.error("Camera access failed. Falling back to system camera.");
          onFallback();
        }
      });

    return () => {
      cancelled = true;
      // Stop and release the stream for this effect cycle
      streamRef.current?.getTracks().forEach((t) => t.stop());
      streamRef.current = null;
    };
  }, [facingMode, onFallback]);

  function capture() {
    const video = videoRef.current;
    const stream = streamRef.current;
    if (!video || !stream) return;

    const width = video.videoWidth;
    const height = video.videoHeight;
    if (!width || !height) return;

    const canvas = document.createElement("canvas");
    canvas.width = width;
    canvas.height = height;

    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    ctx.drawImage(video, 0, 0, width, height);

    canvas.toBlob(
      (blob) => {
        if (blob) {
          stream.getTracks().forEach((t) => t.stop());
          streamRef.current = null;
          onCapture(blob);
        } else {
          toast.error("Failed to capture image");
        }
      },
      "image/jpeg",
      0.9,
    );
  }

  function toggleCamera() {
    setFacingMode((prev) => (prev === "environment" ? "user" : "environment"));
  }

  return (
    <div className="fixed inset-0 z-50 bg-black flex flex-col justify-between safe-bottom">
      {/* Top Bar */}
      <div className="px-4 py-3 flex items-center justify-between text-white bg-gradient-to-b from-black/60 to-transparent">
        <button
          onClick={onClose}
          className="h-10 w-10 rounded-full bg-white/10 grid place-items-center hover:bg-white/20 active:scale-95 transition-transform"
          aria-label="Close camera"
        >
          <X size={20} />
        </button>
        <span className="text-xs uppercase tracking-wider font-semibold opacity-70">
          In-App Camera
        </span>
        <div className="w-10 h-10" />
      </div>

      {/* Video Stream */}
      <div className="flex-1 flex items-center justify-center overflow-hidden bg-zinc-950 relative">
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
          className={`w-full h-full object-cover transition-opacity duration-300 ${initializing ? "opacity-0" : "opacity-100"}`}
        />
      </div>

      {/* Bottom Controls */}
      <div className="px-6 py-8 pb-[max(2rem,env(safe-area-inset-bottom))] bg-gradient-to-t from-black/80 to-transparent flex items-center justify-between">
        <button
          onClick={() => {
            streamRef.current?.getTracks().forEach((t) => t.stop());
            streamRef.current = null;
            onFallback();
          }}
          className="text-xs font-semibold text-white/70 hover:text-white px-3 py-2 rounded-lg bg-white/10 active:scale-95 transition-all"
        >
          Use System
        </button>

        {/* Shutter */}
        <button
          onClick={capture}
          disabled={initializing}
          className="h-20 w-20 rounded-full border-4 border-white bg-white/25 hover:bg-white/40 active:scale-90 transition-all flex items-center justify-center"
          aria-label="Capture photo"
        >
          <div className="h-14 w-14 rounded-full bg-white shadow-lg" />
        </button>

        {/* Camera switch */}
        {hasMultipleCameras ? (
          <button
            onClick={toggleCamera}
            disabled={initializing}
            className="h-12 w-12 rounded-full bg-white/10 text-white grid place-items-center hover:bg-white/20 active:scale-95 transition-all"
            aria-label="Switch camera"
          >
            <RefreshCw size={20} />
          </button>
        ) : (
          <div className="w-12 h-12" />
        )}
      </div>
    </div>
  );
}
