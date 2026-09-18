-- Production hardening for the admin console:
-- 1) admin_resolve_report — single transactional RPC for all moderation
--    effects (report status, moderation_actions, audit_logs, ban/restrict/
--    suspend/restore, content removal). Client no longer multi-writes.
-- 2) admin_set_ban / admin_set_verified already exist; role stays on
--    admin_set_role. Frontend can() is UX only; this is the authority.
-- 3) Helper views / RPCs for staff list and user moderation context.

-- ─── 1) admin_resolve_report ───────────────────────────────────────────
create or replace function public.admin_resolve_report(
  p_report_id   uuid,
  p_action      text,
  p_reason      text default null,
  p_target_type text default null,
  p_target_id   uuid default null,
  p_target_user_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  caller_role   text;
  target_role   text;
  has_report    boolean;
  now_ts        timestamptz := now();
  resolved_target_user uuid;
  resolved_target_type text;
  resolved_target_id   uuid;
  r_row         public.reports%rowtype;
begin
  -- Staff gate
  select app_role into caller_role from public.profiles where id = auth.uid();
  if caller_role is null or caller_role not in ('moderator', 'admin', 'super_admin') then
    raise exception 'Not authorized';
  end if;

  if p_action not in (
    'no_action', 'remove_content', 'warn', 'restrict', 'suspend', 'ban', 'restore'
  ) then
    raise exception 'Invalid action';
  end if;

  has_report := p_report_id is not null
                and p_report_id <> '00000000-0000-0000-0000-000000000000'::uuid;

  if has_report then
    select * into r_row from public.reports where id = p_report_id for update;
    if not found then
      raise exception 'Report not found';
    end if;
    if r_row.status <> 'open' then
      raise exception 'Report is not open';
    end if;
    resolved_target_type := coalesce(p_target_type, r_row.target_type);
    resolved_target_id   := coalesce(p_target_id, r_row.target_id);
    -- Prefer explicit target user; else derive from profile targets
    if p_target_user_id is not null then
      resolved_target_user := p_target_user_id;
    elsif r_row.target_type = 'profile' then
      resolved_target_user := r_row.target_id;
    else
      -- For post/comment targets try to resolve author
      if r_row.target_type = 'post' then
        select author_id into resolved_target_user from public.posts where id = r_row.target_id;
      elsif r_row.target_type = 'comment' then
        select author_id into resolved_target_user from public.comments where id = r_row.target_id;
      end if;
    end if;
  else
    resolved_target_type := coalesce(p_target_type, 'profile');
    resolved_target_id   := coalesce(p_target_id, p_target_user_id);
    resolved_target_user := p_target_user_id;
  end if;

  -- Never let staff ban/restrict/suspend other staff of equal-or-higher tier
  if resolved_target_user is not null and p_action in ('ban', 'restrict', 'suspend') then
    if resolved_target_user = auth.uid() then
      raise exception 'Cannot moderate yourself';
    end if;
    select app_role into target_role from public.profiles where id = resolved_target_user;
    if target_role in ('admin', 'super_admin') then
      raise exception 'Not authorized to moderate this user';
    end if;
    if target_role = 'moderator' and caller_role = 'moderator' then
      raise exception 'Not authorized to moderate this user';
    end if;
  end if;

  -- Update report
  if has_report then
    update public.reports
      set status      = case when p_action = 'no_action' then 'dismissed' else 'actioned' end,
          reviewed_at = now_ts,
          reviewed_by = auth.uid()
      where id = p_report_id;
  end if;

  -- Moderation action row
  insert into public.moderation_actions (
    report_id, actor_id, target_user_id, target_type, target_id, action, reason
  ) values (
    case when has_report then p_report_id else null end,
    auth.uid(),
    resolved_target_user,
    coalesce(resolved_target_type, 'unknown'),
    resolved_target_id,
    p_action,
    p_reason
  );

  -- Audit log
  insert into public.audit_logs (
    actor_id, action, target_type, target_id, reason, metadata
  ) values (
    auth.uid(),
    p_action,
    resolved_target_type,
    resolved_target_id,
    p_reason,
    jsonb_build_object(
      'report_id', p_report_id,
      'target_user_id', resolved_target_user
    )
  );

  -- Apply profile effects
  if resolved_target_user is not null then
    if p_action = 'ban' then
      update public.profiles
        set is_banned = true, updated_at = now_ts
        where id = resolved_target_user;
    elsif p_action = 'restrict' then
      update public.profiles
        set is_restricted = true,
            restricted_until = now_ts + interval '7 days',
            updated_at = now_ts
        where id = resolved_target_user;
    elsif p_action = 'suspend' then
      update public.profiles
        set is_restricted = true,
            restricted_until = now_ts + interval '30 days',
            updated_at = now_ts
        where id = resolved_target_user;
    elsif p_action = 'restore' then
      update public.profiles
        set is_banned = false,
            is_restricted = false,
            restricted_until = null,
            updated_at = now_ts
        where id = resolved_target_user;
    end if;
    -- 'warn' is log-only (already written to moderation_actions)
  end if;

  -- Content removal
  if p_action = 'remove_content' then
    if resolved_target_type = 'post' and resolved_target_id is not null then
      update public.posts
        set is_deleted = true, updated_at = now_ts
        where id = resolved_target_id;
    elsif resolved_target_type = 'comment' and resolved_target_id is not null then
      begin
        update public.comments
          set is_deleted = true, updated_at = now_ts
          where id = resolved_target_id;
      exception when undefined_column then
        null;
      end;
    elsif resolved_target_type = 'squad' and resolved_target_id is not null then
      update public.squads
        set is_deleted = true, deleted_at = now_ts
        where id = resolved_target_id;
      update public.squad_members
        set status = 'left'
        where squad_id = resolved_target_id and status = 'active';
    end if;
  end if;
end;
$$;

grant execute on function public.admin_resolve_report(
  uuid, text, text, text, uuid, uuid
) to authenticated;

-- ─── 2) list_staff — super_admin only ──────────────────────────────────
create or replace function public.admin_list_staff()
returns table (
  id uuid,
  username text,
  gamer_name text,
  app_role text,
  is_verified boolean,
  is_banned boolean,
  is_restricted boolean,
  avatar_url text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  caller_role text;
begin
  select app_role into caller_role from public.profiles where id = auth.uid();
  if caller_role is null or caller_role <> 'super_admin' then
    raise exception 'Not authorized';
  end if;

  return query
    select p.id, p.username, p.gamer_name, p.app_role,
           p.is_verified, p.is_banned, p.is_restricted, p.avatar_url, p.created_at
    from public.profiles p
    where p.app_role in ('moderator', 'admin', 'super_admin')
    order by
      case p.app_role
        when 'super_admin' then 1
        when 'admin' then 2
        when 'moderator' then 3
        else 4
      end,
      p.username;
end;
$$;

grant execute on function public.admin_list_staff() to authenticated;

-- ─── 3) user moderation context for Manage drawer ──────────────────────
create or replace function public.admin_user_moderation_context(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  caller_role text;
  profile_row jsonb;
  reports_received int;
  warnings int;
  restrictions int;
  suspensions int;
  bans int;
  history jsonb;
begin
  select app_role into caller_role from public.profiles where id = auth.uid();
  if caller_role is null or caller_role not in ('moderator', 'admin', 'super_admin') then
    raise exception 'Not authorized';
  end if;

  select to_jsonb(p) - 'email' into profile_row
  from public.profiles p where p.id = p_user_id;
  if profile_row is null then
    raise exception 'User not found';
  end if;

  select count(*) into reports_received
  from public.reports
  where (target_type = 'profile' and target_id = p_user_id)
     or target_id in (select id from public.posts where author_id = p_user_id);

  select count(*) into warnings
  from public.moderation_actions
  where target_user_id = p_user_id and action = 'warn';

  select count(*) into restrictions
  from public.moderation_actions
  where target_user_id = p_user_id and action = 'restrict';

  select count(*) into suspensions
  from public.moderation_actions
  where target_user_id = p_user_id and action = 'suspend';

  select count(*) into bans
  from public.moderation_actions
  where target_user_id = p_user_id and action = 'ban';

  select coalesce(jsonb_agg(row_to_json(m) order by m.created_at desc), '[]'::jsonb)
  into history
  from (
    select ma.id, ma.action, ma.reason, ma.created_at, ma.target_type, ma.target_id,
           a.username as actor_username
    from public.moderation_actions ma
    left join public.profiles a on a.id = ma.actor_id
    where ma.target_user_id = p_user_id
    order by ma.created_at desc
    limit 30
  ) m;

  return jsonb_build_object(
    'profile', profile_row,
    'reports_received', reports_received,
    'warnings', warnings,
    'restrictions', restrictions,
    'suspensions', suspensions,
    'bans', bans,
    'history', history
  );
end;
$$;

grant execute on function public.admin_user_moderation_context(uuid) to authenticated;

-- ─── 4) report content preview helper ──────────────────────────────────
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
begin
  select app_role into caller_role from public.profiles where id = auth.uid();
  if caller_role is null or caller_role not in ('moderator', 'admin', 'super_admin') then
    raise exception 'Not authorized';
  end if;

  select * into r from public.reports where id = p_report_id;
  if not found then
    raise exception 'Report not found';
  end if;

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
    'prior_actions', prior
  );
end;
$$;

grant execute on function public.admin_report_preview(uuid) to authenticated;
