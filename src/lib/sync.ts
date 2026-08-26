/**
 * Comprehensive Sync Engine for Dispatch Diary
 * - Local-first: IndexedDB is always the local source of truth.
 * - Multi-device synchronization via Supabase PostgreSQL & Storage.
 * - Batch-optimized pulls & 30-day signed URLs for zero rate-limiting.
 * - Reactive Sync State Store with live UI updates and manual trigger.
 * - Supabase Realtime synchronization across all active devices.
 */

import { useState, useEffect } from "react";
import type { QueryClient } from "@tanstack/react-query";
import { supabase } from "./supabase";
import { allEntries, saveEntryLocal } from "./db";
import type { Attachment, Entry, LoadingSheetTrip, NoteBlock } from "./types";

// ── Types & Reactive Sync State ─────────────────────────────────────────────

export type SyncStatus = "idle" | "syncing" | "synced" | "error" | "offline";

export interface SyncState {
  status: SyncStatus;
  lastSyncedAt: number | null;
  pendingCount: number;
  errorMessage: string | null;
}

let currentSyncState: SyncState = {
  status: typeof navigator !== "undefined" && !navigator.onLine ? "offline" : "idle",
  lastSyncedAt: null,
  pendingCount: 0,
  errorMessage: null,
};

const syncListeners = new Set<(state: SyncState) => void>();

function setSyncState(patch: Partial<SyncState>) {
  currentSyncState = { ...currentSyncState, ...patch };
  syncListeners.forEach((fn) => {
    try {
      fn(currentSyncState);
    } catch (e) {
      console.error("Error in sync state listener:", e);
    }
  });
}

export function getSyncState(): SyncState {
  return currentSyncState;
}

export function subscribeSyncState(fn: (state: SyncState) => void): () => void {
  syncListeners.add(fn);
  fn(currentSyncState);
  return () => {
    syncListeners.delete(fn);
  };
}

export function useSyncState(): SyncState {
  const [state, setState] = useState<SyncState>(currentSyncState);
  useEffect(() => {
    return subscribeSyncState(setState);
  }, []);
  return state;
}

// ── Auth Helper ─────────────────────────────────────────────────────────────

async function getUserId(): Promise<string | null> {
  const { data } = await supabase.auth.getUser();
  if (data.user?.id) return data.user.id;

  // Silently re-authenticate using the operational master account
  const { data: authData, error } = await supabase.auth.signInWithPassword({
    email: "kiddow@dispatch.local",
    password: "dispatch2026",
  });

  if (error) {
    console.error("Supabase auto-login failed:", error.message);
    return null;
  }
  return authData.user?.id ?? null;
}

// ── Storage Helpers ─────────────────────────────────────────────────────────

/** Upload a Blob directly to Supabase Storage with upsert: true */
async function uploadBlob(
  userId: string,
  attachmentId: string,
  blob: Blob,
  mime: string,
): Promise<string | null> {
  const ext = mime.split("/")[1]?.split(";")[0] ?? "bin";
  const path = `${userId}/${attachmentId}.${ext}`;

  const { error } = await supabase.storage
    .from("attachments")
    .upload(path, blob, { contentType: mime, upsert: true });

  if (error) {
    console.error("Blob upload failed for attachment:", attachmentId, error.message);
    return null;
  }
  return path;
}

/** Upload media attachments and sync their metadata rows */
async function syncAttachments(
  userId: string,
  entryId: string,
  attachments: Attachment[],
): Promise<void> {
  for (const att of attachments) {
    if (!att.blob) continue;

    const path = await uploadBlob(userId, att.id, att.blob, att.mime);
    if (!path) continue;

    const { error } = await supabase.from("entry_attachments").upsert(
      {
        id: att.id,
        entry_id: entryId,
        user_id: userId,
        kind: att.kind,
        mime: att.mime,
        name: att.name ?? null,
        caption: att.caption ?? null,
        duration_ms: att.durationMs ?? null,
        width: att.width ?? null,
        height: att.height ?? null,
        storage_path: path,
        created_at: att.createdAt,
      },
      { onConflict: "id" },
    );

    if (error) {
      console.error("Failed to upsert attachment metadata:", att.id, error.message);
    }
  }
}

// ── Push (Local IndexedDB → Supabase Cloud) ─────────────────────────────────

export async function pushEntry(entry: Entry): Promise<boolean> {
  if (typeof navigator !== "undefined" && !navigator.onLine) {
    setSyncState({ status: "offline" });
    return false;
  }

  const userId = await getUserId();
  if (!userId) {
    setSyncState({ status: "error", errorMessage: "Authentication failed" });
    return false;
  }

  // Non-blocking attachment upload
  syncAttachments(userId, entry.id, entry.attachments).catch(console.error);

  // Encode loadingSheetTrips & despatcherName safely in __meta_sheet__ note to avoid schema mismatch
  const cleanNotes = (entry.notes || []).filter((n) => n.id !== "__meta_sheet__");
  const hasMeta =
    (entry.loadingSheetTrips && entry.loadingSheetTrips.length > 0) || entry.despatcherName;

  const notesPayload = hasMeta
    ? [
        ...cleanNotes,
        {
          id: "__meta_sheet__",
          text: JSON.stringify({
            loadingSheetTrips: entry.loadingSheetTrips || [],
            despatcherName: entry.despatcherName || "Theolus",
          }),
          createdAt: entry.updatedAt || Date.now(),
        },
      ]
    : cleanNotes;

  const { error } = await supabase.from("entries").upsert(
    {
      id: entry.id,
      user_id: userId,
      title: entry.title,
      tags: entry.tags,
      notes: notesPayload,
      trips: entry.trips ?? null,
      expected_total: entry.expectedTotal ?? null,
      day_key: entry.dayKey,
      month_key: entry.monthKey,
      year_key: entry.yearKey,
      created_at: entry.createdAt,
      updated_at: entry.updatedAt,
    },
    { onConflict: "id" },
  );

  if (error) {
    console.error("Supabase push failed for entry:", entry.id, error.message);
    setSyncState({ status: "error", errorMessage: error.message });
    return false;
  }

  return true;
}

// ── Pull (Supabase Cloud → Local IndexedDB) ─────────────────────────────────

export async function pullAndMerge(): Promise<{ pulledCount: number; hasUpdates: boolean }> {
  if (typeof navigator !== "undefined" && !navigator.onLine) {
    setSyncState({ status: "offline" });
    return { pulledCount: 0, hasUpdates: false };
  }

  const userId = await getUserId();
  if (!userId) {
    setSyncState({ status: "error", errorMessage: "Authentication failed" });
    return { pulledCount: 0, hasUpdates: false };
  }

  // Optimized parallel queries with order by updated_at
  const [entriesRes, attsRes] = await Promise.all([
    supabase
      .from("entries")
      .select("*")
      .eq("user_id", userId)
      .order("updated_at", { ascending: false })
      .limit(500),
    supabase
      .from("entry_attachments")
      .select("*")
      .eq("user_id", userId)
      .limit(1000),
  ]);

  if (entriesRes.error) {
    console.error("Supabase pull entries failed:", entriesRes.error.message);
    setSyncState({ status: "error", errorMessage: entriesRes.error.message });
    return { pulledCount: 0, hasUpdates: false };
  }

  const remoteEntries = entriesRes.data || [];
  const remoteAttachments = attsRes.data || [];

  // Batch-sign all attachment storage paths in a single API call (30-day expiration)
  const pathsToSign = Array.from(
    new Set(
      remoteAttachments
        .map((a: any) => a.storage_path)
        .filter((p: any): p is string => typeof p === "string" && p.length > 0),
    ),
  );

  const signedUrlMap = new Map<string, string>();
  if (pathsToSign.length > 0) {
    try {
      const { data: signedList, error: signErr } = await supabase.storage
        .from("attachments")
        .createSignedUrls(pathsToSign, 86400 * 30); // 30 days

      if (signedList && !signErr) {
        for (const item of signedList) {
          if (item.path && item.signedUrl) {
            signedUrlMap.set(item.path, item.signedUrl);
          }
        }
      }
    } catch (signEx) {
      console.error("Batch signing storage URLs error:", signEx);
    }
  }

  const localEntries = await allEntries();
  const localMap = new Map(localEntries.map((e) => [e.id, e]));
  let updateCount = 0;

  for (const remote of remoteEntries) {
    const local = localMap.get(remote.id);

    // If local version is newer or equal, preserve local changes
    if (local && local.updatedAt >= remote.updated_at) {
      continue;
    }

    // Decode metadata note (__meta_sheet__) into loadingSheetTrips & despatcherName
    let loadingSheetTrips: LoadingSheetTrip[] | undefined = undefined;
    let despatcherName: string | undefined = undefined;
    const userNotes: NoteBlock[] = [];

    for (const note of remote.notes || []) {
      if (note && note.id === "__meta_sheet__") {
        try {
          const parsed = JSON.parse(note.text);
          if (Array.isArray(parsed.loadingSheetTrips)) {
            loadingSheetTrips = parsed.loadingSheetTrips;
          }
          if (typeof parsed.despatcherName === "string") {
            despatcherName = parsed.despatcherName;
          }
        } catch {
          // ignore malformed metadata
        }
      } else if (note) {
        userNotes.push(note);
      }
    }

    // Map attachments for this entry with long-lived signed URLs
    const attsForEntry = remoteAttachments.filter((a: any) => a.entry_id === remote.id);
    const mergedAttachments: Attachment[] = attsForEntry.map((a: any) => {
      const existingLocalAtt = local?.attachments?.find((la) => la.id === a.id);
      const signedUrl = a.storage_path ? signedUrlMap.get(a.storage_path) : undefined;

      return {
        id: a.id,
        kind: a.kind,
        mime: a.mime,
        name: a.name ?? undefined,
        caption: a.caption ?? undefined,
        durationMs: a.duration_ms ?? undefined,
        width: a.width ?? undefined,
        height: a.height ?? undefined,
        storagePath: a.storage_path,
        blob: existingLocalAtt?.blob, // Preserve local blob if already downloaded
        downloadUrl: signedUrl ?? existingLocalAtt?.downloadUrl,
        createdAt: a.created_at,
      } as Attachment;
    });

    const merged: Entry = {
      id: remote.id,
      title: remote.title,
      tags: remote.tags ?? [],
      notes: userNotes,
      trips: remote.trips ?? undefined,
      loadingSheetTrips: loadingSheetTrips ?? local?.loadingSheetTrips,
      despatcherName: despatcherName ?? local?.despatcherName,
      expectedTotal: remote.expected_total ?? undefined,
      attachments: mergedAttachments,
      createdAt: remote.created_at,
      updatedAt: remote.updated_at,
      dayKey: remote.day_key,
      monthKey: remote.month_key,
      yearKey: remote.year_key,
    };

    // Save locally without triggering an unnecessary recursive cloud push
    await saveEntryLocal(merged);
    updateCount++;
  }

  return { pulledCount: remoteEntries.length, hasUpdates: updateCount > 0 };
}

// ── Full Sync & Manual Sync Trigger ─────────────────────────────────────────

let isSyncRunning = false;

export async function fullSync(queryClient?: QueryClient): Promise<boolean> {
  if (isSyncRunning) return false;
  if (typeof navigator !== "undefined" && !navigator.onLine) {
    setSyncState({ status: "offline" });
    return false;
  }

  isSyncRunning = true;
  setSyncState({ status: "syncing", errorMessage: null });

  try {
    const userId = await getUserId();
    if (!userId) {
      setSyncState({ status: "error", errorMessage: "Failed to authenticate" });
      isSyncRunning = false;
      return false;
    }

    // 1. Push all local entries in parallel batches of 6
    const local = await allEntries();
    const chunks: Entry[][] = [];
    for (let i = 0; i < local.length; i += 6) {
      chunks.push(local.slice(i, i + 6));
    }
    for (const chunk of chunks) {
      await Promise.all(chunk.map(pushEntry));
    }

    // 2. Pull remote changes
    const { hasUpdates } = await pullAndMerge();

    // 3. Invalidate React Query cache if new updates arrived or queryClient provided
    if (queryClient) {
      queryClient.invalidateQueries({ queryKey: ["entries"] });
      queryClient.invalidateQueries({ queryKey: ["entry"] });
      queryClient.invalidateQueries({ queryKey: ["tags"] });
    }

    setSyncState({
      status: "synced",
      lastSyncedAt: Date.now(),
      pendingCount: 0,
      errorMessage: null,
    });
    isSyncRunning = false;
    return true;
  } catch (err: any) {
    console.error("Full sync failed with error:", err);
    setSyncState({ status: "error", errorMessage: err?.message || "Sync error" });
    isSyncRunning = false;
    return false;
  }
}

/** Explicit user-triggered or automated sync action */
export async function syncNow(queryClient?: QueryClient): Promise<boolean> {
  return fullSync(queryClient);
}

// ── Realtime Synchronization Listener ───────────────────────────────────────

let realtimeChannel: any = null;

export function setupRealtimeSync(queryClient?: QueryClient): () => void {
  if (typeof window === "undefined") return () => {};
  if (realtimeChannel) return () => {};

  try {
    realtimeChannel = supabase
      .channel("dispatch_live_sync")
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "entries" },
        async (payload: any) => {
          console.log("Supabase Realtime entry event:", payload.eventType);
          const { hasUpdates } = await pullAndMerge();
          if (hasUpdates && queryClient) {
            queryClient.invalidateQueries({ queryKey: ["entries"] });
            queryClient.invalidateQueries({ queryKey: ["entry"] });
            queryClient.invalidateQueries({ queryKey: ["tags"] });
          }
        },
      )
      .subscribe();
  } catch (e) {
    console.error("Realtime sync setup failed:", e);
  }

  return () => {
    if (realtimeChannel) {
      try {
        supabase.removeChannel(realtimeChannel);
      } catch {}
      realtimeChannel = null;
    }
  };
}

// ── Delete Propagation ──────────────────────────────────────────────────────

export async function deleteRemoteEntry(id: string): Promise<void> {
  const userId = await getUserId();
  if (!userId) return;
  await supabase.from("entries").delete().eq("id", id).eq("user_id", userId);
}
