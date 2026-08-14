/**
 * Background sync engine — pushes local IndexedDB entries to Supabase.
 * - Local-first: IndexedDB is always the source of truth.
 * - Sync runs silently in the background; never blocks the UI.
 * - Conflict resolution: higher updatedAt wins.
 * - Blobs (photos, audio, video) are uploaded to Supabase Storage.
 *   Only the storage path is stored in the DB row; signed URLs are
 *   generated on pull so every device can display media.
 */

import { supabase } from "./supabase";
import { allEntries, updateEntry as localUpdateEntry } from "./db";
import type { Attachment, Entry } from "./types";

// ── Helpers ────────────────────────────────────────────────────────────────

async function getUserId(): Promise<string | null> {
  const { data } = await supabase.auth.getUser();
  if (data.user?.id) return data.user.id;

  // If session dropped, silently re-authenticate using the master account
  const { data: authData, error } = await supabase.auth.signInWithPassword({
    email: "kiddow@dispatch.local",
    password: "dispatch2026",
  });

  if (error) {
    console.error("Auto-login failed:", error.message);
    return null;
  }
  return authData.user?.id ?? null;
}

/** Upload a Blob to Supabase Storage and return its path */
async function uploadBlob(
  userId: string,
  attachmentId: string,
  blob: Blob,
  mime: string,
): Promise<string | null> {
  const ext = mime.split("/")[1]?.split(";")[0] ?? "bin";
  const path = `${userId}/${attachmentId}.${ext}`;

  // Skip if already uploaded
  const { data: existing } = await supabase.storage
    .from("attachments")
    .list(userId, { search: `${attachmentId}.${ext}` });
  if (existing && existing.length > 0) return path;

  const { error } = await supabase.storage
    .from("attachments")
    .upload(path, blob, { contentType: mime, upsert: true });

  if (error) {
    console.error("Blob upload failed:", error.message);
    return null;
  }
  return path;
}

/** Strip blobs from attachments and upload them; return metadata-only array */
async function syncAttachments(
  userId: string,
  entryId: string,
  attachments: Attachment[],
): Promise<void> {
  for (const att of attachments) {
    if (!att.blob) continue;

    const path = await uploadBlob(userId, att.id, att.blob, att.mime);
    if (!path) continue;

    await supabase.from("entry_attachments").upsert(
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
  }
}

/**
 * Generate a signed URL for a Supabase Storage path.
 * Signed URLs expire in 1 hour — good enough for in-session viewing.
 * Returns null if the path is empty or the call fails.
 */
async function getSignedUrl(storagePath: string): Promise<string | null> {
  if (!storagePath) return null;
  try {
    const { data, error } = await supabase.storage
      .from("attachments")
      .createSignedUrl(storagePath, 3600); // 1-hour signed URL
    if (error || !data?.signedUrl) return null;
    return data.signedUrl;
  } catch {
    return null;
  }
}

// ── Push (local → cloud) ───────────────────────────────────────────────────

export async function pushEntry(entry: Entry): Promise<void> {
  const userId = await getUserId();
  if (!userId) return; // not signed in, skip silently

  // Sync blobs first (fire-and-forget, non-blocking to text sync)
  syncAttachments(userId, entry.id, entry.attachments).catch(console.error);

  const { error } = await supabase.from("entries").upsert(
    {
      id: entry.id,
      user_id: userId,
      title: entry.title,
      tags: entry.tags,
      notes: entry.notes,
      trips: entry.trips ?? null,
      loading_sheet_trips: entry.loadingSheetTrips ?? null,
      despatcher_name: entry.despatcherName ?? null,
      expected_total: entry.expectedTotal ?? null,
      day_key: entry.dayKey,
      month_key: entry.monthKey,
      year_key: entry.yearKey,
      created_at: entry.createdAt,
      updated_at: entry.updatedAt,
    },
    { onConflict: "id" },
  );

  if (error) console.error("Supabase push failed:", error.message);
}

// ── Pull (cloud → local) ───────────────────────────────────────────────────

export async function pullAndMerge(): Promise<void> {
  const userId = await getUserId();
  if (!userId) return;

  const { data: remoteEntries, error: eError } = await supabase
    .from("entries")
    .select("*")
    .eq("user_id", userId);

  const { data: remoteAttachments, error: aError } = await supabase
    .from("entry_attachments")
    .select("*")
    .eq("user_id", userId);

  if (eError || !remoteEntries || aError) {
    console.error("Supabase pull failed:", eError?.message || aError?.message);
    return;
  }

  const localEntries = await allEntries();
  const localMap = new Map(localEntries.map((e) => [e.id, e]));

  for (const remote of remoteEntries) {
    const local = localMap.get(remote.id);
    if (local && local.updatedAt >= remote.updated_at) continue;

    const attachmentsForEntry = remoteAttachments.filter((a) => a.entry_id === remote.id);

    // Build attachments — generate signed URLs so media renders on any device
    const mergedAttachments: Attachment[] = await Promise.all(
      attachmentsForEntry.map(async (a) => {
        // Try to get a signed URL for remote media
        const signedUrl = a.storage_path ? await getSignedUrl(a.storage_path) : null;

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
          // downloadUrl is the signed URL — AttachmentView falls back to this
          downloadUrl: signedUrl ?? undefined,
          createdAt: a.created_at,
        } as Attachment;
      }),
    );

    const merged: Entry = {
      id: remote.id,
      title: remote.title,
      tags: remote.tags ?? [],
      notes: remote.notes ?? [],
      trips: remote.trips ?? undefined,
      loadingSheetTrips: remote.loading_sheet_trips ?? undefined,
      despatcherName: remote.despatcher_name ?? undefined,
      expectedTotal: remote.expected_total ?? undefined,
      attachments: mergedAttachments,
      createdAt: remote.created_at,
      updatedAt: remote.updated_at,
      dayKey: remote.day_key,
      monthKey: remote.month_key,
      yearKey: remote.year_key,
    };

    await localUpdateEntry(merged);
  }
}

// ── Full sync on launch ────────────────────────────────────────────────────

export async function fullSync(): Promise<void> {
  const userId = await getUserId();
  if (!userId) return;

  // Push all local entries in parallel (batches of 8)
  const local = await allEntries();
  const chunks: Entry[][] = [];
  for (let i = 0; i < local.length; i += 8) chunks.push(local.slice(i, i + 8));
  for (const chunk of chunks) {
    await Promise.all(chunk.map(pushEntry));
  }

  // Pull remote changes not yet on device
  await pullAndMerge();
}

// ── Delete (propagate deletes) ─────────────────────────────────────────────

export async function deleteRemoteEntry(id: string): Promise<void> {
  const userId = await getUserId();
  if (!userId) return;
  await supabase.from("entries").delete().eq("id", id).eq("user_id", userId);
}
