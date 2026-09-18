-- Stories feature: 24h ephemeral stories with privacy + media support

create table if not exists public.stories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  media_type text not null check (media_type in ('photo', 'video', 'text')),
  media_url text,
  text_content text,
  background_color text default '#7C3AED',
  privacy text not null default 'everyone'
    check (privacy in ('everyone', 'followers', 'friends', 'only_me')),
  community_id uuid references public.communities(id) on delete set null,
  view_count integer not null default 0,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '24 hours')
);

create index if not exists stories_user_id_idx on public.stories(user_id);
create index if not exists stories_expires_at_idx on public.stories(expires_at);
create index if not exists stories_created_at_idx on public.stories(created_at desc);

-- Who has viewed a story
create table if not exists public.story_views (
  story_id uuid not null references public.stories(id) on delete cascade,
  viewer_id uuid not null references auth.users(id) on delete cascade,
  viewed_at timestamptz not null default now(),
  primary key (story_id, viewer_id)
);

-- Optional highlights (saved after expiry)
create table if not exists public.story_highlights (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  cover_url text,
  created_at timestamptz not null default now()
);

create table if not exists public.story_highlight_items (
  highlight_id uuid not null references public.story_highlights(id) on delete cascade,
  story_id uuid not null references public.stories(id) on delete cascade,
  position integer not null default 0,
  primary key (highlight_id, story_id)
);

alter table public.stories enable row level security;
alter table public.story_views enable row level security;
alter table public.story_highlights enable row level security;
alter table public.story_highlight_items enable row level security;

-- SELECT: visible if not expired AND (everyone OR owner OR followers/friends logic simplified)
create policy "stories_select"
  on public.stories for select
  using (
    expires_at > now()
    and (
      privacy = 'everyone'
      or user_id = auth.uid()
      or (privacy = 'followers' and exists (
        select 1 from public.follows f
        where f.following_id = stories.user_id and f.follower_id = auth.uid()
      ))
      or (privacy = 'only_me' and user_id = auth.uid())
    )
  );

create policy "stories_insert"
  on public.stories for insert
  with check (user_id = auth.uid());

create policy "stories_delete"
  on public.stories for delete
  using (user_id = auth.uid());

create policy "story_views_select"
  on public.story_views for select
  using (true);

create policy "story_views_insert"
  on public.story_views for insert
  with check (viewer_id = auth.uid());

create policy "highlights_select"
  on public.story_highlights for select
  using (true);

create policy "highlights_insert"
  on public.story_highlights for insert
  with check (user_id = auth.uid());

create policy "highlights_delete"
  on public.story_highlights for delete
  using (user_id = auth.uid());

create policy "highlight_items_all"
  on public.story_highlight_items for all
  using (
    exists (
      select 1 from public.story_highlights h
      where h.id = highlight_id and h.user_id = auth.uid()
    )
  );

-- Auto-cleanup function (can be called by cron / edge function)
create or replace function public.cleanup_expired_stories()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Delete media is handled by storage policies / app; just remove rows past grace
  delete from public.stories
  where expires_at < now() - interval '1 hour'
    and id not in (select story_id from public.story_highlight_items);
end;
$$;
