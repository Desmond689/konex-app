-- Shared community chat. Every active community member is added as a
-- participant when the chat is first opened, so it appears in Inbox.
alter table public.conversations
  add column if not exists community_id uuid references public.communities(id) on delete cascade;

create unique index if not exists conversations_one_community_chat
  on public.conversations (community_id)
  where type = 'community' and community_id is not null;
