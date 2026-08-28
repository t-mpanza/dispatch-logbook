import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { ArrowLeft, Sparkles } from "lucide-react";
import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { createEntry, allTags } from "@/lib/db";
import { QUICK_TEMPLATES } from "@/lib/templates";
import { TagsInput } from "@/components/TagsInput";
import { vibrate } from "@/lib/haptics";

export const Route = createFileRoute("/entry/new")({
  head: () => ({ meta: [{ title: "New Entry — Dispatch Diary" }] }),
  component: NewEntryPage,
});

function NewEntryPage() {
  const navigate = useNavigate();
  const [title, setTitle] = useState("");
  const [tags, setTags] = useState<string[]>([]);
  const { data: suggestions = [] } = useQuery({ queryKey: ["tags"], queryFn: allTags });
  const [saving, setSaving] = useState(false);
  const [withCounter, setWithCounter] = useState(false);

  async function create() {
    vibrate("success");
    setSaving(true);
    const e = await createEntry({ title, tags, withCounter });
    navigate({ to: "/entry/$id", params: { id: e.id } });
  }

  function applyTemplate(t: (typeof QUICK_TEMPLATES)[number]) {
    vibrate("light");
    setTitle(t.title);
    setTags(Array.from(new Set([...tags, ...t.tags])));
    if (t.withCounter) setWithCounter(true);
  }

  return (
    <div className="min-h-screen bg-transparent max-w-md mx-auto pb-12">
      <header className="sticky top-0 z-30 ios-glass border-b border-white/[0.1] pt-[env(safe-area-inset-top)] shadow-md">
        <div className="flex items-center justify-between px-4 py-3">
          <button
            onClick={() => {
              vibrate("light");
              navigate({ to: "/" });
            }}
            className="h-9 w-9 rounded-full bg-white/[0.06] border border-white/[0.1] grid place-items-center hover:bg-white/[0.12] ios-press text-slate-100"
            aria-label="Back"
          >
            <ArrowLeft size={18} />
          </button>
          <span className="text-sm font-bold text-slate-100">New Entry</span>
          <button
            onClick={create}
            disabled={saving}
            className="px-5 h-9 rounded-full bg-blue-600 hover:bg-blue-500 text-white text-xs font-bold ios-press shadow-md disabled:opacity-40"
          >
            {saving ? "Creating…" : "Create"}
          </button>
        </div>
      </header>

      <div className="p-5 space-y-6">
        <div>
          <label className="text-[10px] uppercase tracking-wider text-slate-400 font-bold block">
            Trip Header / Destination Title
          </label>
          <input
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            placeholder="e.g. STOCKS 1, NLH, Bay 4…"
            autoFocus
            className="mt-2 w-full bg-transparent border-b border-white/[0.2] focus:border-blue-500 outline-none py-2 text-2xl font-mono uppercase font-bold tracking-wider text-slate-100 placeholder:text-slate-500 placeholder:normal-case placeholder:tracking-normal placeholder:font-sans placeholder:text-base"
          />
        </div>

        <div>
          <label className="text-[10px] uppercase tracking-wider text-slate-400 font-bold block">
            Tags
          </label>
          <div className="mt-2 rounded-2xl ios-glass p-3 shadow-md">
            <TagsInput value={tags} onChange={setTags} suggestions={suggestions} />
          </div>
        </div>

        <div>
          <div className="flex items-center gap-1.5 text-[10px] uppercase tracking-wider text-primary-glow font-bold">
            <Sparkles size={12} /> Quick Templates
          </div>
          <div className="mt-2 flex flex-wrap gap-2">
            {QUICK_TEMPLATES.map((t) => (
              <button
                key={t.label}
                onClick={() => applyTemplate(t)}
                className="px-3.5 py-1.5 rounded-full text-xs font-bold ios-glass text-slate-200 hover:bg-white/[0.12] ios-press shadow-xs"
              >
                {t.label}
              </button>
            ))}
          </div>
        </div>

        <label className="flex items-center gap-3.5 rounded-2xl ios-glass p-3.5 cursor-pointer select-none shadow-md ios-press">
          <input
            type="checkbox"
            checked={withCounter}
            onChange={(e) => {
              vibrate("light");
              setWithCounter(e.target.checked);
            }}
            className="h-5 w-5 rounded-lg accent-blue-600 cursor-pointer"
          />
          <div className="flex-1">
            <p className="text-xs font-bold text-slate-100">Enable Tyre Counter</p>
            <p className="text-[11px] text-slate-400 mt-0.5">
              Adds a running tally for tyre counting and loading sheet logging.
            </p>
          </div>
        </label>

        <p className="text-xs text-slate-400 pt-2 text-center font-medium">
          Tap <span className="text-slate-100 font-bold">Create</span> to log trips, record voice memos, or take photos.
        </p>
      </div>
    </div>
  );
}
