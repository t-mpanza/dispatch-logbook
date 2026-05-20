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
  const [note, setNote] = useState("");

  const total = trips.reduce((n, t) => n + t.count, 0);

  function add(n: number) {
    if (n <= 0) return;
    const t: Trip = {
      id: uid(),
      count: n,
      note: note.trim() || undefined,
      createdAt: Date.now(),
    };
    onChange([...trips, t]);
    setCount(0);
    setNote("");
  }

  function remove(id: string) {
    onChange(trips.filter((t) => t.id !== id));
  }

  function adjust(delta: number) {
    setCount((c) => Math.max(0, c + delta));
  }

  return (
    <div className="rounded-2xl bg-surface border border-border overflow-hidden">
      {/* Total */}
      <div className="px-4 pt-4 pb-3 bg-[image:var(--gradient-primary)] text-primary-foreground">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2 text-xs uppercase tracking-[0.18em] font-medium opacity-90">
            <Truck size={13} /> Trip counter
          </div>
          <div className="text-[11px] opacity-80 tabular-nums">
            {trips.length} {trips.length === 1 ? "trip" : "trips"}
          </div>
        </div>
        <div className="mt-1 flex items-baseline gap-2">
          <span className="text-5xl font-bold tabular-nums leading-none">{total}</span>
          <span className="text-xs uppercase tracking-wider opacity-80">total</span>
        </div>
      </div>

      {/* Adder */}
      <div className="p-4 space-y-3">
        <div className="flex items-center gap-2">
          <button
            onClick={() => adjust(-1)}
            className="h-12 w-12 rounded-xl bg-surface-elevated border border-border grid place-items-center active:scale-95"
            aria-label="Decrease"
          >
            <Minus size={18} />
          </button>
          <input
            type="number"
            inputMode="numeric"
            value={count || ""}
            onChange={(e) => setCount(Math.max(0, parseInt(e.target.value || "0", 10)))}
            placeholder="0"
            className="flex-1 h-12 rounded-xl bg-surface-elevated border border-border text-center text-2xl font-bold tabular-nums outline-none focus:border-primary"
          />
          <button
            onClick={() => adjust(1)}
            className="h-12 w-12 rounded-xl bg-surface-elevated border border-border grid place-items-center active:scale-95"
            aria-label="Increase"
          >
            <Plus size={18} />
          </button>
        </div>

        <div className="grid grid-cols-4 gap-2">
          {QUICK.map((n) => (
            <button
              key={n}
              onClick={() => setCount(n)}
              className="py-2 rounded-lg text-sm font-semibold bg-surface-elevated border border-border hover:border-primary/50 tabular-nums"
            >
              {n}
            </button>
          ))}
        </div>

        <input
          value={note}
          onChange={(e) => setNote(e.target.value)}
          placeholder="Optional note (e.g. driver, rejected: 2)"
          className="w-full h-10 px-3 rounded-lg bg-surface-elevated border border-border outline-none text-sm focus:border-primary placeholder:text-muted-foreground/70"
        />

        <button
          onClick={() => add(count)}
          disabled={count <= 0}
          className="w-full h-12 rounded-xl bg-primary text-primary-foreground font-semibold disabled:opacity-40 active:scale-[0.98] transition-transform"
        >
          Log trip {count > 0 ? `+${count}` : ""}
        </button>
      </div>

      {/* History */}
      {trips.length > 0 && (
        <div className="border-t border-border">
          <div className="px-4 pt-3 pb-1 text-[11px] uppercase tracking-wider text-muted-foreground font-medium">
            Trip history
          </div>
          <ul className="divide-y divide-border">
            {[...trips]
              .sort((a, b) => b.createdAt - a.createdAt)
              .map((t, i) => {
                const tripNum = trips.length - i;
                return (
                  <li key={t.id} className="flex items-center gap-3 px-4 py-2.5">
                    <div className="h-9 w-9 rounded-lg bg-primary/15 text-primary-glow grid place-items-center text-xs font-semibold tabular-nums">
                      #{tripNum}
                    </div>
                    <div className="min-w-0 flex-1">
                      <div className="flex items-baseline gap-2">
                        <span className="text-lg font-bold tabular-nums">+{t.count}</span>
                        <span className="text-[10px] text-muted-foreground tabular-nums">
                          {fmtTime(t.createdAt)}
                        </span>
                      </div>
                      {t.note && (
                        <p className="text-xs text-muted-foreground truncate">{t.note}</p>
                      )}
                    </div>
                    <button
                      onClick={() => remove(t.id)}
                      className="h-8 w-8 rounded-full grid place-items-center text-muted-foreground hover:text-destructive hover:bg-destructive/10"
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
