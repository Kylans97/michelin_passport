-- Events V2 Step 1 — Database Foundation, part 3 of 5: confirmed event
-- attendance (history), structurally separate from event_attendance
-- (intent, widened in the previous migration in this sequence).
--
-- A row here is created only on explicit user confirmation — manual, a
-- future post-event prompt, or trip completion — never solely because
-- event_attendance.status = 'going'. Deleting/changing an intent row after
-- the fact never touches confirmed history, and vice versa: the two tables
-- share no column, no trigger, no cascade between them.
--
-- unique(event_id, user_id) already gives full database-level idempotency
-- across every creation path on its own: a specific dated event happens
-- once for a given attendee, regardless of whether the confirming action
-- came from a manual tap, a future prompt, or trip completion.
-- converted_from_planned_venue_id (added here for symmetry/provenance with
-- the same column being added to visits in this sequence's part 4) is not
-- required for correctness on this table the way it is on visits — see
-- that migration's own header comment for why visits genuinely needs it
-- and this table does not.
--
-- rating is overall-only (1-10, matching every other rating scale in this
-- schema) — an event can be a festival, tasting, masterclass or bar shift,
-- and no five-dimension restaurant/hotel-style breakdown generalizes
-- across those. comment/photos are optional, never required to confirm.
--
-- Does NOT touch event_attendance's own status/visibility semantics,
-- events, event_restaurants, event_hotels, event_chefs, wishlist,
-- planned_trips.
--
-- NOT applied to production by this migration file's authoring — prepared
-- for pre-deployment review only.

begin;

-- ============================================================
-- 1. EVENT_CONFIRMED_ATTENDANCE — table
-- ============================================================

create table public.event_confirmed_attendance (
  id            uuid primary key default gen_random_uuid(),
  event_id      uuid not null references public.events(id) on delete cascade,
  user_id       uuid not null references public.profiles(id) on delete cascade,
  confirmed_at  timestamptz not null default now(),
  rating        smallint check (rating between 1 and 10),
  comment       text,
  -- Same private|friends shape as visits/event_attendance, but a more
  -- conservative default ('private', matching visits) than
  -- event_attendance's own 'friends' default — confirmed attendance is
  -- personal history, the same sensitivity tier as a visit, not a
  -- lower-stakes "I clicked going on a public event" signal.
  visibility    text not null default 'private'
    check (visibility in ('private', 'friends')),
  -- Coarse creation-source tag — see the Personal History Source section
  -- of the architecture doc. Distinct from converted_from_planned_venue_id
  -- below: source answers "how" in general terms, the FK answers "from
  -- which specific plan item, if any" and is what the database actually
  -- enforces idempotency against.
  source        text not null default 'manual'
    check (source in ('manual', 'post_event_prompt', 'trip_completion')),
  -- Provenance link back to the originating planned_venues row, populated
  -- only by a future trip-completion flow. NULL for every other creation
  -- path (manual, post_event_prompt). Postgres treats NULL as distinct for
  -- UNIQUE purposes, so this constraint only ever fires if two rows both
  -- claim the same specific planned_venues.id — exactly and only the
  -- double-write failure mode it exists to prevent. on delete set null
  -- (not cascade) matches planned_venues.trip_id's own existing behavior:
  -- deleting the plan item afterward severs provenance, never the real
  -- history it produced.
  converted_from_planned_venue_id
    uuid references public.planned_venues(id) on delete set null unique,
  created_at    timestamptz not null default now(),
  -- One confirmed attendance per user per event — deliberately unlike
  -- visits (which intentionally allows repeat rows): a specific dated
  -- event genuinely happens once for a given attendee.
  unique (event_id, user_id)
);

-- The unique(event_id, user_id) index above already serves "all confirmed
-- attendances for event X" (event_id is its leftmost column) — no separate
-- event_id-only index added, per "do not add indexes already covered by a
-- unique constraint". user_id-only lookups ("all of this user's confirmed
-- attendances", feeding Passport) are NOT covered by that composite index
-- (user_id is not the leftmost column), so a dedicated index is needed.
create index event_confirmed_attendance_user_idx
  on public.event_confirmed_attendance (user_id);

-- ============================================================
-- 2. EVENT_CONFIRMED_ATTENDANCE — RLS
-- ============================================================

alter table public.event_confirmed_attendance enable row level security;

-- Identical shape to event_attendance_select/visits_read: owner always
-- reads their own row; otherwise only when the row opted into 'friends'
-- AND the viewer currently has an accepted friendship with the confirmed
-- attendee. No public/stranger read path.
create policy event_confirmed_attendance_select on public.event_confirmed_attendance
  for select to authenticated
  using (
    user_id = auth.uid()
    or (visibility = 'friends' and public.is_friend(user_id))
  );

create policy event_confirmed_attendance_insert on public.event_confirmed_attendance
  for insert to authenticated
  with check (user_id = auth.uid());

create policy event_confirmed_attendance_update on public.event_confirmed_attendance
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy event_confirmed_attendance_delete on public.event_confirmed_attendance
  for delete to authenticated
  using (user_id = auth.uid());

-- Explicit table-level GRANT, matching the established convention on
-- event_attendance/friendships/private_chef_enquiries. Note for the
-- pre-apply report: confirmed empirically against production that a
-- project-level default-privilege setting already grants anon and
-- authenticated full table-level privileges on every new table regardless
-- of any explicit GRANT here — RLS's own `to authenticated` role scoping
-- (never `to anon`, for every policy above) is what actually keeps anon
-- out, not the absence of a raw grant. This statement is written anyway
-- for self-documentation and consistency with existing migrations.
grant select, insert, update, delete on public.event_confirmed_attendance to authenticated;

-- ============================================================
-- 3. PHOTOS — attendance photo relationship
-- ============================================================
--
-- Mirrors photos.visit_id exactly: a nullable FK, cascade on delete (a
-- deleted confirmed attendance takes its own photos with it, matching how
-- a deleted visit already takes its photos with it today).
alter table public.photos
  add column attendance_id uuid references public.event_confirmed_attendance(id) on delete cascade;

-- photos_read must gain an attendance_id branch mirroring its existing
-- visit_id branch exactly, or a friends-visible attendance photo
-- (attendance_id set, visit_id null) would be invisible to friends despite
-- its parent event_confirmed_attendance row correctly opting into
-- 'friends' — an actual, not hypothetical, gap if left unaddressed here.
-- The visit_id branch below is reproduced byte-for-byte from the live
-- policy (confirmed via pg_policies before writing this migration) so this
-- statement changes nothing about existing photo visibility — it only
-- adds the new, currently-unreachable attendance_id branch (unreachable
-- because attendance_id was NULL on every row until the ALTER above).
drop policy photos_read on public.photos;
create policy photos_read on public.photos
  for select to authenticated
  using (
    user_id = auth.uid()
    or (
      visit_id is not null
      and exists (
        select 1 from public.visits v
        where v.id = photos.visit_id
          and v.visibility = 'friends'
          and public.is_friend(v.user_id)
      )
    )
    or (
      attendance_id is not null
      and exists (
        select 1 from public.event_confirmed_attendance eca
        where eca.id = photos.attendance_id
          and eca.visibility = 'friends'
          and public.is_friend(eca.user_id)
      )
    )
  );

commit;
