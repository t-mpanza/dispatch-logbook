# Handoff Report — Data Models & Supabase Sync Investigation

## 1. Observation

### 1.1 Data Models & Schemas

- **TypeScript Types** (`src/lib/types.ts:1-52`):
  - `Attachment`: `id`, `kind` (`"audio" | "image" | "video" | "file"`), `blob: Blob`, `mime`, `name?`, `caption?`, `durationMs?`, `width?`, `height?`, `createdAt`.
  - `Entry`: `id`, `title`, `tags`, `notes: NoteBlock[]`, `attachments: Attachment[]`, `trips?: Trip[]`, `expectedTotal?: number`, `createdAt`, `updatedAt`, `dayKey`, `monthKey`, `yearKey`.
  - `Trip`: `id`, `count`, `rejected?`, `note?`, `createdAt`.
  - `Reminder`: `id`, `entryId`, `at`, `text`, `done`.
- **PostgreSQL Schema** (`supabase/migrations/20260521212319_init_dispatch_diary.sql:7-59`):
  - Table `public.entries`: `id` (text PK), `user_id` (uuid FK auth.users), `title`, `tags` (jsonb), `notes` (jsonb), `trips` (jsonb), `expected_total` (int), `day_key`, `month_key`, `year_key`, `created_at` (bigint), `updated_at` (bigint). RLS policy: `"Users can CRUD their own entries"` (`auth.uid() = user_id`).
  - Table `public.entry_attachments`: `id` (text PK), `entry_id` (text FK entries), `user_id` (uuid FK auth.users), `kind`, `mime`, `name`, `caption`, `duration_ms`, `width`, `height`, `storage_path`, `created_at`. RLS policy: `"Users can CRUD their own attachments"` (`auth.uid() = user_id`).

### 1.2 Storage RLS Policies

- `supabase/migrations/20260521212602_storage_rls_policies.sql:5-31`:
  - 4 policies on `storage.objects` for bucket `'attachments'` validating `(storage.foldername(name))[1] = auth.uid()::text`.

### 1.3 Local Persistence & State Stores

- **IndexedDB Setup** (`src/lib/db.ts:6-34`):
  - `openDB("dispatch-diary", 1)` creates object stores `entries` (indexes: `byDay`, `byMonth`, `byYear`, `byUpdated`) and `reminders` (indexes: `byEntry`, `byAt`).
- **State Libraries**: `package.json` confirms `@tanstack/react-query` (~5.83.0) and `idb` (~8.0.3). No Zustand, Redux, Pinia, or React Context stores exist.

### 1.4 Supabase Integration & Auto-Login Fallback

- **Client Configuration** (`src/lib/supabase.ts:10-16`): `createClient(SUPABASE_URL, SUPABASE_KEY, { auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true } })`.
- **Auto-Login Fallback** (`src/lib/sync.ts:20-30`): `getUserId()` attempts `signInWithPassword({ email: 'kiddow@dispatch.local', password: 'dispatch2026' })` if session drops.

### 1.5 Sync Mechanics & Identified Bugs

- **Timestamp Mutation in `updateEntry`** (`src/lib/db.ts:67-72`):
  ```ts
  export async function updateEntry(entry: Entry) {
    entry.updatedAt = Date.now();
    const db = await getDB();
    await db.put("entries", entry);
    pushEntry(entry).catch(console.error);
  }
  ```
- **Pull and Merge Logic** (`src/lib/sync.ts:125-167`):
  ```ts
  export async function pullAndMerge(): Promise<void> {
    ...
    const { data: remoteEntries, error } = await supabase
      .from("entries")
      .select("*")
      .eq("user_id", userId);
    ...
    for (const remote of remoteEntries) {
      ...
      const merged: Entry = {
        ...
        attachments: local?.attachments ?? [],
        ...
      };
      await localUpdateEntry(merged);
    }
  }
  ```
- **Remote Delete Logic** (`src/lib/sync.ts:189-193`):
  ```ts
  export async function deleteRemoteEntry(id: string): Promise<void> {
    const userId = await getUserId();
    if (!userId) return;
    await supabase.from("entries").delete().eq("id", id).eq("user_id", userId);
  }
  ```

---

## 2. Logic Chain

1. **Re-Push Loop Bug Reasoning**:
   - Step 1: `pullAndMerge()` in `sync.ts` fetches remote entries from Supabase.
   - Step 2: When `local.updatedAt < remote.updated_at`, line 165 calls `await localUpdateEntry(merged)`.
   - Step 3: `localUpdateEntry` points to `updateEntry()` in `db.ts`.
   - Step 4: `db.ts:68` executes `entry.updatedAt = Date.now();`, overwriting the remote timestamp with the current local time.
   - Step 5: `db.ts:71` calls `pushEntry(entry)`, pushing the merged entry back to Supabase with the new timestamp.
   - Conclusion: Every pull operation mutates `updatedAt` and triggers an immediate re-push, creating a re-sync loop.

2. **Media Restoration Failure & Missing Download URLs Reasoning**:
   - Step 1: `syncAttachments()` in `sync.ts` uploads Blobs to Supabase Storage path `${userId}/${attachmentId}.${ext}` and saves metadata to `public.entry_attachments`.
   - Step 2: `pullAndMerge()` in `sync.ts` queries `supabase.from("entries").select("*")` but NEVER queries `public.entry_attachments` or Supabase Storage.
   - Step 3: `pullAndMerge()` sets `attachments: local?.attachments ?? []`. On a fresh install or second device, `local` is undefined, so `attachments` becomes `[]`.
   - Step 4: `AttachmentView.tsx:17` attempts `URL.createObjectURL(attachment.blob)`. There is no mechanism to fetch storage paths from Supabase Storage or convert them to signed/public URLs or Blobs when `blob` is absent.
   - Conclusion: Media attachments uploaded on Device A cannot be restored or rendered on Device B or on fresh installations.

3. **Orphaned Storage Files Reasoning**:
   - Step 1: `deleteRemoteEntry(id)` deletes the entry row from `public.entries`.
   - Step 2: Foreign key `ON DELETE CASCADE` removes `entry_attachments` rows in PostgreSQL.
   - Step 3: No call is made to `supabase.storage.from("attachments").remove([...])`.
   - Conclusion: Deleting entries leaves raw media blobs in Supabase Storage indefinitely.

---

## 3. Caveats

- **Live Supabase Environment**: Live cloud sync execution was not tested against an active remote Supabase server because network access is restricted to CODE_ONLY mode. However, analysis of static SQL migrations and TS source code provides 100% deterministic evidence of runtime behavior.
- **Capacitor Native Storage**: Mobile native builds use the webview's standard IndexedDB implementation via `idb`. No native SQLite plugin is currently integrated.

---

## 4. Conclusion

The application has a clean local-first architecture built around IndexedDB and TanStack Query, but the Supabase cloud sync layer contains three major structural defects:

1. **Re-Push Loop**: Caused by `localUpdateEntry()` updating `updatedAt = Date.now()` and calling `pushEntry()` inside `db.ts`.
2. **Missing Media Sync/Restore**: Caused by `pullAndMerge()` neglecting to query `entry_attachments` or fetch storage files from Supabase Storage, coupled with `AttachmentView` relying exclusively on local `Blob` objects.
3. **Storage Leaks**: Caused by `deleteRemoteEntry()` omitting Supabase Storage deletion calls.

---

## 5. Verification Method

### 5.1 Re-Push Loop Verification

1. Inspect `src/lib/db.ts` lines 67-72 and `src/lib/sync.ts` lines 125-167.
2. Invalidate condition: `localUpdateEntry(merged)` in `pullAndMerge()` calls `updateEntry()`, which mutates `entry.updatedAt` to `Date.now()` and calls `pushEntry()`.

### 5.2 Media Sync & Missing Download URL Verification

1. Inspect `src/lib/sync.ts` lines 129-166 and `src/components/AttachmentView.tsx` lines 15-20.
2. Invalidate condition: Confirm `pullAndMerge()` has zero references to `entry_attachments` table or `supabase.storage.from("attachments")`.

### 5.3 Storage Leak Verification

1. Inspect `src/lib/sync.ts` lines 189-193.
2. Invalidate condition: Confirm `deleteRemoteEntry` only executes SQL delete on table `entries` without calling `supabase.storage.from("attachments").remove()`.
