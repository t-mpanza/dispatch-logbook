import { createFileRoute, Link, useNavigate } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { Plus, Truck } from "lucide-react";
import { AppShell } from "@/components/AppShell";
import { createEntry, entriesWithCounter } from "@/lib/db";
import { fmtDayLabel, fmtTime } from "@/lib/format";

export const Route = createFileRoute("/counter")({
  head: () => ({ meta: [{ title: "Counter — Dispatch Diary" }] }),
  component: CounterIndex,
});

function CounterIndex() {
  const navigate = useNavigate();
  const { data: sessions = [], isLoading } = useQuery({
    queryKey: ["entries", "counter"],
    queryFn: entriesWithCounter,
  });

  async function startNew() {
    const e = await createEntry({
      title: `Tyre count – ${fmtTime(Date.now())}`,
      tags: ["tyres", "count"],
      withCounter: true,
    });
    navigate({ to: "/entry/$id", params: { id: e.id } });
  }

  return (
    <AppShell>
      <header className="px-5 pt-8 pb-4">
        <p className="text-xs uppercase tracking-[0.2em] text-primary-glow font-medium">
          Counter
        </p>
        <h1 className="mt-1 text-2xl font-semibold tracking-tight">Trip counting</h1>
        <p className="mt-1 text-sm text-muted-foreground">
          {sessions.length === 0
            ? "Start a session to log tyres trip-by-trip."
            : `${sessions.length} ${sessions.length === 1 ? "session" : "sessions"} recorded`}
        </p>
      </header>

      <div className="px-5">
        <button
          onClick={startNew}
          className="w-full flex items-center justify-center gap-2 h-14 rounded-2xl bg-[image:var(--gradient-primary)] text-primary-foreground font-semibold shadow-[var(--shadow-glow)] active:scale-[0.99] transition-transform"
        >
          <Plus size={20} /> Start new count session
        </button>
      </div>

      <div className="px-5 pt-6 space-y-2.5">
        {isLoading && <p className="text-sm text-muted-foreground">Loading…</p>}
        {!isLoading && sessions.length === 0 && (
          <div className="mt-2 rounded-2xl border border-dashed border-border p-6 text-center">
            <div className="mx-auto h-12 w-12 rounded-full bg-primary/15 text-primary-glow grid place-items-center">
              <Truck size={20} />
            </div>
            <p className="mt-3 text-sm text-muted-foreground">
              Each session has its own running total, history, notes and media.
            </p>
          </div>
        )}
        {sessions.map((s) => {
          const total = (s.trips ?? []).reduce((n, t) => n + t.count, 0);
          const trips = (s.trips ?? []).length;
          return (
            <Link
              key={s.id}
              to="/entry/$id"
              params={{ id: s.id }}
              className="block rounded-xl bg-surface border border-border p-4 hover:border-primary/40 transition-colors"
            >
              <div className="flex items-start justify-between gap-3">
                <div className="min-w-0">
                  <p className="font-mono text-sm font-semibold uppercase tracking-wider truncate">
                    {s.title}
                  </p>
                  <p className="text-xs text-muted-foreground mt-0.5">
                    {fmtDayLabel(s.createdAt)} · {fmtTime(s.createdAt)}
                  </p>
                </div>
                <div className="text-right shrink-0">
                  <p className="text-2xl font-bold tabular-nums text-primary-glow leading-none">
                    {total}
                  </p>
                  <p className="text-[10px] uppercase tracking-wider text-muted-foreground mt-1">
                    {trips} {trips === 1 ? "trip" : "trips"}
                  </p>
                </div>
              </div>
            </Link>
          );
        })}
      </div>
    </AppShell>
  );
}
