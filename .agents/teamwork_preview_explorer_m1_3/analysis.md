# Codebase Audit & Technical Analysis Report: Despatch Diary

**Author**: Explorer 3 (Milestone 1 — Exploration & Codebase Audit)  
**Date**: 2026-08-13  
**Target Project**: Despatch Diary (`t-mpanza/dispatch-logbook`)  
**Working Directory**: `/home/kiddow/Desktop/Work/Despatch Diary/.agents/teamwork_preview_explorer_m1_3`

---

## 1. Executive Summary

Despatch Diary is a hybrid desktop/mobile web and progressive web application (PWA) built with React 19, TanStack Start & Router, Tailwind CSS v4, Capacitor 8 (for native Android builds), IndexedDB (`idb`), and Supabase (PostgreSQL, Storage, RLS, Auth).

This audit investigated the data layer, offline persistence, PWA service worker caching, Supabase client/schema/storage integration, media lifecycle, multi-device synchronization engine, and the E2E test runner infrastructure.

### Key Discoveries & Highlights

1. **Solid Local-First Architecture**: IndexedDB (`dispatch-diary`, v2) serves as the local source of truth for entries, reminders, and settings. Dual-tier fallbacks (IndexedDB + `localStorage`) preserve despatcher preferences.
2. **Offline PWA Capabilities**: Service Worker (`public/sw.js`) uses standard cache management (`dispatch-diary-v2`) with network-first navigation, cache-first immutable asset handling, and stale-while-revalidate for general GET requests.
3. **Critical Defect #1 — Re-push Sync Loop**: `pullAndMerge()` in `src/lib/sync.ts` calls `localUpdateEntry(merged)` when pulling cloud changes. `localUpdateEntry` (which maps to `updateEntry` in `db.ts`) updates `updatedAt` to `Date.now()` and calls `pushEntry(entry)`, forcing freshly pulled cloud data to immediately re-push back to Supabase in a loop.
4. **Critical Defect #2 — Remote Media Download / Display Failure**: `pullAndMerge()` reconstructs attachment metadata (`storagePath`) from `entry_attachments` but leaves `blob` `undefined`. `AttachmentView.tsx` and `Lightbox.tsx` call `URL.createObjectURL(attachment.blob)` without checking for `undefined` or downloading the file from Supabase Storage, leading to runtime exceptions when viewing remote media on fresh devices.
5. **Comprehensive Test Suite**: The E2E test runner (`tests/e2e/runner.ts`) executes 130 test cases across Tiers 1–4 using a custom Node test runner (`node --experimental-strip-types tests/e2e/runner.ts`). All 130 tests currently pass.

---

## 2. Data Layer, State Management & Offline Storage

### 2.1 Entity Models & Types (`src/lib/types.ts`)

- **`Entry`**: Core document containing metadata (`id`, `title`, `tags`, `notes`, `attachments`, `trips`, `loadingSheetTrips`, `expectedTotal`, `createdAt`, `updatedAt`, `dayKey`, `monthKey`, `yearKey`).
- **`LoadingSheetTrip`**: Truck loading record (`id`, `reg`, `driverName`, `tripId`, `presetKey`, `startTime`, `finishTime`, `durationMinutes`, `quantityLoaded`, `rejectedCount`, `note`, `isManual`, `createdAt`).
- **`Attachment`**: Media asset contract (`id`, `kind`, `blob`, `mime`, `name`, `caption`, `durationMs`, `width`, `height`, `storagePath`, `createdAt`).
- **`Reminder`**: Task/reminder model (`id`, `entryId`, `at`, `text`, `done`).

### 2.2 IndexedDB Engine (`src/lib/db.ts`)

- Database: `"dispatch-diary"` (v2).
- Object Stores:
  - `"entries"` (keyPath: `id`; indexes: `byDay`, `byMonth`, `byYear`, `byUpdated`).
  - `"reminders"` (keyPath: `id`; indexes: `byEntry`, `byAt`).
  - `"settings"` (keyPath: out-of-line string keys).
- Preference Persistence: Dual-tier storage for Despatcher Name (`getDespatcherName` / `saveDespatcherName`). Tries `localStorage` keys `"dispatch_despatcher_name"` / `"despatch_diary_despatcher_name"` first, then falls back to IndexedDB `"settings"` store.
- Daily Counter Persistence: STOCKS counter state stored in `localStorage` under `"dispatch_stocks_counter"`, auto-resetting on date key change.

### 2.3 State Management & PWA Service Worker (`public/sw.js`, `vite.config.ts`, `src/routes/__root.tsx`)

- Server/UI State: TanStack React Query (`@tanstack/react-query`) combined with React 19 router contexts and component state (`useState`, `useRef`).
- PWA Manifest & Setup: Managed via `vite-plugin-pwa` with `strategies: "injectManifest"`.
- Service Worker Strategy (`public/sw.js`):
  - **Navigation**: Network-first → fallback to SPA shell (`/`, `index.html`, scope).
  - **Hashed Assets (`/assets/*-<hash>.*`)**: Cache-first (immutable assets).
  - **Other GET requests**: Stale-while-revalidate.
  - **Lifecycle**: Immediate activation via `skipWaiting()` and client claiming (`clients.claim()`).

---

## 3. Supabase Integration & Database Schema

### 3.1 Client Configuration (`src/lib/supabase.ts`)

Initializes `@supabase/supabase-js` `createClient` using environment variables `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY` with session persistence enabled.

### 3.2 SQL Schema & Indexes (`supabase/migrations/20260521212319_init_dispatch_diary.sql`)

1. **`public.entries`**:
   - Stores entry metadata and JSON fields (`tags`, `notes`, `trips`).
   - Row-Level Security (RLS): Policy `"Users can CRUD their own entries"` (`auth.uid() = user_id`).
   - Indexes: `(user_id)`, `(user_id, day_key)`, `(user_id, month_key)`, `(user_id, updated_at desc)`.
2. **`public.entry_attachments`**:
   - Stores attachment metadata linked to entries (`entry_id` foreign key with `ON DELETE CASCADE`).
   - RLS Policy: `"Users can CRUD their own attachments"` (`auth.uid() = user_id`).
   - Indexes: `(entry_id)`, `(user_id)`.

### 3.3 Supabase Storage RLS (`supabase/migrations/20260521212602_storage_rls_policies.sql`)

- Bucket: `'attachments'`.
- Storage Path: `${user_id}/${attachment_id}.${ext}`.
- RLS Policies: Restricts INSERT, SELECT, UPDATE, DELETE to authenticated users matching folder name `(storage.foldername(name))[1] = auth.uid()::text`.

---

## 4. Media Lifecycle & Multi-Device Sync Gaps

### 4.1 Image Downscaling & Pre-Upload Optimization (`src/lib/image.ts`)

- Images > 600 KB are resized using `OffscreenCanvas` (or standard `canvas`) to a maximum edge of 1800 px at 85% JPEG quality.
- Significantly reduces memory pressure and upload size (brings 12 MP photos from ~6 MB down to ~300–500 KB).

### 4.2 Media Upload Pipeline (`src/lib/sync.ts`)

- `uploadBlob()` checks for existence of file in Supabase Storage before uploading.
- `syncAttachments()` iterates over attachments containing `blob`, uploads to storage path `${userId}/${attachmentId}.${ext}`, and upserts metadata into `entry_attachments`.

### 4.3 Media Download & Display Defect Analysis (`AttachmentView.tsx`, `Lightbox.tsx`, `sync.ts`)

- **Observed Behavior**:
  - `pullAndMerge()` maps remote `entry_attachments` to `Attachment` objects without populating `blob` or downloading media files from Supabase Storage.
  - `AttachmentView.tsx` (line 17) and `Lightbox.tsx` (line 21) call `URL.createObjectURL(attachment.blob)`.
- **Impact**: When an entry created on Device A is pulled by Device B, `attachment.blob` is `undefined`. Device B crashes with `TypeError: Failed to execute 'createObjectURL' on 'URL'` when rendering the attachment view.
- **Required Fix (Milestone 2)**:
  1. Add on-demand or background downloading of media Blobs from Supabase Storage (`supabase.storage.from("attachments").download(storagePath)`).
  2. Cache downloaded Blobs in local IndexedDB.
  3. Update `AttachmentView` to render a placeholder or loading state while media is being downloaded.

---

## 5. Multi-Device Sync Engine & Re-Push Loop Analysis

### 5.1 Re-Push Loop Defect Mechanism (`src/lib/sync.ts`, `src/lib/db.ts`)

- **Code Trace**:
  1. `pullAndMerge()` in `sync.ts` fetches remote entries:
     ```ts
     const merged: Entry = { ...remoteData };
     await localUpdateEntry(merged);
     ```
  2. `localUpdateEntry` is imported from `db.ts` where it points to `updateEntry(entry)`:
     ```ts
     export async function updateEntry(entry: Entry) {
       entry.updatedAt = Date.now(); // <--- OVERWRITES CLOUD TIMESTAMP
       const db = await getDB();
       await db.put("entries", entry);
       pushEntry(entry).catch(console.error); // <--- TRIGGERS RE-PUSH TO SUPABASE
     }
     ```
- **Consequence**: Every time cloud data is pulled to a client device, the client overwrites `updatedAt` with the current local time and immediately re-pushes the item to Supabase. In a multi-device setup, this creates an infinite ping-pong sync loop.
- **Required Fix (Milestone 2)**:
  - Introduce `updateEntryLocally(entry: Entry, options?: { skipPush?: boolean })` in `db.ts` that saves to IndexedDB without altering `updatedAt` or calling `pushEntry`.

---

## 6. Testing Infrastructure & Verification

### 6.1 Test Suite Architecture (`tests/e2e/`)

- Custom Node test runner (`tests/e2e/runner.ts`) utilizing `--experimental-strip-types`.
- Polyfills in-memory IndexedDB and `navigator.vibrate` for headless execution.
- Categorized test suites:
  - `src/lib/loading-presets.test.ts`: Loading sheet compliance & calculations unit tests.
  - `tests/e2e/tier1_feature_coverage.test.ts`: 55 feature coverage test cases (Features 1–11).
  - `tests/e2e/tier2_boundary_corner.test.ts`: 55 boundary and corner test cases.
  - `tests/e2e/tier3_cross_feature.test.ts`: 15 cross-feature interaction test cases.
  - `tests/e2e/tier4_real_world.test.ts`: 5 end-to-end application scenario tests.

### 6.2 Test Execution Results

- Executed `npm run test:e2e` (`node --experimental-strip-types tests/e2e/runner.ts`).
- **Results**: 130 / 130 tests passed (100% pass rate, exit code 0).

---

## 7. Actionable Recommendations

1. **Implement `skipPush` in Local Store Updates**:
   Update `db.ts` so `pullAndMerge()` can persist entries into IndexedDB without updating `updatedAt` or triggering `pushEntry`.
2. **Implement Storage Download & Blob Caching**:
   Enhance `sync.ts` with remote media download logic (`fetchAttachmentBlob(storagePath)`) and update IndexedDB stores to persist downloaded media blobs locally.
3. **Guard Media View Components**:
   Update `AttachmentView.tsx` and `Lightbox.tsx` to handle `attachment.blob === undefined` gracefully by rendering placeholder thumbnails or triggering background download.
4. **Implement Remote Delete Cleanup**:
   Ensure `deleteRemoteEntry` removes storage objects from the Supabase `attachments` bucket in addition to database rows.
