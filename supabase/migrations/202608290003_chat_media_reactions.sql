-- Chat media + pin support
alter table public.messages
  add column if not exists media_url text,
  add column if not exists media_type text,
  add column if not exists pinned boolean not null default false;

create table if not exists public.message_reactions (
  message_id uuid not null references public.messages(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  emoji text not null,
  created_at timestamptz not null default now(),
  primary key (message_id, user_id, emoji)
);

alter table public.message_reactions enable row level security;

create policy if not exists "reactions_select" on public.message_reactions
  for select using (true);

create policy if not exists "reactions_insert" on public.message_reactions
  for insert with check (user_id = auth.uid());

create policy if not exists "reactions_delete" on public.message_reactions
  for delete using (user_id = auth.uid());
