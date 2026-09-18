create table if not exists public.verification_rate_limits (
  subject_type text not null check (subject_type in ('email', 'ip', 'device')),
  subject_value text not null,
  last_sent_at timestamptz,
  hourly_count integer not null default 0,
  hourly_window_start timestamptz not null default now(),
  daily_count integer not null default 0,
  daily_window_start timestamptz not null default now(),
  blocked_until timestamptz,
  primary key (subject_type, subject_value)
);

alter table public.verification_rate_limits enable row level security;

create or replace function public.check_verification_rate_limit(
  p_email text,
  p_ip text,
  p_device text
)
returns table (allowed boolean, retry_after integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  subject record;
  now_value timestamptz := now();
  max_retry integer := 0;
begin
  for subject in
    select * from (values
      ('email', lower(trim(p_email))),
      ('ip', nullif(trim(p_ip), '')),
      ('device', nullif(trim(p_device), ''))
    ) as values_list(subject_type, subject_value)
  loop
    if subject.subject_value is null then
      continue;
    end if;
    perform pg_advisory_xact_lock(
      hashtextextended(subject.subject_type || ':' || subject.subject_value, 0)
    );
    insert into public.verification_rate_limits (subject_type, subject_value)
      values (subject.subject_type, subject.subject_value)
      on conflict (subject_type, subject_value) do nothing;
    select * into subject from public.verification_rate_limits
      where verification_rate_limits.subject_type = subject.subject_type
        and verification_rate_limits.subject_value = subject.subject_value
      for update;
    if subject.blocked_until is not null and subject.blocked_until > now_value then
      max_retry := greatest(max_retry, ceil(extract(epoch from subject.blocked_until - now_value))::integer);
    end if;
    if subject.last_sent_at is not null and subject.last_sent_at > now_value - interval '60 seconds' then
      max_retry := greatest(max_retry, ceil(extract(epoch from subject.last_sent_at + interval '60 seconds' - now_value))::integer);
    end if;
    if subject.hourly_window_start > now_value - interval '1 hour' and subject.hourly_count >= 5 then
      max_retry := greatest(max_retry, ceil(extract(epoch from subject.hourly_window_start + interval '1 hour' - now_value))::integer);
    end if;
    if subject.daily_window_start > now_value - interval '1 day' and subject.daily_count >= 10 then
      max_retry := greatest(max_retry, ceil(extract(epoch from subject.daily_window_start + interval '1 day' - now_value))::integer);
    end if;
  end loop;

  if max_retry > 0 then
    return query select false, max_retry;
    return;
  end if;
  for subject in
    select * from (values
      ('email', lower(trim(p_email))),
      ('ip', nullif(trim(p_ip), '')),
      ('device', nullif(trim(p_device), ''))
    ) as values_list(subject_type, subject_value)
  loop
    if subject.subject_value is null then
      continue;
    end if;
    insert into public.verification_rate_limits
      (subject_type, subject_value, last_sent_at, hourly_count,
       hourly_window_start, daily_count, daily_window_start)
    values
      (subject.subject_type, subject.subject_value, now_value, 1,
       now_value, 1, now_value)
    on conflict (subject_type, subject_value) do update set
      last_sent_at = now_value,
      hourly_count = case
        when verification_rate_limits.hourly_window_start <= now_value - interval '1 hour'
          then 1
        else verification_rate_limits.hourly_count + 1
      end,
      hourly_window_start = case
        when verification_rate_limits.hourly_window_start <= now_value - interval '1 hour'
          then now_value
        else verification_rate_limits.hourly_window_start
      end,
      daily_count = case
        when verification_rate_limits.daily_window_start <= now_value - interval '1 day'
          then 1
        else verification_rate_limits.daily_count + 1
      end,
      daily_window_start = case
        when verification_rate_limits.daily_window_start <= now_value - interval '1 day'
          then now_value
        else verification_rate_limits.daily_window_start
      end;
  end loop;
  return query select true, 0;
end;
$$;
