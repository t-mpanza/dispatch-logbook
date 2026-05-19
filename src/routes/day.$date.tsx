import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { ArrowLeft } from "lucide-react";
import { parseISO } from "date-fns";
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
  try {
    label = fmtDayLabel(parseISO(date));
  } catch {
    // keep raw
  }

  return (
    <div className="min-h-screen bg-background max-w-md mx-auto pb-10">
      <header className="sticky top-0 z-30 bg-background/85 backdrop-blur-xl border-b border-border">
        <div className="flex items-center gap-3 px-4 py-3">
          <button
            onClick={() => navigate({ to: "/archive" })}
            className="h-9 w-9 rounded-full grid place-items-center hover:bg-muted"
          >
            <ArrowLeft size={18} />
          </button>
          <div>
            <p className="text-[10px] uppercase tracking-widest text-primary-glow font-medium">
              Day
            </p>
            <h1 className="text-base font-semibold">{label}</h1>
          </div>
        </div>
      </header>

      <div className="px-5 pt-4 space-y-2.5">
        {isLoading && <p className="text-sm text-muted-foreground">Loading…</p>}
        {!isLoading && entries.length === 0 && (
          <p className="text-sm text-muted-foreground">No entries on this day.</p>
        )}
        {entries.map((e) => (
          <EntryListItem key={e.id} entry={e} />
        ))}
      </div>
    </div>
  );
}
