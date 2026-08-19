-- Events V2 Step 1 — Database Foundation, part 2 of 5: widen
-- event_attendance to support Interested in addition to Going.
--
-- Confirmed live in production before writing this migration: the current
-- CHECK is `status = 'going'` (a single-value equality check, not an
-- ARRAY-form IN-list — confirmed via pg_get_constraintdef, constraint name
-- event_attendance_status_check), exactly 2 rows exist, both status='going'.
-- Both rows already satisfy the widened CHECK below unchanged — this is a
-- zero-data-impact migration. No row is touched, no row is recreated, no
-- existing Going relationship is lost.
--
-- event_attendance remains the INTENT table only (Interested/Going) — see
-- docs/Architecture/EVENTS_V2_ARCHITECTURE.md §9. Confirmed attendance
-- (history) is a separate table, added in the next migration in this
-- sequence, never a third value on this same status column: a single
-- visibility/created_at pair on this row would otherwise have to describe
-- both a revisable intent and an immutable historical fact, which is
-- exactly the collapse the architecture's hard source-of-truth rule
-- forbids.
--
-- Does NOT touch events, event_restaurants, event_hotels, event_chefs,
-- visits, wishlist, photos, planned_trips, planned_venues.
--
-- NOT applied to production by this migration file's authoring — prepared
-- for pre-deployment review only.

begin;

-- ============================================================
-- 1. EVENT_ATTENDANCE — widen status to (interested, going)
-- ============================================================

alter table public.event_attendance
  drop constraint event_attendance_status_check,
  add constraint event_attendance_status_check
    check (status in ('interested', 'going'));

-- unique(event_id, user_id) is untouched (still the correct shape: one
-- intent row per user per event; Interested <-> Going is an UPDATE, not a
-- new row).

-- ============================================================
-- 2. INDEXES — status-aware lookups
-- ============================================================
--
-- Existing indexes (event_attendance_user_idx on user_id,
-- event_attendance_event_idx on event_id, plus the unique constraint's own
-- composite on (event_id, user_id)) are untouched and remain in place —
-- these two new composite indexes are additive, not replacements, and
-- specifically serve the query patterns Interested/Going introduces:
-- "count/list Going for event X" and "this user's Interested items",
-- both of which now need to filter on status in addition to event_id/
-- user_id, not just look the row up by identity.
create index event_attendance_event_status_idx
  on public.event_attendance (event_id, status);
create index event_attendance_user_status_idx
  on public.event_attendance (user_id, status);

commit;
