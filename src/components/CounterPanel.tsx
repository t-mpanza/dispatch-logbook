import { useRef, useState } from "react";
import { Camera, Check, Minus, Plus } from "lucide-react";
import type { Attachment, Trip } from "@/lib/types";
import { uid } from "@/lib/format";
import { InAppCamera } from "./InAppCamera";
import { downscaleImage, getImageDimensions } from "@/lib/image";
import { vibrate } from "@/lib/haptics";

interface Props {
  trips: Trip[];
  onChange: (next: Trip[]) => void;
  onAttachment?: (a: Attachment) => void;
}

const QUICK = [2, 4, 8, 10];

export function CounterPanel({ trips, onChange, onAttachment }: Props) {
  const [tab, setTab] = useState<"scanned" | "manual">("scanned");
  const [count, setCount] = useState(0);
  const [manualCount, setManualCount] = useState(1);
  const [slipNumber, setSlipNumber] = useState("");
  const [showCamera, setShowCamera] = useState(false);
  const [processing, setProcessing] = useState(false);

  function logScanned() {
    if (count <= 0) return;
    vibrate("success");
    onChange([...trips, { id: uid(), count, createdAt: Date.now() }]);
    setCount(0);
  }

  function logManual(noteOverride?: string) {
    if (manualCount <= 0) return;
    vibrate("success");
    const note = noteOverride ?? (slipNumber.trim() ? `slip:text:${slipNumber.trim()}` : undefined);
    onChange([
      ...trips,
      { id: uid(), count: 0, rejected: manualCount, note, createdAt: Date.now() },
    ]);
    setManualCount(1);
    setSlipNumber("");
  }

  async function handlePhotoCapture(blob: Blob) {
    setShowCamera(false);
    setProcessing(true);
    try {
      const scaled = await downscaleImage(blob, `slip-${Date.now()}.jpg`);
      const dims = await getImageDimensions(scaled);
      const id = uid();
      const name = `slip-${Date.now()}.jpg`;
      onAttachment?.({
        id,
        kind: "image",
        blob: scaled,
        mime: scaled.type || "image/jpeg",
        name,
        width: dims?.width,
        height: dims?.height,
        createdAt: Date.now(),
      });
      logManual(`slip:photo:${id}`);
    } finally {
      setProcessing(false);
    }
  }

  const canLog = tab === "scanned" ? count > 0 : manualCount > 0;

  return (
    <div className="rounded-2xl bg-surface border border-border/80 overflow-hidden shadow-xs">
      {/* Tab row */}
      <div className="flex border-b border-border/80 bg-background/50">
        {(["scanned", "manual"] as const).map((t) => (
          <button
            key={t}
            onClick={() => {
              vibrate("light");
              setTab(t);
            }}
            className={`flex-1 py-2.5 text-[10px] font-bold uppercase tracking-widest transition-all ${
              tab === t
                ? "text-foreground bg-surface font-black border-b-2 border-primary-glow shadow-xs"
                : "text-muted-foreground hover:text-foreground"
            }`}
          >
            {t === "scanned" ? "Scanned" : "Manual (No-NFC)"}
          </button>
        ))}
      </div>

      {/* Input row */}
      <div className="flex items-center gap-2 p-3">
        {/* Stepper */}
        <button
          onClick={() => {
            vibrate("light");
            tab === "scanned"
              ? setCount((c) => Math.max(0, c - 1))
              : setManualCount((c) => Math.max(1, c - 1));
          }}
          className="h-11 w-11 shrink-0 rounded-xl border border-border/80 bg-surface-elevated grid place-items-center active:scale-90 transition-transform text-muted-foreground hover:text-foreground shadow-xs"
        >
          <Minus size={18} />
        </button>

        <input
          type="number"
          inputMode="numeric"
          value={(tab === "scanned" ? count : manualCount) || ""}
          onChange={(e) => {
            const n = Math.max(tab === "scanned" ? 0 : 1, parseInt(e.target.value || "0", 10));
            tab === "scanned" ? setCount(n) : setManualCount(n);
          }}
          placeholder={tab === "scanned" ? "0" : "1"}
          className="h-11 w-14 shrink-0 rounded-xl border border-border/80 bg-surface-elevated text-center text-xl font-black tabular-nums outline-none focus:border-primary-glow shadow-inner"
        />

        <button
          onClick={() => {
            vibrate("light");
            tab === "scanned" ? setCount((c) => c + 1) : setManualCount((c) => c + 1);
          }}
          className="h-11 w-11 shrink-0 rounded-xl border border-border/80 bg-surface-elevated grid place-items-center active:scale-90 transition-transform text-muted-foreground hover:text-foreground shadow-xs"
        >
          <Plus size={18} />
        </button>

        {tab === "scanned" ? (
          /* Quick-add buttons */
          <div className="flex flex-1 gap-1.5 justify-end">
            {QUICK.map((n) => (
              <button
                key={n}
                onClick={() => {
                  vibrate("light");
                  setCount((c) => c + n);
                }}
                className="h-11 flex-1 rounded-xl border border-border/80 bg-surface-elevated hover:border-primary/50 text-xs font-black tabular-nums active:scale-90 transition-all shadow-xs hover:text-primary-glow"
              >
                +{n}
              </button>
            ))}
          </div>
        ) : (
          /* Slip input */
          <div className="flex flex-1 items-center gap-1.5">
            <input
              value={slipNumber}
              onChange={(e) => setSlipNumber(e.target.value)}
              placeholder="Slip #"
              className="h-11 flex-1 rounded-xl border border-border/80 bg-surface-elevated px-3 text-sm font-mono outline-none focus:border-orange-500 placeholder:text-muted-foreground/40"
            />
            {onAttachment && (
              <button
                onClick={() => {
                  vibrate("medium");
                  setShowCamera(true);
                }}
                disabled={processing}
                className="h-11 w-11 shrink-0 rounded-xl border border-dashed border-orange-500/50 text-orange-400 grid place-items-center hover:bg-orange-500/10 active:scale-90 transition-all disabled:opacity-40 shadow-xs"
              >
                <Camera size={18} />
              </button>
            )}
          </div>
        )}
      </div>

      {/* Log button */}
      <div className="px-3 pb-3">
        <button
          onClick={tab === "scanned" ? logScanned : () => logManual()}
          disabled={!canLog || processing}
          className={`w-full h-11 rounded-xl font-bold text-xs uppercase tracking-wider flex items-center justify-center gap-2 active:scale-95 transition-all disabled:opacity-30 cursor-pointer ${
            tab === "scanned"
              ? "bg-[image:var(--gradient-primary)] text-primary-foreground shadow-[var(--shadow-glow)]"
              : "bg-orange-500 text-white shadow-lg shadow-orange-500/25"
          }`}
        >
          <Check size={16} />
          {processing
            ? "Processing…"
            : tab === "scanned"
              ? `Log ${count > 0 ? count : ""} Scanned`
              : `Log ${manualCount} Manual`}
        </button>
      </div>

      {/* Camera overlay */}
      {showCamera && (
        <InAppCamera onCapture={handlePhotoCapture} onClose={() => setShowCamera(false)} />
      )}
    </div>
  );
}
