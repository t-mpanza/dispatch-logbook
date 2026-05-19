import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { ArrowLeft, Sparkles } from "lucide-react";
import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { createEntry, allTags } from "@/lib/db";
import { QUICK_TEMPLATES } from "@/lib/templates";
import { TagsInput } from "@/components/TagsInput";

export const Route = createFileRoute("/entry/new")({
  head: () => ({ meta: [{ title: "New entry — Dispatch Diary" }] }),
  component: NewEntryPage,
});

function NewEntryPage() {
  const navigate = useNavigate();
  const [title, setTitle] = useState("");
  const [tags, setTags] = useState<string[]>([]);
  const { data: suggestions = [] } = useQuery({ queryKey: ["tags"], queryFn: allTags });
  const [saving, setSaving] = useState(false);

  async function create() {
    setSaving(true);
    const e = await createEntry({ title, tags });
    navigate({ to: "/entry/$id", params: { id: e.id } });
  }

  function applyTemplate(t: (typeof QUICK_TEMPLATES)[number]) {
    setTitle(t.title);
    setTags(Array.from(new Set([...tags, ...t.tags])));
  }

  return (
    <div className="min-h-screen bg-background max-w-md mx-auto">
      <header className="sticky top-0 z-30 bg-background/85 backdrop-blur-xl border-b border-border">
        <div className="flex items-center justify-between px-4 py-3">
          <button
            onClick={() => navigate({ to: "/" })}
            className="h-9 w-9 rounded-full grid place-items-center hover:bg-muted"
            aria-label="Back"
          >
            <ArrowLeft size={18} />
          </button>
          <span className="text-sm font-medium">New entry</span>
          <button
            onClick={create}
            disabled={saving}
            className="px-4 h-9 rounded-full bg-primary text-primary-foreground text-sm font-medium disabled:opacity-50"
          >
            Create
          </button>
        </div>
      </header>

      <div className="p-5 space-y-6">
        <div>
          <label className="text-[11px] uppercase tracking-wider text-muted-foreground font-medium">
            Header / title
          </label>
          <input
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            placeholder="HT76CBGP, INV00234, Bay 4…"
            autoFocus
            className="mt-2 w-full bg-transparent border-b border-border focus:border-primary outline-none py-2 text-xl font-mono uppercase tracking-wider placeholder:text-muted-foreground/60 placeholder:normal-case placeholder:tracking-normal placeholder:font-sans"
          />
        </div>

        <div>
          <label className="text-[11px] uppercase tracking-wider text-muted-foreground font-medium">
            Tags
          </label>
          <div className="mt-2 rounded-xl bg-surface border border-border p-3">
            <TagsInput value={tags} onChange={setTags} suggestions={suggestions} />
          </div>
        </div>

        <div>
          <div className="flex items-center gap-2 text-[11px] uppercase tracking-wider text-muted-foreground font-medium">
            <Sparkles size={12} /> Quick templates
          </div>
          <div className="mt-2 flex flex-wrap gap-2">
            {QUICK_TEMPLATES.map((t) => (
              <button
                key={t.label}
                onClick={() => applyTemplate(t)}
                className="px-3 py-1.5 rounded-full text-xs bg-surface-elevated border border-border hover:border-primary/50"
              >
                {t.label}
              </button>
            ))}
          </div>
        </div>

        <p className="text-xs text-muted-foreground pt-4">
          Tap <span className="text-foreground font-medium">Create</span> — you'll be taken
          straight to the entry to add voice notes, photos and files.
        </p>
      </div>
    </div>
  );
}
