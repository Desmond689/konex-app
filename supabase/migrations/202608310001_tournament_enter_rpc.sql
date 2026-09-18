-- TournamentRepository.enter() was doing a non-atomic read-then-write:
-- fetch tournaments.participant_count client-side, check it against
-- max_participants, then write participant_count + 1 back. Two people
-- tapping "Join" on the same near-full tournament within the same window
-- can both read the same count and both write the same incremented value
-- (undercounting entries and letting the tournament exceed
-- max_participants), and there's no server-side enforcement of the cap at
-- all — a client that skips the check can insert an entry unconditionally.
--
-- This moves the whole "already entered? full? still open?" check plus the
-- increment into a single locked transaction, so it's correct under
-- concurrent joins and can't be bypassed by a modified client.

create or replace function public.enter_tournament(p_tournament_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_status text;
  v_max int;
  v_count int;
  v_already boolean;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  -- Lock the tournament row for the duration of this transaction so two
  -- concurrent callers can't both pass the capacity check below.
  select status, max_participants, participant_count
    into v_status, v_max, v_count
    from public.tournaments
    where id = p_tournament_id
    for update;

  if not found then
    raise exception 'Tournament not found';
  end if;
  if v_status not in ('open', 'locked') then
    raise exception 'Tournament not open';
  end if;

  select exists(
    select 1 from public.tournament_entries
    where tournament_id = p_tournament_id and user_id = v_uid
  ) into v_already;
  if v_already then
    return;
  end if;

  if v_count >= v_max then
    raise exception 'Tournament full';
  end if;

  insert into public.tournament_entries (tournament_id, user_id, status)
  values (p_tournament_id, v_uid, 'joined');

  update public.tournaments
    set participant_count = v_count + 1,
        updated_at = now()
    where id = p_tournament_id;
end;
$$;

grant execute on function public.enter_tournament(uuid) to authenticated;
