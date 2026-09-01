import { createFileRoute, Link, useNavigate } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { Plus, Truck, Clock } from "lucide-react";
import { AppShell } from "@/components/AppShell";
import { ThemeToggle } from "@/components/ThemeToggle";
import { createEntry, entriesWithCounter } from "@/lib/db";
import { calculateLoadingSheetTotals } from "@/lib/loading-presets";
import { fmtDayLabel, fmtTime } from "@/lib/format";
import { vibrate } from "@/lib/haptics";

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
    vibrate("success");
    const e = await createEntry({
      title: `Tyre count – ${fmtTime(Date.now())}`,
      tags: ["tyres", "count"],
      withCounter: true,
    });
    navigate({ to: "/entry/$id", params: { id: e.id } });
  }

  return (
    <AppShell>
      <header className="px-5 pt-[max(2.25rem,env(safe-area-inset-top))] pb-3 flex items-start justify-between">
        <div>
          <p className="text-[11px] uppercase tracking-[0.2em] text-primary-glow font-bold">Counter</p>
          <h1 className="mt-0.5 text-3xl font-extrabold tracking-tight text-slate-900 dark:text-slate-100 font-sans">Trip Counting</h1>
          <p className="mt-1 text-xs text-slate-500 dark:text-slate-400 font-medium">
            {sessions.length === 0
              ? "Start a session to log tyres trip-by-trip."
              : `${sessions.length} ${sessions.length === 1 ? "session" : "sessions"} recorded`}
          </p>
        </div>
        <ThemeToggle />
      </header>

      <div className="px-5">
        <button
          onClick={startNew}
          className="w-full flex items-center justify-center gap-2 h-13 rounded-2xl bg-blue-600 hover:bg-blue-500 text-white font-bold text-xs uppercase tracking-wider shadow-[0_8px_25px_rgba(37,99,235,0.4)] border-t border-white/20 ios-press cursor-pointer"
        >
          <Plus size={18} /> Start New Count Session
        </button>
      </div>

      <div className="px-5 pt-5 space-y-3 pb-28">
        {isLoading && <p className="text-xs text-slate-500 text-center py-8 font-mono">Loading sessions…</p>}
        {!isLoading && sessions.length === 0 && (
          <div className="mt-2 ios-glass-card p-6 text-center border-dashed">
            <div className="mx-auto h-12 w-12 rounded-full bg-blue-500/15 text-blue-600 dark:text-blue-400 grid place-items-center border border-blue-500/30">
              <Truck size={20} />
            </div>
            <p className="mt-3 text-xs text-slate-500 dark:text-slate-400 font-medium">
              Each session has its own running total, history, notes and media.
            </p>
          </div>
        )}
        {sessions.map((s) => {
          const loadingTrips = s.loadingSheetTrips ?? [];
          const legacyTrips = s.trips ?? [];

          let totalTyres = 0;
          let tripCount = 0;
          let totalMinutes = 0;

          if (loadingTrips.length > 0) {
            const totals = calculateLoadingSheetTotals(loadingTrips);
            totalTyres = totals.totalTyresLoaded;
            totalMinutes = totals.totalLoadingTimeMinutes;
            tripCount = loadingTrips.length;
          } else {
            totalTyres = legacyTrips.reduce((n, t) => n + t.count, 0);
            tripCount = legacyTrips.length;
          }

          return (
            <Link
              key={s.id}
              to="/entry/$id"
              params={{ id: s.id }}
              onClick={() => vibrate("light")}
              className="block ios-glass-card p-4 ios-press shadow-md"
            >
              <div className="flex items-start justify-between gap-3">
                <div className="min-w-0">
                  <p className="font-mono text-sm font-bold uppercase tracking-wider truncate text-slate-900 dark:text-slate-100">
                    {s.title}
                  </p>
                  <p className="text-xs text-slate-500 dark:text-slate-400 mt-0.5">
                    {fmtDayLabel(s.createdAt)} · {fmtTime(s.createdAt)}
                  </p>
                  {totalMinutes > 0 && (
                    <p className="text-[11px] text-slate-500 dark:text-slate-400 mt-1 flex items-center gap-1">
                      <Clock size={12} className="text-primary-glow" />
                      <span>{totalMinutes} min total loading duration</span>
                    </p>
                  )}
                </div>

                <div className="text-right shrink-0">
                  <span className="font-mono text-2xl font-black text-blue-600 dark:text-primary-glow">
                    {totalTyres}
                  </span>
                  <p className="text-[10px] uppercase font-bold tracking-wider text-slate-500 dark:text-slate-400">
                    {tripCount} {tripCount === 1 ? "truck" : "trucks"}
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
