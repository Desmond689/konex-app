create or replace function public.increment_story_view(p_story_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.stories
  set view_count = (
    select count(*) from public.story_views where story_id = p_story_id
  )
  where id = p_story_id;
end;
$$;

revoke all on function public.increment_story_view(uuid) from public;
grant execute on function public.increment_story_view(uuid) to authenticated;

drop policy if exists "stories_select" on public.stories;
create policy "stories_select"
on public.stories for select
using (
  expires_at > now()
  and not exists (
    select 1
    from public.blocks b
    where (b.blocker_id = auth.uid() and b.blocked_id = stories.user_id)
       or (b.blocker_id = stories.user_id and b.blocked_id = auth.uid())
  )
  and (
    user_id = auth.uid()
    or (
      privacy = 'everyone'
      and (
        community_id is null
        or exists (
          select 1 from public.community_members cm
          where cm.community_id = stories.community_id
            and cm.user_id = auth.uid()
            and cm.status = 'active'
        )
      )
    )
    or (
      privacy = 'followers'
      and exists (
        select 1 from public.follows f
        where f.following_id = stories.user_id
          and f.follower_id = auth.uid()
      )
      and (
        community_id is null
        or exists (
          select 1 from public.community_members cm
          where cm.community_id = stories.community_id
            and cm.user_id = auth.uid()
            and cm.status = 'active'
        )
      )
    )
    or (
      privacy = 'friends'
      and exists (
        select 1 from public.follows f1
        where f1.following_id = stories.user_id
          and f1.follower_id = auth.uid()
          and exists (
            select 1 from public.follows f2
            where f2.following_id = auth.uid()
              and f2.follower_id = stories.user_id
          )
      )
      and (
        community_id is null
        or exists (
          select 1 from public.community_members cm
          where cm.community_id = stories.community_id
            and cm.user_id = auth.uid()
            and cm.status = 'active'
        )
      )
    )
  )
);

drop policy if exists "stories_insert" on public.stories;
create policy "stories_insert"
on public.stories for insert
with check (
  user_id = auth.uid()
  and (
    community_id is null
    or exists (
      select 1 from public.community_members cm
      where cm.community_id = stories.community_id
        and cm.user_id = auth.uid()
        and cm.status = 'active'
    )
  )
);

drop policy if exists "story_views_insert" on public.story_views;
create policy "story_views_insert"
on public.story_views for insert
with check (
  viewer_id = auth.uid()
  and exists (
    select 1 from public.stories s
    where s.id = story_views.story_id
      and s.expires_at > now()
  )
);
