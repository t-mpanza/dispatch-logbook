-- ============================================================
-- Dispatch Diary — initial schema
-- ============================================================

-- ── Entries ──────────────────────────────────────────────────

create table if not exists public.entries (
  id            text        primary key,
  user_id       uuid        not null references auth.users(id) on delete cascade,
  title         text        not null,
  tags          jsonb       not null default '[]',
  notes         jsonb       not null default '[]',
  trips         jsonb,
  expected_total int,
  day_key       text        not null,
  month_key     text        not null,
  year_key      text        not null,
  created_at    bigint      not null,
  updated_at    bigint      not null
);

create index if not exists entries_user_id_idx     on public.entries (user_id);
create index if not exists entries_day_key_idx     on public.entries (user_id, day_key);
create index if not exists entries_month_key_idx   on public.entries (user_id, month_key);
create index if not exists entries_updated_at_idx  on public.entries (user_id, updated_at desc);

alter table public.entries enable row level security;

create policy "Users can CRUD their own entries"
  on public.entries for all
  using  (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ── Attachment metadata ───────────────────────────────────────

create table if not exists public.entry_attachments (
  id            text        primary key,
  entry_id      text        not null references public.entries(id) on delete cascade,
  user_id       uuid        not null references auth.users(id) on delete cascade,
  kind          text        not null check (kind in ('audio','image','video','file')),
  mime          text        not null,
  name          text,
  caption       text,
  duration_ms   int,
  width         int,
  height        int,
  storage_path  text        not null,
  created_at    bigint      not null
);

create index if not exists attachments_entry_id_idx on public.entry_attachments (entry_id);
create index if not exists attachments_user_id_idx  on public.entry_attachments (user_id);

alter table public.entry_attachments enable row level security;

create policy "Users can CRUD their own attachments"
  on public.entry_attachments for all
  using  (auth.uid() = user_id)
  with check (auth.uid() = user_id);
