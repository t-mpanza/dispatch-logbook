import { createFileRoute, Link } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { Plus, ChevronLeft } from "lucide-react";
import { AppShell } from "@/components/AppShell";
import { entriesByDay } from "@/lib/db";
import { dayKey, fmtDayLabel } from "@/lib/format";
import { EntryListItem } from "@/components/EntryListItem";

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "Today — Dispatch Diary" },
      { name: "description", content: "Fast-capture operational diary for dispatch." },
      { name: "theme-color", content: "#0a0a1a" },
    ],
    links: [
      { rel: "manifest", href: "/manifest.webmanifest" },
      { rel: "icon", href: "/icon-512.png" },
      { rel: "apple-touch-icon", href: "/icon-512.png" },
    ],
  }),
  component: TodayPage,
});

function TodayPage() {
  const today = new Date();
  const key = dayKey(today);
  const { data: entries = [], isLoading } = useQuery({
    queryKey: ["entries", "day", key],
    queryFn: () => entriesByDay(key),
  });

  const yesterday = new Date(today);
  yesterday.setDate(yesterday.getDate() - 1);
  const yesterdayDateStr = dayKey(yesterday);

  return (
    <AppShell>
      <header className="px-5 pt-[max(2rem,env(safe-area-inset-top))] pb-4 flex items-start justify-between">
        <div>
          <p className="text-xs uppercase tracking-[0.2em] text-primary-glow font-medium">
            Today
          </p>
          <h1 className="mt-1 text-2xl font-semibold tracking-tight">{fmtDayLabel(today)}</h1>
          <p className="mt-1 text-sm text-muted-foreground">
            {entries.length === 0
              ? "Nothing logged yet. Tap + to capture."
              : `${entries.length} ${entries.length === 1 ? "entry" : "entries"}`}
          </p>
        </div>

        <Link
          to={`/day/${yesterdayDateStr}`}
          className="mt-1 h-9 px-3 rounded-xl bg-surface-elevated border border-border flex items-center gap-1.5 text-xs text-muted-foreground hover:text-foreground hover:border-primary/50 transition-all active:scale-95"
          aria-label="Yesterday"
        >
          <ChevronLeft size={16} />
          <span className="font-semibold">Yesterday</span>
        </Link>
      </header>

      <div className="px-5 space-y-2.5">
        {isLoading ? (
          <p className="text-sm text-muted-foreground">Loading…</p>
        ) : entries.length === 0 ? (
          <EmptyState />
        ) : (
          entries.map((e) => <EntryListItem key={e.id} entry={e} />)
        )}
      </div>

      <Link
        to="/entry/new"
        className="fixed bottom-24 right-5 z-50 h-14 w-14 rounded-full bg-[image:var(--gradient-primary)] text-primary-foreground grid place-items-center shadow-[var(--shadow-glow)] active:scale-95 transition-transform"
        aria-label="New entry"
      >
        <Plus size={26} />
      </Link>
    </AppShell>
  );
}

function EmptyState() {
  return (
    <div className="mt-6 rounded-2xl border border-dashed border-border p-8 text-center">
      <div className="mx-auto h-14 w-14 rounded-full bg-[image:var(--gradient-primary)] grid place-items-center shadow-[var(--shadow-glow)]">
        <Plus size={22} className="text-primary-foreground" />
      </div>
      <h2 className="mt-4 font-semibold">Start logging</h2>
      <p className="mt-1 text-sm text-muted-foreground">
        Voice notes, photos, videos, files — all stored on this device.
      </p>
      <Link
        to="/entry/new"
        className="inline-flex mt-4 px-4 py-2 rounded-full bg-primary text-primary-foreground text-sm font-medium"
      >
        New entry
      </Link>
    </div>
  );
}
