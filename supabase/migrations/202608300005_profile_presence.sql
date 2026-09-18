-- Real "online" status. Previously the green dot on the profile avatar was
-- hardcoded in the Flutter UI with no backing data — it showed regardless
-- of whether the user was actually online. This adds a real last_seen
-- timestamp the client updates via heartbeat, and a security-definer RPC
-- so it can be written without needing broad update access to `profiles`.

alter table public.profiles
  add column if not exists last_seen timestamptz not null default now();

create index if not exists idx_profiles_last_seen on public.profiles (last_seen);

create or replace function public.touch_presence()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.profiles set last_seen = now() where id = auth.uid();
end;
$$;

grant execute on function public.touch_presence() to authenticated;
