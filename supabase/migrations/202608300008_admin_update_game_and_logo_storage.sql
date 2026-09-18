-- 1) Lets staff edit an existing game/community (including its logo),
--    the same way admin_create_game() creates one. Before this there
--    was no writer for an existing community from the app at all.
create or replace function public.admin_update_game(
  p_community_id uuid,
  p_name text default null,
  p_description text default null,
  p_rules text default null,
  p_category text default null,
  p_platforms text[] default null,
  p_avatar_url text default null,
  p_banner_url text default null,
  p_primary_region text default null,
  p_is_private boolean default null,
  p_require_approval boolean default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  caller_role text;
begin
  select app_role into caller_role from public.profiles where id = auth.uid();
  if caller_role is null or caller_role not in ('moderator', 'admin', 'super_admin') then
    raise exception 'Not authorized';
  end if;

  update public.communities set
    name = coalesce(p_name, name),
    game_name = coalesce(p_name, game_name),
    description = coalesce(p_description, description),
    rules = coalesce(p_rules, rules),
    category = coalesce(p_category, category),
    platforms = coalesce(p_platforms, platforms),
    avatar_url = coalesce(p_avatar_url, avatar_url),
    banner_url = coalesce(p_banner_url, banner_url),
    primary_region = coalesce(p_primary_region, primary_region),
    is_private = coalesce(p_is_private, is_private),
    require_approval = coalesce(p_require_approval, require_approval)
  where id = p_community_id;
end;
$$;

grant execute on function public.admin_update_game(
  uuid, text, text, text, text, text[], text, text, text, boolean, boolean
) to authenticated;

-- 2) Logo storage for game communities, mirroring the existing
--    squad-logos bucket: public read (logos are shown to everyone),
--    writes restricted to staff (moderator/admin/super_admin).
insert into storage.buckets (id, name, public)
values ('community-logos', 'community-logos', true)
on conflict (id) do nothing;

create policy if not exists "community-logos public read"
  on storage.objects for select
  using (bucket_id = 'community-logos');

create policy if not exists "community-logos staff insert"
  on storage.objects for insert
  with check (
    bucket_id = 'community-logos'
    and exists (
      select 1 from public.profiles
      where id = auth.uid() and app_role in ('moderator', 'admin', 'super_admin')
    )
  );

create policy if not exists "community-logos staff update"
  on storage.objects for update
  using (
    bucket_id = 'community-logos'
    and exists (
      select 1 from public.profiles
      where id = auth.uid() and app_role in ('moderator', 'admin', 'super_admin')
    )
  );

create policy if not exists "community-logos staff delete"
  on storage.objects for delete
  using (
    bucket_id = 'community-logos'
    and exists (
      select 1 from public.profiles
      where id = auth.uid() and app_role in ('moderator', 'admin', 'super_admin')
    )
  );
