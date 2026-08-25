-- PROFILE PRIVACY & DISCOVERABILITY V1
--
-- Splits "can another member find my basic identity through Find
-- Friends" (NEW: profiles.is_discoverable) from "is my content public"
-- (unchanged: friendship status + the existing per-table visibility
-- columns on visits/photos/event_attendance/event_confirmed_attendance,
-- and wishlist's own unconditional friends-only rule). Nothing in this
-- migration touches visits/wishlist/photos/event_attendance/
-- event_confirmed_attendance/planned_trips/planned_venues/friendships'
-- structure/rankings/storage/auth — see the Pre-Apply Report for the
-- full audit this migration implements.
--
-- ============================================================
-- 1. New column — same default for BOTH existing and new users.
-- ============================================================
--
-- Find Friends is an intentional core member feature; the information a
-- discoverable profile exposes is limited to basic identity (username/
-- display_name/avatar_url) and only ever reachable by an authenticated
-- Chasing Stars member — never anon, never activity/content. Defaulting
-- to true (rather than requiring opt-in) preserves the feature's
-- day-one usefulness and matches today's existing de facto behavior
-- (every profile is currently unconditionally discoverable, with zero
-- toggle ever having existed) — existing users see no change, new users
-- get a working Find Friends immediately, and anyone who wants out has
-- an explicit, real Settings toggle from day one.

alter table public.profiles
  add column is_discoverable boolean not null default true;

comment on column public.profiles.is_discoverable is
  'Whether another authenticated Chasing Stars member can discover this '
  'profile''s basic identity (username/display_name/avatar_url) through '
  'Find Friends search. Governs discovery ONLY — visits, ratings, '
  'photos, wishlist, Trips, event activity and Community Rankings are '
  'entirely unaffected and remain governed by friendship status and '
  'their own existing visibility rules. An existing accepted friendship '
  'or a pending request still resolves identity through '
  'get_profile_identity()/search_profiles() regardless of this flag — '
  'turning it off only stops NEW, unrelated members from finding you.';

comment on column public.profiles.is_public is
  'DEPRECATED for discovery purposes as of Profile Privacy & '
  'Discoverability V1 (see is_discoverable). No longer read by '
  'profiles_read, search_profiles(), or get_profile_identity(). '
  'Retained only to avoid a destructive column drop — do not add new '
  'logic depending on this column.';

-- ============================================================
-- 2. profiles_read — narrow to authenticated owner-only.
-- ============================================================
--
-- No current app code path depends on the broader grant: the only
-- direct `.from('profiles')` read in the Flutter app (ProfileRepository.
-- getProfile) is always called with the caller's own id, and every
-- cross-user identity read already goes through a SECURITY DEFINER RPC
-- (get_friends/get_incoming_friend_requests/get_outgoing_friend_requests/
-- get_profile_identity/search_profiles) that bypasses this policy
-- entirely — see the Pre-Apply Report's full call-site audit. Removing
-- `anon` and the `is_public OR` branch here closes previously-unused
-- attack surface without changing any real feature's behavior.

drop policy profiles_read on public.profiles;

create policy profiles_read on public.profiles
  for select to authenticated
  using (id = auth.uid());

-- ============================================================
-- 3. search_profiles() — corrected relationship-state logic.
-- ============================================================
--
-- A result may appear when EITHER:
--   (a) the target is discoverable (is_discoverable = true), OR
--   (b) an ACCEPTED or PENDING relationship already exists between the
--       caller and the target (in either direction) — so an existing
--       friend or an outstanding request never silently disappears
--       from search just because the other person later opts out of
--       discovery.
-- DECLINED does NOT count as (b) — a stale declined row must never
-- resurrect discoverability for someone who has since opted out.
-- BLOCKED is excluded unconditionally, exactly as before, regardless of
-- (a) or (b) — a blocked-either-direction pair never appears to each
-- other through this function, full stop.
--
-- CREATE OR REPLACE preserves the function's existing OID and ACL
-- (grants) as long as the signature (name + argument types) is
-- unchanged, which it is here — no separate revoke/grant statements are
-- needed to keep `execute` scoped to `authenticated` only; Postgres
-- carries the prior grant forward automatically. Re-stated explicitly
-- below anyway, defensively, so this migration is correct even if that
-- were ever not true.

create or replace function public.search_profiles(query text)
returns table (
  id uuid,
  username text,
  display_name text,
  avatar_url text,
  relationship_status text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.id,
    p.username,
    p.display_name,
    p.avatar_url,
    case
      when f.status is null then null
      when f.status = 'accepted' then 'accepted'
      when f.status = 'pending' and f.requester_id = auth.uid() then 'pending_sent'
      when f.status = 'pending' and f.addressee_id = auth.uid() then 'pending_received'
      when f.status = 'declined' then 'declined'
      else null
    end
  from public.profiles p
  left join public.friendships f
    on (f.requester_id = auth.uid() and f.addressee_id = p.id)
    or (f.addressee_id = auth.uid() and f.requester_id = p.id)
  where auth.uid() is not null
    and p.id <> auth.uid()
    and p.username is not null
    and char_length(trim(query)) >= 2
    and p.username ilike (trim(query) || '%')
    and (f.status is null or f.status <> 'blocked')
    and (p.is_discoverable or f.status in ('accepted', 'pending'))
  order by p.username
  limit 20;
$$;

revoke execute on function public.search_profiles(text) from public;
grant  execute on function public.search_profiles(text) to authenticated;

-- ============================================================
-- 4. get_profile_identity() — same corrected relationship-state logic.
-- ============================================================

create or replace function public.get_profile_identity(target_user_id uuid)
returns table (
  id uuid,
  username text,
  display_name text,
  avatar_url text,
  relationship_status text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.id,
    p.username,
    p.display_name,
    p.avatar_url,
    case
      when f.status is null then null
      when f.status = 'accepted' then 'accepted'
      when f.status = 'pending' and f.requester_id = auth.uid() then 'pending_sent'
      when f.status = 'pending' and f.addressee_id = auth.uid() then 'pending_received'
      when f.status = 'declined' then 'declined'
      else null -- 'blocked' rows never surface a relationship state here
    end
  from public.profiles p
  left join public.friendships f
    on (f.requester_id = auth.uid() and f.addressee_id = p.id)
    or (f.addressee_id = auth.uid() and f.requester_id = p.id)
  where auth.uid() is not null
    and p.id = target_user_id
    and (f.status is null or f.status <> 'blocked')
    and (p.is_discoverable or f.status in ('accepted', 'pending'))
$$;

revoke execute on function public.get_profile_identity(uuid) from public;
grant  execute on function public.get_profile_identity(uuid) to authenticated;
