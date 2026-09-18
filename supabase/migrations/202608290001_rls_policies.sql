create schema if not exists private;

create or replace function private.is_squad_member(p_squad_id uuid, p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.squad_members sm
    where sm.squad_id = p_squad_id
      and sm.user_id = p_user_id
      and sm.status = 'active'
  );
$$;

create or replace function private.is_squad_moderator(p_squad_id uuid, p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.squad_members sm
    where sm.squad_id = p_squad_id
      and sm.user_id = p_user_id
      and sm.role in ('owner', 'moderator')
      and sm.status = 'active'
  );
$$;

create or replace function private.is_conversation_participant(p_conversation_id uuid, p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.conversation_participants cp
    where cp.conversation_id = p_conversation_id
      and cp.user_id = p_user_id
  );
$$;

revoke all on function private.is_squad_member(uuid, uuid) from public;
revoke all on function private.is_squad_moderator(uuid, uuid) from public;
revoke all on function private.is_conversation_participant(uuid, uuid) from public;

grant usage on schema private to authenticated;
grant execute on function private.is_squad_member(uuid, uuid) to authenticated;
grant execute on function private.is_squad_moderator(uuid, uuid) to authenticated;
grant execute on function private.is_conversation_participant(uuid, uuid) to authenticated;

alter table public.conversation_participants enable row level security;
alter table public.posts enable row level security;
alter table public.squad_members enable row level security;
alter table public.squads enable row level security;

drop policy if exists "cp_insert" on public.conversation_participants;
drop policy if exists "cp_select" on public.conversation_participants;
drop policy if exists "cp_update_own" on public.conversation_participants;

drop policy if exists "posts_delete_own" on public.posts;
drop policy if exists "posts_insert_own" on public.posts;
drop policy if exists "posts_select" on public.posts;
drop policy if exists "posts_staff_update" on public.posts;
drop policy if exists "posts_update_own" on public.posts;

drop policy if exists "sm_delete_own_or_mod" on public.squad_members;
drop policy if exists "sm_insert_own" on public.squad_members;
drop policy if exists "sm_select" on public.squad_members;
drop policy if exists "sm_update_mod" on public.squad_members;

drop policy if exists "squads_delete_owner" on public.squads;
drop policy if exists "squads_insert" on public.squads;
drop policy if exists "squads_select" on public.squads;
drop policy if exists "squads_update_owner" on public.squads;

create policy "cp_insert"
on public.conversation_participants
as permissive
for insert
with check (user_id = auth.uid());

create policy "cp_select"
on public.conversation_participants
as permissive
for select
using (user_id = auth.uid());

create policy "cp_update_own"
on public.conversation_participants
as permissive
for update
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy "posts_select"
on public.posts
as permissive
for select
using (
  is_deleted = false
  and (
    visibility = 'public'
    or author_id = auth.uid()
    or exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and p.app_role in ('moderator', 'admin', 'super_admin')
    )
  )
);

create policy "posts_insert_own"
on public.posts
as permissive
for insert
with check (author_id = auth.uid());

create policy "posts_update_own"
on public.posts
as permissive
for update
using (author_id = auth.uid())
with check (author_id = auth.uid());

create policy "posts_delete_own"
on public.posts
as permissive
for delete
using (author_id = auth.uid());

create policy "posts_staff_update"
on public.posts
as permissive
for update
using (
  exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.app_role in ('moderator', 'admin', 'super_admin')
  )
)
with check (
  exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.app_role in ('moderator', 'admin', 'super_admin')
  )
);

create policy "sm_select"
on public.squad_members
as permissive
for select
using (
  user_id = auth.uid()
  or exists (
    select 1
    from public.squads s
    where s.id = squad_members.squad_id
      and s.owner_id = auth.uid()
  )
  or private.is_squad_member(squad_members.squad_id, auth.uid())
  or exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.app_role in ('moderator', 'admin', 'super_admin')
  )
);

create policy "sm_insert_own"
on public.squad_members
as permissive
for insert
with check (
  user_id = auth.uid()
  and (
    status in ('active', 'pending')
    or exists (
      select 1
      from public.squads s
      where s.id = squad_members.squad_id
        and s.owner_id = auth.uid()
    )
  )
);

create policy "sm_update_mod"
on public.squad_members
as permissive
for update
using (
  exists (
    select 1
    from public.squads s
    where s.id = squad_members.squad_id
      and s.owner_id = auth.uid()
  )
  or private.is_squad_moderator(squad_members.squad_id, auth.uid())
)
with check (
  exists (
    select 1
    from public.squads s
    where s.id = squad_members.squad_id
      and s.owner_id = auth.uid()
  )
  or private.is_squad_moderator(squad_members.squad_id, auth.uid())
);

create policy "sm_delete_own_or_mod"
on public.squad_members
as permissive
for delete
using (
  user_id = auth.uid()
  or exists (
    select 1
    from public.squads s
    where s.id = squad_members.squad_id
      and s.owner_id = auth.uid()
  )
  or private.is_squad_moderator(squad_members.squad_id, auth.uid())
);

create policy "squads_select"
on public.squads
as permissive
for select
using (
  is_deleted = false
  and (
    is_public = true
    or owner_id = auth.uid()
    or private.is_squad_member(squads.id, auth.uid())
  )
);

create policy "squads_insert"
on public.squads
as permissive
for insert
with check (owner_id = auth.uid());

create policy "squads_update_owner"
on public.squads
as permissive
for update
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

create policy "squads_delete_owner"
on public.squads
as permissive
for delete
using (owner_id = auth.uid());
