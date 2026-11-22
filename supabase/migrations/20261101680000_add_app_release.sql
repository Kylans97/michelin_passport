-- Asking members to update the app (product owner, 2026-11-22: "oke bouw
-- maar", after choosing versions kept in Supabase over asking the App
-- Store, which lags, and can't say a version no longer works).
--
-- One row, edited by hand in the dashboard after each App Store release:
--   latest_version   the version now on the App Store. An older app shows
--                    a quiet "A new version is available" once per version,
--                    with Update and Later.
--   minimum_version  the oldest version that still works. An older app
--                    shows only "Update" until it is updated. Raise it only
--                    when an old build would really break, the middle step
--                    of CLAUDE.md's three-step removal.
-- Versions are the App Store's "1.9.0" (CFBundleShortVersionString), never
-- build numbers: TestFlight builds share a version.
--
-- Written 2026-11-22. Readable by everyone, the entrance included: a
-- version too old to work must be stopped before sign-in too. No client
-- writes and no function, so there is no SECURITY DEFINER to revoke.
-- Seeded at what is live today (1.6.0, per the App Store) and a minimum
-- that blocks no one, so applying it changes nothing for anybody until
-- the row is edited.

begin;

create table public.app_release (
  id               boolean primary key default true check (id),
  latest_version   text not null check (latest_version ~ '^\d+\.\d+\.\d+$'),
  minimum_version  text not null check (minimum_version ~ '^\d+\.\d+\.\d+$'),
  updated_at       timestamptz not null default now()
);

comment on table public.app_release is
  'One row: the App Store version (latest_version, a gentle update prompt '
  'below it) and the oldest that still works (minimum_version, a blocking '
  'update screen below it). Edited by hand after each release.';

alter table public.app_release enable row level security;

create policy app_release_select on public.app_release
  for select to anon, authenticated
  using (true);

revoke all on public.app_release from anon, authenticated;
grant select on public.app_release to anon, authenticated;

insert into public.app_release (latest_version, minimum_version)
values ('1.6.0', '1.0.0');

commit;
