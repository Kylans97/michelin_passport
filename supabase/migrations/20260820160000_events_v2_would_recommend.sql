-- Events V2 Step 4.1 — PROPOSED, NOT DEPLOYED. Adds optional "Would you
-- recommend this event?" feedback to confirmed Attendance.
--
-- Confirmed live against production before drafting this file (not
-- assumed): public.event_confirmed_attendance has 10 columns today
-- (id, event_id, user_id, confirmed_at, rating, comment, visibility,
-- source, converted_from_planned_venue_id, created_at), 3 CHECK
-- constraints (rating 1-10, source enum, visibility enum), no view or
-- function references this table anywhere in the schema
-- (`select proname from pg_proc where prosrc ilike '%event_confirmed_
-- attendance%'` and the pg_views equivalent both returned zero rows), and
-- its RLS policies (select/insert/update/delete) key off `user_id` and
-- `visibility` only — none enumerate specific columns, so adding a new
-- nullable column requires no RLS change. Confirmed, not assumed.
--
-- Product distinction this column exists to capture (see
-- EVENTS_V2_ARCHITECTURE.md's Step 4.1 addendum for the full statement):
-- `rating` answers "how good was this experience?" — `would_recommend`
-- answers "would I recommend this experience to someone else?" — related
-- but independent signals, never derived from one another.
--
-- Semantics: NULL = no recommendation feedback supplied (never
-- interpreted as "No" — a future recommendation_rate calculation must
-- exclude NULL from its denominator, counting only rows where this
-- column IS NOT NULL). TRUE = Yes. FALSE = No. No default value — every
-- existing row (and every newly-inserted row that doesn't explicitly set
-- it) stays NULL, exactly matching how `rating`/`comment` already behave
-- on this table. No CHECK constraint needed: a nullable boolean is
-- already exactly three-valued (true/false/null) with no illegal
-- fourth state to guard against, unlike `source`/`visibility`'s text
-- columns.
--
-- NOT applied to production by this migration file's authoring.

begin;

alter table public.event_confirmed_attendance
  add column would_recommend boolean null;

comment on column public.event_confirmed_attendance.would_recommend is
  'Optional "Would you recommend this event?" feedback. NULL = not '
  'answered (never treated as No) — TRUE = Yes — FALSE = No. Independent '
  'of `rating`: one answers "how good was it," the other answers "would '
  'you recommend it." A future recommendation_rate = count(would_'
  'recommend = true) / count(would_recommend is not null) must exclude '
  'NULL rows from the denominator.';

commit;
