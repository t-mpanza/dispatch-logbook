import { useState } from "react";
import { CheckCircle2, Pencil, X } from "lucide-react";

interface Props {
  total: number;
  tripCount: number;
  expectedTotal?: number;
  onSetExpected: (n: number | undefined) => void;
}

export function CounterProgress({ total, tripCount, expectedTotal, onSetExpected }: Props) {
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState("");

  const hasTarget = expectedTotal != null && expectedTotal > 0;
  const remaining = hasTarget ? expectedTotal! - total : null;
  const over = hasTarget && remaining !== null && remaining < 0 ? Math.abs(remaining) : 0;
  const pct = hasTarget ? Math.min((total / expectedTotal!) * 100, 100) : 0;
  const isComplete = hasTarget && remaining === 0;
  const isOver = over > 0;

  function commit() {
    const n = parseInt(draft, 10);
    onSetExpected(n > 0 ? n : undefined);
    setEditing(false);
  }

  return (
    <div className="rounded-2xl overflow-hidden bg-[image:var(--gradient-primary)] text-primary-foreground relative">
      {/* Glow */}
      <div className="pointer-events-none absolute -right-10 -top-10 h-36 w-36 rounded-full bg-white/10 blur-2xl" />

      <div className="relative z-10 px-5 pt-4 pb-3 space-y-3">
        {/* Main number row */}
        <div className="flex items-start justify-between">
          <div>
            <div className="flex items-baseline gap-3">
              <span className="text-6xl font-black tabular-nums leading-none tracking-tight">
                {total}
              </span>
              {hasTarget && (
                <span className="text-2xl font-bold opacity-50">/ {expectedTotal}</span>
              )}
            </div>

            {/* Status line — the important bit */}
            <div className="mt-1.5">
              {!hasTarget && (
                <p className="text-sm font-semibold opacity-70">
                  {tripCount} {tripCount === 1 ? "log" : "logs"} · Set a target to track progress
                </p>
              )}
              {hasTarget && isComplete && (
                <div className="flex items-center gap-1.5 text-emerald-300 font-bold text-sm">
                  <CheckCircle2 size={16} />
                  Complete — exact match
                </div>
              )}
              {hasTarget && isOver && (
                <p className="text-red-300 font-black text-lg tabular-nums">
                  {over} OVER TARGET
                </p>
              )}
              {hasTarget && !isComplete && !isOver && remaining !== null && (
                <p className="font-black text-3xl tabular-nums leading-none opacity-90">
                  {remaining}
                  <span className="text-sm font-semibold opacity-70 ml-1.5">remaining</span>
                </p>
              )}
            </div>
          </div>

          {/* Target edit */}
          {editing ? (
            <div className="flex items-center gap-1 mt-1">
              <input
                type="number"
                inputMode="numeric"
                autoFocus
                value={draft}
                onChange={(e) => setDraft(e.target.value)}
                onKeyDown={(e) => e.key === "Enter" && commit()}
                placeholder="Total"
                className="w-20 rounded-lg bg-white/15 border border-white/30 px-2 py-1.5 text-sm font-bold text-white outline-none focus:border-white/60 text-center"
              />
              <button onClick={commit} className="rounded-lg bg-white/20 px-2.5 py-1.5 text-xs font-bold hover:bg-white/30 active:scale-95">
                Set
              </button>
              <button onClick={() => setEditing(false)} className="rounded-lg p-1.5 hover:bg-white/20">
                <X size={14} />
              </button>
            </div>
          ) : (
            <button
              onClick={() => { setDraft(expectedTotal?.toString() ?? ""); setEditing(true); }}
              className="mt-1 flex items-center gap-1.5 rounded-xl bg-white/10 border border-white/20 px-3 py-1.5 text-xs font-bold hover:bg-white/20 active:scale-95 transition-all"
            >
              <Pencil size={11} />
              {hasTarget ? "Edit target" : "Set target"}
            </button>
          )}
        </div>

        {/* Progress bar */}
        {hasTarget && (
          <div className="h-2 rounded-full bg-white/20 overflow-hidden">
            <div
              className={`h-full rounded-full transition-all duration-700 ${
                isOver ? "bg-red-400" : isComplete ? "bg-emerald-400" : "bg-white/90"
              }`}
              style={{ width: `${pct}%` }}
            />
          </div>
        )}

        {/* Footer */}
        <p className="text-[10px] font-semibold opacity-60 uppercase tracking-wider">
          {tripCount} {tripCount === 1 ? "log" : "logs"} · Scanned + Manual combined
        </p>
      </div>
    </div>
  );
}
