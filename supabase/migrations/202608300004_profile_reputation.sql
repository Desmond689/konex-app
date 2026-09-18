-- Adds a real `reputation` score to profiles, computed entirely from
-- existing activity (followers, likes received, comments received) —
-- replacing the client-side placeholder formula that was previously
-- shown on the profile banner when this column didn't exist.
--
-- Score = followers * 10 + likes received * 2 + comments received * 1.
-- Self-correcting via triggers, same pattern as
-- 202608300003_post_count_triggers.sql, so it can never drift.

alter table public.profiles
  add column if not exists reputation integer not null default 0;

create or replace function public.recompute_profile_reputation(target_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.profiles p
    set reputation = (
      (select count(*) from public.follows f where f.following_id = target_user_id) * 10
      + (
          select count(*) from public.likes l
          join public.posts po on po.id = l.post_id
          where po.user_id = target_user_id
        ) * 2
      + (
          select count(*) from public.comments c
          join public.posts po on po.id = c.post_id
          where po.user_id = target_user_id and c.is_deleted = false
        )
    )
    where p.id = target_user_id;
end;
$$;

-- Followers change reputation of the followed user.
create or replace function public.trg_follows_recompute_reputation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.recompute_profile_reputation(coalesce(new.following_id, old.following_id));
  return null;
end;
$$;

drop trigger if exists trg_follows_recompute_reputation on public.follows;
create trigger trg_follows_recompute_reputation
  after insert or delete on public.follows
  for each row execute function public.trg_follows_recompute_reputation();

-- Likes on a post change reputation of that post's author.
create or replace function public.trg_likes_recompute_reputation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  author_id uuid;
begin
  select user_id into author_id from public.posts where id = coalesce(new.post_id, old.post_id);
  if author_id is not null then
    perform public.recompute_profile_reputation(author_id);
  end if;
  return null;
end;
$$;

drop trigger if exists trg_likes_recompute_reputation on public.likes;
create trigger trg_likes_recompute_reputation
  after insert or delete on public.likes
  for each row execute function public.trg_likes_recompute_reputation();

-- Comments on a post change reputation of that post's author.
create or replace function public.trg_comments_recompute_reputation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  author_id uuid;
begin
  select user_id into author_id from public.posts where id = coalesce(new.post_id, old.post_id);
  if author_id is not null then
    perform public.recompute_profile_reputation(author_id);
  end if;
  return null;
end;
$$;

drop trigger if exists trg_comments_recompute_reputation on public.comments;
create trigger trg_comments_recompute_reputation
  after insert or update of is_deleted or delete on public.comments
  for each row execute function public.trg_comments_recompute_reputation();

-- One-time backfill for every existing profile.
do $$
declare
  r record;
begin
  for r in select id from public.profiles loop
    perform public.recompute_profile_reputation(r.id);
  end loop;
end $$;
