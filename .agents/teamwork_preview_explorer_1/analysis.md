# Comprehensive Technical Analysis: Data Models & Supabase Sync

## Executive Summary

This document presents a deep-dive investigation into the **Despatch Diary** application architecture, specifically focusing on data models, state stores, local persistence via IndexedDB, Supabase cloud sync, RLS security policies, and media attachment lifecycle.

Key critical findings include:

1. **Re-Push Loop Bug**: `pullAndMerge()` in `src/lib/sync.ts` triggers `localUpdateEntry()`, which in turn mutates `updatedAt` to `Date.now()` and immediately invokes `pushEntry()`, pushing pulled data straight back to the cloud in an endless sync loop.
2. **Media Non-Restoration / Missing Download URLs**: `pullAndMerge()` never queries `entry_attachments` or Supabase Storage, discarding attachment metadata on fresh installs (`attachments: local?.attachments ?? []`). Furthermore, `Attachment` types mandate an inline JavaScript `Blob`, with zero mechanism to resolve remote storage paths into Blob URLs or signed URLs.
3. **Missing Real-Time Subscriptions**: Supabase real-time capabilities (`supabase.channel()`) are completely absent. Sync relies solely on manual triggers (app launch, auth state change, local write actions).
4. **Orphaned Storage Blobs**: Remote deletion (`deleteRemoteEntry`) cascades PostgreSQL table rows but fails to call Supabase Storage API (`supabase.storage.from('attachments').remove()`), causing deleted media files to remain in storage indefinitely.

---

## 1. Data Models and Schemas

### 1.1 Core TypeScript Interfaces (`src/lib/types.ts`)

The application defines five main data abstractions:

```ts
export type AttachmentKind = "audio" | "image" | "video" | "file";

export interface Attachment {
  id: string;
  kind: AttachmentKind;
  blob: Blob; // Raw binary stored directly in IDB
  mime: string;
  name?: string;
  caption?: string;
  durationMs?: number; // Audio duration in ms
  width?: number; // Image width in px
  height?: number; // Image height in px
  createdAt: number; // Epoch ms
}

export interface NoteBlock {
  id: string;
  text: string;
  createdAt: number;
}

export interface Reminder {
  id: string;
  entryId: string; // FK -> Entry.id
  at: number; // Epoch ms notification target
  text: string;
  done: boolean;
}

export interface Trip {
  id: string;
  count: number; // Scanned / accepted count
  rejected?: number; // Manual / rejected count
  note?: string; // Slip reference e.g., "slip:photo:<att_id>" or "slip:text:123"
  createdAt: number;
}

export interface Entry {
  id: string;
  title: string;
  tags: string[];
  notes: NoteBlock[];
  attachments: Attachment[];
  trips?: Trip[]; // Defined & Array -> Counter Session enabled
  expectedTotal?: number; // Target total count for counter session
  createdAt: number;
  updatedAt: number;
  dayKey: string; // YYYY-MM-DD
  monthKey: string; // YYYY-MM
  yearKey: string; // YYYY
}
```

### 1.2 Supabase Database Schema (`supabase/migrations/20260521212319_init_dispatch_diary.sql`)

The cloud backend utilizes two PostgreSQL tables:

#### Table `public.entries`

| Column           | Type     | Constraints / Default                                  | Notes                         |
| ---------------- | -------- | ------------------------------------------------------ | ----------------------------- |
| `id`             | `text`   | `PRIMARY KEY`                                          | Client-generated `uid()`      |
| `user_id`        | `uuid`   | `NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE` | RLS owner link                |
| `title`          | `text`   | `NOT NULL`                                             | Entry title                   |
| `tags`           | `jsonb`  | `NOT NULL DEFAULT '[]'`                                | Array of tag strings          |
| `notes`          | `jsonb`  | `NOT NULL DEFAULT '[]'`                                | Array of NoteBlock objects    |
| `trips`          | `jsonb`  | `NULL`                                                 | Array of Trip objects or NULL |
| `expected_total` | `int`    | `NULL`                                                 | Session goal                  |
| `day_key`        | `text`   | `NOT NULL`                                             | `"YYYY-MM-DD"`                |
| `month_key`      | `text`   | `NOT NULL`                                             | `"YYYY-MM"`                   |
| `year_key`       | `text`   | `NOT NULL`                                             | `"YYYY"`                      |
| `created_at`     | `bigint` | `NOT NULL`                                             | Client epoch ms               |
| `updated_at`     | `bigint` | `NOT NULL`                                             | Client epoch ms               |

#### Table `public.entry_attachments`

| Column         | Type     | Constraints / Default                                      | Notes                                                    |
| -------------- | -------- | ---------------------------------------------------------- | -------------------------------------------------------- |
| `id`           | `text`   | `PRIMARY KEY`                                              | Attachment UUID                                          |
| `entry_id`     | `text`   | `NOT NULL REFERENCES public.entries(id) ON DELETE CASCADE` | Parent entry FK                                          |
| `user_id`      | `uuid`   | `NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE`     | RLS owner link                                           |
| `kind`         | `text`   | `CHECK (kind IN ('audio','image','video','file'))`         | Attachment type                                          |
| `mime`         | `text`   | `NOT NULL`                                                 | MIME type string                                         |
| `name`         | `text`   | `NULL`                                                     | Filename                                                 |
| `caption`      | `text`   | `NULL`                                                     | Text caption                                             |
| `duration_ms`  | `int`    | `NULL`                                                     | Audio length                                             |
| `width`        | `int`    | `NULL`                                                     | Image width                                              |
| `height`       | `int`    | `NULL`                                                     | Image height                                             |
| `storage_path` | `text`   | `NOT NULL`                                                 | Supabase Storage path: `{user_id}/{attachment_id}.{ext}` |
| `created_at`   | `bigint` | `NOT NULL`                                                 | Client epoch ms                                          |

---

## 2. State Stores and Local Persistence

### 2.1 Local Persistence (IndexedDB)

Local data is persisted via `idb` (v8.0.3) in `src/lib/db.ts`:

- **Database Name**: `dispatch-diary`
- **Database Version**: `1`
- **Object Stores**:
  1. `entries` (keyPath: `"id"`)
     - Indexes: `byDay` (`dayKey`), `byMonth` (`monthKey`), `byYear` (`yearKey`), `byUpdated` (`updatedAt`)
     - Binary blobs are stored **inline** inside `entry.attachments[i].blob`.
  2. `reminders` (keyPath: `"id"`)
     - Indexes: `byEntry` (`entryId`), `byAt` (`at`)

### 2.2 Application State Management

- **No Global Store Libraries**: Neither Redux, Zustand, Pinia, nor React Context are used for application domain state.
- **Server/Async State**: Managed via TanStack Query (`@tanstack/react-query` v5.83.0).
  - Query keys include: `["entry", id]`, `["entries"]`, `["entries", "day", dayKey]`, `["tags"]`, `["reminders", entryId]`, `["search", q]`.
  - Save operations invalidate queries via `qc.invalidateQueries({ queryKey: [...] })`.
- **UI State**: Handled locally per component using React `useState` / `useRef`.

---

## 3. Supabase Integration and Security

### 3.1 Client Setup (`src/lib/supabase.ts`)

- Initialized with `@supabase/supabase-js` (v2.106.1).
- Reads `import.meta.env.VITE_SUPABASE_URL` and `import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY`.
- Configured with `persistSession: true`, `autoRefreshToken: true`, `detectSessionInUrl: true`.

### 3.2 Authentication & Fallback Mechanism (`src/lib/sync.ts:16-31`)

When performing cloud sync operations, `getUserId()` attempts `supabase.auth.getUser()`. If no active session is detected, it automatically attempts a background fallback login using a hardcoded master user:

- Email: `kiddow@dispatch.local`
- Password: `dispatch2026`

### 3.3 Row Level Security (RLS) Policies

- **Table Policies** (`supabase/migrations/20260521212319_init_dispatch_diary.sql`):
  - `public.entries`: Policy `"Users can CRUD their own entries"` (`auth.uid() = user_id`).
  - `public.entry_attachments`: Policy `"Users can CRUD their own attachments"` (`auth.uid() = user_id`).
- **Storage Policies** (`supabase/migrations/20260521212602_storage_rls_policies.sql`):
  - Target bucket: `'attachments'`
  - Path rule: `(storage.foldername(name))[1] = auth.uid()::text`
  - Four granular policies cover `INSERT`, `SELECT`, `UPDATE`, and `DELETE`.

### 3.4 Real-time Subscriptions Status

- **Status**: **NOT IMPLEMENTED**.
- Searching the entire `src/` codebase confirms zero usages of `supabase.channel()` or real-time event listeners. Sync is strictly poll/push triggered.

---

## 4. Media Storage Sync & Critical Bug Analysis

### 4.1 Local-to-Cloud Upload Flow (`pushEntry` & `syncAttachments`)

1. User captures image/video/audio.
2. `CaptureBar.tsx` / `VoiceRecorder.tsx` downscales image via `downscaleImage()` in `src/lib/image.ts` (1800px max edge, 0.85 JPEG) and constructs an `Attachment` object with an inline `Blob`.
3. `updateEntry(entry)` in `src/lib/db.ts` saves the entry to IndexedDB and triggers `pushEntry(entry)`.
4. `pushEntry` fires `syncAttachments(userId, entry.id, entry.attachments)`:
   - For each attachment with a `blob`, it calculates `path = ${userId}/${attachmentId}.${ext}`.
   - Checks if the file already exists on storage (`supabase.storage.from("attachments").list(...)`).
   - If missing, uploads via `supabase.storage.from("attachments").upload(path, blob, { contentType: mime, upsert: true })`.
   - Upserts metadata into `public.entry_attachments`.
5. `pushEntry` upserts entry metadata (title, tags, notes, trips) to `public.entries`.

### 4.2 Root Cause Analysis: Re-Push Loop Bug

**Location**: `src/lib/sync.ts:165` and `src/lib/db.ts:68`

**Sequence of Failure**:

1. `pullAndMerge()` fetches remote entries from Supabase.
2. If `local.updatedAt < remote.updated_at`, `pullAndMerge()` constructs a merged entry object and calls `await localUpdateEntry(merged)`.
3. `localUpdateEntry` is an alias for `updateEntry` exported from `src/lib/db.ts`.
4. Inside `db.ts:68`:
   ```ts
   export async function updateEntry(entry: Entry) {
     entry.updatedAt = Date.now(); // <-- MUTATES TIMESTAMP TO NOW!
     const db = await getDB();
     await db.put("entries", entry);
     pushEntry(entry).catch(console.error); // <-- TRIGGERS RE-PUSH!
   }
   ```
5. **Consequence**: Receiving cloud data causes the local entry to be re-stamped with a higher timestamp and re-pushed back to Supabase. On multi-device setups or rapid updates, this triggers perpetual back-and-forth re-pushing.

### 4.3 Root Cause Analysis: Missing Media on Fresh Install / Multi-Device

**Location**: `src/lib/sync.ts:129-167`

**Sequence of Failure**:

1. `pullAndMerge()` queries only `public.entries` (`supabase.from("entries").select("*")`).
2. It NEVER queries `public.entry_attachments` table.
3. Line 157 sets `attachments: local?.attachments ?? []`.
4. On a fresh installation (or new device), `local` is `undefined`, resulting in `attachments: []`.
5. Even if `entry_attachments` metadata were pulled, the frontend `Attachment` model requires `blob: Blob`. Components like `AttachmentView.tsx` render images via `URL.createObjectURL(attachment.blob)`.
6. There is no code in `sync.ts` or `AttachmentView.tsx` to download binary object files from Supabase Storage or convert `storage_path` to a public/signed URL or downloadable Blob.

### 4.4 Root Cause Analysis: Orphaned Storage Files on Delete

**Location**: `src/lib/sync.ts:189-193`

**Sequence of Failure**:

1. `deleteRemoteEntry(id)` executes:
   ```ts
   await supabase.from("entries").delete().eq("id", id).eq("user_id", userId);
   ```
2. The database cascade deletes `entry_attachments` table rows.
3. However, `deleteRemoteEntry` does NOT list or remove files from Supabase Storage bucket (`supabase.storage.from("attachments").remove([...])`).
4. Deleted media files remain in Supabase Storage indefinitely.

---

## 5. Architectural Recommendations

1. **Fix Re-Push Loop**: Separate internal DB persistence (`db.put("entries", entry)`) from UI update functions. Create a dedicated `savePulledEntry(entry)` function in `db.ts` that preserves `entry.updatedAt` without calling `pushEntry()`.
2. **Implement Attachment Pulling**:
   - In `pullAndMerge()`, fetch rows from `public.entry_attachments` where `user_id = userId`.
   - Download missing blobs from Supabase Storage (`supabase.storage.from("attachments").download(storage_path)`).
   - Reconstruct full `Attachment` objects (including `Blob`) in IndexedDB.
3. **Add Real-Time Listener**: Implement `supabase.channel('public:entries')` subscription in `__root.tsx` to reactively trigger `pullAndMerge()` upon remote changes.
4. **Implement Storage Cleanup**: In `deleteRemoteEntry(id)`, query attachment `storage_path` values before entry deletion and issue a batch `storage.from("attachments").remove(paths)` call.
