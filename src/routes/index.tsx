import { createFileRoute, Link } from "@tanstack/react-router";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { Plus, ChevronLeft, X, RefreshCw, Smartphone, Cloud, CloudOff } from "lucide-react";
import { useState } from "react";
import { AppShell } from "@/components/AppShell";
import { entriesByDay } from "@/lib/db";
import { dayKey, fmtDayLabel, fmtTime } from "@/lib/format";
import { EntryListItem } from "@/components/EntryListItem";
import { Capacitor } from "@capacitor/core";
import { useSyncState, syncNow } from "@/lib/sync";
import { vibrate } from "@/lib/haptics";
import { toast } from "sonner";

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "Today — Dispatch Diary" },
      { name: "description", content: "Fast-capture operational diary for dispatch." },
      { name: "theme-color", content: "#080816" },
    ],
    links: [
      { rel: "manifest", href: "/manifest.webmanifest" },
      { rel: "icon", href: "/icon-512.png" },
      { rel: "apple-touch-icon", href: "/icon-512.png" },
    ],
  }),
  component: TodayPage,
});

const APP_VERSION = import.meta.env.VITE_APP_VERSION || "dev";

function TodayPage() {
  const qc = useQueryClient();
  const syncState = useSyncState();
  const today = new Date();
  const key = dayKey(today);
  const { data: entries = [], isLoading } = useQuery({
    queryKey: ["entries", "day", key],
    queryFn: () => entriesByDay(key),
  });

  const yesterday = new Date(today);
  yesterday.setDate(yesterday.getDate() - 1);
  const yesterdayDateStr = dayKey(yesterday);

  const [showAbout, setShowAbout] = useState(false);
  const [checkingUpdate, setCheckingUpdate] = useState(false);
  const [updateStatus, setUpdateStatus] = useState<string | null>(null);
  const [syncingModal, setSyncingModal] = useState(false);

  async function handleModalSync() {
    vibrate("medium");
    setSyncingModal(true);
    toast.info("Syncing…", { description: "Pushing and pulling all entries" });
    const success = await syncNow(qc);
    setSyncingModal(false);
    if (success) {
      vibrate("success");
      toast.success("Database Synced", { description: "All records are synchronized with cloud." });
    } else {
      vibrate("error");
      toast.error("Sync Error", { description: syncState.errorMessage || "Check network connection." });
    }
  }

  async function handleCheckForUpdates() {
    vibrate("light");
    setCheckingUpdate(true);
    setUpdateStatus(null);
    try {
      const res = await fetch(
        "https://api.github.com/repos/t-mpanza/dispatch-logbook/releases/latest"
      );
      if (!res.ok) throw new Error("Network error");
      const release = await res.json();
      const latestTag: string = release.tag_name;
      if (!latestTag) throw new Error("No tag found");

      if (latestTag === APP_VERSION) {
        setUpdateStatus(`✓ Already on latest (${latestTag})`);
      } else if (Capacitor.isNativePlatform()) {
        const { CapacitorUpdater } = await import("@capgo/capacitor-updater");
        const asset = release.assets?.find((a: any) => a.name === "dist.zip");
        if (asset) {
          setUpdateStatus(`Downloading ${latestTag}…`);
          const bundle = await CapacitorUpdater.download({
            url: asset.browser_download_url,
            version: latestTag,
          });
          setShowAbout(false);
          toast("Update Ready", {
            description: `${latestTag} downloaded. Tap Restart to apply.`,
            action: {
              label: "Restart",
              onClick: () => CapacitorUpdater.set({ id: bundle.id }),
            },
            duration: Infinity,
          });
        } else {
          setUpdateStatus(`${latestTag} available — reinstall APK from GitHub Releases`);
        }
      } else {
        setUpdateStatus(`${latestTag} available — refresh the page`);
      }
    } catch {
      setUpdateStatus("Could not check for updates. Try again later.");
    } finally {
      setCheckingUpdate(false);
    }
  }

  return (
    <AppShell>
      {/* iOS Large Header */}
      <header className="px-5 pt-[max(2.25rem,env(safe-area-inset-top))] pb-3 flex items-start justify-between">
        <div>
          <p className="text-[11px] uppercase tracking-[0.2em] text-primary-glow font-bold">Today</p>
          <h1 className="mt-0.5 text-3xl font-extrabold tracking-tight text-white font-sans">{fmtDayLabel(today)}</h1>
          <p className="mt-1 text-xs text-white/50 font-medium">
            {entries.length === 0
              ? "Nothing logged yet. Tap + to capture."
              : `${entries.length} ${entries.length === 1 ? "trip entry" : "trip entries"}`}
          </p>
        </div>

        <div className="flex flex-col items-end gap-2">
          <Link
            to="/day/$date"
            params={{ date: yesterdayDateStr }}
            onClick={() => vibrate("light")}
            className="h-9 px-3.5 rounded-full ios-glass flex items-center gap-1 text-xs font-bold text-white/80 hover:text-white ios-press shadow-md"
            aria-label="Yesterday"
          >
            <ChevronLeft size={16} className="text-primary-glow" />
            <span>Yesterday</span>
          </Link>
          {/* Version badge */}
          <button
            onClick={() => {
              vibrate("light");
              setShowAbout(true);
              setUpdateStatus(null);
            }}
            className="flex items-center gap-1 text-[10px] text-white/40 hover:text-white/80 transition-colors px-1.5 py-0.5 rounded-full bg-white/[0.04] border border-white/[0.06]"
            aria-label="App version info"
          >
            <Smartphone size={10} />
            <span className="font-mono">{APP_VERSION}</span>
          </button>
        </div>
      </header>

      {/* ── About / Diagnostics iOS Bottom Sheet ──────────────────── */}
      {showAbout && (
        <div
          className="fixed inset-0 z-50 flex items-end justify-center bg-black/65 backdrop-blur-md animate-fade-in"
          onClick={() => setShowAbout(false)}
        >
          <div
            className="w-full max-w-md mx-auto ios-glass-elevated rounded-t-[2.5rem] p-6 pb-[max(1.5rem,env(safe-area-inset-bottom))] shadow-2xl animate-sheet-slide-up"
            onClick={(e) => e.stopPropagation()}
          >
            {/* iOS Grabber */}
            <div className="ios-grabber" />

            <div className="flex items-center justify-between pb-3.5 border-b border-white/[0.08]">
              <div>
                <h2 className="text-base font-bold text-white">Dispatch Diary</h2>
                <p className="text-xs text-white/50">System Info & Cloud Diagnostics</p>
              </div>
              <button
                onClick={() => setShowAbout(false)}
                className="h-8 w-8 rounded-full bg-white/[0.08] grid place-items-center text-white/60 hover:text-white active:scale-90 transition-all"
              >
                <X size={16} />
              </button>
            </div>

            <div className="space-y-3 text-xs mt-4">
              <div className="flex justify-between py-2 border-b border-white/[0.06]">
                <span className="text-white/50">Version</span>
                <span className="font-mono font-bold text-white">{APP_VERSION}</span>
              </div>
              <div className="flex justify-between py-2 border-b border-white/[0.06]">
                <span className="text-white/50">Platform</span>
                <span className="font-mono text-white/90">{Capacitor.isNativePlatform() ? Capacitor.getPlatform() : "web"}</span>
              </div>
              <div className="flex justify-between py-2 border-b border-white/[0.06]">
                <span className="text-white/50">Database Sync</span>
                <span className="flex items-center gap-1.5 font-medium text-xs">
                  {syncState.status === "syncing" ? (
                    <>
                      <RefreshCw size={12} className="animate-spin text-primary-glow" />
                      <span className="text-primary-glow font-bold">Syncing…</span>
                    </>
                  ) : syncState.status === "error" ? (
                    <span className="text-rose-400 font-bold">Sync Error</span>
                  ) : syncState.status === "offline" ? (
                    <span className="text-white/40">Offline</span>
                  ) : (
                    <>
                      <Cloud size={12} className="text-primary-glow" />
                      <span className="text-primary-glow font-bold">
                        Synced {syncState.lastSyncedAt ? `(${fmtTime(syncState.lastSyncedAt)})` : ""}
                      </span>
                    </>
                  )}
                </span>
              </div>
              <div className="flex justify-between py-2 border-b border-white/[0.06]">
                <span className="text-white/50">Repository</span>
                <span className="font-mono text-primary-glow text-xs">t-mpanza/dispatch-logbook</span>
              </div>
            </div>

            <div className="grid grid-cols-2 gap-2 mt-5">
              <button
                onClick={handleModalSync}
                disabled={syncingModal || syncState.status === "syncing"}
                className="flex items-center justify-center gap-2 rounded-2xl bg-white/[0.06] border border-white/[0.12] text-white py-3 text-xs font-semibold hover:bg-white/[0.12] ios-press disabled:opacity-40 shadow-sm"
              >
                <RefreshCw size={14} className={syncingModal || syncState.status === "syncing" ? "animate-spin text-primary-glow" : ""} />
                {syncingModal || syncState.status === "syncing" ? "Syncing…" : "Sync Database"}
              </button>

              <button
                onClick={handleCheckForUpdates}
                disabled={checkingUpdate}
                className="flex items-center justify-center gap-2 rounded-2xl bg-primary text-white py-3 text-xs font-bold hover:bg-primary/90 ios-press disabled:opacity-40 shadow-md"
              >
                <Smartphone size={14} className={checkingUpdate ? "animate-spin" : ""} />
                {checkingUpdate ? "Checking…" : "Check Update"}
              </button>
            </div>

            {updateStatus && (
              <p className="mt-3 text-center text-xs text-white/70 bg-black/40 py-2.5 rounded-xl border border-white/[0.08] font-mono shadow-inner">{updateStatus}</p>
            )}
          </div>
        </div>
      )}

      {/* Entry List */}
      <div className="px-4 space-y-3">
        {isLoading ? (
          <p className="text-xs text-white/40 text-center py-8 font-mono">Loading entries…</p>
        ) : entries.length === 0 ? (
          <EmptyState />
        ) : (
          entries.map((e) => <EntryListItem key={e.id} entry={e} />)
        )}
      </div>

      {/* iOS Floating Action Button (Glass Glow) */}
      <Link
        to="/entry/new"
        onClick={() => vibrate("medium")}
        className="fixed bottom-24 right-5 z-40 h-14 w-14 rounded-full bg-[image:var(--gradient-primary)] text-white grid place-items-center shadow-[0_8px_30px_rgba(139,92,246,0.55)] border-t border-white/30 ios-press-bounce cursor-pointer"
        aria-label="New entry"
      >
        <Plus size={26} />
      </Link>
    </AppShell>
  );
}

function EmptyState() {
  return (
    <div className="mt-6 ios-glass-card p-8 text-center border-dashed">
      <div className="mx-auto h-14 w-14 rounded-full bg-primary/20 border border-primary-glow/40 grid place-items-center shadow-lg text-primary-glow">
        <Plus size={24} />
      </div>
      <h2 className="mt-4 font-bold text-white text-base">Start logging</h2>
      <p className="mt-1 text-xs text-white/50 max-w-xs mx-auto">
        Voice notes, photos, videos, and loading sheets — stored securely on this device.
      </p>
      <Link
        to="/entry/new"
        onClick={() => vibrate("light")}
        className="inline-flex mt-4 px-5 py-2.5 rounded-full bg-primary text-white text-xs font-bold ios-press shadow-md"
      >
        New Trip Entry
      </Link>
    </div>
  );
}
