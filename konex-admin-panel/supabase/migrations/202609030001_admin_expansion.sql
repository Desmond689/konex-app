-- Konex Admin Panel expansion
-- Adds: community member management, appeals workflow, canned moderation
-- reasons, internal staff notes, and audit-log hardening.
--
-- Safe to run against an existing project — every statement is
-- create-if-not-exists / additive. Review before running in production,
-- same as the original 202608310002_admin_missing_rpcs.sql migration.

-- =========================================================
-- 1. COMMUNITY MEMBERS (admin can view + manage members of a game/community)
-- =========================================================
-- Assumes a `community_members` table already backs `communities.member_count`
-- (community_id, user_id, role, joined_at). Adjust column names below if
-- your schema differs.

create or replace function admin_list_community_members(
  p_community_id uuid,
  p_query text default null,
  p_limit int default 100,
  p_offset int default 0
) returns table (
  user_id uuid,
  username text,
  gamer_name text,
  avatar_url text,
  app_role text,
  is_banned boolean,
  is_verified boolean,
  member_role text,
  joined_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1 from profiles where id = auth.uid() and app_role in ('moderator','admin','super_admin')
  ) then
    raise exception 'not authorized';
  end if;

  return query
  select
    p.id, p.username, p.gamer_name, p.avatar_url, p.app_role, p.is_banned, p.is_verified,
    cm.role, cm.joined_at
  from community_members cm
  join profiles p on p.id = cm.user_id
  where cm.community_id = p_community_id
    and (
      p_query is null or p_query = '' or
      p.username ilike '%' || p_query || '%' or
      p.gamer_name ilike '%' || p_query || '%'
    )
  order by cm.joined_at asc
  limit p_limit offset p_offset;
end;
$$;

create or replace function admin_remove_community_member(
  p_community_id uuid,
  p_user_id uuid,
  p_reason text default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor_role text;
begin
  select app_role into v_actor_role from profiles where id = auth.uid();
  if v_actor_role not in ('moderator','admin','super_admin') then
    raise exception 'not authorized';
  end if;

  delete from community_members where community_id = p_community_id and user_id = p_user_id;
  update communities set member_count = greatest(coalesce(member_count,1) - 1, 0) where id = p_community_id;

  insert into audit_logs (actor_id, action, target_type, target_id, reason)
  values (auth.uid(), 'remove_community_member', 'community_member', p_user_id, p_reason);
end;
$$;

create or replace function admin_set_community_member_role(
  p_community_id uuid,
  p_user_id uuid,
  p_role text,
  p_reason text default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor_role text;
begin
  select app_role into v_actor_role from profiles where id = auth.uid();
  if v_actor_role not in ('admin','super_admin') then
    raise exception 'not authorized';
  end if;
  if p_role not in ('member','moderator','owner') then
    raise exception 'invalid community role';
  end if;

  update community_members set role = p_role
  where community_id = p_community_id and user_id = p_user_id;

  insert into audit_logs (actor_id, action, target_type, target_id, reason)
  values (auth.uid(), 'set_community_member_role', 'community_member', p_user_id, coalesce(p_reason, p_role));
end;
$$;

-- =========================================================
-- 2. APPEALS WORKFLOW
-- =========================================================
create table if not exists appeals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  moderation_action_id uuid references moderation_actions(id) on delete set null,
  message text not null,
  status text not null default 'open' check (status in ('open','approved','denied')),
  reviewed_by uuid references profiles(id),
  review_reason text,
  created_at timestamptz not null default now(),
  reviewed_at timestamptz
);

alter table appeals enable row level security;

drop policy if exists "users can view own appeals" on appeals;
create policy "users can view own appeals" on appeals
  for select using (auth.uid() = user_id);

drop policy if exists "users can create own appeals" on appeals;
create policy "users can create own appeals" on appeals
  for insert with check (auth.uid() = user_id);

drop policy if exists "staff can view all appeals" on appeals;
create policy "staff can view all appeals" on appeals
  for select using (
    exists (select 1 from profiles where id = auth.uid() and app_role in ('moderator','admin','super_admin'))
  );

create or replace function admin_list_appeals(p_status text default 'open', p_limit int default 50)
returns table (
  id uuid, user_id uuid, username text, gamer_name text, message text, status text,
  created_at timestamptz, reviewed_at timestamptz, review_reason text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from profiles where id = auth.uid() and app_role in ('moderator','admin','super_admin')) then
    raise exception 'not authorized';
  end if;

  return query
  select a.id, a.user_id, p.username, p.gamer_name, a.message, a.status, a.created_at, a.reviewed_at, a.review_reason
  from appeals a
  join profiles p on p.id = a.user_id
  where p_status = 'all' or a.status = p_status
  order by a.created_at desc
  limit p_limit;
end;
$$;

create or replace function admin_review_appeal(p_appeal_id uuid, p_approve boolean, p_reason text default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
begin
  if not exists (select 1 from profiles where id = auth.uid() and app_role in ('moderator','admin','super_admin')) then
    raise exception 'not authorized';
  end if;

  select user_id into v_user_id from appeals where id = p_appeal_id and status = 'open';
  if v_user_id is null then
    raise exception 'appeal not found or already reviewed';
  end if;

  update appeals
  set status = case when p_approve then 'approved' else 'denied' end,
      reviewed_by = auth.uid(),
      review_reason = p_reason,
      reviewed_at = now()
  where id = p_appeal_id;

  if p_approve then
    update profiles set is_banned = false, is_restricted = false, restricted_until = null
    where id = v_user_id;
  end if;

  insert into audit_logs (actor_id, action, target_type, target_id, reason)
  values (
    auth.uid(),
    case when p_approve then 'approve_appeal' else 'deny_appeal' end,
    'appeal', p_appeal_id, p_reason
  );
end;
$$;

-- =========================================================
-- 3. CANNED MODERATION REASONS (staff-editable, used in ConfirmDialog)
-- =========================================================
create table if not exists canned_reasons (
  id uuid primary key default gen_random_uuid(),
  action_type text not null, -- 'ban' | 'suspend' | 'restrict' | 'remove_content' | 'warn'
  label text not null,
  body text not null,
  created_by uuid references profiles(id),
  created_at timestamptz not null default now()
);

alter table canned_reasons enable row level security;

drop policy if exists "staff can read canned reasons" on canned_reasons;
create policy "staff can read canned reasons" on canned_reasons
  for select using (
    exists (select 1 from profiles where id = auth.uid() and app_role in ('moderator','admin','super_admin'))
  );

create or replace function admin_upsert_canned_reason(
  p_id uuid, p_action_type text, p_label text, p_body text
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  if not exists (select 1 from profiles where id = auth.uid() and app_role in ('admin','super_admin')) then
    raise exception 'not authorized';
  end if;

  if p_id is null then
    insert into canned_reasons (action_type, label, body, created_by)
    values (p_action_type, p_label, p_body, auth.uid())
    returning id into v_id;
  else
    update canned_reasons set action_type = p_action_type, label = p_label, body = p_body
    where id = p_id
    returning id into v_id;
  end if;
  return v_id;
end;
$$;

create or replace function admin_delete_canned_reason(p_id uuid) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from profiles where id = auth.uid() and app_role in ('admin','super_admin')) then
    raise exception 'not authorized';
  end if;
  delete from canned_reasons where id = p_id;
end;
$$;

-- =========================================================
-- 4. INTERNAL STAFF NOTES (case collaboration; never visible to end users)
-- =========================================================
create table if not exists staff_notes (
  id uuid primary key default gen_random_uuid(),
  target_type text not null, -- 'profile' | 'report' | 'community' | 'squad'
  target_id uuid not null,
  author_id uuid references profiles(id),
  body text not null,
  created_at timestamptz not null default now()
);

alter table staff_notes enable row level security;

drop policy if exists "staff can read notes" on staff_notes;
create policy "staff can read notes" on staff_notes
  for select using (
    exists (select 1 from profiles where id = auth.uid() and app_role in ('moderator','admin','super_admin'))
  );

drop policy if exists "staff can insert notes" on staff_notes;
create policy "staff can insert notes" on staff_notes
  for insert with check (
    auth.uid() = author_id and
    exists (select 1 from profiles where id = auth.uid() and app_role in ('moderator','admin','super_admin'))
  );

-- =========================================================
-- 5. AUDIT LOG HARDENING — insert-only for staff, no update/delete.
-- Flagged as a known gap in the original README.
-- =========================================================
alter table audit_logs enable row level security;

drop policy if exists "staff can read audit logs" on audit_logs;
create policy "staff can read audit logs" on audit_logs
  for select using (
    exists (select 1 from profiles where id = auth.uid() and app_role in ('moderator','admin','super_admin'))
  );

drop policy if exists "staff can insert audit logs" on audit_logs;
create policy "staff can insert audit logs" on audit_logs
  for insert with check (
    exists (select 1 from profiles where id = auth.uid() and app_role in ('moderator','admin','super_admin'))
  );

-- Deliberately no update/delete policy is created for any role, and RLS is
-- enabled, so no authenticated client — including staff — can modify or
-- remove an existing audit_logs row. Only a service-role connection
-- (bypasses RLS) or a direct DB admin can.

-- =========================================================
-- 6. Helpful indexes for the new analytics dashboard
-- =========================================================
create index if not exists idx_profiles_created_at on profiles (created_at);
create index if not exists idx_reports_created_at on reports (created_at);
create index if not exists idx_posts_created_at on posts (created_at) where is_deleted = false;
