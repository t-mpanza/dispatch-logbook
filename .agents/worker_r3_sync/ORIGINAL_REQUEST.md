## 2026-08-13T20:32:13Z

You are worker_r3_sync.
Working Directory: /home/kiddow/Desktop/Work/Despatch Diary/.agents/worker_r3_sync
Project Root: /home/kiddow/Desktop/Work/Despatch Diary

Your task: Implement Requirement R3 (Multi-Device Media Sync, Storage Fix & Anti-RePush Loop).

1. Fix Re-Push Loop in `src/lib/sync.ts` & `src/lib/db.ts`: In `pullAndMerge()`, ensure remote entries pulled from Supabase DB are updated in IndexedDB WITHOUT mutating `updatedAt` to `Date.now()` and WITHOUT triggering an immediate re-push to Supabase (`pushEntry`).
2. Fix Media Restoration & Download URLs: In `src/lib/sync.ts:pullAndMerge()`, query `entry_attachments` from Supabase and construct `downloadUrl` or `storagePath`. In `src/components/AttachmentView.tsx`, if `attachment.blob` is undefined (on fresh install or second device), render media using `attachment.downloadUrl` or `storagePath` public URL via Supabase Storage.
3. Fix Storage Leaks: In `src/lib/sync.ts:deleteRemoteEntry()`, retrieve storage paths for attachments belonging to entry `id` and remove objects from Supabase Storage bucket `attachments` before deleting the DB row.
4. Verify using `npx tsc --noEmit` and `npm run test:e2e`.
5. Write `handoff.md` and report back when finished.
