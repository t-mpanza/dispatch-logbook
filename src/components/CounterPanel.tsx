import { useState } from "react";
import { Camera, Check, Minus, Plus, Trash2, Truck } from "lucide-react";
import type { Attachment, Trip } from "@/lib/types";
import { fmtTime, uid } from "@/lib/format";
import { InAppCamera } from "./InAppCamera";
import { downscaleImage, getImageDimensions } from "@/lib/image";

interface Props {
  trips: Trip[];
  onChange: (next: Trip[]) => void;
  onAttachment?: (a: Attachment) => void;
}

const QUICK = [4, 8, 10, 12];

export function CounterPanel({ trips, onChange, onAttachment }: Props) {
  const [activeTab, setActiveTab] = useState<"scanned" | "manual">("scanned");
  
  // Scanned State
  const [scannedCount, setScannedCount] = useState<number>(0);
  
  // Manual State
  const [manualCount, setManualCount] = useState<number>(1);
  const [slipNumber, setSlipNumber] = useState("");
  
  // Camera State
  const [showCamera, setShowCamera] = useState(false);
  const [processingPhoto, setProcessingPhoto] = useState(false);

  const totalScanned = trips.reduce((n, t) => n + t.count, 0);
  const totalManual = trips.reduce((n, t) => n + (t.rejected || 0), 0);
  const grandTotal = totalScanned + totalManual;

  function logScanned() {
    if (scannedCount <= 0) return;
    const t: Trip = {
      id: uid(),
      count: scannedCount,
      createdAt: Date.now(),
    };
    onChange([...trips, t]);
    setScannedCount(0);
  }

  function logManual(slipText?: string) {
    if (manualCount <= 0) return;
    const t: Trip = {
      id: uid(),
      count: 0,
      rejected: manualCount,
      note: slipText || slipNumber.trim() || undefined,
      createdAt: Date.now(),
    };
    onChange([...trips, t]);
    setManualCount(1);
    setSlipNumber("");
  }

  async function handlePhotoCapture(blob: Blob) {
    setShowCamera(false);
    setProcessingPhoto(true);
    try {
      const scaled = await downscaleImage(blob, `slip-${Date.now()}.jpg`);
      const dims = await getImageDimensions(scaled);
      const name = `slip-${Date.now()}.jpg`;
      if (onAttachment) {
        onAttachment({
          id: uid(),
          kind: "image",
          blob: scaled,
          mime: scaled.type || "image/jpeg",
          name,
          width: dims?.width,
          height: dims?.height,
          createdAt: Date.now(),
        });
      }
      logManual(`Slip attached: ${name}`);
    } catch (err) {
      console.error("Photo capture failed:", err);
    } finally {
      setProcessingPhoto(false);
    }
  }

  function remove(id: string) {
    onChange(trips.filter((t) => t.id !== id));
  }

  return (
    <div className="rounded-2xl bg-surface border border-border overflow-hidden shadow-md relative">
      {/* Total Header */}
      <div className="px-5 pt-5 pb-5 bg-[image:var(--gradient-primary)] text-primary-foreground relative overflow-hidden">
        {/* Glow effect */}
        <div className="absolute top-0 right-0 -mr-16 -mt-16 w-48 h-48 rounded-full bg-white/10 blur-2xl pointer-events-none" />
        
        <div className="flex items-center justify-between relative z-10">
          <div className="flex items-center gap-2 text-[10px] uppercase tracking-[0.2em] font-bold opacity-90">
            <Truck size={14} /> Total Tyres
          </div>
          <div className="text-xs font-medium opacity-80 tabular-nums bg-white/10 px-2.5 py-1 rounded-full">
            {trips.length} {trips.length === 1 ? "log" : "logs"}
          </div>
        </div>
        
        <div className="mt-3 relative z-10">
          <div className="text-6xl font-black tabular-nums leading-none tracking-tight">
            {grandTotal}
          </div>
          <div className="flex gap-4 mt-3 text-xs font-semibold opacity-90">
            <div className="flex items-center gap-1.5">
               <span className="w-2 h-2 rounded-full bg-white/80 shadow-[0_0_8px_rgba(255,255,255,0.6)]" />
               {totalScanned} Scanned
            </div>
            <div className="flex items-center gap-1.5">
               <span className="w-2 h-2 rounded-full bg-orange-400 shadow-[0_0_8px_rgba(251,146,60,0.6)]" />
               {totalManual} Manual
            </div>
          </div>
        </div>
      </div>

      {/* Tabs */}
      <div className="flex p-2 gap-1 bg-surface-elevated/50 border-b border-border">
        <button
          onClick={() => setActiveTab("scanned")}
          className={`flex-1 py-2 text-xs font-bold uppercase tracking-wider rounded-lg transition-all ${
            activeTab === "scanned" 
              ? "bg-surface shadow-sm text-foreground" 
              : "text-muted-foreground hover:bg-surface/50 hover:text-foreground"
          }`}
        >
          Scanned
        </button>
        <button
          onClick={() => setActiveTab("manual")}
          className={`flex-1 py-2 text-xs font-bold uppercase tracking-wider rounded-lg transition-all ${
            activeTab === "manual" 
              ? "bg-surface shadow-sm text-foreground" 
              : "text-muted-foreground hover:bg-surface/50 hover:text-foreground"
          }`}
        >
          Manual (No-NFC)
        </button>
      </div>

      {/* Input Area */}
      <div className="p-4 bg-surface">
        {activeTab === "scanned" ? (
          <div className="space-y-4 animate-in fade-in slide-in-from-right-4 duration-300">
            <div className="flex items-center gap-2">
              <button
                type="button"
                onClick={() => setScannedCount((c) => Math.max(0, c - 1))}
                className="h-12 w-12 rounded-xl bg-surface-elevated border border-border grid place-items-center active:scale-95 hover:border-primary/50 transition-all text-muted-foreground hover:text-foreground"
                aria-label="Decrease"
              >
                <Minus size={18} />
              </button>
              <input
                type="number"
                inputMode="numeric"
                value={scannedCount || ""}
                onChange={(e) => setScannedCount(Math.max(0, parseInt(e.target.value || "0", 10)))}
                placeholder="0"
                className="flex-1 h-12 w-full rounded-xl bg-surface-elevated border border-border text-center text-2xl font-black tabular-nums outline-none focus:border-primary focus:ring-1 focus:ring-primary shadow-inner"
              />
              <button
                type="button"
                onClick={() => setScannedCount((c) => c + 1)}
                className="h-12 w-12 rounded-xl bg-surface-elevated border border-border grid place-items-center active:scale-95 hover:border-primary/50 transition-all text-muted-foreground hover:text-foreground"
                aria-label="Increase"
              >
                <Plus size={18} />
              </button>
            </div>

            <div className="grid grid-cols-4 gap-2">
              {QUICK.map((n) => (
                <button
                  key={n}
                  type="button"
                  onClick={() => setScannedCount(n)}
                  className="py-2.5 rounded-xl text-sm font-bold bg-surface-elevated border border-border hover:border-primary/50 active:scale-95 transition-all tabular-nums text-foreground/90"
                >
                  +{n}
                </button>
              ))}
            </div>

            <button
              type="button"
              onClick={() => logScanned()}
              disabled={scannedCount <= 0}
              className="w-full h-12 rounded-xl bg-primary text-primary-foreground font-bold text-sm tracking-wide uppercase disabled:opacity-30 active:scale-[0.98] transition-all shadow-[var(--shadow-glow)] flex items-center justify-center gap-2"
            >
              <Check size={18} /> Log Scanned Tyres
            </button>
          </div>
        ) : (
          <div className="space-y-4 animate-in fade-in slide-in-from-left-4 duration-300">
             <div className="flex items-center justify-between">
              <label className="text-xs font-semibold text-muted-foreground whitespace-nowrap">Tyre Count</label>
              <div className="flex items-center gap-1 ml-auto">
                <button
                  type="button"
                  onClick={() => setManualCount((c) => Math.max(1, c - 1))}
                  className="h-9 w-9 rounded-lg bg-surface-elevated border border-border grid place-items-center active:scale-95 text-muted-foreground hover:bg-surface-elevated/80"
                >
                  <Minus size={14} />
                </button>
                <input
                  type="number"
                  inputMode="numeric"
                  value={manualCount || ""}
                  onChange={(e) => setManualCount(Math.max(1, parseInt(e.target.value || "1", 10)))}
                  className="w-16 h-9 rounded-lg bg-surface-elevated border border-border text-center text-lg font-bold tabular-nums outline-none focus:border-orange-500 text-orange-400"
                />
                <button
                  type="button"
                  onClick={() => setManualCount((c) => c + 1)}
                  className="h-9 w-9 rounded-lg bg-surface-elevated border border-border grid place-items-center active:scale-95 text-muted-foreground hover:bg-surface-elevated/80"
                >
                  <Plus size={14} />
                </button>
              </div>
            </div>

            <div className="space-y-2">
              <label className="text-[10px] uppercase tracking-wider font-bold text-muted-foreground">Slip Number</label>
              <input
                value={slipNumber}
                onChange={(e) => setSlipNumber(e.target.value)}
                placeholder="Enter manual slip #"
                className="w-full h-11 px-3 rounded-xl bg-surface-elevated border border-border outline-none text-sm focus:border-orange-500 placeholder:text-muted-foreground/50 transition-colors"
              />
            </div>

            <div className="flex gap-2">
              {onAttachment && (
                <button
                  type="button"
                  onClick={() => setShowCamera(true)}
                  disabled={processingPhoto}
                  className="h-12 px-4 rounded-xl border border-dashed border-orange-500/50 text-orange-400 font-semibold hover:bg-orange-500/10 active:scale-95 transition-all flex items-center justify-center shrink-0 disabled:opacity-50"
                  aria-label="Capture Slip Photo"
                >
                  <Camera size={20} />
                </button>
              )}
              <button
                type="button"
                onClick={() => logManual()}
                disabled={manualCount <= 0 || processingPhoto}
                className="flex-1 h-12 rounded-xl bg-orange-500 text-white font-bold text-sm tracking-wide uppercase disabled:opacity-30 active:scale-[0.98] transition-all shadow-lg shadow-orange-500/20 flex items-center justify-center gap-2"
              >
                 <Check size={18} /> {processingPhoto ? "Processing..." : "Log Manual"}
              </button>
            </div>
          </div>
        )}
      </div>

      {/* History */}
      {trips.length > 0 && (
        <div className="border-t border-border bg-surface-elevated/30">
          <div className="px-5 pt-4 pb-2 text-[10px] uppercase tracking-wider text-muted-foreground font-bold flex justify-between items-center">
            <span>Recent Logs</span>
            <span className="opacity-70">Newest first</span>
          </div>
          <ul className="divide-y divide-border/60">
            {[...trips]
              .sort((a, b) => b.createdAt - a.createdAt)
              .map((t) => {
                const isScanned = t.count > 0;
                return (
                  <li key={t.id} className="flex items-start gap-3 px-5 py-3 hover:bg-surface-elevated/40 transition-colors">
                    <div className={`mt-1.5 h-2 w-2 rounded-full shrink-0 ${isScanned ? 'bg-primary-glow shadow-[0_0_8px_rgba(255,255,255,0.4)]' : 'bg-orange-400 shadow-[0_0_8px_rgba(251,146,60,0.4)]'}`} />
                    <div className="min-w-0 flex-1">
                      <div className="flex items-center justify-between">
                        <span className="text-sm font-bold tabular-nums text-foreground">
                          {isScanned ? `+${t.count} Scanned` : `+${t.rejected} Manual`}
                        </span>
                        <span className="text-[10px] text-muted-foreground/70 tabular-nums">
                          {fmtTime(t.createdAt)}
                        </span>
                      </div>
                      {t.note && (
                        <p className={`text-xs mt-1 font-medium ${isScanned ? 'text-muted-foreground' : 'text-orange-400/80'}`}>{t.note}</p>
                      )}
                    </div>
                    <button
                      type="button"
                      onClick={() => remove(t.id)}
                      className="h-7 w-7 rounded-lg grid place-items-center text-muted-foreground/50 hover:text-destructive hover:bg-destructive/10 transition-colors shrink-0"
                      aria-label="Remove log"
                    >
                      <Trash2 size={14} />
                    </button>
                  </li>
                );
              })}
          </ul>
        </div>
      )}

      {/* Camera overlay */}
      {showCamera && (
        <InAppCamera
          onCapture={handlePhotoCapture}
          onClose={() => setShowCamera(false)}
          onFallback={() => {
            setShowCamera(false);
          }}
        />
      )}
    </div>
  );
}
