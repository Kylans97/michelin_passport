-- Events V2 Step 7 — Friends Interested + Friends Going + anonymous
-- Chasing Stars member Going count.
--
-- Does NOT touch RLS on event_attendance: the existing
-- event_attendance_select policy (`user_id = auth.uid() OR (visibility =
-- 'friends' AND is_friend(user_id))`) already has no reference to
-- `status` at all — re-verified live against production during the Step
-- 7 architecture audit (docs/Architecture/
-- EVENTS_V2_STEP_7_SOCIAL_SIGNALS_AUDIT.md) — so it already supports
-- friends-visible Interested rows identically to friends-visible Going
-- rows, the moment the Dart-side default (`visibilityForIntent`,
-- lib/models/event_intent.dart) writes `visibility = 'friends'` for
-- Interested. No migration is needed for that change.
--
-- Does NOT touch, modify, or reuse the existing
-- get_event_attendance_count(uuid) function (from
-- 20260815120000_social_foundation_step2b_event_attendance.sql /
-- 20260815130000_..._revoke_anon_execute.sql): that function counts
-- Interested + Going combined (it predates the Interested/Going split —
-- at authoring time `status` had only one legal value, 'going' — and was
-- never updated when the split landed) and uses a >=5-anonymity
-- threshold with no upper cap, the opposite shape from the privacy rule
-- below. Left untouched for backwards compatibility, per explicit
-- instruction; a future cleanup may decide whether to deprecate it, not
-- decided here.
--
-- This migration adds exactly one new, distinctly-named aggregate:
--
-- get_event_going_member_count(target_event_id uuid) -> integer
--
-- Counts only event_attendance rows with status = 'going' for the given
-- event — Interested rows are never counted, and visibility does NOT
-- affect inclusion (visibility governs identity disclosure, i.e. who can
-- see WHICH friend is going; it has no bearing on whether a row counts
-- toward this anonymous aggregate — both private and friends-visible
-- Going rows count).
--
-- PRIVACY CAP (the entire point of this function): the returned integer
-- is capped server-side at exactly 100, meaning "100 or more." The
-- Flutter client must never receive the true count once it reaches 100 —
-- capping in Dart would be too late, since the exact number would
-- already have left the server. `least(count(*), 100)` enforces this in
-- one line: 0 Going -> 0, 1-99 Going -> the exact number, 100+ Going ->
-- always exactly 100. The client-side contract (Events V2 Step 7): 0 is
-- never displayed, 1-99 renders as the exact number, and a returned
-- value of 100 always renders as "100+" — the client can never tell the
-- difference between exactly 100 and 5000 Going, by design.
--
-- A non-existent event_id simply yields a 0 row count -> 0, the same
-- "nothing to show" result as a real event with no Going intent — no
-- existence check, no exception, nothing for a caller to distinguish
-- (mirrors get_event_attendance_count's own equally simple, identity-
-- free shape).
--
-- Security posture copied from get_event_attendance_count exactly,
-- including the lesson its own follow-up migration learned the hard
-- way: a bare `REVOKE ... FROM PUBLIC` does NOT stop Postgres's ambient
-- default-privilege grant to the `anon` role — anon must be revoked
-- explicitly, or an unauthenticated caller could execute this function
-- despite no line of this migration ever intending that. STABLE (a pure
-- read, safe to cache within one statement), SECURITY DEFINER with a
-- hardened search_path (so it can count every Going row regardless of
-- the caller's own friendships, while still never selecting anything
-- but count(*) — no event_id/user_id/any row-level column is ever
-- selected, so there is no identity-enumeration surface here at all).

begin;

create function public.get_event_going_member_count(target_event_id uuid)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select least(count(*)::integer, 100)
  from public.event_attendance
  where event_id = target_event_id
    and status = 'going';
$$;

revoke execute on function public.get_event_going_member_count(uuid) from public;
revoke execute on function public.get_event_going_member_count(uuid) from anon;
grant  execute on function public.get_event_going_member_count(uuid) to authenticated;

commit;
