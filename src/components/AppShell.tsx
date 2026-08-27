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
    <div className="min-h-screen bg-background text-foreground flex flex-col max-w-md mx-auto relative">
      <main className="flex-1 pb-24">{children}</main>

      <nav className="fixed bottom-0 left-1/2 -translate-x-1/2 w-full max-w-md glass-dock z-40">
        <div className="flex items-center justify-around px-2 py-2 pb-[max(0.6rem,env(safe-area-inset-bottom))]">
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

          {/* Interactive Sync status button */}
          <button
            onClick={handleManualSync}
            disabled={syncState.status === "syncing"}
            className={`flex flex-col items-center gap-1 px-2.5 py-1.5 rounded-xl transition-all active:scale-90 ${
              syncState.status === "syncing"
                ? "text-primary-glow"
                : syncState.status === "error"
                  ? "text-destructive"
                  : syncState.status === "offline"
                    ? "text-muted-foreground opacity-60"
                    : "text-primary-glow hover:text-primary-glow"
            }`}
            title="Tap to sync with cloud database"
            aria-label={`Sync status: ${syncState.status}`}
          >
            <div className="relative grid place-items-center">
              {syncState.status === "syncing" ? (
                <RefreshCw size={18} className="animate-spin text-primary-glow" />
              ) : syncState.status === "error" ? (
                <AlertCircle size={18} className="text-destructive animate-pulse" />
              ) : syncState.status === "offline" ? (
                <CloudOff size={18} className="text-muted-foreground" />
              ) : (
                <Cloud size={18} className="text-primary-glow" />
              )}
            </div>
            <span className="text-[9px] font-semibold uppercase tracking-wider truncate max-w-[48px]">
              {syncState.status === "syncing"
                ? "Syncing"
                : syncState.status === "error"
                  ? "Retry"
                  : syncState.status === "offline"
                    ? "Offline"
                    : "Synced"}
            </span>
          </button>
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
      onClick={() => vibrate("light")}
      className={`flex flex-col items-center gap-1 px-2.5 py-1.5 rounded-xl transition-all active:scale-90 relative ${
        active ? "text-primary-glow font-bold" : "text-muted-foreground hover:text-foreground"
      }`}
    >
      <div className={`grid place-items-center p-1 rounded-lg transition-all ${active ? "nav-pill-glow scale-105" : ""}`}>
        {icon}
      </div>
      <span className={`text-[9px] uppercase tracking-wider transition-all ${active ? "font-bold text-primary-glow scale-105" : "font-medium"}`}>
        {label}
      </span>
    </Link>
  );
}
