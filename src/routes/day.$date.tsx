import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { ArrowLeft, ChevronLeft, ChevronRight } from "lucide-react";
import { parseISO, addDays, subDays, format } from "date-fns";
import { entriesByDay } from "@/lib/db";
import { fmtDayLabel } from "@/lib/format";
import { EntryListItem } from "@/components/EntryListItem";
import { ThemeToggle } from "@/components/ThemeToggle";
import { vibrate } from "@/lib/haptics";

export const Route = createFileRoute("/day/$date")({
  head: () => ({ meta: [{ title: "Day — Dispatch Diary" }] }),
  component: DayPage,
});

function DayPage() {
  const { date } = Route.useParams();
  const navigate = useNavigate();
  const { data: entries = [], isLoading } = useQuery({
    queryKey: ["entries", "day", date],
    queryFn: () => entriesByDay(date),
  });

  let label = date;
  let prevDateStr = "";
  let nextDateStr = "";

  try {
    const currentDate = parseISO(date);
    label = fmtDayLabel(currentDate);
    prevDateStr = format(subDays(currentDate, 1), "yyyy-MM-dd");
    nextDateStr = format(addDays(currentDate, 1), "yyyy-MM-dd");
  } catch {
    // fallback if date parsing fails
  }

  return (
    <div className="min-h-screen bg-transparent max-w-md mx-auto pb-10">
      <div className="ios-ambient-bg" />

      <header className="sticky top-0 z-30 ios-glass border-b border-slate-200 dark:border-white/[0.1] pt-[env(safe-area-inset-top)] shadow-md">
        <div className="flex items-center justify-between px-4 py-3">
          <div className="flex items-center gap-3 min-w-0">
            <button
              onClick={() => {
                vibrate("light");
                navigate({ to: "/archive" });
              }}
              className="h-9 w-9 rounded-full bg-slate-100 dark:bg-white/[0.06] border border-slate-200 dark:border-white/[0.1] grid place-items-center hover:bg-slate-200 dark:hover:bg-white/[0.12] ios-press flex-shrink-0 text-slate-800 dark:text-slate-100"
              aria-label="Back to archive"
            >
              <ArrowLeft size={18} />
            </button>
            <div className="min-w-0">
              <p className="text-[10px] uppercase tracking-widest text-primary-glow font-bold">
                Daily Log
              </p>
              <h1 className="text-base font-bold truncate text-slate-900 dark:text-slate-100">{label}</h1>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <ThemeToggle />
            {prevDateStr && nextDateStr && (
              <div className="flex items-center gap-1 bg-slate-100 dark:bg-white/[0.06] border border-slate-200 dark:border-white/[0.1] rounded-2xl p-1 flex-shrink-0 shadow-inner">
                <button
                  onClick={() => {
                    vibrate("light");
                    navigate({ to: `/day/${prevDateStr}` });
                  }}
                  className="h-8 w-8 rounded-xl grid place-items-center hover:bg-slate-200 dark:hover:bg-white/[0.1] text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-200 ios-press"
                  aria-label="Previous day"
                >
                  <ChevronLeft size={18} />
                </button>
                <button
                  onClick={() => {
                    vibrate("light");
                    navigate({ to: `/day/${nextDateStr}` });
                  }}
                  className="h-8 w-8 rounded-xl grid place-items-center hover:bg-slate-200 dark:hover:bg-white/[0.1] text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-200 ios-press"
                  aria-label="Next day"
                >
                  <ChevronRight size={18} />
                </button>
              </div>
            )}
          </div>
        </div>
      </header>

      <div className="px-4 pt-4 space-y-3 pb-24">
        {isLoading && <p className="text-xs text-slate-500 text-center py-8 font-mono">Loading day entries…</p>}
        {!isLoading && entries.length === 0 && (
          <p className="text-xs text-slate-500 text-center py-8 font-mono">No entries logged on this day.</p>
        )}
        {entries.map((e) => (
          <EntryListItem key={e.id} entry={e} />
        ))}
      </div>
    </div>
  );
}
