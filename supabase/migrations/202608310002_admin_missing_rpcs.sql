-- Adds the three RPCs the Flutter admin screens and the konex-admin-panel
-- web app both already call but that were never migrated:
-- admin_set_role, admin_set_ban, admin_create_game. Until this runs,
-- role changes, direct bans, and "Create game" all fail with a Postgres
-- "function not found" error in both clients.
--
-- Also adds the P0 role-tiering called for in moderation review, enforced
-- here server-side (the client-side `can()` gating in the web panel, and
-- the mirrored gating added to the Flutter admin_users_screen, are both
-- just UI convenience — this is the real boundary):
--   - moderator: can resolve reports, ban/restrict via the report flow,
--     and manage games, but cannot change anyone's role.
--   - admin: can promote/demote between 'user' and 'moderator', but
--     cannot grant 'admin' and cannot touch an existing admin's or
--     super_admin's role.
--   - super_admin: can additionally grant/revoke 'admin'.
--   - 'super_admin' itself can never be set through the app by anyone,
--     and nobody (of any role) can change their own role. Both require a
--     direct database edit.

-- 1) admin_set_role -----------------------------------------------------
create or replace function public.admin_set_role(p_user_id uuid, p_role text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  caller_role text;
  target_role text;
begin
  if p_role not in ('user', 'moderator', 'admin') then
    raise exception 'Invalid role';
  end if;

  if p_user_id = auth.uid() then
    raise exception 'Cannot change your own role';
  end if;

  select app_role into caller_role from public.profiles where id = auth.uid();
  select app_role into target_role from public.profiles where id = p_user_id;

  if target_role is null then
    raise exception 'User not found';
  end if;

  if target_role = 'super_admin' then
    raise exception 'Not authorized';
  end if;

  if caller_role = 'super_admin' then
    -- may set user / moderator / admin
    null;
  elsif caller_role = 'admin' then
    -- may only move between user <-> moderator, and only for targets
    -- that aren't already admin (or super_admin, excluded above)
    if p_role = 'admin' or target_role = 'admin' then
      raise exception 'Not authorized';
    end if;
  else
    -- moderator, or anything else (including null / plain 'user')
    raise exception 'Not authorized';
  end if;

  update public.profiles
    set app_role = p_role,
        updated_at = now()
    where id = p_user_id;
end;
$$;

grant execute on function public.admin_set_role(uuid, text) to authenticated;

-- 2) admin_set_ban -------------------------------------------------------
-- Direct ban/unban toggle. Currently unused by either client's UI (both
-- route ban/restore through resolveReport instead) but kept available
-- since AdminRepository.setUserBan already calls it, and to avoid the
-- same "function not found" failure if anything starts calling it.
create or replace function public.admin_set_ban(p_user_id uuid, p_banned boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  caller_role text;
  target_role text;
begin
  if p_user_id = auth.uid() then
    raise exception 'Cannot ban yourself';
  end if;

  select app_role into caller_role from public.profiles where id = auth.uid();
  if caller_role is null or caller_role not in ('moderator', 'admin', 'super_admin') then
    raise exception 'Not authorized';
  end if;

  select app_role into target_role from public.profiles where id = p_user_id;
  if target_role is null then
    raise exception 'User not found';
  end if;
  if target_role in ('admin', 'super_admin') then
    raise exception 'Not authorized';
  end if;

  update public.profiles
    set is_banned = p_banned,
        updated_at = now()
    where id = p_user_id;
end;
$$;

grant execute on function public.admin_set_ban(uuid, boolean) to authenticated;

-- 3) admin_create_game ----------------------------------------------------
-- Mirrors what 202608300007_seed_games.sql already writes for bulk-seeded
-- games (is_official = false here since these are staff-created rather
-- than seeded, is_private = false, require_approval = false, member_count
-- = 0), plus a description/rules pair the seed script doesn't set.
create or replace function public.admin_create_game(
  p_name text,
  p_slug text,
  p_description text default null,
  p_rules text default null,
  p_category text default null,
  p_platforms text[] default array['mobile']::text[]
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  caller_role text;
  new_id uuid;
begin
  select app_role into caller_role from public.profiles where id = auth.uid();
  if caller_role is null or caller_role not in ('moderator', 'admin', 'super_admin') then
    raise exception 'Not authorized';
  end if;

  if p_name is null or length(trim(p_name)) = 0 then
    raise exception 'Name is required';
  end if;
  if p_slug is null or length(trim(p_slug)) = 0 then
    raise exception 'Slug is required';
  end if;

  insert into public.communities (
    name, slug, game_name, description, rules, category, platforms,
    is_official, is_private, require_approval, member_count
  ) values (
    trim(p_name), trim(p_slug), trim(p_name), p_description, p_rules, p_category, p_platforms,
    false, false, false, 0
  )
  returning id into new_id;

  return new_id;
end;
$$;

grant execute on function public.admin_create_game(
  text, text, text, text, text, text[]
) to authenticated;
