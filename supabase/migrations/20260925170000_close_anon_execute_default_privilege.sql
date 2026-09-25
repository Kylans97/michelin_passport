begin;

-- ============================================================
-- This is the FOURTH time this exact class of gap has been touched in
-- this schema's history — read this before assuming it's finally closed
-- for good, because it isn't, fully:
--
--   1. 20260813130000_social_foundation_step1_revoke_anon_execute.sql
--      — 10 functions, first discovery (documented in that migration's
--      own header: this project auto-grants EXECUTE to anon on every new
--      function, independent of any `REVOKE ... FROM PUBLIC` — anon is a
--      real role, not an alias for PUBLIC).
--   2. 20260815130000_social_foundation_step2b_revoke_anon_execute.sql
--      — 1 more function, same root cause, cross-referenced back to #1.
--   3. 20260925140000_add_venue_invites.sql /
--      20260925160000_add_venue_id_to_get_notifications.sql — 4 more
--      functions, same root cause again, found independently a third
--      time during this session's own rollback-transaction validation.
--
-- All three treated the symptom (revoke on whichever functions happened
-- to be in scope that day), never the cause. Proof this isn't
-- hypothetical: get_profile_identity(uuid) was explicitly closed by #1 on
-- 2026-08-13, then silently reopened when
-- 20260925130000_add_member_number_to_profile_identity.sql dropped and
-- recreated it — that migration's own `revoke execute ... from public`
-- line repeats, verbatim, the exact mistake #1's own header already
-- warned about.
--
-- ============================================================
-- IMPORTANT — READ BEFORE TRUSTING §1 BELOW:
-- §1 does NOT close the source for functions the way
-- 20260918130000_revoke_anon_defaults_on_private_tables.sql's identical-
-- looking statement closed it for TABLES. Tested directly, not assumed:
-- inside a rolled-back transaction, `alter default privileges for role
-- postgres in schema public revoke execute on functions from public,
-- anon` followed by a brand-new `create function public.__probe(...)`
-- still leaves that new function EXECUTE-able by anon (confirmed via
-- `has_function_privilege('anon', ..., 'EXECUTE')` returning true, and
-- via the function's raw `proacl` still carrying a bare `=X` PUBLIC
-- entry). Tables have no built-in "PUBLIC gets access" default in
-- Postgres, so revoking the one custom grant was sufficient; functions
-- do carry a built-in PUBLIC-execute default that this project's ALTER
-- DEFAULT PRIVILEGES statement does not override here, for reasons not
-- fully root-caused (a second, separate `defaclrole = supabase_admin`
-- default-ACL entry for the same (public, function) slot also grants
-- anon, and `postgres` gets "permission denied to change default
-- privileges" attempting to touch it — plausibly related, not confirmed
-- as the sole cause).
--
-- Practical consequence: THIS MIGRATION ONLY CLEARS THE KNOWN BACKLOG
-- (§2). It does not prevent a fifth occurrence by itself. Every future
-- `SECURITY DEFINER` function still needs its own explicit
-- `revoke execute on function ... from public, anon;` written in the
-- SAME migration that creates it — see CLAUDE.md's Security and
-- infrastructure section, updated alongside this migration specifically
-- so this requirement lives somewhere every future migration-writing
-- session actually reads, not only here.
-- ============================================================

-- 1. Kept anyway — not a no-op: it removes anon's and PUBLIC's NAMED
--    entries from this project's own custom default-ACL row for
--    (postgres, public, functions), which is real state even though it
--    doesn't change what a brand-new function gets (see above). Scoped
--    to anon/public only — authenticated/service_role untouched.
alter default privileges for role postgres in schema public
  revoke execute on functions from public, anon;

-- ============================================================
-- 2. Clear the existing backlog — every public-schema, non-extension
--    function anon could execute as of this migration, confirmed live
--    (has_function_privilege('anon', oid, 'EXECUTE') = true for all of
--    the below, PostGIS's own ~1000 extension-owned functions excluded
--    throughout). Grouped by why each was open, not just dumped as one
--    flat list, so the next person can see which bucket a function they
--    care about falls in.
-- ============================================================

-- Every statement below revokes from `public` as well as `anon` —
-- confirmed necessary by validation, not just for symmetry: a handful of
-- these (§2b/§2c) were plain `create function` with no grant/revoke
-- management in their origin migrations at all, so PUBLIC's own built-in
-- default EXECUTE grant (which every role, including anon, inherits
-- automatically) was never revoked for them. `revoke ... from anon`
-- alone is a no-op against a still-standing PUBLIC grant — Postgres ACL
-- semantics don't let a per-role revoke override a PUBLIC-wide one; only
-- revoking PUBLIC's own grant actually removes it for every role that
-- was inheriting through it.

-- 2a. Real gaps — auth.uid()-scoped, so anon calling any of these today
-- returns an empty/false/zero result (harmless in practice), but every
-- one contradicts a migration that explicitly meant to restrict it:
-- get_profile_identity (closed once already, see header), the siblings
-- of already-fixed functions that were simply missed
-- (get_unread_notification_count next to get_notifications,
-- get_blocked_users next to get_friends/get_incoming_friend_requests),
-- and has_approved_venue_claim (its own 20260828120000 migration
-- explicitly granted `to authenticated` only, no anon intended at all).
revoke execute on function public.get_profile_identity(uuid) from public, anon;
revoke execute on function public.get_unread_notification_count() from public, anon;
revoke execute on function public.get_blocked_users() from public, anon;
revoke execute on function public.has_approved_venue_claim(text, uuid) from public, anon;

-- 2b. Trigger functions — RETURNS trigger, so Postgres refuses to
-- execute any of these outside real trigger context regardless of
-- caller (confirmed per-function via pg_proc.prorettype = 'trigger').
-- Zero practical exposure either way; revoked anyway because a
-- consistent "anon has nothing in public it wasn't explicitly given" is
-- easier to audit than a list of exceptions relying on this exact
-- Postgres behavior to stay a safe list forever.
revoke execute on function public.enforce_hotel_photo_limit() from public, anon;
revoke execute on function public.enforce_photo_duplicate_check() from public, anon;
revoke execute on function public.enforce_photo_submission_replacement() from public, anon;
revoke execute on function public.enforce_private_chef_photo_limit() from public, anon;
revoke execute on function public.enforce_restaurant_photo_limit() from public, anon;
revoke execute on function public.handle_new_user() from public, anon;
revoke execute on function public.notify_friendship_change() from public, anon;
revoke execute on function public.notify_venue_invite_change() from public, anon;
revoke execute on function public.prevent_member_number_change() from public, anon;
revoke execute on function public.set_updated_at() from public, anon;
revoke execute on function public.validate_event_timezone() from public, anon;
revoke execute on function public.check_username_not_blocked() from public, anon;

-- 2c. Pure constant/threshold functions — hardcoded numeric returns
-- (`select 5`, `select 10`), IMMUTABLE, not even SECURITY DEFINER, no
-- table access at all. Zero data exposure regardless of grantee; revoked
-- for the same "consistent stand, not a list of exceptions" reason as §2b.
revoke execute on function public.news_article_open_min_unique_users() from public, anon;
revoke execute on function public.venue_link_click_min_unique_users() from public, anon;
revoke execute on function public.venue_photo_duplicate_hamming_threshold() from public, anon;
revoke execute on function public.venue_ranking_bayesian_m() from public, anon;
revoke execute on function public.venue_ranking_min_reviews() from public, anon;

-- 2d. profile_is_visible(uuid) — genuinely orphaned, not a live
-- dependency. Its origin migration (20260805141519) granted it to
-- `anon, authenticated` because visits_read/wishlist_read/photos_read
-- called it from their own USING clauses at the time. That stopped being
-- true on 2026-08-14:
-- 20260814120000_social_foundation_step2_visit_visibility.sql rewired
-- all three policies onto is_friend()-based friends-visibility instead,
-- and its own header says so explicitly ("profile_is_visible() has zero
-- remaining callers among RLS policies... removal is a later,
-- independent cleanup, not required for correctness"). Confirmed live
-- before writing this line, not assumed from that comment alone: zero
-- rows in `select * from pg_policies where qual ilike
-- '%profile_is_visible%'`, and no reference anywhere in lib/. Folded
-- into the ordinary backlog rather than kept as a third named exception
-- — a function nothing calls doesn't need a standing carve-out to
-- remember, and if a future policy genuinely needs it again, the missing
-- grant will surface immediately as a real error, the same way
-- get_profile_identity's own regression did.
revoke execute on function public.profile_is_visible(uuid) from public, anon;

-- ============================================================
-- 3. Deliberately NOT touched — username_available is the one function
--    in this schema whose anon EXECUTE grant is a real, currently-used
--    dependency, not a leftover default: the signup form calls it before
--    an account/session exists, so it must work signed out. Explicitly
--    granted `to anon, authenticated` in its origin migration
--    (20260813120000_social_foundation_step1_username_friendships.sql),
--    confirmed still called today from
--    lib/data/repositories/profile_repository.dart.
-- ============================================================

comment on function public.username_available(text) is
  'Deliberately EXECUTE-granted to anon (origin: 20260813120000) -- the '
  'signup form calls this before an account/session exists, so it must '
  'work signed out. Not a default-privilege leftover -- see '
  '20260925170000''s own header before revoking this one.';

commit;
