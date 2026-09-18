-- Adds pin support for announcements (squad + community) so the
-- "Pin announcement" toggle in the app is backed by a real column.
alter table public.posts
  add column if not exists is_pinned boolean not null default false;

create index if not exists posts_squad_pinned_idx
  on public.posts (squad_id, is_pinned, created_at desc)
  where squad_id is not null;

create index if not exists posts_community_pinned_idx
  on public.posts (community_id, is_pinned, created_at desc)
  where community_id is not null;
