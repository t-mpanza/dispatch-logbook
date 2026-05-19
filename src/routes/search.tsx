import { createFileRoute } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { Search as SearchIcon } from "lucide-react";
import { useState } from "react";
import { AppShell } from "@/components/AppShell";
import { allTags, searchEntries } from "@/lib/db";
import { EntryListItem } from "@/components/EntryListItem";

export const Route = createFileRoute("/search")({
  head: () => ({ meta: [{ title: "Search — Dispatch Diary" }] }),
  component: SearchPage,
});

function SearchPage() {
  const [q, setQ] = useState("");
  const { data: results = [] } = useQuery({
    queryKey: ["search", q],
    queryFn: () => searchEntries(q),
  });
  const { data: tags = [] } = useQuery({ queryKey: ["tags"], queryFn: allTags });

  return (
    <AppShell>
      <header className="px-5 pt-8 pb-2">
        <p className="text-xs uppercase tracking-[0.2em] text-primary-glow font-medium">
          Search
        </p>
        <h1 className="mt-1 text-2xl font-semibold tracking-tight">Find anything</h1>
      </header>

      <div className="px-5 mt-3">
        <div className="flex items-center gap-2 rounded-xl bg-surface border border-border px-3 py-2.5">
          <SearchIcon size={16} className="text-muted-foreground" />
          <input
            autoFocus
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder="Reg, invoice, tag, note…"
            className="flex-1 bg-transparent outline-none text-sm"
          />
        </div>

        {tags.length > 0 && (
          <div className="mt-4">
            <p className="text-[11px] uppercase tracking-wider text-muted-foreground font-medium mb-2">
              Tags
            </p>
            <div className="flex flex-wrap gap-1.5">
              {tags.map((t) => (
                <button
                  key={t}
                  onClick={() => setQ(t)}
                  className="text-xs px-2.5 py-1 rounded-full bg-primary/15 text-primary-glow border border-primary/30"
                >
                  #{t}
                </button>
              ))}
            </div>
          </div>
        )}

        <div className="mt-5 space-y-2.5">
          {results.length === 0 ? (
            <p className="text-sm text-muted-foreground">
              {q ? "No matches." : "Type to search across titles, tags and notes."}
            </p>
          ) : (
            results.map((e) => <EntryListItem key={e.id} entry={e} />)
          )}
        </div>
      </div>
    </AppShell>
  );
}
