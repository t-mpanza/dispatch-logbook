-- ============================================================
-- Dispatch Diary — soft-delete tombstones for cross-device deletes
-- ============================================================

-- Entries are never hard-deleted from the cloud by clients; instead a
-- deleted_at tombstone is written so offline devices converge on the
-- deletion instead of resurrecting stale rows.
alter table public.entries add column if not exists deleted_at bigint;

create index if not exists entries_deleted_at_idx
  on public.entries (deleted_at)
  where deleted_at is not null;
