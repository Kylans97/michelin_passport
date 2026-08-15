-- Social Foundation Step 2B — Event Attendance.
--
-- Smallest useful "I'm going" model: one row per (event, user), a single
-- legal status ('going' — removing attendance is a DELETE, not a status
-- transition, matching how unfriending a friendship is a DELETE rather
-- than a status value in Step 1), and a visibility column reusing the
-- exact private|friends shape Step 2 already established for visits.
--
-- Reuses Step 1's public.is_friend(uuid) helper as the single shared
-- friendship predicate — not reimplemented here. Every authorization
-- check is a live subquery against public.friendships, so an unfriend or
-- a block revokes attendance visibility on the very next read, with zero
-- rows ever rewritten — identical guarantee to visits/wishlist/photos.
--
-- Does NOT touch visits, wishlist, photos, planned_trips, restaurants,
-- hotels, or award_history in any way.
--
-- Also adds one narrow, read-only aggregate RPC
-- (get_event_attendance_count) so anonymous "N members are going" counts
-- are backend-ready without exposing any individual's identity — never
-- wired into any UI in this step (see the Step 2B implementation report,
-- which documents this as a deliberate "prepare, don't overbuild"
-- decision).
--
-- NOT applied to production by this task — prepared for physical-device
-- and pre-deployment review only.

begin;

-- ============================================================
-- 1. EVENT_ATTENDANCE — table
-- ============================================================

create table public.event_attendance (
  id          uuid primary key default gen_random_uuid(),
  event_id    uuid not null references public.events(id) on delete cascade,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  -- Single legal value for MVP, deliberately — see this file's own header
  -- comment. A CHECK (not a Postgres enum) matches this schema's existing
  -- convention for status/type taxonomies.
  status      text not null default 'going' check (status in ('going')),
  -- Default 'friends', not 'private': an event is already fully public
  -- catalogue content (unlike a personal dining rating), so "I'm going to
  -- a public festival" is a materially lower-sensitivity disclosure than
  -- a private rating — the same reasoning the earlier architecture spike
  -- (FRIENDS_PRIVACY_COMMUNITY_INTELLIGENCE.md §16) already recorded for
  -- this exact decision. No dedicated visibility-toggle control is built
  -- in this step's UI (see the implementation report §17) — the column
  -- still supports 'private' at the schema/RLS/repository level so a
  -- future control needs no new migration.
  visibility  text not null default 'friends' check (visibility in ('private', 'friends')),
  created_at  timestamptz not null default now(),
  -- One attendance row per user per event — "no duplicate going rows" is
  -- structurally guaranteed here (there is only one legal status value),
  -- not just enforced by application logic.
  unique (event_id, user_id)
);

-- "Every event this user is attending" (Friend Profile GOING, and the
-- viewer's own upcoming attendance) — user_id as the leading column,
-- complementing the unique constraint's own (event_id, user_id) index
-- which only serves "who's attending this event" lookups.
create index event_attendance_user_idx on public.event_attendance (user_id);
create index event_attendance_event_idx on public.event_attendance (event_id);

-- ============================================================
-- 2. EVENT_ATTENDANCE — RLS
-- ============================================================

alter table public.event_attendance enable row level security;

-- Owner always reads their own row; otherwise only when the row itself
-- opted into 'friends' AND the viewer currently has an accepted
-- friendship with the attendee. No public/stranger read path exists.
create policy event_attendance_select on public.event_attendance
  for select to authenticated
  using (
    user_id = auth.uid()
    or (visibility = 'friends' and public.is_friend(user_id))
  );

-- A client can never create attendance on another user's behalf.
create policy event_attendance_insert on public.event_attendance
  for insert to authenticated
  with check (user_id = auth.uid());

-- Forward-compatible for a future visibility toggle — no status
-- transition exists to gate (the only legal status is 'going').
create policy event_attendance_update on public.event_attendance
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy event_attendance_delete on public.event_attendance
  for delete to authenticated
  using (user_id = auth.uid());

-- Table-level GRANT is required in addition to the RLS policies above —
-- RLS alone is a no-op without it for a brand-new table (confirmed the
-- hard way during Social Foundation Step 1: see that migration's own
-- friendships GRANT and its report's finding).
grant select, insert, update, delete on public.event_attendance to authenticated;

-- ============================================================
-- 3. AGGREGATE ATTENDANCE COUNT — prepared, not wired into any UI
-- ============================================================
--
-- Returns the exact count once >= 5 unique attendees exist (the
-- previously-approved minimum aggregation threshold, matching
-- FRIENDS_PRIVACY_COMMUNITY_INTELLIGENCE.md §5.7's own reasoning), NULL
-- below that — never a specific small number that could make an
-- individual attendee identifiable. Deliberately identity-free: selects
-- only count(*), never event_id/user_id rows. SECURITY DEFINER so it can
-- count every attendance row regardless of the caller's own friendships,
-- while still never returning row-level data.
create function public.get_event_attendance_count(target_event_id uuid)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select case when count(*) >= 5 then count(*)::integer else null end
  from public.event_attendance
  where event_id = target_event_id;
$$;

revoke execute on function public.get_event_attendance_count(uuid) from public;
grant  execute on function public.get_event_attendance_count(uuid) to authenticated;

commit;
