import { X } from "lucide-react";
import { useState } from "react";

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
    onChange([...value, t]);
    setInput("");
  };

  const remove = (t: string) => onChange(value.filter((x) => x !== t));

  const filteredSuggestions = suggestions.filter(
    (s) => !value.includes(s) && s.includes(input.toLowerCase())
  );

  return (
    <div>
      <div className="flex flex-wrap gap-1.5">
        {value.map((t) => (
          <span
            key={t}
            className="inline-flex items-center gap-1 rounded-full bg-primary/20 text-primary-glow text-xs px-2.5 py-1 border border-primary/30"
          >
            #{t}
            <button onClick={() => remove(t)} aria-label={`Remove ${t}`}>
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
          className="flex-1 min-w-[6rem] bg-transparent text-sm outline-none placeholder:text-muted-foreground"
        />
      </div>
      {input && filteredSuggestions.length > 0 && (
        <div className="mt-2 flex flex-wrap gap-1.5">
          {filteredSuggestions.slice(0, 6).map((s) => (
            <button
              key={s}
              onClick={() => add(s)}
              className="text-xs px-2 py-1 rounded-full bg-muted text-muted-foreground hover:text-foreground"
            >
              #{s}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
