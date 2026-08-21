-- Events V2 Step 4 — PROPOSED, NOT DEPLOYED. Widens photos.entity_type to
-- permit event-attendance photo uploads.
--
-- Discovered by direct audit before writing any photo-upload code for
-- this step (never assumed): public.photos.entity_type is `text not null
-- check (entity_type in ('hotel', 'restaurant'))`, and entity_id is also
-- `uuid not null`. Both predate Events V2 entirely (schema v1). Step 1's
-- own confirmed-attendance migration already added `photos.attendance_id`
-- (nullable FK -> event_confirmed_attendance, on delete cascade) and
-- extended photos_read's RLS to cover it — but never touched this CHECK
-- constraint, so inserting a photo row for an event attendance is
-- currently rejected outright: entity_type/entity_id are NOT NULL, and
-- 'event' is not a legal entity_type value. This is a genuine schema gap,
-- not a Dart-side oversight — no amount of repository/UI code can work
-- around a NOT NULL + CHECK constraint the database itself enforces.
--
-- Confirmed live against production before drafting this file:
--   select conname, pg_get_constraintdef(oid) from pg_constraint
--     where conrelid = 'public.photos'::regclass and contype = 'c';
--   -> photos_entity_type_check: CHECK ((entity_type = ANY
--      (ARRAY['hotel'::text, 'restaurant'::text])))
--
-- Proposed fix: widen the CHECK to also permit 'event', following the
-- exact same denormalization convention visit photos already use
-- (entity_type/entity_id identify the venue independently of visit_id,
-- enabling "every photo of this venue" queries without joining through
-- visits) — an event-attendance photo would be inserted with
-- entity_type='event', entity_id=<the event's own id>, attendance_id=<the
-- confirmed-attendance row's id>. entity_type/entity_id stay NOT NULL,
-- unchanged in shape; only the permitted value set widens. This is a
-- pure CHECK-widening migration — zero data risk, does not touch any
-- existing row, and does not invalidate any value already stored (every
-- existing photos row already satisfies the widened check trivially,
-- since 'hotel'/'restaurant' remain legal).
--
-- NOT applied to production by this migration file's authoring — this is
-- a proposal surfaced in the Step 4 pre-final report for human review; no
-- photo-upload UI/repository code in this step's own Dart changes writes
-- to `photos` for an event attendance, so nothing in this pass depends on
-- this migration having been deployed. Once approved and deployed, the
-- remaining Dart-side work (PhotoRepository.uploadAttendancePhoto/
-- deleteAllPhotosForAttendance, wiring an upload affordance into
-- attendance_details_sheet.dart) is a self-contained follow-up, not
-- bundled into this file.

begin;

alter table public.photos
  drop constraint photos_entity_type_check,
  add constraint photos_entity_type_check
    check (entity_type in ('hotel', 'restaurant', 'event'));

commit;
