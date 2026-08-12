begin;

-- Social Foundation Step 1 follow-up: tighten EXECUTE grants.
--
-- The prior migration's own GRANT/REVOKE block only ever revoked EXECUTE
-- FROM public, never FROM anon specifically. This project's schema-level
-- default privileges (ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL
-- ON FUNCTIONS TO ...) grant EXECUTE to anon automatically the moment any
-- new function is created, independent of any REVOKE ... FROM PUBLIC —
-- anon is a real role, not an alias for PUBLIC. Confirmed via live
-- production ACL inspection (pg_proc.proacl) immediately after deploying
-- the prior migration: every one of these ten functions carried an
-- unintended anon=X grant.
--
-- Every affected function already guards against auth.uid() being null
-- (an explicit `raise exception 'Not authenticated'`, or a WHERE clause
-- that structurally matches zero rows when auth.uid() is null) — so this
-- was not an exploitable data/mutation leak, only a least-privilege
-- deviation from the documented design ("anon" was only ever meant to be
-- granted on username_available, the one RPC that must work pre-signup).
-- This closes that gap explicitly rather than relying on defense-in-depth
-- alone.

revoke execute on function public.is_friend(uuid) from anon;
revoke execute on function public.send_friend_request(uuid) from anon;
revoke execute on function public.accept_friend_request(uuid) from anon;
revoke execute on function public.decline_friend_request(uuid) from anon;
revoke execute on function public.block_user(uuid) from anon;
revoke execute on function public.get_friends() from anon;
revoke execute on function public.get_incoming_friend_requests() from anon;
revoke execute on function public.get_outgoing_friend_requests() from anon;
revoke execute on function public.get_profile_identity(uuid) from anon;
revoke execute on function public.search_profiles(text) from anon;

commit;
