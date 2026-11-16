-- Confirmed attendance — the only source of an event Passport stamp — can
-- only be recorded for a published, uncancelled event that has ended.
--
-- Written 2026-11-16. Named after 20261101430000_harden_claims_hotels_and_
-- chefs_insert per CLAUDE.md's monotonic-sequence rule. PENDING A PRODUCT
-- DECISION: prepared, not approved. It does not depend on 20261101420000
-- or 20261101430000 and may be applied without them, or left out.
--
-- The gap: event_confirmed_attendance_insert (only definition
-- 20260819142000, confirmed live on 2026-11-16) checks only user_id =
-- auth.uid(). "Event published, ended, not cancelled" lives only in Dart
-- (lib/models/event_attendance_eligibility.dart, resolveAttendanceUiState),
-- so anyone with a member session and the public key can stamp an event
-- that hasn't happened yet, was cancelled, or was never published.
--
-- The rule mirrors the app exactly:
--   - ended = eventEndReferenceInstant (lib/core/utils/event_time.dart):
--     end_at when known, else the first instant of the day after end_date
--     in the event's own timezone. Never a fabricated clock time.
--   - published = moderation_status = 'published' (the app only lists
--     published events; the other live values are 'submitted' and
--     'rejected').
--   - not cancelled = cancelled_at is null (Event.isCancelled).
-- Only INSERT is gated. The app deliberately keeps an attendance that
-- already exists editable when the event is cancelled after the fact
-- (resolveAttendanceUiState checks hasConfirmedAttendance first), so the
-- update policy is not given the same condition.
--
-- Instead, UPDATE is narrowed to the four columns the app edits (rating,
-- comment, visibility, would_recommend — buildAttendanceDetailsUpdate).
-- Without that, a row inserted for an ended event could have its event_id
-- updated to a future one, and the insert check would mean nothing.
-- Every shipped build updates only those columns.
--
-- Not covered, on purpose: source = 'trip_completion' is in the CHECK
-- constraint but no code writes it yet (EventAttendanceSource's own doc
-- comment). Whoever builds trip completion inherits this rule, which is
-- the point. The one-day-widened windows in events_repository.dart are a
-- list-query optimisation, not an eligibility rule, and do not apply here.
--
-- What could break: a member whose phone clock runs ahead sees "I attended
-- this" a little before the event's end and gets an error instead of a
-- stamp. The app turns any insert error into its existing error message.
--
-- Production on 2026-11-16: event_confirmed_attendance has zero rows.

begin;

drop policy event_confirmed_attendance_insert on public.event_confirmed_attendance;
create policy event_confirmed_attendance_insert on public.event_confirmed_attendance
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and exists (
      select 1
      from public.events e
      where e.id = event_id
        and e.moderation_status = 'published'
        and e.cancelled_at is null
        and coalesce(
          e.end_at,
          ((e.end_date + 1)::timestamp at time zone e.timezone)
        ) <= now()
    )
  );

revoke update on public.event_confirmed_attendance from authenticated;
grant update (rating, comment, visibility, would_recommend)
  on public.event_confirmed_attendance to authenticated;

commit;
