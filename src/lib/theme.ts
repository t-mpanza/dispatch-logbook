import { useEffect, useState } from "react";
import { Capacitor } from "@capacitor/core";
import { StatusBar, Style } from "@capacitor/status-bar";
import { vibrate } from "./haptics";

export type ThemeMode = "system" | "light" | "dark";

const THEME_KEY = "dispatch_diary_theme";

export function getStoredTheme(): ThemeMode {
  if (typeof window === "undefined") return "system";
  try {
    const saved = localStorage.getItem(THEME_KEY);
    if (saved === "light" || saved === "dark" || saved === "system") {
      return saved;
    }
  } catch {}
  return "system";
}

export function applyTheme(mode: ThemeMode) {
  if (typeof document === "undefined") return;

  const root = document.documentElement;
  const isDark =
    mode === "dark" ||
    (mode === "system" &&
      window.matchMedia &&
      window.matchMedia("(prefers-color-scheme: dark)").matches);

  if (isDark) {
    root.classList.add("dark");
    root.classList.remove("light");
    root.style.colorScheme = "dark";
  } else {
    root.classList.add("light");
    root.classList.remove("dark");
    root.style.colorScheme = "light";
  }

  // Update native StatusBar if on mobile
  if (Capacitor.isNativePlatform()) {
    try {
      if (Capacitor.getPlatform() === "android") {
        StatusBar.setBackgroundColor({ color: isDark ? "#0b0c12" : "#f8fafc" }).catch(() => {});
      }
      StatusBar.setStyle({ style: isDark ? Style.Dark : Style.Light }).catch(() => {});
    } catch {}
  }
}

export function useTheme() {
  const [theme, setThemeState] = useState<ThemeMode>(() => getStoredTheme());
  const [isDark, setIsDark] = useState<boolean>(() => {
    if (typeof window === "undefined") return true;
    const current = getStoredTheme();
    return (
      current === "dark" ||
      (current === "system" &&
        window.matchMedia &&
        window.matchMedia("(prefers-color-scheme: dark)").matches)
    );
  });

  useEffect(() => {
    applyTheme(theme);

    const mediaQuery = window.matchMedia("(prefers-color-scheme: dark)");
    const handleChange = () => {
      if (theme === "system") {
        applyTheme("system");
        setIsDark(mediaQuery.matches);
      }
    };

    mediaQuery.addEventListener("change", handleChange);
    return () => mediaQuery.removeEventListener("change", handleChange);
  }, [theme]);

  function setTheme(newMode: ThemeMode) {
    vibrate("light");
    setThemeState(newMode);
    try {
      localStorage.setItem(THEME_KEY, newMode);
    } catch {}
    applyTheme(newMode);

    const resolvedDark =
      newMode === "dark" ||
      (newMode === "system" &&
        window.matchMedia &&
        window.matchMedia("(prefers-color-scheme: dark)").matches);
    setIsDark(resolvedDark);
  }

  function toggleTheme() {
    vibrate("medium");
    const nextMode: ThemeMode = isDark ? "light" : "dark";
    setTheme(nextMode);
  }

  return { theme, isDark, setTheme, toggleTheme };
}
