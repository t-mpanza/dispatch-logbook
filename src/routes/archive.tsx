import { createFileRoute, Link } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { useMemo } from "react";
import { ChevronRight, Folder } from "lucide-react";
import { AppShell } from "@/components/AppShell";
import { ThemeToggle } from "@/components/ThemeToggle";
import { allEntries } from "@/lib/db";
import type { Entry } from "@/lib/types";
import { fmtMonth, fmtShortDay, weekNumber, weekRangeLabel } from "@/lib/format";
import { vibrate } from "@/lib/haptics";
import { parseISO } from "date-fns";

export const Route = createFileRoute("/archive")({
  head: () => ({ meta: [{ title: "Archive — Dispatch Diary" }] }),
  component: ArchivePage,
});

interface Grouped {
  year: string;
  months: {
    monthKey: string;
    monthLabel: string;
    weeks: {
      weekNum: number;
      weekLabel: string;
      days: {
        dayKey: string;
        dayLabel: string;
        entries: Entry[];
      }[];
    }[];
  }[];
}

function groupEntries(entries: Entry[]): Grouped[] {
  const byYear = new Map<string, Entry[]>();
  for (const e of entries) {
    if (!byYear.has(e.yearKey)) byYear.set(e.yearKey, []);
    byYear.get(e.yearKey)!.push(e);
  }
  const years: Grouped[] = [];
  Array.from(byYear.keys())
    .sort((a, b) => b.localeCompare(a))
    .forEach((year) => {
      const yEntries = byYear.get(year)!;
      const byMonth = new Map<string, Entry[]>();
      yEntries.forEach((e) => {
        if (!byMonth.has(e.monthKey)) byMonth.set(e.monthKey, []);
        byMonth.get(e.monthKey)!.push(e);
      });
      const months = Array.from(byMonth.keys())
        .sort((a, b) => b.localeCompare(a))
        .map((monthKey) => {
          const mEntries = byMonth.get(monthKey)!;
          const date = parseISO(`${monthKey}-01`);
          const byWeek = new Map<number, Entry[]>();
          mEntries.forEach((e) => {
            const w = weekNumber(parseISO(e.dayKey));
            if (!byWeek.has(w)) byWeek.set(w, []);
            byWeek.get(w)!.push(e);
          });
          const weeks = Array.from(byWeek.keys())
            .sort((a, b) => b - a)
            .map((w) => {
              const wEntries = byWeek.get(w)!;
              const sample = parseISO(wEntries[0].dayKey);
              const byDay = new Map<string, Entry[]>();
              wEntries.forEach((e) => {
                if (!byDay.has(e.dayKey)) byDay.set(e.dayKey, []);
                byDay.get(e.dayKey)!.push(e);
              });
              const days = Array.from(byDay.keys())
                .sort((a, b) => b.localeCompare(a))
                .map((dayKey) => ({
                  dayKey,
                  dayLabel: fmtShortDay(parseISO(dayKey)),
                  entries: byDay.get(dayKey)!.sort((a, b) => b.createdAt - a.createdAt),
                }));
              return {
                weekNum: w,
                weekLabel: `Week ${w} · ${weekRangeLabel(sample)}`,
                days,
              };
            });
          return {
            monthKey,
            monthLabel: fmtMonth(date),
            weeks,
          };
        });
      years.push({ year, months });
    });
  return years;
}

function ArchivePage() {
  const { data: entries = [], isLoading } = useQuery({
    queryKey: ["entries", "all"],
    queryFn: allEntries,
  });
  const grouped = useMemo(() => groupEntries(entries), [entries]);

  return (
    <AppShell>
      <header className="px-5 pt-[max(2.25rem,env(safe-area-inset-top))] pb-3 flex items-start justify-between">
        <div>
          <p className="text-[11px] uppercase tracking-[0.2em] text-primary-glow font-bold">Archive</p>
          <h1 className="mt-0.5 text-3xl font-extrabold tracking-tight text-slate-900 dark:text-slate-100 font-sans">All Records</h1>
          <p className="mt-1 text-xs text-slate-500 dark:text-slate-400 font-medium">
            {entries.length} {entries.length === 1 ? "entry" : "entries"} stored on this device
          </p>
        </div>
        <ThemeToggle />
      </header>

      <div className="px-4 space-y-5 pb-28">
        {isLoading && <p className="text-xs text-slate-500 text-center py-8 font-mono">Loading archive…</p>}
        {!isLoading && grouped.length === 0 && (
          <p className="text-xs text-slate-500 text-center py-8 font-mono">No entries archived yet.</p>
        )}
        {grouped.map((y) => (
          <section key={y.year}>
            <h2 className="text-[10px] uppercase tracking-widest text-slate-500 dark:text-slate-400 font-bold mb-2 px-1">
              {y.year}
            </h2>
            <div className="space-y-3">
              {y.months.map((m) => (
                <details
                  key={m.monthKey}
                  className="group rounded-2xl ios-glass-card overflow-hidden shadow-md"
                >
                  <summary className="flex items-center gap-3 px-4 py-3.5 cursor-pointer list-none ios-press">
                    <Folder size={17} className="text-blue-600 dark:text-primary-glow shrink-0" />
                    <span className="font-bold text-sm text-slate-900 dark:text-slate-100 flex-1">{m.monthLabel}</span>
                    <span className="text-xs font-mono font-bold text-slate-600 dark:text-slate-400 bg-slate-100 dark:bg-white/[0.06] px-2 py-0.5 rounded-md">
                      {m.weeks.reduce(
                        (n, w) => n + w.days.reduce((nn, d) => nn + d.entries.length, 0),
                        0,
                      )}
                    </span>
                    <ChevronRight
                      size={16}
                      className="text-slate-400 transition-transform group-open:rotate-90"
                    />
                  </summary>
                  <div className="border-t border-slate-200 dark:border-white/[0.08] divide-y divide-slate-200 dark:divide-white/[0.06]">
                    {m.weeks.map((w) => (
                      <details key={w.weekNum} className="group/w">
                        <summary className="flex items-center gap-3 px-5 py-2.5 cursor-pointer list-none bg-slate-50 dark:bg-black/20 text-xs font-semibold text-slate-700 dark:text-slate-300">
                          <span className="flex-1">{w.weekLabel}</span>
                          <ChevronRight
                            size={14}
                            className="text-slate-400 dark:text-slate-500 transition-transform group-open/w:rotate-90"
                          />
                        </summary>
                        <ul className="bg-white dark:bg-black/30 divide-y divide-slate-100 dark:divide-white/[0.04]">
                          {w.days.map((d) => (
                            <li key={d.dayKey}>
                              <Link
                                to="/day/$date"
                                params={{ date: d.dayKey }}
                                onClick={() => vibrate("light")}
                                className="flex items-center justify-between px-6 py-2.5 text-xs text-slate-800 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-white/[0.06] ios-press"
                              >
                                <span className="font-medium">{d.dayLabel}</span>
                                <span className="font-mono font-bold text-[11px] text-slate-400 dark:text-slate-500 tabular-nums">
                                  {d.entries.length} {d.entries.length === 1 ? "entry" : "entries"}
                                </span>
                              </Link>
                            </li>
                          ))}
                        </ul>
                      </details>
                    ))}
                  </div>
                </details>
              ))}
            </div>
          </section>
        ))}
      </div>
    </AppShell>
  );
}
