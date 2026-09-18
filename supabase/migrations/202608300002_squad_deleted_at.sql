-- squads.is_deleted already exists and is used throughout the app for
-- discovery/active-squad filtering, but there's no timestamp recording
-- when a soft-delete happened. Needed for the new owner "delete squad" flow.
alter table public.squads
  add column if not exists deleted_at timestamptz;
