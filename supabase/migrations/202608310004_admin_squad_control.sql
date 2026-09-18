-- Squad Control for admin console + squad reports.
-- Sensitive ops are security-definer RPCs; super_admin for destructive/system,
-- staff (moderator+) for inspect + soft moderation.

-- Optional columns used by control panel
alter table public.squads
  add column if not exists is_restricted boolean not null default false;

alter table public.squads
  add column if not exists restricted_at timestamptz;

alter table public.squads
  add column if not exists restricted_reason text;

-- ─── helpers ───────────────────────────────────────────────────────────
create or replace function public._admin_require_staff()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  r text;
begin
  select app_role into r from public.profiles where id = auth.uid();
  if r is null or r not in ('moderator', 'admin', 'super_admin') then
    raise exception 'Not authorized';
  end if;
  return r;
end;
$$;

create or replace function public._admin_require_super()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  r text;
begin
  r := public._admin_require_staff();
  if r <> 'super_admin' then
    raise exception 'Not authorized — super_admin required';
  end if;
end;
$$;

create or replace function public._admin_audit(
  p_action text,
  p_target_type text,
  p_target_id uuid,
  p_reason text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.audit_logs (actor_id, action, target_type, target_id, reason, metadata)
  values (auth.uid(), p_action, p_target_type, p_target_id, p_reason, p_metadata);
end;
$$;

-- ─── overview stats ────────────────────────────────────────────────────
create or replace function public.admin_squad_stats()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  out jsonb;
begin
  perform public._admin_require_staff();

  select jsonb_build_object(
    'total', (select count(*) from public.squads),
    'public', (select count(*) from public.squads where coalesce(is_public, true) and not coalesce(is_deleted, false)),
    'private', (select count(*) from public.squads where not coalesce(is_public, true) and not coalesce(is_deleted, false)),
    'active', (select count(*) from public.squads where not coalesce(is_deleted, false) and not coalesce(is_restricted, false)),
    'restricted', (select count(*) from public.squads where coalesce(is_restricted, false) and not coalesce(is_deleted, false)),
    'archived', (select count(*) from public.squads where coalesce(is_deleted, false)),
    'members', (select count(*) from public.squad_members where status = 'active'),
    'pending_requests', (
      select count(*) from public.squad_join_requests where status = 'pending'
    ),
    'open_squad_reports', (
      select count(*) from public.reports
      where status = 'open' and target_type = 'squad'
    ),
    'resolved_squad_reports', (
      select count(*) from public.reports
      where status in ('actioned', 'dismissed') and target_type = 'squad'
    ),
    'created_today', (
      select count(*) from public.squads
      where created_at >= date_trunc('day', now())
    )
  ) into out;

  return out;
end;
$$;

grant execute on function public.admin_squad_stats() to authenticated;

-- ─── search / list ─────────────────────────────────────────────────────
create or replace function public.admin_list_squads(
  p_query text default null,
  p_filter text default 'all',  -- all|public|private|restricted|archived
  p_limit int default 50
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  q text;
  rows jsonb;
begin
  perform public._admin_require_staff();
  q := nullif(trim(coalesce(p_query, '')), '');

  select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb)
  into rows
  from (
    select
      s.id,
      s.name,
      s.slug,
      s.logo_url,
      s.primary_game,
      s.is_public,
      s.require_approval,
      s.invite_policy,
      s.member_count,
      s.is_deleted,
      s.deleted_at,
      s.is_restricted,
      s.restricted_at,
      s.restricted_reason,
      s.created_at,
      s.owner_id,
      o.username as owner_username,
      o.gamer_name as owner_gamer_name,
      o.avatar_url as owner_avatar_url
    from public.squads s
    left join public.profiles o on o.id = s.owner_id
    where
      (
        q is null
        or s.name ilike '%' || q || '%'
        or s.slug ilike '%' || q || '%'
        or s.id::text ilike q || '%'
        or o.username ilike '%' || q || '%'
        or s.primary_game ilike '%' || q || '%'
      )
      and (
        case lower(coalesce(p_filter, 'all'))
          when 'public' then coalesce(s.is_public, true) and not coalesce(s.is_deleted, false)
          when 'private' then not coalesce(s.is_public, true) and not coalesce(s.is_deleted, false)
          when 'restricted' then coalesce(s.is_restricted, false) and not coalesce(s.is_deleted, false)
          when 'archived' then coalesce(s.is_deleted, false)
          else true
        end
      )
    order by s.member_count desc nulls last, s.created_at desc
    limit greatest(1, least(coalesce(p_limit, 50), 100))
  ) x;

  return rows;
end;
$$;

grant execute on function public.admin_list_squads(text, text, int) to authenticated;

-- ─── full squad context ────────────────────────────────────────────────
create or replace function public.admin_squad_detail(p_squad_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  squad jsonb;
  members jsonb;
  requests jsonb;
  history jsonb;
  reports_open int;
begin
  perform public._admin_require_staff();

  select to_jsonb(s) || jsonb_build_object(
    'owner_username', o.username,
    'owner_gamer_name', o.gamer_name,
    'owner_avatar_url', o.avatar_url
  )
  into squad
  from public.squads s
  left join public.profiles o on o.id = s.owner_id
  where s.id = p_squad_id;

  if squad is null then
    raise exception 'Squad not found';
  end if;

  select coalesce(jsonb_agg(to_jsonb(m) order by m.joined_at), '[]'::jsonb)
  into members
  from (
    select
      sm.user_id,
      sm.role,
      sm.status,
      sm.joined_at,
      p.username,
      p.gamer_name,
      p.avatar_url,
      p.is_banned as user_banned
    from public.squad_members sm
    left join public.profiles p on p.id = sm.user_id
    where sm.squad_id = p_squad_id
  ) m;

  select coalesce(jsonb_agg(to_jsonb(r) order by r.created_at desc), '[]'::jsonb)
  into requests
  from (
    select
      jr.user_id,
      jr.status,
      jr.created_at,
      jr.reviewed_at,
      p.username,
      p.gamer_name,
      p.avatar_url
    from public.squad_join_requests jr
    left join public.profiles p on p.id = jr.user_id
    where jr.squad_id = p_squad_id and jr.status = 'pending'
  ) r;

  select coalesce(jsonb_agg(to_jsonb(h) order by h.created_at desc), '[]'::jsonb)
  into history
  from (
    select al.action, al.reason, al.created_at, a.username as actor_username
    from public.audit_logs al
    left join public.profiles a on a.id = al.actor_id
    where al.target_type = 'squad' and al.target_id = p_squad_id
    order by al.created_at desc
    limit 40
  ) h;

  select count(*) into reports_open
  from public.reports
  where target_type = 'squad' and target_id = p_squad_id and status = 'open';

  return jsonb_build_object(
    'squad', squad,
    'members', members,
    'pending_requests', requests,
    'moderation_history', history,
    'open_reports', reports_open
  );
end;
$$;

grant execute on function public.admin_squad_detail(uuid) to authenticated;

-- ─── restrict / restore / archive ──────────────────────────────────────
create or replace function public.admin_restrict_squad(p_squad_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public._admin_require_staff();
  if p_reason is null or length(trim(p_reason)) < 3 then
    raise exception 'Reason required';
  end if;

  update public.squads
    set is_restricted = true,
        restricted_at = now(),
        restricted_reason = trim(p_reason)
    where id = p_squad_id;

  if not found then raise exception 'Squad not found'; end if;

  perform public._admin_audit('restrict_squad', 'squad', p_squad_id, p_reason);
end;
$$;

grant execute on function public.admin_restrict_squad(uuid, text) to authenticated;

create or replace function public.admin_restore_squad(p_squad_id uuid, p_reason text default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public._admin_require_staff();

  update public.squads
    set is_restricted = false,
        restricted_at = null,
        restricted_reason = null,
        is_deleted = false,
        deleted_at = null
    where id = p_squad_id;

  if not found then raise exception 'Squad not found'; end if;

  perform public._admin_audit('restore_squad', 'squad', p_squad_id, p_reason);
end;
$$;

grant execute on function public.admin_restore_squad(uuid, text) to authenticated;

create or replace function public.admin_archive_squad(p_squad_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public._admin_require_staff();
  if p_reason is null or length(trim(p_reason)) < 3 then
    raise exception 'Reason required';
  end if;

  update public.squads
    set is_deleted = true,
        deleted_at = now()
    where id = p_squad_id;

  if not found then raise exception 'Squad not found'; end if;

  -- Deactivate memberships so members can join other squads
  update public.squad_members
    set status = 'left'
    where squad_id = p_squad_id and status = 'active';

  perform public._admin_audit('archive_squad', 'squad', p_squad_id, p_reason);
end;
$$;

grant execute on function public.admin_archive_squad(uuid, text) to authenticated;

-- ─── transfer ownership (super_admin) ──────────────────────────────────
create or replace function public.admin_transfer_squad_owner(
  p_squad_id uuid,
  p_new_owner_id uuid,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  old_owner uuid;
begin
  perform public._admin_require_super();
  if p_reason is null or length(trim(p_reason)) < 3 then
    raise exception 'Reason required';
  end if;

  select owner_id into old_owner from public.squads where id = p_squad_id for update;
  if old_owner is null then raise exception 'Squad not found'; end if;
  if old_owner = p_new_owner_id then raise exception 'Already the owner'; end if;

  -- New owner must be an active member
  if not exists (
    select 1 from public.squad_members
    where squad_id = p_squad_id and user_id = p_new_owner_id and status = 'active'
  ) then
    raise exception 'New owner must be an active member of the squad';
  end if;

  update public.squads set owner_id = p_new_owner_id where id = p_squad_id;

  update public.squad_members
    set role = 'owner'
    where squad_id = p_squad_id and user_id = p_new_owner_id;

  update public.squad_members
    set role = 'member'
    where squad_id = p_squad_id and user_id = old_owner and role = 'owner';

  perform public._admin_audit(
    'transfer_squad_owner',
    'squad',
    p_squad_id,
    p_reason,
    jsonb_build_object('old_owner', old_owner, 'new_owner', p_new_owner_id)
  );
end;
$$;

grant execute on function public.admin_transfer_squad_owner(uuid, uuid, text) to authenticated;

-- ─── member role / remove ──────────────────────────────────────────────
create or replace function public.admin_set_squad_member_role(
  p_squad_id uuid,
  p_user_id uuid,
  p_role text,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  owner uuid;
begin
  perform public._admin_require_staff();
  if p_role not in ('member', 'moderator') then
    raise exception 'Role must be member or moderator (use transfer for owner)';
  end if;

  select owner_id into owner from public.squads where id = p_squad_id;
  if owner is null then raise exception 'Squad not found'; end if;
  if p_user_id = owner then raise exception 'Cannot change owner role this way'; end if;

  update public.squad_members
    set role = p_role
    where squad_id = p_squad_id and user_id = p_user_id and status = 'active';

  if not found then raise exception 'Active member not found'; end if;

  perform public._admin_audit(
    'set_squad_member_role',
    'squad',
    p_squad_id,
    p_reason,
    jsonb_build_object('user_id', p_user_id, 'role', p_role)
  );
end;
$$;

grant execute on function public.admin_set_squad_member_role(uuid, uuid, text, text) to authenticated;

create or replace function public.admin_remove_squad_member(
  p_squad_id uuid,
  p_user_id uuid,
  p_ban boolean default false,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  owner uuid;
begin
  perform public._admin_require_staff();

  select owner_id into owner from public.squads where id = p_squad_id;
  if owner is null then raise exception 'Squad not found'; end if;
  if p_user_id = owner then raise exception 'Cannot remove owner — transfer first'; end if;

  if p_ban then
    update public.squad_members
      set status = 'banned', role = 'member'
      where squad_id = p_squad_id and user_id = p_user_id;
  else
    delete from public.squad_members
      where squad_id = p_squad_id and user_id = p_user_id;
  end if;

  update public.squads
    set member_count = greatest(0, coalesce(member_count, 1) - 1)
    where id = p_squad_id;

  perform public._admin_audit(
    case when p_ban then 'ban_squad_member' else 'remove_squad_member' end,
    'squad',
    p_squad_id,
    p_reason,
    jsonb_build_object('user_id', p_user_id)
  );
end;
$$;

grant execute on function public.admin_remove_squad_member(uuid, uuid, boolean, text) to authenticated;

-- ─── join requests ─────────────────────────────────────────────────────
create or replace function public.admin_list_pending_join_requests(p_limit int default 50)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  rows jsonb;
begin
  perform public._admin_require_staff();

  select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb)
  into rows
  from (
    select
      jr.squad_id,
      jr.user_id,
      jr.created_at,
      s.name as squad_name,
      s.primary_game,
      s.logo_url,
      p.username,
      p.gamer_name,
      p.avatar_url
    from public.squad_join_requests jr
    join public.squads s on s.id = jr.squad_id
    left join public.profiles p on p.id = jr.user_id
    where jr.status = 'pending'
    order by jr.created_at desc
    limit greatest(1, least(coalesce(p_limit, 50), 100))
  ) x;

  return rows;
end;
$$;

grant execute on function public.admin_list_pending_join_requests(int) to authenticated;

create or replace function public.admin_review_join_request(
  p_squad_id uuid,
  p_user_id uuid,
  p_approve boolean,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public._admin_require_staff();

  update public.squad_join_requests
    set status = case when p_approve then 'approved' else 'rejected' end,
        reviewed_at = now(),
        reviewed_by = auth.uid()
    where squad_id = p_squad_id and user_id = p_user_id and status = 'pending';

  if not found then raise exception 'Pending request not found'; end if;

  if p_approve then
    -- Block if already active in another squad
    if exists (
      select 1 from public.squad_members
      where user_id = p_user_id and status = 'active' and squad_id <> p_squad_id
    ) then
      raise exception 'User already belongs to another squad';
    end if;

    insert into public.squad_members (squad_id, user_id, role, status)
    values (p_squad_id, p_user_id, 'member', 'active')
    on conflict (squad_id, user_id) do update
      set status = 'active', role = 'member';

    update public.squads
      set member_count = coalesce(member_count, 0) + 1
      where id = p_squad_id;
  end if;

  perform public._admin_audit(
    case when p_approve then 'approve_join_request' else 'deny_join_request' end,
    'squad',
    p_squad_id,
    p_reason,
    jsonb_build_object('user_id', p_user_id)
  );
end;
$$;

grant execute on function public.admin_review_join_request(uuid, uuid, boolean, text) to authenticated;

-- ─── settings patch (super_admin) ──────────────────────────────────────
create or replace function public.admin_update_squad_settings(
  p_squad_id uuid,
  p_name text default null,
  p_description text default null,
  p_rules text default null,
  p_is_public boolean default null,
  p_require_approval boolean default null,
  p_invite_policy text default null,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public._admin_require_super();

  update public.squads set
    name = coalesce(nullif(trim(p_name), ''), name),
    description = case when p_description is null then description else p_description end,
    rules = case when p_rules is null then rules else p_rules end,
    is_public = coalesce(p_is_public, is_public),
    require_approval = coalesce(p_require_approval, require_approval),
    invite_policy = coalesce(p_invite_policy, invite_policy)
  where id = p_squad_id;

  if not found then raise exception 'Squad not found'; end if;

  perform public._admin_audit('update_squad_settings', 'squad', p_squad_id, p_reason);
end;
$$;

grant execute on function public.admin_update_squad_settings(
  uuid, text, text, text, boolean, boolean, text, text
) to authenticated;

-- Extend report preview for squad targets (recreate with squad branch)
-- Safe: create or replace the whole function from previous migration + squad.
create or replace function public.admin_report_preview(p_report_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  caller_role text;
  r public.reports%rowtype;
  content jsonb := null;
  target_user jsonb := null;
  prior jsonb := '[]'::jsonb;
  author_id uuid;
  squad_info jsonb := null;
begin
  select app_role into caller_role from public.profiles where id = auth.uid();
  if caller_role is null or caller_role not in ('moderator', 'admin', 'super_admin') then
    raise exception 'Not authorized';
  end if;

  select * into r from public.reports where id = p_report_id;
  if not found then raise exception 'Report not found'; end if;

  if r.target_type = 'post' then
    select jsonb_build_object(
      'type', 'post',
      'id', p.id,
      'body', p.body,
      'post_type', p.post_type,
      'media_urls', coalesce((
        select jsonb_agg(m.media_url)
        from public.post_media pm
        join public.media m on m.id = pm.media_id
        where pm.post_id = p.id
      ), '[]'::jsonb),
      'is_deleted', p.is_deleted,
      'created_at', p.created_at,
      'author_id', p.author_id,
      'author_username', pr.username,
      'author_gamer_name', pr.gamer_name,
      'author_avatar_url', pr.avatar_url,
      'like_count', p.like_count,
      'comment_count', p.comment_count
    ), p.author_id
    into content, author_id
    from public.posts p
    left join public.profiles pr on pr.id = p.author_id
    where p.id = r.target_id;
  elsif r.target_type = 'comment' then
    select jsonb_build_object(
      'type', 'comment',
      'id', c.id,
      'body', c.body,
      'media_url', c.media_url,
      'created_at', c.created_at,
      'author_id', c.author_id,
      'author_username', pr.username,
      'post_id', c.post_id
    ), c.author_id
    into content, author_id
    from public.comments c
    left join public.profiles pr on pr.id = c.author_id
    where c.id = r.target_id;
  elsif r.target_type = 'profile' then
    author_id := r.target_id;
  elsif r.target_type = 'squad' then
    select jsonb_build_object(
      'type', 'squad',
      'id', s.id,
      'name', s.name,
      'slug', s.slug,
      'logo_url', s.logo_url,
      'primary_game', s.primary_game,
      'member_count', s.member_count,
      'is_public', s.is_public,
      'is_deleted', s.is_deleted,
      'is_restricted', s.is_restricted,
      'description', s.description,
      'owner_id', s.owner_id,
      'owner_username', o.username,
      'owner_gamer_name', o.gamer_name,
      'owner_avatar_url', o.avatar_url,
      'created_at', s.created_at
    ), s.owner_id
    into content, author_id
    from public.squads s
    left join public.profiles o on o.id = s.owner_id
    where s.id = r.target_id;
    squad_info := content;
  end if;

  if author_id is not null then
    select to_jsonb(pr) - 'email' into target_user
    from public.profiles pr where pr.id = author_id;

    select coalesce(jsonb_agg(row_to_json(m) order by m.created_at desc), '[]'::jsonb)
    into prior
    from (
      select ma.action, ma.reason, ma.created_at, a.username as actor_username
      from public.moderation_actions ma
      left join public.profiles a on a.id = ma.actor_id
      where ma.target_user_id = author_id
      order by ma.created_at desc
      limit 10
    ) m;
  end if;

  return jsonb_build_object(
    'report', jsonb_build_object(
      'id', r.id,
      'target_type', r.target_type,
      'target_id', r.target_id,
      'reason', r.reason,
      'details', r.details,
      'status', r.status,
      'created_at', r.created_at,
      'reporter_id', r.reporter_id
    ),
    'content', content,
    'target_user', target_user,
    'prior_actions', prior,
    'squad', squad_info
  );
end;
$$;

grant execute on function public.admin_report_preview(uuid) to authenticated;
