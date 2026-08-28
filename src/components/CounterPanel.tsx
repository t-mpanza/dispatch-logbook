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
    <div className="ios-glass-elevated overflow-hidden shadow-2xl p-1.5 space-y-2.5">
      {/* iOS Segmented Control Tab Row */}
      <div className="p-1 rounded-xl bg-black/40 border border-white/[0.08] flex items-center gap-1">
        {(["scanned", "manual"] as const).map((t) => (
          <button
            key={t}
            onClick={() => {
              vibrate("light");
              setTab(t);
            }}
            className={`flex-1 py-1.5 text-[11px] font-bold uppercase tracking-wider rounded-lg transition-all duration-200 ios-press ${
              tab === t
                ? "bg-white/[0.12] text-slate-100 shadow-[0_2px_10px_rgba(0,0,0,0.3)] border border-white/20 font-black"
                : "text-slate-400 hover:text-slate-200"
            }`}
          >
            {t === "scanned" ? "Scanned" : "Manual (No-NFC)"}
          </button>
        ))}
      </div>

      {/* Input Row */}
      <div className="flex items-center gap-2 px-1">
        {/* Stepper Down */}
        <button
          onClick={() => {
            vibrate("light");
            tab === "scanned"
              ? setCount((c) => Math.max(0, c - 1))
              : setManualCount((c) => Math.max(1, c - 1));
          }}
          className="h-12 w-12 shrink-0 rounded-2xl bg-white/[0.06] border border-white/[0.1] grid place-items-center ios-press-bounce text-slate-300 hover:text-slate-100 shadow-md active:bg-white/[0.12]"
        >
          <Minus size={20} />
        </button>

        {/* Numeric Display */}
        <input
          type="number"
          inputMode="numeric"
          value={(tab === "scanned" ? count : manualCount) || ""}
          onChange={(e) => {
            const n = Math.max(tab === "scanned" ? 0 : 1, parseInt(e.target.value || "0", 10));
            tab === "scanned" ? setCount(n) : setManualCount(n);
          }}
          placeholder={tab === "scanned" ? "0" : "1"}
          className="h-12 w-16 shrink-0 rounded-2xl bg-black/40 border border-white/[0.1] text-center text-2xl font-black tabular-nums outline-none text-slate-100 focus:border-blue-500 shadow-inner font-mono"
        />

        {/* Stepper Up */}
        <button
          onClick={() => {
            vibrate("light");
            tab === "scanned" ? setCount((c) => c + 1) : setManualCount((c) => c + 1);
          }}
          className="h-12 w-12 shrink-0 rounded-2xl bg-white/[0.06] border border-white/[0.1] grid place-items-center ios-press-bounce text-slate-300 hover:text-slate-100 shadow-md active:bg-white/[0.12]"
        >
          <Plus size={20} />
        </button>

        {tab === "scanned" ? (
          /* iOS Quick-add Buttons */
          <div className="flex flex-1 gap-1.5 justify-end">
            {QUICK.map((n) => (
              <button
                key={n}
                onClick={() => {
                  vibrate("light");
                  setCount((c) => c + n);
                }}
                className="h-12 flex-1 rounded-2xl bg-white/[0.06] border border-white/[0.1] text-xs font-black tabular-nums text-slate-200 hover:text-blue-400 ios-press-bounce shadow-md active:bg-white/[0.14] flex items-center justify-center font-mono"
              >
                +{n}
              </button>
            ))}
          </div>
        ) : (
          /* Manual Slip Input */
          <div className="flex flex-1 items-center gap-1.5">
            <input
              value={slipNumber}
              onChange={(e) => setSlipNumber(e.target.value)}
              placeholder="Slip #"
              className="h-12 flex-1 rounded-2xl bg-black/40 border border-white/[0.1] px-3.5 text-sm font-mono outline-none text-slate-100 focus:border-amber-500 placeholder:text-slate-500"
            />
            {onAttachment && (
              <button
                onClick={() => {
                  vibrate("medium");
                  setShowCamera(true);
                }}
                disabled={processing}
                className="h-12 w-12 shrink-0 rounded-2xl border border-dashed border-amber-500/50 bg-amber-500/10 text-amber-400 grid place-items-center ios-press-bounce disabled:opacity-40 shadow-md"
              >
                <Camera size={20} />
              </button>
            )}
          </div>
        )}
      </div>

      {/* Log Action Button */}
      <div className="px-1 pb-1">
        <button
          onClick={tab === "scanned" ? logScanned : () => logManual()}
          disabled={!canLog || processing}
          className={`w-full h-12 rounded-2xl font-bold text-xs uppercase tracking-wider flex items-center justify-center gap-2 ios-press disabled:opacity-30 cursor-pointer shadow-xl ${
            tab === "scanned"
              ? "bg-blue-600 hover:bg-blue-500 text-white shadow-[0_8px_25px_rgba(37,99,235,0.4)] border-t border-white/25"
              : "bg-amber-600 hover:bg-amber-500 text-white shadow-[0_8px_25px_rgba(217,119,6,0.4)] border-t border-white/25"
          }`}
        >
          <Check size={18} />
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
