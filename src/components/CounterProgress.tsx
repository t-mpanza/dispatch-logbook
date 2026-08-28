import { useState } from "react";
import { CheckCircle2, Pencil, X } from "lucide-react";
import { vibrate } from "@/lib/haptics";

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
    vibrate("light");
    const n = parseInt(draft, 10);
    onSetExpected(n > 0 ? n : undefined);
    setEditing(false);
  }

  return (
    <div className="ios-glass-elevated overflow-hidden relative shadow-2xl p-4">
      {/* Specular ambient lights */}
      <div className="pointer-events-none absolute -right-8 -top-8 h-32 w-32 rounded-full bg-primary/20 blur-2xl" />
      <div className="pointer-events-none absolute -left-8 -bottom-8 h-32 w-32 rounded-full bg-purple-500/15 blur-2xl" />

      <div className="relative z-10 space-y-2.5">
        <div className="flex items-center justify-between">
          <div className="flex items-baseline gap-2">
            <span className="text-4xl font-black tabular-nums leading-none tracking-tight text-white font-mono">
              {total}
            </span>
            {hasTarget && (
              <span className="text-lg font-bold text-white/50 font-mono">/ {expectedTotal}</span>
            )}
            <span className="text-xs font-semibold text-white/40 uppercase tracking-wider ml-1">
              tyres
            </span>
          </div>

          <div className="text-right flex flex-col items-end">
            {!hasTarget && (
              <button
                onClick={() => {
                  vibrate("light");
                  setDraft(expectedTotal?.toString() ?? "");
                  setEditing(true);
                }}
                className="flex items-center gap-1.5 rounded-full bg-white/[0.08] border border-white/[0.14] px-3 py-1.5 text-xs font-bold text-white hover:bg-white/[0.15] ios-press shadow-md"
              >
                <Pencil size={11} className="text-primary-glow" /> Set Target
              </button>
            )}

            {hasTarget && isComplete && (
              <span className="flex items-center gap-1 text-emerald-400 font-bold text-sm bg-emerald-500/15 border border-emerald-500/30 px-2.5 py-0.5 rounded-full">
                <CheckCircle2 size={14} /> Complete
              </span>
            )}

            {hasTarget && isOver && (
              <span className="text-rose-400 font-black text-sm uppercase tracking-wide bg-rose-500/15 border border-rose-500/30 px-2.5 py-0.5 rounded-full">
                {over} Over
              </span>
            )}

            {hasTarget && !isComplete && !isOver && remaining !== null && (
              <span className="font-bold text-base leading-none text-white/90 tabular-nums">
                {remaining} <span className="text-xs font-semibold text-white/50">remaining</span>
              </span>
            )}

            {hasTarget && !editing && (
              <button
                onClick={() => {
                  vibrate("light");
                  setDraft(expectedTotal?.toString() ?? "");
                  setEditing(true);
                }}
                className="mt-1 text-[10px] uppercase font-bold text-white/40 hover:text-white flex items-center gap-1 transition-colors"
              >
                Edit target <Pencil size={9} />
              </button>
            )}
          </div>
        </div>

        {/* Target edit inline form */}
        {editing && (
          <div className="flex items-center gap-1.5 mt-1 justify-end animate-fade-in-scale">
            <input
              type="number"
              inputMode="numeric"
              autoFocus
              value={draft}
              onChange={(e) => setDraft(e.target.value)}
              onKeyDown={(e) => e.key === "Enter" && commit()}
              placeholder="Target"
              className="w-20 rounded-xl bg-black/40 border border-white/[0.2] px-3 py-1 text-sm font-bold text-white outline-none focus:border-primary-glow text-center font-mono"
            />
            <button
              onClick={commit}
              className="rounded-xl bg-primary px-3 py-1 text-xs font-bold text-white hover:bg-primary/90 ios-press shadow-md"
            >
              Set
            </button>
            <button
              onClick={() => setEditing(false)}
              className="rounded-xl p-1.5 bg-white/[0.08] hover:bg-white/[0.15] text-white/70"
            >
              <X size={14} />
            </button>
          </div>
        )}

        {/* Liquid progress bar */}
        {hasTarget && (
          <div className="h-2 mt-1 rounded-full bg-white/[0.1] border border-white/[0.08] overflow-hidden p-0.5 shadow-inner">
            <div
              className={`h-full rounded-full transition-all duration-500 ${
                isOver
                  ? "bg-rose-500 shadow-[0_0_12px_rgba(244,63,94,0.7)]"
                  : isComplete
                    ? "bg-emerald-400 shadow-[0_0_12px_rgba(52,211,153,0.7)]"
                    : "bg-gradient-to-r from-indigo-500 to-violet-400 shadow-[0_0_12px_rgba(139,92,246,0.7)]"
              }`}
              style={{ width: `${pct}%` }}
            />
          </div>
        )}
      </div>
    </div>
  );
}
