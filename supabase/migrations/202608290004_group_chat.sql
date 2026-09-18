-- Allow group conversations (multi-person, not squad-bound)
-- If type is constrained via CHECK, expand it:
do $$
begin
  -- Soft approach: no-op if unconstrained; document expected values: dm | squad | group
  null;
end $$;

-- Ensure title exists for group chats
alter table public.conversations
  add column if not exists title text;

alter table public.conversations
  add column if not exists created_by uuid references auth.users(id);

-- Optional role on participants
alter table public.conversation_participants
  add column if not exists role text default 'member';
