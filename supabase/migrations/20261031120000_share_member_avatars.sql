-- Member profile photos visible to the people who can already see that
-- member's identity — friends, people with a pending request either way,
-- and anyone who can find a discoverable member in search.
--
-- Written 2026-10-31 for 1.5.1 (19). NOT YET APPLIED — prepared for
-- review; apply with `supabase db push --linked` once the product owner
-- approves. Named after 20261030180000_add_country_to_rankings.sql, the
-- highest migration on any branch when this was written.
--
-- Until now a profile photo (`profiles.avatar_path`, private bucket
-- `profile-photos`) was readable by its owner only: 20260825170000 chose
-- owner-only storage reads on purpose and deferred cross-account display
-- to "whichever future pass actually wires avatar display into
-- Friends/Community-facing surfaces" (PROFILE_AVATAR_V1.md, "Storage read
-- visibility"). This is that pass, asked for by the product owner
-- ("ik wil de profiel foto van vrienden kunnen zien, en bij zoeken de
-- foto met de username").
--
-- The rule is the identity rule search_profiles already applies
-- (20260923130000), not a new one: a photo is part of the minimal
-- identity (username, display name, photo) that
-- FRIENDS_PRIVACY_COMMUNITY_INTELLIGENCE.md §3.5 treats as phonebook-level
-- information. A viewer may see member X's photo when
--   - X is the viewer, or
--   - no block exists between them, AND (X is discoverable, OR they are
--     friends, OR a request is pending either way).
-- A non-discoverable member's photo stays hidden from strangers, a
-- declined request reveals nothing new, and a block hides it both ways.
--
-- 1. can_view_member_avatar(owner): that rule, once. SECURITY DEFINER so
--    it can read profiles/friendships whatever their own RLS says.
-- 2. get_member_avatar_paths(user_ids): the storage path of each listed
--    member's current photo the caller may see — the client signs the
--    URLs itself. A new RPC rather than changing get_friends /
--    search_profiles / get_profile_identity / the request RPCs, so build
--    1.5.0 (18), which reads those, is untouched; they keep returning the
--    never-populated avatar_url.
-- 3. A storage SELECT policy on the bucket that allows exactly the
--    current photo (profiles.avatar_path) of a member the caller may see,
--    through can_view_member_avatar_object(name).
--    RLS policies OR together, so the owner-only policy stays as it is;
--    a superseded upload (normally deleted on replace) is never covered.
--
-- All three functions get `revoke execute ... from public, anon` here, per
-- CLAUDE.md; verify with has_function_privilege after applying.

-- ============================================================
-- 1. can_view_member_avatar
-- ============================================================

create function public.can_view_member_avatar(p_owner uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select auth.uid() is not null
    and (
      p_owner = auth.uid()
      or exists (
        select 1
        from public.profiles p
        left join public.friendships f
          on (f.requester_id = auth.uid() and f.addressee_id = p.id)
          or (f.addressee_id = auth.uid() and f.requester_id = p.id)
        where p.id = p_owner
          and (f.status is null or f.status <> 'blocked')
          and (p.is_discoverable or f.status in ('accepted', 'pending'))
      )
    );
$$;

revoke execute on function public.can_view_member_avatar(uuid) from public, anon;
grant execute on function public.can_view_member_avatar(uuid) to authenticated;

-- ============================================================
-- 2. get_member_avatar_paths
-- ============================================================

create function public.get_member_avatar_paths(p_user_ids uuid[])
returns table (user_id uuid, avatar_path text)
language sql
stable
security definer
set search_path = public
as $$
  select p.id, p.avatar_path
  from public.profiles p
  where p.id = any(p_user_ids)
    and p.avatar_path is not null
    and public.can_view_member_avatar(p.id);
$$;

revoke execute on function public.get_member_avatar_paths(uuid[]) from public, anon;
grant execute on function public.get_member_avatar_paths(uuid[]) to authenticated;

-- ============================================================
-- 3. storage read policy
-- ============================================================
--
-- The policy runs as the caller, who cannot read another member's
-- profiles row under profiles RLS — so the "is this object someone's
-- current photo, and may I see them" lookup is one more SECURITY DEFINER
-- helper rather than an inline join.

create function public.can_view_member_avatar_object(p_object_name text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.avatar_path = p_object_name
      and public.can_view_member_avatar(p.id)
  );
$$;

revoke execute on function public.can_view_member_avatar_object(text) from public, anon;
grant execute on function public.can_view_member_avatar_object(text) to authenticated;

create policy profile_photos_read_visible_members on storage.objects
  for select to authenticated
  using (
    bucket_id = 'profile-photos'
    and public.can_view_member_avatar_object(name)
  );
