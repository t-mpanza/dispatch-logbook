/**
 * Background sync engine — pushes local IndexedDB entries to Supabase.
 * - Local-first: IndexedDB is always the source of truth.
 * - Sync runs silently in the background; never blocks the UI.
 * - Conflict resolution: higher updatedAt wins.
 * - Blobs (photos, audio, video) are uploaded to Supabase Storage.
 *   Only the storage path is stored in the DB row.
 */

import { supabase } from "./supabase";
import { allEntries, updateEntry as localUpdateEntry } from "./db";
import type { Attachment, Entry } from "./types";

// ── Helpers ────────────────────────────────────────────────────────────────

async function getUserId(): Promise<string | null> {
  const { data } = await supabase.auth.getUser();
  return data.user?.id ?? null;
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
      // notes and trips: strip nothing, these are plain JSON (no blobs)
      notes: entry.notes,
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

  if (error) console.error("Supabase push failed:", error.message);
}

// ── Pull (cloud → local) ───────────────────────────────────────────────────

export async function pullAndMerge(): Promise<void> {
  const userId = await getUserId();
  if (!userId) return;

  const { data: remoteEntries, error } = await supabase
    .from("entries")
    .select("*")
    .eq("user_id", userId);

  if (error || !remoteEntries) {
    console.error("Supabase pull failed:", error?.message);
    return;
  }

  const localEntries = await allEntries();
  const localMap = new Map(localEntries.map((e) => [e.id, e]));

  for (const remote of remoteEntries) {
    const local = localMap.get(remote.id);

    // If local is newer or equal, don't overwrite
    if (local && local.updatedAt >= remote.updated_at) continue;

    // Merge remote into local — preserve local blobs if present
    const merged: Entry = {
      id: remote.id,
      title: remote.title,
      tags: remote.tags ?? [],
      notes: remote.notes ?? [],
      trips: remote.trips ?? undefined,
      expectedTotal: remote.expected_total ?? undefined,
      // Preserve existing local attachments (blobs); remote only carries metadata
      attachments: local?.attachments ?? [],
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
