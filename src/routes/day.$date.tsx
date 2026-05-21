import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { ArrowLeft, ChevronLeft, ChevronRight } from "lucide-react";
import { parseISO, addDays, subDays, format } from "date-fns";
import { entriesByDay } from "@/lib/db";
import { fmtDayLabel } from "@/lib/format";
import { EntryListItem } from "@/components/EntryListItem";

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
    <div className="min-h-screen bg-background max-w-md mx-auto pb-10">
      <header className="sticky top-0 z-30 bg-background/85 backdrop-blur-xl border-b border-border pt-[env(safe-area-inset-top)]">
        <div className="flex items-center justify-between px-4 py-3">
          <div className="flex items-center gap-3 min-w-0">
            <button
              onClick={() => navigate({ to: "/archive" })}
              className="h-9 w-9 rounded-full grid place-items-center hover:bg-muted flex-shrink-0"
              aria-label="Back to archive"
            >
              <ArrowLeft size={18} />
            </button>
            <div className="min-w-0">
              <p className="text-[10px] uppercase tracking-widest text-primary-glow font-medium">
                Day
              </p>
              <h1 className="text-base font-semibold truncate">{label}</h1>
            </div>
          </div>

          {prevDateStr && nextDateStr && (
            <div className="flex items-center gap-1 bg-surface-elevated border border-border rounded-xl p-1 flex-shrink-0 ml-2">
              <button
                onClick={() => navigate({ to: `/day/${prevDateStr}` })}
                className="h-8 w-8 rounded-lg grid place-items-center hover:bg-surface text-muted-foreground hover:text-foreground active:scale-90 transition-all"
                aria-label="Previous day"
              >
                <ChevronLeft size={18} />
              </button>
              <button
                onClick={() => navigate({ to: `/day/${nextDateStr}` })}
                className="h-8 w-8 rounded-lg grid place-items-center hover:bg-surface text-muted-foreground hover:text-foreground active:scale-90 transition-all"
                aria-label="Next day"
              >
                <ChevronRight size={18} />
              </button>
            </div>
          )}
        </div>
      </header>

      <div className="px-5 pt-4 space-y-2.5">
        {isLoading && <p className="text-sm text-muted-foreground">Loading…</p>}
        {!isLoading && entries.length === 0 && (
          <p className="text-sm text-muted-foreground">No entries logged on this day.</p>
        )}
        {entries.map((e) => (
          <EntryListItem key={e.id} entry={e} />
        ))}
      </div>
    </div>
  );
}
