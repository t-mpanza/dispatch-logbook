import { createFileRoute, Link } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { ChevronRight, Folder } from "lucide-react";
import { AppShell } from "@/components/AppShell";
import { allEntries } from "@/lib/db";
import type { Entry } from "@/lib/types";
import { fmtMonth, fmtShortDay, weekNumber, weekRangeLabel } from "@/lib/format";
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
  const grouped = groupEntries(entries);

  return (
    <AppShell>
      <header className="px-5 pt-8 pb-4">
        <p className="text-xs uppercase tracking-[0.2em] text-primary-glow font-medium">
          Archive
        </p>
        <h1 className="mt-1 text-2xl font-semibold tracking-tight">All your records</h1>
        <p className="mt-1 text-sm text-muted-foreground">
          {entries.length} {entries.length === 1 ? "entry" : "entries"} on this device
        </p>
      </header>

      <div className="px-5 space-y-5">
        {isLoading && <p className="text-sm text-muted-foreground">Loading…</p>}
        {!isLoading && grouped.length === 0 && (
          <p className="text-sm text-muted-foreground">No entries archived yet.</p>
        )}
        {grouped.map((y) => (
          <section key={y.year}>
            <h2 className="text-xs uppercase tracking-widest text-muted-foreground font-semibold mb-2">
              {y.year}
            </h2>
            <div className="space-y-3">
              {y.months.map((m) => (
                <details
                  key={m.monthKey}
                  className="group rounded-xl bg-surface border border-border overflow-hidden"
                  open={m === y.months[0]}
                >
                  <summary className="flex items-center gap-3 px-4 py-3 cursor-pointer list-none">
                    <Folder size={16} className="text-primary-glow" />
                    <span className="font-medium flex-1">{m.monthLabel}</span>
                    <span className="text-xs text-muted-foreground">
                      {m.weeks.reduce(
                        (n, w) => n + w.days.reduce((nn, d) => nn + d.entries.length, 0),
                        0
                      )}
                    </span>
                    <ChevronRight
                      size={16}
                      className="text-muted-foreground transition-transform group-open:rotate-90"
                    />
                  </summary>
                  <div className="border-t border-border divide-y divide-border">
                    {m.weeks.map((w) => (
                      <details key={w.weekNum} className="group/w">
                        <summary className="flex items-center gap-3 px-5 py-2.5 cursor-pointer list-none bg-background/30">
                          <span className="text-sm flex-1">{w.weekLabel}</span>
                          <ChevronRight
                            size={14}
                            className="text-muted-foreground transition-transform group-open/w:rotate-90"
                          />
                        </summary>
                        <ul className="bg-background/60">
                          {w.days.map((d) => (
                            <li key={d.dayKey}>
                              <Link
                                to="/day/$date"
                                params={{ date: d.dayKey }}
                                className="flex items-center justify-between px-6 py-2.5 text-sm hover:bg-muted/40"
                              >
                                <span>{d.dayLabel}</span>
                                <span className="text-xs text-muted-foreground tabular-nums">
                                  {d.entries.length}
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
