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
      <div className="pointer-events-none absolute -right-8 -top-8 h-32 w-32 rounded-full bg-blue-500/10 blur-2xl" />
      <div className="pointer-events-none absolute -left-8 -bottom-8 h-32 w-32 rounded-full bg-slate-500/10 blur-2xl" />

      <div className="relative z-10 space-y-2.5">
        <div className="flex items-center justify-between">
          <div className="flex items-baseline gap-2">
            <span className="text-4xl font-black tabular-nums leading-none tracking-tight text-slate-900 dark:text-slate-100 font-mono">
              {total}
            </span>
            {hasTarget && (
              <span className="text-lg font-bold text-slate-400 dark:text-slate-500 font-mono">/ {expectedTotal}</span>
            )}
            <span className="text-xs font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wider ml-1">
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
                className="flex items-center gap-1.5 rounded-full bg-slate-100 dark:bg-white/[0.06] border border-slate-200 dark:border-white/[0.1] px-3 py-1.5 text-xs font-bold text-slate-800 dark:text-slate-200 hover:bg-slate-200 dark:hover:bg-white/[0.12] ios-press shadow-sm"
              >
                <Pencil size={11} className="text-blue-600 dark:text-primary-glow" /> Set Target
              </button>
            )}

            {hasTarget && isComplete && (
              <span className="flex items-center gap-1 text-emerald-600 dark:text-emerald-400 font-bold text-sm bg-emerald-500/15 border border-emerald-500/30 px-2.5 py-0.5 rounded-full">
                <CheckCircle2 size={14} /> Complete
              </span>
            )}

            {hasTarget && isOver && (
              <span className="text-rose-600 dark:text-rose-400 font-black text-sm uppercase tracking-wide bg-rose-500/15 border border-rose-500/30 px-2.5 py-0.5 rounded-full">
                {over} Over
              </span>
            )}

            {hasTarget && !isComplete && !isOver && remaining !== null && (
              <span className="font-bold text-base leading-none text-slate-900 dark:text-slate-100 tabular-nums">
                {remaining} <span className="text-xs font-semibold text-slate-500 dark:text-slate-400">remaining</span>
              </span>
            )}

            {hasTarget && !editing && (
              <button
                onClick={() => {
                  vibrate("light");
                  setDraft(expectedTotal?.toString() ?? "");
                  setEditing(true);
                }}
                className="mt-1 text-[10px] uppercase font-bold text-slate-500 hover:text-slate-700 dark:hover:text-slate-300 flex items-center gap-1 transition-colors"
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
              className="w-20 rounded-xl bg-white dark:bg-black/40 border border-slate-300 dark:border-white/[0.1] px-3 py-1 text-sm font-bold text-slate-900 dark:text-slate-100 outline-none focus:border-blue-500 text-center font-mono"
            />
            <button
              onClick={commit}
              className="rounded-xl bg-blue-600 px-3 py-1 text-xs font-bold text-white hover:bg-blue-500 ios-press shadow-md"
            >
              Set
            </button>
            <button
              onClick={() => setEditing(false)}
              className="rounded-xl p-1.5 bg-slate-100 dark:bg-white/[0.06] hover:bg-slate-200 dark:hover:bg-white/[0.12] text-slate-600 dark:text-slate-400"
            >
              <X size={14} />
            </button>
          </div>
        )}

        {/* Liquid progress bar */}
        {hasTarget && (
          <div className="h-2 mt-1 rounded-full bg-slate-200/80 dark:bg-white/[0.08] border border-slate-300/60 dark:border-white/[0.06] overflow-hidden p-0.5 shadow-inner">
            <div
              className={`h-full rounded-full transition-all duration-500 ${
                isOver
                  ? "bg-rose-500 shadow-[0_0_12px_rgba(244,63,94,0.6)]"
                  : isComplete
                    ? "bg-emerald-500 shadow-[0_0_12px_rgba(52,211,153,0.6)]"
                    : "bg-gradient-to-r from-blue-600 to-blue-400 shadow-[0_0_12px_rgba(59,130,246,0.6)]"
              }`}
              style={{ width: `${pct}%` }}
            />
          </div>
        )}
      </div>
    </div>
  );
}
