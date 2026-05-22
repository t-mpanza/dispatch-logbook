import { Link, useLocation } from "@tanstack/react-router";
import { Archive, Home, Search, Truck, CloudOff, Cloud, UserCircle } from "lucide-react";
import type { ReactNode } from "react";
import { useEffect, useState } from "react";
import { rescheduleAll } from "@/lib/reminders";
import { supabase } from "@/lib/supabase";

// Only reschedule once per session
let rescheduled = false;

export function AppShell({ children }: { children: ReactNode }) {
  const [online, setOnline] = useState(navigator.onLine);

  useEffect(() => {
    if (!rescheduled) {
      rescheduled = true;
      void rescheduleAll();
    }

    // Online state
    const setOn = () => setOnline(true);
    const setOff = () => setOnline(false);
    window.addEventListener("online", setOn);
    window.addEventListener("offline", setOff);

    return () => {
      window.removeEventListener("online", setOn);
      window.removeEventListener("offline", setOff);
    };
  }, []);

  const loc = useLocation();
  const path = loc.pathname;
  const isActive = (base: string) =>
    base === "/" ? path === "/" : path.startsWith(base);

  return (
    <div className="min-h-screen bg-background text-foreground flex flex-col max-w-md mx-auto relative">
      <main className="flex-1 pb-20">{children}</main>

      <nav className="fixed bottom-0 left-1/2 -translate-x-1/2 w-full max-w-md bg-surface/90 backdrop-blur-xl border-t border-border z-40">
        <div className="flex items-center justify-around px-2 py-2 pb-[max(0.5rem,env(safe-area-inset-bottom))]">
          <NavBtn to="/" active={isActive("/")} label="Today" icon={<Home size={20} />} />
          <NavBtn to="/counter" active={isActive("/counter")} label="Counter" icon={<Truck size={20} />} />
          <NavBtn to="/search" active={isActive("/search")} label="Search" icon={<Search size={20} />} />
          <NavBtn to="/archive" active={isActive("/archive")} label="Archive" icon={<Archive size={20} />} />

          {/* Sync status pill */}
          <div
            className={`flex flex-col items-center gap-1 px-3 py-1.5 rounded-lg transition-colors ${
              online ? "text-primary-glow" : "text-muted-foreground"
            }`}
            aria-label={online ? "Synced" : "Offline"}
          >
            {online ? (
              <Cloud size={20} className="text-primary-glow" />
            ) : (
              <CloudOff size={20} className="text-muted-foreground" />
            )}
            <span className="text-[10px] font-medium uppercase tracking-wider">
              {online ? "Synced" : "Offline"}
            </span>
          </div>
        </div>
      </nav>
    </div>
  );
}

function NavBtn({
  to,
  active,
  label,
  icon,
}: {
  to: string;
  active: boolean;
  label: string;
  icon: ReactNode;
}) {
  return (
    <Link
      to={to}
      className={`flex flex-col items-center gap-1 px-3 py-1.5 rounded-lg transition-colors ${
        active ? "text-primary-glow" : "text-muted-foreground"
      }`}
    >
      {icon}
      <span className="text-[10px] font-medium uppercase tracking-wider">{label}</span>
    </Link>
  );
}
