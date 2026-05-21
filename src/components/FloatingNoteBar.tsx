import { useRef, useState } from "react";
import { Send } from "lucide-react";

interface Props {
  onAdd: (text: string) => void;
}

export function FloatingNoteBar({ onAdd }: Props) {
  const [text, setText] = useState("");
  const [expanded, setExpanded] = useState(false);
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  function submit() {
    const t = text.trim();
    if (!t) return;
    onAdd(t);
    setText("");
    setExpanded(false);
  }

  function handleKey(e: React.KeyboardEvent<HTMLTextAreaElement>) {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      submit();
    }
    if (e.key === "Escape") {
      setText("");
      setExpanded(false);
      textareaRef.current?.blur();
    }
  }

  return (
    <div
      className={`fixed bottom-[calc(4rem+env(safe-area-inset-bottom))] left-1/2 -translate-x-1/2 w-full max-w-md px-4 z-30 transition-all duration-200`}
    >
      <div
        className={`flex items-end gap-2 rounded-2xl border bg-surface/95 backdrop-blur-xl shadow-xl transition-all duration-200 ${
          expanded ? "border-primary/40 px-4 py-3" : "border-border px-4 py-2.5"
        }`}
      >
        <textarea
          ref={textareaRef}
          value={text}
          rows={expanded ? 3 : 1}
          onChange={(e) => setText(e.target.value)}
          onFocus={() => setExpanded(true)}
          onBlur={() => {
            if (!text.trim()) setExpanded(false);
          }}
          onKeyDown={handleKey}
          placeholder="Quick note…"
          className="flex-1 resize-none bg-transparent text-sm outline-none placeholder:text-muted-foreground/50 leading-snug"
        />
        <button
          onClick={submit}
          disabled={!text.trim()}
          className="shrink-0 h-8 w-8 rounded-full bg-primary text-primary-foreground grid place-items-center disabled:opacity-30 active:scale-90 transition-all"
          aria-label="Add note"
        >
          <Send size={14} />
        </button>
      </div>
    </div>
  );
}
