-- Lets staff (moderator/admin/super_admin) toggle a profile's verified
-- badge from the app, the same way admin_set_role/admin_set_ban already
-- let them set role and ban status. Before this, `is_verified` had no
-- writer anywhere in the app — the only way to flip it was a direct
-- database edit.

create or replace function public.admin_set_verified(p_user_id uuid, p_verified boolean)
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

  update public.profiles
    set is_verified = p_verified,
        updated_at = now()
    where id = p_user_id;
end;
$$;

grant execute on function public.admin_set_verified(uuid, boolean) to authenticated;
