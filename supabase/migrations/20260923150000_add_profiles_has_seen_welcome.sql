begin;

-- ============================================================
-- Welcome flow — one-shot, server-tracked "has this account seen
-- onboarding" state.
-- ============================================================
--
-- Deliberately NOT stored on-device: local storage doesn't survive a
-- reinstall, which would show the welcome flow again to someone who
-- already saw it. A single boolean on profiles is enough — the flow
-- doesn't need to know WHEN it was seen, only whether it was.
--
-- `not null default false` backfills every EXISTING row to false in
-- the same statement, not just new ones going forward — deliberate,
-- not an oversight: current testers should see the welcome flow once
-- on the next build (explicit request), not be treated as having
-- already completed it just because their account predates this
-- column.
--
-- No RLS change needed: profiles_update (20260805141519, "14.2
-- profiles") is already row-level or (id = auth.uid()), not
-- column-restricted, so an owner can already write this column like
-- any other on their own row.
alter table public.profiles
  add column has_seen_welcome boolean not null default false;

comment on column public.profiles.has_seen_welcome is
  'Set true once this account has completed or skipped the first-run '
  'welcome flow. Server-tracked (not local storage) so a reinstall '
  'never shows it twice.';

commit;
