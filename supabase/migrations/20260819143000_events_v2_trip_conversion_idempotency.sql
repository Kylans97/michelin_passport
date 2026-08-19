-- Events V2 Step 1 — Database Foundation, part 4 of 5: planned_venues
-- gains 'event' as a legal entity_type, and visits gains an explicit
-- provenance link back to the plan item that produced it.
--
-- Confirmed live in production before writing this migration:
-- planned_venues.entity_type CHECK is currently ARRAY['hotel','restaurant']
-- (8 existing rows, none using a value this migration doesn't already
-- allow); visits has 5 existing rows and no column of this name today.
--
-- WHY visits genuinely needs converted_from_planned_venue_id (and
-- event_confirmed_attendance, added in the previous migration in this
-- sequence, mostly doesn't): a future trip-completion flow must never be
-- able to write the same history twice, even under retry or a double
-- submit. For event_confirmed_attendance, unique(event_id, user_id)
-- already makes that structurally impossible regardless of how many times
-- the flow is invoked. visits has no equivalent — and deliberately cannot
-- get one: a table-level unique(user_id, entity_id) is explicitly wrong
-- here, because a user must be able to genuinely visit or stay at the same
-- venue many times (this is existing, documented, deliberate behavior —
-- visits carries no uniqueness constraint of any kind today). The fix is
-- an explicit provenance link, not a fuzzy date/name match: this column is
-- populated only by the trip-completion flow, and its own UNIQUE
-- constraint means a retried write for the same planned_venues row fails
-- at the database, while ordinary manually-logged visits (which never
-- populate it, leaving it NULL) are entirely unaffected — Postgres treats
-- NULL as distinct from every other NULL for UNIQUE purposes, so this
-- constraint only ever fires on two rows genuinely claiming the same plan
-- item.
--
-- This is a separate, distinct mechanism from "detect a visit the user
-- already logged manually before a review prompt appears" — that remains
-- a query-time existence check against visited_on/entity_type/entity_id
-- (no provenance link exists for a manual visit, by definition), performed
-- in application code, not by this migration.
--
-- Does NOT touch events, event_restaurants, event_hotels, event_chefs,
-- event_attendance, event_confirmed_attendance, wishlist, planned_trips.
--
-- NOT applied to production by this migration file's authoring — prepared
-- for pre-deployment review only.

begin;

-- ============================================================
-- 1. PLANNED_VENUES — widen entity_type to include 'event'
-- ============================================================

alter table public.planned_venues
  drop constraint planned_venues_entity_type_check,
  add constraint planned_venues_entity_type_check
    check (entity_type in ('hotel', 'restaurant', 'event'));

-- No existing row uses 'event' — confirmed via production audit before
-- writing this migration — so every one of the 8 live rows is unaffected.

-- ============================================================
-- 2. VISITS — trip-conversion provenance link
-- ============================================================

alter table public.visits
  add column converted_from_planned_venue_id
    uuid references public.planned_venues(id) on delete set null unique;

-- Every one of the 5 currently-live visit rows gets NULL here (no
-- trip-completion flow exists yet to have populated it), so this is a
-- zero-data-impact migration exactly like every other ALTER in this
-- sequence. on delete set null (not cascade) matches
-- planned_venues.trip_id's own existing behavior: deleting the plan item
-- afterward severs provenance, never the real visit it produced —
-- "history is never overwritten or destroyed" is preserved structurally,
-- not just by convention.
--
-- No new index needed beyond the UNIQUE constraint's own automatic index:
-- the one query this column exists to serve ("has this specific plan item
-- already been converted?") is answered directly by that index.

commit;
