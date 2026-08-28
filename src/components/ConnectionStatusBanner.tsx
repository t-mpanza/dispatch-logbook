import { useEffect, useState } from "react";
import { WifiOff, CheckCircle2, RefreshCw } from "lucide-react";
import { subscribeSyncState, type SyncState } from "@/lib/sync";

export function ConnectionStatusBanner() {
  const [syncState, setSyncState] = useState<SyncState>({
    status: "idle",
    lastSyncedAt: null,
    pendingCount: 0,
    errorMessage: null,
  });

  const [showOnlineToast, setShowOnlineToast] = useState(false);
  const [wasOffline, setWasOffline] = useState(false);

  useEffect(() => {
    return subscribeSyncState((state) => {
      setSyncState(state);

      if (state.status === "offline") {
        setWasOffline(true);
      } else if (wasOffline && (state.status === "synced" || state.status === "idle")) {
        setShowOnlineToast(true);
        setWasOffline(false);
        const timer = setTimeout(() => setShowOnlineToast(false), 3200);
        return () => clearTimeout(timer);
      }
    });
  }, [wasOffline]);

  if (syncState.status === "offline") {
    return (
      <div className="fixed top-[max(0.75rem,env(safe-area-inset-top))] left-1/2 -translate-x-1/2 z-50 animate-fade-in-scale pointer-events-none">
        <div className="ios-glass-elevated px-3.5 py-1.5 rounded-full flex items-center gap-2 border border-amber-500/30 bg-amber-500/10 shadow-2xl">
          <WifiOff size={13} className="text-amber-400 animate-pulse" />
          <span className="text-[11px] font-bold font-mono text-amber-300 uppercase tracking-wider">
            Offline · Saving Locally
          </span>
          {syncState.pendingCount > 0 && (
            <span className="text-[10px] bg-amber-500/20 text-amber-300 font-bold font-mono px-1.5 py-0.5 rounded-full">
              {syncState.pendingCount}
            </span>
          )}
        </div>
      </div>
    );
  }

  if (showOnlineToast) {
    return (
      <div className="fixed top-[max(0.75rem,env(safe-area-inset-top))] left-1/2 -translate-x-1/2 z-50 animate-fade-in-scale pointer-events-none">
        <div className="ios-glass-elevated px-3.5 py-1.5 rounded-full flex items-center gap-2 border border-emerald-500/30 bg-emerald-500/10 shadow-2xl">
          <CheckCircle2 size={13} className="text-emerald-400" />
          <span className="text-[11px] font-bold font-mono text-emerald-300 uppercase tracking-wider">
            Back Online · Synced
          </span>
        </div>
      </div>
    );
  }

  if (syncState.status === "syncing") {
    return (
      <div className="fixed top-[max(0.75rem,env(safe-area-inset-top))] left-1/2 -translate-x-1/2 z-50 animate-fade-in-scale pointer-events-none">
        <div className="ios-glass-pill px-3 py-1 flex items-center gap-2 shadow-xl border border-blue-500/20">
          <RefreshCw size={11} className="text-blue-400 animate-spin" />
          <span className="text-[10px] font-bold font-mono text-slate-300 uppercase tracking-wider">
            Syncing Cloud…
          </span>
        </div>
      </div>
    );
  }

  return null;
}
