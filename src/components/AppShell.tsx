import { Link, useLocation } from "@tanstack/react-router";
import { useQueryClient } from "@tanstack/react-query";
import { Archive, Home, Search, Truck, CloudOff, Cloud, FileText, RefreshCw, AlertCircle } from "lucide-react";
import type { ReactNode } from "react";
import { useEffect } from "react";
import { rescheduleAll } from "@/lib/reminders";
import { useSyncState, syncNow } from "@/lib/sync";
import { vibrate } from "@/lib/haptics";
import { toast } from "sonner";

let rescheduled = false;

export function AppShell({ children }: { children: ReactNode }) {
  const qc = useQueryClient();
  const syncState = useSyncState();

  useEffect(() => {
    if (!rescheduled) {
      rescheduled = true;
      void rescheduleAll();
    }
  }, []);

  const loc = useLocation();
  const path = loc.pathname;
  const isActive = (base: string) => (base === "/" ? path === "/" : path.startsWith(base));

  const handleManualSync = async () => {
    vibrate("medium");
    if (syncState.status === "offline") {
      toast.error("Offline", { description: "Connect to internet to sync data." });
      return;
    }
    if (syncState.status === "syncing") {
      return;
    }

    toast.info("Syncing…", { description: "Connecting to database" });
    const success = await syncNow(qc);
    if (success) {
      vibrate("success");
      toast.success("Synced", { description: "All records and media up to date." });
    } else {
      vibrate("error");
      toast.error("Sync Error", {
        description: syncState.errorMessage || "Failed to sync. Tap again to retry.",
      });
    }
  };

  return (
    <div className="min-h-screen bg-transparent text-foreground flex flex-col max-w-md mx-auto relative antialiased">
      {/* Hardware-Composited Fixed Background Layer (Zero scroll invalidation) */}
      <div className="ios-ambient-bg" />

      {/* Main scrollable content container */}
      <main className="flex-1 pb-32">{children}</main>

      {/* Floating Titanium Obsidian Dock Navigation */}
      <div className="fixed bottom-0 left-1/2 -translate-x-1/2 w-full max-w-md px-3 pb-[max(0.75rem,env(safe-area-inset-bottom))] z-40 pointer-events-none">
        <nav className="ios-glass-dock px-2 py-1.5 pointer-events-auto flex items-center justify-between shadow-2xl">
          <NavBtn to="/" active={isActive("/")} label="Today" icon={<Home size={19} />} />
          <NavBtn
            to="/loading-sheet"
            active={isActive("/loading-sheet")}
            label="Sheet"
            icon={<FileText size={19} />}
          />
          <NavBtn
            to="/counter"
            active={isActive("/counter")}
            label="Counter"
            icon={<Truck size={19} />}
          />
          <NavBtn
            to="/search"
            active={isActive("/search")}
            label="Search"
            icon={<Search size={19} />}
          />
          <NavBtn
            to="/archive"
            active={isActive("/archive")}
            label="Archive"
            icon={<Archive size={19} />}
          />

          {/* Interactive Cloud Sync status button */}
          <button
            onClick={handleManualSync}
            disabled={syncState.status === "syncing"}
            className={`flex flex-col items-center gap-0.5 px-2 py-1 rounded-2xl ios-press ${
              syncState.status === "syncing"
                ? "text-primary-glow"
                : syncState.status === "error"
                  ? "text-destructive"
                  : syncState.status === "offline"
                    ? "text-slate-500"
                    : "text-primary-glow/90 hover:text-primary-glow"
            }`}
            title="Tap to sync with cloud database"
            aria-label={`Sync status: ${syncState.status}`}
          >
            <div className="relative grid place-items-center h-7 w-7 rounded-xl bg-white/[0.04] border border-white/[0.08]">
              {syncState.status === "syncing" ? (
                <RefreshCw size={14} className="animate-spin text-primary-glow" />
              ) : syncState.status === "error" ? (
                <AlertCircle size={14} className="text-destructive animate-pulse" />
              ) : syncState.status === "offline" ? (
                <CloudOff size={14} className="text-slate-500" />
              ) : (
                <Cloud size={14} className="text-primary-glow" />
              )}
            </div>
            <span className="text-[9px] font-bold uppercase tracking-wider truncate max-w-[48px] scale-90">
              {syncState.status === "syncing"
                ? "Sync"
                : syncState.status === "error"
                  ? "Retry"
                  : syncState.status === "offline"
                    ? "Off"
                    : "Live"}
            </span>
          </button>
        </nav>

        {/* iOS Home Indicator Bar */}
        <div className="ios-home-indicator" />
      </div>
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
      onClick={() => vibrate("light")}
      className={`flex flex-col items-center gap-0.5 px-2.5 py-1 rounded-2xl ios-press relative ${
        active ? "text-primary-glow" : "text-slate-400 hover:text-slate-200"
      }`}
    >
      <div
        className={`grid place-items-center h-7 w-7 rounded-xl transition-all duration-200 ${
          active
            ? "bg-primary/20 border border-primary-glow/40 shadow-[0_0_14px_rgba(59,130,246,0.35)] text-primary-glow scale-105"
            : "bg-transparent text-slate-400"
        }`}
      >
        {icon}
      </div>
      <span
        className={`text-[9px] tracking-wide uppercase transition-all duration-200 ${
          active ? "font-bold text-slate-100 scale-95" : "font-medium text-slate-500"
        }`}
      >
        {label}
      </span>
    </Link>
  );
}
