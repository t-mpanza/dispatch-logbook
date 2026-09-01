import { Link, useLocation } from "@tanstack/react-router";
import { useQueryClient } from "@tanstack/react-query";
import { Archive, Home, Search, Truck, CloudOff, Cloud, FileText, RefreshCw, AlertCircle } from "lucide-react";
import type { ReactNode } from "react";
import { useEffect } from "react";
import { rescheduleAll } from "@/lib/reminders";
import { useSyncState, syncNow } from "@/lib/sync";
import { vibrate } from "@/lib/haptics";
import { toast } from "sonner";
import { ConnectionStatusBanner } from "./ConnectionStatusBanner";

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
    <div className="min-h-screen bg-transparent text-foreground flex flex-col max-w-md mx-auto relative antialiased select-none">
      {/* Hardware-Composited Fixed Background Layer */}
      <div className="ios-ambient-bg" />

      {/* Dynamic Island Style Connection Status Pill */}
      <ConnectionStatusBanner />

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
            className={`flex flex-col items-center gap-0.5 px-2 py-1 rounded-2xl ios-press relative ${
              syncState.status === "syncing"
                ? "text-blue-600 dark:text-primary-glow"
                : syncState.status === "error"
                  ? "text-destructive"
                  : syncState.status === "offline"
                    ? "text-slate-400 dark:text-slate-500"
                    : "text-blue-600 dark:text-primary-glow/90 hover:text-blue-700 dark:hover:text-primary-glow"
            }`}
            title="Tap to sync with cloud database"
            aria-label={`Sync status: ${syncState.status}`}
          >
            <div className="relative grid place-items-center h-7 w-7 rounded-xl bg-slate-100 dark:bg-white/[0.04] border border-slate-200 dark:border-white/[0.08]">
              {syncState.status === "syncing" ? (
                <RefreshCw size={14} className="animate-spin text-blue-600 dark:text-primary-glow" />
              ) : syncState.status === "error" ? (
                <AlertCircle size={14} className="text-destructive animate-pulse" />
              ) : syncState.status === "offline" ? (
                <CloudOff size={14} className="text-slate-400 dark:text-slate-500" />
              ) : (
                <Cloud size={14} className="text-blue-600 dark:text-primary-glow" />
              )}

              {/* Unsynced pending badge */}
              {syncState.pendingCount > 0 && (
                <span className="absolute -top-1 -right-1 h-3.5 w-3.5 rounded-full bg-blue-600 text-white font-mono text-[9px] font-bold grid place-items-center shadow-md">
                  {syncState.pendingCount > 9 ? "9+" : syncState.pendingCount}
                </span>
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
        active ? "text-blue-600 dark:text-primary-glow" : "text-slate-500 dark:text-slate-400 hover:text-slate-800 dark:hover:text-slate-200"
      }`}
    >
      <div
        className={`grid place-items-center h-7 w-7 rounded-xl transition-all duration-200 ${
          active
            ? "bg-blue-500/15 border border-blue-500/30 shadow-[0_0_14px_rgba(59,130,246,0.25)] text-blue-600 dark:text-primary-glow scale-105"
            : "bg-transparent text-slate-500 dark:text-slate-400"
        }`}
      >
        {icon}
      </div>
      <span
        className={`text-[9px] tracking-wide uppercase transition-all duration-200 ${
          active ? "font-bold text-slate-900 dark:text-slate-100 scale-95" : "font-medium text-slate-500 dark:text-slate-500"
        }`}
      >
        {label}
      </span>
    </Link>
  );
}
