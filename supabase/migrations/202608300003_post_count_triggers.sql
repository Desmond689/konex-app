-- The Flutter client now keeps its own optimistic like/comment counts
-- (see PostCard's local state), but that's still best-effort against
-- concurrent likers/commenters, dropped requests, and screens that don't
-- go through the same code path. These triggers make posts.like_count and
-- posts.comment_count self-correcting from the source tables (likes,
-- comments) regardless of what the client believes, so counts can never
-- permanently drift.

create or replace function public.recompute_post_like_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_post_id uuid;
begin
  target_post_id := coalesce(new.post_id, old.post_id);
  update public.posts
    set like_count = (
      select count(*) from public.likes where post_id = target_post_id
    )
    where id = target_post_id;
  return null;
end;
$$;

drop trigger if exists trg_likes_recompute_post_count on public.likes;
create trigger trg_likes_recompute_post_count
  after insert or delete on public.likes
  for each row execute function public.recompute_post_like_count();

create or replace function public.recompute_post_comment_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_post_id uuid;
begin
  target_post_id := coalesce(new.post_id, old.post_id);
  update public.posts
    set comment_count = (
      select count(*) from public.comments
      where post_id = target_post_id and is_deleted = false
    )
    where id = target_post_id;
  return null;
end;
$$;

drop trigger if exists trg_comments_recompute_post_count on public.comments;
create trigger trg_comments_recompute_post_count
  after insert or update of is_deleted or delete on public.comments
  for each row execute function public.recompute_post_comment_count();

-- One-time backfill so existing rows aren't left with whatever
-- possibly-drifted count the client last wrote.
update public.posts p
  set like_count = (select count(*) from public.likes l where l.post_id = p.id);

update public.posts p
  set comment_count = (
    select count(*) from public.comments c
    where c.post_id = p.id and c.is_deleted = false
  );
