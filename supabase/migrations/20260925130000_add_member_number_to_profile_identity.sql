-- Extends get_profile_identity() to also return member_number, so a
-- friend's Passport booklet (read-only, reusing the same booklet UI as
-- the current user's own) can show their real member number instead of
-- the honest "—" fallback that column's own nullability already renders.
--
-- profiles_read RLS is owner-only (20260825160000_profile_privacy_
-- discoverability_v1.sql) — a friend can never read another user's
-- profiles row directly, member_number included. This SECURITY DEFINER
-- RPC is the only surface that already exposes identity fields across
-- users at all; member_number joins the same curated column list
-- (id/username/display_name/avatar_url/relationship_status) rather than
-- opening a new access path. Every other clause (the relationship-status
-- case, the friendship join, the discoverability/blocked filtering) is
-- untouched — copied verbatim from that migration's own current
-- definition, plus the one new column.
--
-- search_profiles() is deliberately NOT touched here — nothing asked for
-- a member number in search results, and ProfileIdentity.fromRow (the one
-- Dart factory both RPCs funnel through) already treats a missing
-- member_number key as null, so search_profiles' results are unaffected
-- either way.

-- Postgres refuses `create or replace` when the OUT-parameter row shape
-- itself changes ("cannot change return type of existing function") —
-- confirmed by actually trying it against the live database before
-- writing this workaround, not assumed. The function must be dropped and
-- recreated; nothing else about the drop/recreate changes its behavior,
-- since the grant below re-applies the same authenticated-only access
-- immediately after.
drop function if exists public.get_profile_identity(uuid);

create function public.get_profile_identity(target_user_id uuid)
returns table (
  id uuid,
  username text,
  display_name text,
  avatar_url text,
  relationship_status text,
  member_number integer
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
    end,
    p.member_number
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
