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
import { toast } from "sonner";

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "Today — Dispatch Diary" },
      { name: "description", content: "Fast-capture operational diary for dispatch." },
      { name: "theme-color", content: "#0a0a1a" },
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
    setSyncingModal(true);
    toast.info("Syncing…", { description: "Pushing and pulling all entries" });
    const success = await syncNow(qc);
    setSyncingModal(false);
    if (success) {
      toast.success("Database Synced", { description: "All records are synchronized with cloud." });
    } else {
      toast.error("Sync Error", { description: syncState.errorMessage || "Check network connection." });
    }
  }

  async function handleCheckForUpdates() {
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
        // OTA update via CapacitorUpdater
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
      <header className="px-5 pt-[max(2rem,env(safe-area-inset-top))] pb-4 flex items-start justify-between">
        <div>
          <p className="text-xs uppercase tracking-[0.2em] text-primary-glow font-medium">Today</p>
          <h1 className="mt-1 text-2xl font-semibold tracking-tight">{fmtDayLabel(today)}</h1>
          <p className="mt-1 text-sm text-muted-foreground">
            {entries.length === 0
              ? "Nothing logged yet. Tap + to capture."
              : `${entries.length} ${entries.length === 1 ? "entry" : "entries"}`}
          </p>
        </div>

        <div className="flex flex-col items-end gap-2">
          <Link
            to="/day/$date"
            params={{ date: yesterdayDateStr }}
            className="h-9 px-3 rounded-xl bg-surface-elevated border border-border flex items-center gap-1.5 text-xs text-muted-foreground hover:text-foreground hover:border-primary/50 transition-all active:scale-95"
            aria-label="Yesterday"
          >
            <ChevronLeft size={16} />
            <span className="font-semibold">Yesterday</span>
          </Link>
          {/* Version badge */}
          <button
            onClick={() => { setShowAbout(true); setUpdateStatus(null); }}
            className="flex items-center gap-1 text-[10px] text-muted-foreground/50 hover:text-muted-foreground transition-colors"
            aria-label="App version info"
          >
            <Smartphone size={10} />
            <span>{APP_VERSION}</span>
          </button>
        </div>
      </header>

      {/* ── About / Version sheet ─────────────────────────────────── */}
      {showAbout && (
        <div className="fixed inset-0 z-50 flex items-end bg-black/60 backdrop-blur-sm animate-fade-in" onClick={() => setShowAbout(false)}>
          <div
            className="w-full max-w-md mx-auto bg-surface border border-border/80 rounded-t-3xl p-6 pb-[max(1.5rem,env(safe-area-inset-bottom))] shadow-2xl animate-sheet-slide-up"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-center justify-between mb-5">
              <h2 className="text-base font-bold">Dispatch Diary</h2>
              <button
                onClick={() => setShowAbout(false)}
                className="h-8 w-8 rounded-full bg-muted grid place-items-center text-muted-foreground hover:text-foreground active:scale-90 transition-all"
              >
                <X size={16} />
              </button>
            </div>

            <div className="space-y-3 text-sm">
              <div className="flex justify-between py-2 border-b border-border/50">
                <span className="text-muted-foreground">Version</span>
                <span className="font-mono font-semibold">{APP_VERSION}</span>
              </div>
              <div className="flex justify-between py-2 border-b border-border/50">
                <span className="text-muted-foreground">Platform</span>
                <span className="font-mono">{Capacitor.isNativePlatform() ? Capacitor.getPlatform() : "web"}</span>
              </div>
              <div className="flex justify-between py-2 border-b border-border/50">
                <span className="text-muted-foreground">Database Sync</span>
                <span className="flex items-center gap-1.5 font-medium text-xs">
                  {syncState.status === "syncing" ? (
                    <>
                      <RefreshCw size={12} className="animate-spin text-primary-glow" />
                      <span className="text-primary-glow font-bold">Syncing…</span>
                    </>
                  ) : syncState.status === "error" ? (
                    <span className="text-destructive font-bold">Sync Error</span>
                  ) : syncState.status === "offline" ? (
                    <span className="text-muted-foreground">Offline</span>
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
              <div className="flex justify-between py-2 border-b border-border/50">
                <span className="text-muted-foreground">Repository</span>
                <span className="font-mono text-primary-glow text-xs">t-mpanza/dispatch-logbook</span>
              </div>
            </div>

            <div className="grid grid-cols-2 gap-2 mt-5">
              <button
                onClick={handleModalSync}
                disabled={syncingModal || syncState.status === "syncing"}
                className="flex items-center justify-center gap-2 rounded-xl bg-surface-elevated border border-border text-foreground py-3 text-xs font-semibold hover:border-primary/50 active:scale-95 transition-all disabled:opacity-50"
              >
                <RefreshCw size={14} className={syncingModal || syncState.status === "syncing" ? "animate-spin text-primary-glow" : ""} />
                {syncingModal || syncState.status === "syncing" ? "Syncing…" : "Sync Database"}
              </button>

              <button
                onClick={handleCheckForUpdates}
                disabled={checkingUpdate}
                className="flex items-center justify-center gap-2 rounded-xl bg-primary/15 border border-primary/30 text-primary-glow py-3 text-xs font-semibold hover:bg-primary/25 active:scale-95 transition-all disabled:opacity-50"
              >
                <Smartphone size={14} className={checkingUpdate ? "animate-spin" : ""} />
                {checkingUpdate ? "Checking…" : "Check Update"}
              </button>
            </div>

            {updateStatus && (
              <p className="mt-3 text-center text-xs text-muted-foreground bg-background/50 py-2 rounded-lg border border-border/50 font-mono">{updateStatus}</p>
            )}
          </div>
        </div>
      )}

      <div className="px-5 space-y-2.5">
        {isLoading ? (
          <p className="text-sm text-muted-foreground">Loading…</p>
        ) : entries.length === 0 ? (
          <EmptyState />
        ) : (
          entries.map((e) => <EntryListItem key={e.id} entry={e} />)
        )}
      </div>

      <Link
        to="/entry/new"
        className="fixed bottom-24 right-5 z-40 h-14 w-14 rounded-full bg-[image:var(--gradient-primary)] text-primary-foreground grid place-items-center shadow-[var(--shadow-glow)] active:scale-90 transition-transform cursor-pointer hover:scale-105"
        aria-label="New entry"
      >
        <Plus size={26} />
      </Link>
    </AppShell>
  );
}

function EmptyState() {
  return (
    <div className="mt-6 rounded-2xl border border-dashed border-border p-8 text-center">
      <div className="mx-auto h-14 w-14 rounded-full bg-[image:var(--gradient-primary)] grid place-items-center shadow-[var(--shadow-glow)]">
        <Plus size={22} className="text-primary-foreground" />
      </div>
      <h2 className="mt-4 font-semibold">Start logging</h2>
      <p className="mt-1 text-sm text-muted-foreground">
        Voice notes, photos, videos, files — all stored on this device.
      </p>
      <Link
        to="/entry/new"
        className="inline-flex mt-4 px-4 py-2 rounded-full bg-primary text-primary-foreground text-sm font-medium"
      >
        New entry
      </Link>
    </div>
  );
}
