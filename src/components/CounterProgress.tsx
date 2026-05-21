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
    <div className="rounded-2xl overflow-hidden bg-[image:var(--gradient-primary)] text-primary-foreground relative shadow-[var(--shadow-glow)]">
      {/* Glow effect */}
      <div className="pointer-events-none absolute -right-10 -top-10 h-32 w-32 rounded-full bg-white/15 blur-2xl" />

      <div className="relative z-10 px-4 py-3 space-y-2">
        <div className="flex items-center justify-between">
          <div className="flex items-baseline gap-2">
            <span className="text-4xl font-black tabular-nums leading-none tracking-tight">
              {total}
            </span>
            {hasTarget && (
              <span className="text-xl font-bold opacity-60">/ {expectedTotal}</span>
            )}
          </div>

          <div className="text-right flex flex-col items-end">
            {!hasTarget && (
              <button
                onClick={() => { setDraft(expectedTotal?.toString() ?? ""); setEditing(true); }}
                className="flex items-center gap-1.5 rounded-lg bg-white/10 border border-white/20 px-2.5 py-1 text-xs font-bold hover:bg-white/20 active:scale-95 transition-all"
              >
                <Pencil size={11} /> Set target
              </button>
            )}

            {hasTarget && isComplete && (
              <span className="flex items-center gap-1 text-emerald-300 font-bold text-sm">
                <CheckCircle2 size={14} /> Complete
              </span>
            )}
            
            {hasTarget && isOver && (
              <span className="text-red-300 font-black text-sm uppercase tracking-wide">
                {over} Over
              </span>
            )}

            {hasTarget && !isComplete && !isOver && remaining !== null && (
              <span className="font-bold text-lg leading-none opacity-90 tabular-nums">
                {remaining} <span className="text-xs font-semibold opacity-70">left</span>
              </span>
            )}

            {hasTarget && !editing && (
              <button
                onClick={() => { setDraft(expectedTotal?.toString() ?? ""); setEditing(true); }}
                className="mt-0.5 text-[10px] uppercase font-bold opacity-50 hover:opacity-100 flex items-center gap-1 transition-opacity"
              >
                Edit target <Pencil size={9} />
              </button>
            )}
          </div>
        </div>

        {/* Target edit inline form */}
        {editing && (
          <div className="flex items-center gap-1 mt-1 justify-end animate-in fade-in slide-in-from-right-4 duration-200">
            <input
              type="number"
              inputMode="numeric"
              autoFocus
              value={draft}
              onChange={(e) => setDraft(e.target.value)}
              onKeyDown={(e) => e.key === "Enter" && commit()}
              placeholder="Total"
              className="w-16 rounded-lg bg-white/15 border border-white/30 px-2 py-1 text-sm font-bold text-white outline-none focus:border-white/60 text-center"
            />
            <button onClick={commit} className="rounded-lg bg-white/20 px-2 py-1 text-xs font-bold hover:bg-white/30 active:scale-95">
              Set
            </button>
            <button onClick={() => setEditing(false)} className="rounded-lg p-1 hover:bg-white/20">
              <X size={14} />
            </button>
          </div>
        )}

        {/* Progress bar */}
        {hasTarget && (
          <div className="h-1.5 mt-1 rounded-full bg-white/20 overflow-hidden">
            <div
              className={`h-full rounded-full transition-all duration-700 ${
                isOver ? "bg-red-400" : isComplete ? "bg-emerald-400" : "bg-white"
              }`}
              style={{ width: `${pct}%` }}
            />
          </div>
        )}
      </div>
    </div>
  );
}
