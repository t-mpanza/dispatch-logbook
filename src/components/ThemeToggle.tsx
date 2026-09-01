import { Moon, Sun } from "lucide-react";
import { useTheme } from "@/lib/theme";
import { vibrate } from "@/lib/haptics";

interface Props {
  className?: string;
  showLabel?: boolean;
}

export function ThemeToggle({ className = "", showLabel = false }: Props) {
  const { isDark, toggleTheme } = useTheme();

  return (
    <button
      onClick={() => {
        vibrate("light");
        toggleTheme();
      }}
      className={`h-9 px-2.5 rounded-full ios-glass flex items-center justify-center gap-1.5 text-slate-700 dark:text-slate-200 hover:text-slate-900 dark:hover:text-white ios-press shadow-sm ${className}`}
      aria-label={isDark ? "Switch to light mode" : "Switch to dark mode"}
      title={isDark ? "Switch to light mode" : "Switch to dark mode"}
    >
      {isDark ? (
        <Sun size={16} className="text-amber-400 animate-fade-in-scale" />
      ) : (
        <Moon size={16} className="text-blue-600 animate-fade-in-scale" />
      )}
      {showLabel && (
        <span className="text-xs font-bold uppercase tracking-wider font-mono">
          {isDark ? "Light" : "Dark"}
        </span>
      )}
    </button>
  );
}
