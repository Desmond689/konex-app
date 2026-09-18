-- The app's block/unblock flow (social_repository_impl, profile_remote_data_source,
-- chat_remote_data_source) already reads/writes public.blocks, but no migration
-- ever created it, so those calls fail silently on any DB missing this table.
-- Written idempotently so it's safe to run against DBs where it was hand-created.

create table if not exists public.blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint blocks_no_self_block check (blocker_id <> blocked_id)
);

create index if not exists blocks_blocked_id_idx on public.blocks (blocked_id);

alter table public.blocks enable row level security;

drop policy if exists "blocks_select_own" on public.blocks;
create policy "blocks_select_own"
  on public.blocks for select
  using (auth.uid() = blocker_id or auth.uid() = blocked_id);

drop policy if exists "blocks_insert_own" on public.blocks;
create policy "blocks_insert_own"
  on public.blocks for insert
  with check (auth.uid() = blocker_id);

drop policy if exists "blocks_delete_own" on public.blocks;
create policy "blocks_delete_own"
  on public.blocks for delete
  using (auth.uid() = blocker_id);
