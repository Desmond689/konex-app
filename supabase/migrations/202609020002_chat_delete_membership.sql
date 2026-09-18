alter table public.messages
  add column if not exists is_deleted boolean not null default false,
  add column if not exists updated_at timestamptz not null default now();

alter table public.messages enable row level security;

drop policy if exists "messages_update_own" on public.messages;
create policy "messages_update_own"
on public.messages
for update
using (sender_id = auth.uid())
with check (sender_id = auth.uid());

drop policy if exists "messages_select_participant" on public.messages;
create policy "messages_select_participant"
on public.messages
for select
using (private.is_conversation_participant(conversation_id, auth.uid()));

drop policy if exists "posts_insert_own" on public.posts;
create policy "posts_insert_own"
on public.posts
for insert
with check (
  author_id = auth.uid()
  and (
    community_id is null
    or exists (
      select 1 from public.community_members cm
      where cm.community_id = posts.community_id
        and cm.user_id = auth.uid()
        and cm.status = 'active'
    )
  )
);

drop policy if exists "likes_insert_member" on public.likes;
create policy "likes_insert_member"
on public.likes
for insert
with check (
  user_id = auth.uid()
  and exists (
    select 1 from public.posts p
    where p.id = likes.post_id
      and (
        p.community_id is null
        or exists (
          select 1 from public.community_members cm
          where cm.community_id = p.community_id
            and cm.user_id = auth.uid()
            and cm.status = 'active'
        )
      )
  )
);

drop policy if exists "comments_insert_member" on public.comments;
create policy "comments_insert_member"
on public.comments
for insert
with check (
  author_id = auth.uid()
  and exists (
    select 1 from public.posts p
    where p.id = comments.post_id
      and (
        p.community_id is null
        or exists (
          select 1 from public.community_members cm
          where cm.community_id = p.community_id
            and cm.user_id = auth.uid()
            and cm.status = 'active'
        )
      )
  )
);
