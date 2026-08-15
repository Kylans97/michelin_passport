begin;

-- Social Foundation Step 2B follow-up: tighten EXECUTE grant.
--
-- The prior migration's own REVOKE only ever targeted PUBLIC, never anon
-- specifically — the identical root cause already found and fixed for
-- Step 1's RPCs (see 20260813130000_social_foundation_step1_revoke_anon_execute.sql
-- and its own report). This project's schema-level default privileges
-- auto-grant EXECUTE to anon the moment any new function is created,
-- independent of any REVOKE ... FROM PUBLIC — anon is a real role, not an
-- alias for PUBLIC. Confirmed via live production ACL inspection
-- (pg_proc.proacl) immediately after deploying the prior migration:
-- get_event_attendance_count carried an unintended anon=X grant.
--
-- Unlike the table-level GRANT on event_attendance itself (also ambiently
-- anon-granted, but harmless because every RLS policy on that table is
-- scoped `to authenticated` only, so anon sees zero rows regardless —
-- verified directly against production), this one is not merely cosmetic:
-- get_event_attendance_count has no internal auth.uid() check at all (it
-- was never meant to require one — the aggregate count is designed to be
-- identity-free and threshold-gated), so an anon caller genuinely could
-- execute it successfully today. The count it returns is safe by design
-- (never row-level data, NULL below the 5-unique-attendee threshold), but
-- granting anon access was never the intent this migration's own header
-- comment documented ("grant execute ... to authenticated"), and this
-- task's own explicit instruction is not to grant anon merely by
-- accident. Revoking it now costs nothing — the RPC is not called from
-- anywhere in the Flutter app in this step regardless.

revoke execute on function public.get_event_attendance_count(uuid) from anon;

commit;
