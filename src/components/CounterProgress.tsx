import { useState } from "react";
import { CheckCircle2, Pencil, X } from "lucide-react";

interface Props {
  total: number;
  tripCount: number;
  expectedTotal?: number;
  onSetExpected: (n: number | undefined) => void;
}

export function CounterProgress({
  total,
  tripCount,
  expectedTotal,
  onSetExpected,
}: Props) {
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState("");

  const hasTarget = expectedTotal != null && expectedTotal > 0;
  const pct = hasTarget ? Math.min((total / expectedTotal!) * 100, 100) : 0;
  const over = hasTarget ? total - expectedTotal! : 0;
  const remaining = hasTarget ? expectedTotal! - total : 0;

  const barColor =
    !hasTarget || total < expectedTotal!
      ? "bg-primary"
      : total === expectedTotal
        ? "bg-emerald-500"
        : "bg-red-500";

  function startEdit() {
    setDraft(expectedTotal?.toString() ?? "");
    setEditing(true);
  }

  function commitEdit() {
    const n = parseInt(draft, 10);
    onSetExpected(n > 0 ? n : undefined);
    setEditing(false);
  }

  return (
    <div className="rounded-2xl bg-[image:var(--gradient-primary)] text-primary-foreground px-5 py-4 space-y-3 relative overflow-hidden shadow-[var(--shadow-glow)]">
      {/* Glow blob */}
      <div className="pointer-events-none absolute -right-12 -top-12 h-40 w-40 rounded-full bg-white/10 blur-2xl" />

      {/* Numbers row */}
      <div className="flex items-end justify-between relative z-10">
        <div className="flex items-baseline gap-2">
          <span className="text-5xl font-black tabular-nums leading-none">
            {total}
          </span>
          {hasTarget && (
            <span className="text-lg font-semibold opacity-70">
              / {expectedTotal}
            </span>
          )}
        </div>

        {/* Status badge */}
        <div className="flex flex-col items-end gap-0.5">
          {hasTarget && over > 0 && (
            <span className="rounded-full bg-red-500/30 border border-red-400/40 px-2.5 py-1 text-xs font-bold text-red-200">
              {over} OVER
            </span>
          )}
          {hasTarget && over === 0 && remaining > 0 && (
            <span className="rounded-full bg-white/10 border border-white/20 px-2.5 py-1 text-xs font-semibold opacity-90">
              {remaining} left
            </span>
          )}
          {hasTarget && remaining === 0 && over === 0 && (
            <span className="flex items-center gap-1 rounded-full bg-emerald-500/30 border border-emerald-400/40 px-2.5 py-1 text-xs font-bold text-emerald-200">
              <CheckCircle2 size={12} /> Complete
            </span>
          )}
        </div>
      </div>

      {/* Progress bar */}
      {hasTarget && (
        <div className="relative z-10 h-1.5 rounded-full bg-white/20 overflow-hidden">
          <div
            className={`h-full rounded-full transition-all duration-500 ${barColor}`}
            style={{ width: `${pct}%` }}
          />
        </div>
      )}

      {/* Footer row */}
      <div className="relative z-10 flex items-center justify-between">
        <span className="text-[11px] font-medium opacity-70">
          {tripCount} {tripCount === 1 ? "log" : "logs"} · Scanned + Manual
        </span>

        {/* Expected total edit */}
        {editing ? (
          <div className="flex items-center gap-1">
            <input
              type="number"
              inputMode="numeric"
              autoFocus
              value={draft}
              onChange={(e) => setDraft(e.target.value)}
              onKeyDown={(e) => e.key === "Enter" && commitEdit()}
              placeholder="Expected"
              className="w-20 rounded-lg bg-white/15 border border-white/30 px-2 py-1 text-xs font-bold text-white placeholder:text-white/40 outline-none focus:border-white/60 text-center"
            />
            <button
              onClick={commitEdit}
              className="rounded-lg bg-white/20 px-2 py-1 text-xs font-bold hover:bg-white/30 active:scale-95"
            >
              Set
            </button>
            <button
              onClick={() => setEditing(false)}
              className="rounded-lg p-1 hover:bg-white/20 active:scale-95"
            >
              <X size={14} />
            </button>
          </div>
        ) : (
          <button
            onClick={startEdit}
            className="flex items-center gap-1 rounded-lg bg-white/10 border border-white/20 px-2.5 py-1 text-[11px] font-semibold hover:bg-white/20 active:scale-95 transition-all"
          >
            <Pencil size={11} />
            {hasTarget ? `Target: ${expectedTotal}` : "Set target"}
          </button>
        )}
      </div>
    </div>
  );
}
