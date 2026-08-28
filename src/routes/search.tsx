import { createFileRoute } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { Search as SearchIcon, X } from "lucide-react";
import { useState } from "react";
import { AppShell } from "@/components/AppShell";
import { allTags, searchEntries } from "@/lib/db";
import { EntryListItem } from "@/components/EntryListItem";
import { vibrate } from "@/lib/haptics";

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
      <header className="px-5 pt-[max(2.25rem,env(safe-area-inset-top))] pb-2">
        <p className="text-[11px] uppercase tracking-[0.2em] text-primary-glow font-bold">Search</p>
        <h1 className="mt-0.5 text-3xl font-extrabold tracking-tight text-slate-100 font-sans">Find Anything</h1>
      </header>

      <div className="px-5 mt-3">
        {/* iOS Glass Search Bar */}
        <div className="flex items-center gap-2.5 rounded-2xl ios-glass px-4 py-3 shadow-lg">
          <SearchIcon size={18} className="text-primary-glow shrink-0" />
          <input
            autoFocus
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder="Reg, trip ID, driver, tag, note…"
            className="flex-1 bg-transparent outline-none text-sm text-slate-100 placeholder:text-slate-500 font-sans"
          />
          {q && (
            <button
              onClick={() => {
                vibrate("light");
                setQ("");
              }}
              className="h-6 w-6 rounded-full bg-white/[0.08] grid place-items-center text-slate-400 hover:text-slate-200"
            >
              <X size={13} />
            </button>
          )}
        </div>

        {tags.length > 0 && (
          <div className="mt-4">
            <p className="text-[10px] uppercase tracking-wider text-slate-400 font-bold mb-2">
              Popular Tags
            </p>
            <div className="flex flex-wrap gap-1.5">
              {tags.map((t) => (
                <button
                  key={t}
                  onClick={() => {
                    vibrate("light");
                    setQ(t);
                  }}
                  className="text-xs px-3 py-1 rounded-full ios-glass text-blue-400 hover:bg-white/[0.08] ios-press font-mono font-semibold shadow-xs"
                >
                  #{t}
                </button>
              ))}
            </div>
          </div>
        )}

        <div className="mt-5 space-y-3">
          {results.length === 0 ? (
            <p className="text-xs text-slate-500 text-center py-8 font-mono">
              {q ? "No matches found." : "Type to search across titles, tags, drivers, and notes."}
            </p>
          ) : (
            results.map((e) => <EntryListItem key={e.id} entry={e} />)
          )}
        </div>
      </div>
    </AppShell>
  );
}
