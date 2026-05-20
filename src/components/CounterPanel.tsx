import { useState } from "react";
import { Minus, Plus, Trash2, Truck } from "lucide-react";
import type { Trip } from "@/lib/types";
import { fmtTime, uid } from "@/lib/format";

interface Props {
  trips: Trip[];
  onChange: (next: Trip[]) => void;
}

const QUICK = [4, 8, 10, 12];

export function CounterPanel({ trips, onChange }: Props) {
  const [count, setCount] = useState<number>(0);
  const [rejectedCount, setRejectedCount] = useState<number>(0);
  const [note, setNote] = useState("");

  const totalAccepted = trips.reduce((n, t) => n + t.count, 0);
  const totalRejected = trips.reduce((n, t) => n + (t.rejected || 0), 0);

  function add(c: number, r: number) {
    if (c <= 0 && r <= 0) return;
    const t: Trip = {
      id: uid(),
      count: c,
      rejected: r > 0 ? r : undefined,
      note: note.trim() || undefined,
      createdAt: Date.now(),
    };
    onChange([...trips, t]);
    setCount(0);
    setRejectedCount(0);
    setNote("");
  }

  function remove(id: string) {
    onChange(trips.filter((t) => t.id !== id));
  }

  return (
    <div className="rounded-2xl bg-surface border border-border overflow-hidden shadow-md">
      {/* Total Header */}
      <div className="px-4 pt-4 pb-4 bg-[image:var(--gradient-primary)] text-primary-foreground">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2 text-xs uppercase tracking-[0.18em] font-medium opacity-90">
            <Truck size={13} /> Trip counter
          </div>
          <div className="text-[11px] opacity-80 tabular-nums">
            {trips.length} {trips.length === 1 ? "trip" : "trips"}
          </div>
        </div>
        <div className="mt-2 flex items-baseline justify-between">
          <div className="flex items-baseline gap-2">
            <span className="text-5xl font-bold tabular-nums leading-none">{totalAccepted}</span>
            <span className="text-xs uppercase tracking-wider opacity-85">accepted</span>
          </div>
          {totalRejected > 0 && (
            <div className="bg-red-950/40 text-red-200 border border-red-500/30 rounded-full px-3 py-1 flex items-center gap-1.5 text-xs font-semibold">
              <span className="w-1.5 h-1.5 rounded-full bg-red-500 animate-pulse" />
              {totalRejected} rejected
            </div>
          )}
        </div>
      </div>

      {/* Adder Controls */}
      <div className="p-4 space-y-4">
        <div className="grid grid-cols-2 gap-4">
          {/* Accepted Counter */}
          <div className="space-y-1.5">
            <label className="text-[10px] uppercase font-bold text-muted-foreground tracking-wider block">
              Accepted Tyres
            </label>
            <div className="flex items-center gap-1">
              <button
                type="button"
                onClick={() => setCount((c) => Math.max(0, c - 1))}
                className="h-10 w-10 rounded-lg bg-surface-elevated border border-border grid place-items-center active:scale-95 hover:bg-surface-elevated/80 transition-colors"
                aria-label="Decrease accepted"
              >
                <Minus size={14} />
              </button>
              <input
                type="number"
                inputMode="numeric"
                value={count || ""}
                onChange={(e) => setCount(Math.max(0, parseInt(e.target.value || "0", 10)))}
                placeholder="0"
                className="flex-1 h-10 w-full rounded-lg bg-surface-elevated border border-border text-center text-lg font-bold tabular-nums outline-none focus:border-primary"
              />
              <button
                type="button"
                onClick={() => setCount((c) => c + 1)}
                className="h-10 w-10 rounded-lg bg-surface-elevated border border-border grid place-items-center active:scale-95 hover:bg-surface-elevated/80 transition-colors"
                aria-label="Increase accepted"
              >
                <Plus size={14} />
              </button>
            </div>
          </div>

          {/* Rejected Counter */}
          <div className="space-y-1.5">
            <label className="text-[10px] uppercase font-bold text-red-400 tracking-wider block">
              Rejected Tyres
            </label>
            <div className="flex items-center gap-1">
              <button
                type="button"
                onClick={() => setRejectedCount((r) => Math.max(0, r - 1))}
                className="h-10 w-10 rounded-lg bg-surface-elevated border border-border grid place-items-center active:scale-95 hover:bg-surface-elevated/80 text-red-400/80 transition-colors"
                aria-label="Decrease rejected"
              >
                <Minus size={14} />
              </button>
              <input
                type="number"
                inputMode="numeric"
                value={rejectedCount || ""}
                onChange={(e) => setRejectedCount(Math.max(0, parseInt(e.target.value || "0", 10)))}
                placeholder="0"
                className="flex-1 h-10 w-full rounded-lg bg-surface-elevated border border-border text-center text-lg font-bold text-red-400 tabular-nums outline-none focus:border-red-500"
              />
              <button
                type="button"
                onClick={() => setRejectedCount((r) => r + 1)}
                className="h-10 w-10 rounded-lg bg-surface-elevated border border-border grid place-items-center active:scale-95 hover:bg-surface-elevated/80 text-red-400/80 transition-colors"
                aria-label="Increase rejected"
              >
                <Plus size={14} />
              </button>
            </div>
          </div>
        </div>

        {/* Quick select buttons (for Accepted count) */}
        <div className="grid grid-cols-4 gap-2">
          {QUICK.map((n) => (
            <button
              key={n}
              type="button"
              onClick={() => setCount(n)}
              className="py-1.5 rounded-lg text-xs font-semibold bg-surface-elevated border border-border hover:border-primary/50 hover:bg-surface-elevated/80 active:scale-95 transition-all tabular-nums"
            >
              +{n}
            </button>
          ))}
        </div>

        {/* Optional note */}
        <input
          value={note}
          onChange={(e) => setNote(e.target.value)}
          placeholder="Optional note (e.g. forklift driver name, batch #)"
          className="w-full h-10 px-3 rounded-lg bg-surface-elevated border border-border outline-none text-sm focus:border-primary placeholder:text-muted-foreground/60"
        />

        {/* Log Action Button */}
        <button
          type="button"
          onClick={() => add(count, rejectedCount)}
          disabled={count <= 0 && rejectedCount <= 0}
          className="w-full h-11 rounded-xl bg-primary text-primary-foreground font-semibold disabled:opacity-40 active:scale-[0.98] transition-all flex items-center justify-center gap-1"
        >
          Log trip
          {(count > 0 || rejectedCount > 0) && (
            <span className="text-xs opacity-90 font-medium">
              ({count > 0 ? `+${count} acc` : ""}{count > 0 && rejectedCount > 0 ? ", " : ""}{rejectedCount > 0 ? `+${rejectedCount} rej` : ""})
            </span>
          )}
        </button>
      </div>

      {/* History */}
      {trips.length > 0 && (
        <div className="border-t border-border">
          <div className="px-4 pt-3 pb-1.5 text-[10px] uppercase tracking-wider text-muted-foreground font-bold">
            Trip history
          </div>
          <ul className="divide-y divide-border/60">
            {[...trips]
              .sort((a, b) => b.createdAt - a.createdAt)
              .map((t, i) => {
                const tripNum = trips.length - i;
                return (
                  <li key={t.id} className="flex items-center gap-3 px-4 py-2.5 hover:bg-surface-elevated/20 transition-colors">
                    <div className="h-9 w-9 rounded-lg bg-primary/10 text-primary-glow border border-primary/20 grid place-items-center text-xs font-bold tabular-nums">
                      #{tripNum}
                    </div>
                    <div className="min-w-0 flex-1">
                      <div className="flex items-baseline gap-1.5 flex-wrap">
                        <span className="text-base font-bold tabular-nums text-foreground">
                          +{t.count} accepted
                        </span>
                        {t.rejected && t.rejected > 0 ? (
                          <span className="text-xs font-semibold text-red-400">
                            ({t.rejected} rejected)
                          </span>
                        ) : null}
                        <span className="text-[10px] text-muted-foreground/70 tabular-nums ml-auto">
                          {fmtTime(t.createdAt)}
                        </span>
                      </div>
                      {t.note && (
                        <p className="text-xs text-muted-foreground truncate mt-0.5">{t.note}</p>
                      )}
                    </div>
                    <button
                      type="button"
                      onClick={() => remove(t.id)}
                      className="h-8 w-8 rounded-lg grid place-items-center text-muted-foreground hover:text-destructive hover:bg-destructive/10 transition-colors"
                      aria-label="Remove trip"
                    >
                      <Trash2 size={14} />
                    </button>
                  </li>
                );
              })}
          </ul>
        </div>
      )}
    </div>
  );
}
