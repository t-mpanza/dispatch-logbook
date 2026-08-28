import { X } from "lucide-react";
import { useState } from "react";
import { vibrate } from "@/lib/haptics";

export function TagsInput({
  value,
  onChange,
  suggestions = [],
}: {
  value: string[];
  onChange: (tags: string[]) => void;
  suggestions?: string[];
}) {
  const [input, setInput] = useState("");

  const add = (raw: string) => {
    const t = raw.trim().toLowerCase().replace(/^#/, "");
    if (!t) return;
    if (value.includes(t)) return;
    vibrate("light");
    onChange([...value, t]);
    setInput("");
  };

  const remove = (t: string) => {
    vibrate("light");
    onChange(value.filter((x) => x !== t));
  };

  const filteredSuggestions = suggestions.filter(
    (s) => !value.includes(s) && s.includes(input.toLowerCase()),
  );

  return (
    <div>
      <div className="flex flex-wrap gap-1.5">
        {value.map((t) => (
          <span
            key={t}
            className="inline-flex items-center gap-1.5 rounded-full bg-blue-500/15 text-blue-400 font-mono font-semibold text-xs px-2.5 py-1 border border-blue-500/30 shadow-xs"
          >
            #{t}
            <button onClick={() => remove(t)} aria-label={`Remove ${t}`} className="hover:text-rose-400">
              <X size={12} />
            </button>
          </span>
        ))}
        <input
          value={input}
          onChange={(e) => setInput(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter" || e.key === ",") {
              e.preventDefault();
              add(input);
            } else if (e.key === "Backspace" && !input && value.length) {
              remove(value[value.length - 1]);
            }
          }}
          placeholder="add tag…"
          className="flex-1 min-w-[6rem] bg-transparent text-sm outline-none text-slate-100 placeholder:text-slate-500 font-sans"
        />
      </div>
      {input && filteredSuggestions.length > 0 && (
        <div className="mt-2 flex flex-wrap gap-1.5">
          {filteredSuggestions.slice(0, 6).map((s) => (
            <button
              key={s}
              onClick={() => add(s)}
              className="text-xs px-2.5 py-1 rounded-full ios-glass text-slate-400 hover:text-slate-200 font-mono"
            >
              #{s}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
