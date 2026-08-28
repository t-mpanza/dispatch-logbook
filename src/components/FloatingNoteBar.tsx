import { useRef, useState } from "react";
import { Send } from "lucide-react";
import { CaptureBar } from "./CaptureBar";
import type { Attachment } from "@/lib/types";
import { vibrate } from "@/lib/haptics";

interface Props {
  onAdd: (text: string) => void;
  onAttachment: (a: Attachment) => void;
  onStartVoice: () => void;
}

export function FloatingNoteBar({ onAdd, onAttachment, onStartVoice }: Props) {
  const [text, setText] = useState("");
  const [expanded, setExpanded] = useState(false);
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  function submit() {
    const t = text.trim();
    if (!t) return;
    vibrate("success");
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
    <div className="fixed bottom-0 left-1/2 -translate-x-1/2 w-full max-w-md z-30 px-3 pb-[max(0.75rem,env(safe-area-inset-bottom))]">
      <div
        className={`flex items-end gap-2 rounded-3xl ios-glass-dock shadow-2xl transition-all duration-200 ${
          expanded ? "border-blue-500/50 px-3 py-3" : "px-3 py-2"
        }`}
      >
        <CaptureBar onAttachment={onAttachment} onStartVoice={onStartVoice} />

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
          placeholder="Log observation or note…"
          className="flex-1 resize-none bg-transparent text-sm text-slate-100 outline-none placeholder:text-slate-500 leading-snug py-1.5 font-sans"
        />
        <button
          onClick={submit}
          disabled={!text.trim()}
          className="shrink-0 h-9 w-9 rounded-full bg-blue-600 hover:bg-blue-500 text-white grid place-items-center disabled:opacity-30 ios-press shadow-md"
          aria-label="Add note"
        >
          <Send size={15} />
        </button>
      </div>
    </div>
  );
}
