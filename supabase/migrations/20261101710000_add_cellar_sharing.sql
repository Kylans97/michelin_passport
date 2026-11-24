-- Friends in the Cellar: one switch for the whole Cellar. Asked for by
-- the product owner on 2026-11-24 ("ik wil van mijn vrienden kunnen zien
-- wat voor wijnen zij hebben gedronken en andersom ook"), planned on the
-- review page https://claude.ai/artifact/DAqg8Aikb8T4qBkVUBx9Ra and
-- approved the same day ("let's do it for the whole cellar then someone
-- doesn't have to do that for every wine"; "oke dit kunnen we bouwen").
-- Written 2026-11-24 on claude/friends-cellar. The number is sort order,
-- not a date: it follows 20261101700000_add_undated_visits.sql, which
-- another branch holds and is not on main yet.
--
-- PREPARED -- NOT APPLIED until the product owner says yes to applying it.
--
-- 1. profiles.cellar_shared, true by default, so nothing changes for
--    anyone until they turn it off. The same shape as is_discoverable
--    (20260825160000): the member writes it on their own row under the
--    existing profiles_update policy. Purely additive: builds up to 1.9.0
--    never read it.
--
-- 2. can_see_cellar(owner): may the caller see this member's Cellar.
--    True for the member themself, or for an accepted friend whose switch
--    is on; false for everyone else, so it says nothing about strangers.
--    SECURITY DEFINER because profiles_read is owner only, so a friend
--    cannot read the switch directly. Revoked from public and anon in
--    this same migration (CLAUDE.md: Supabase grants PUBLIC execute on
--    every new function in public).
--
-- 3. cellar_wines_select (20261101640000) uses it. Wines kept without a
--    visit are the Cellar's own rows, so the switch hides them in the
--    database. visit_wines is NOT changed: a wine on a visit stays
--    exactly as visible as its visit, and a shared visit keeps showing
--    its wines (product owner: "You do see the wine someone had on a
--    particular visit"). The app leaves those out of a friend's Cellar
--    tab and of Community's "Loved by your friends" when the switch is
--    off; they remain reachable through the shared visit itself, which
--    is the member's own choice per visit.

begin;

-- ============================================================
-- 1. The switch
-- ============================================================
alter table public.profiles
  add column cellar_shared boolean not null default true;

comment on column public.profiles.cellar_shared is
  'Share my Cellar with friends. True: friends see the member''s Cellar '
  '(wines kept without a visit, and the Cellar tab). False: only the '
  'member. Wines on a visit follow that visit''s own visibility either way.';

-- ============================================================
-- 2. can_see_cellar
-- ============================================================
create function public.can_see_cellar(p_owner uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select p_owner = auth.uid()
      or (
        public.is_friend(p_owner)
        and coalesce(
          (select p.cellar_shared from public.profiles p where p.id = p_owner),
          false
        )
      );
$$;

comment on function public.can_see_cellar(uuid) is
  'True when the caller may see this member''s Cellar: themself, or an '
  'accepted friend who shares it. False for everyone else.';

revoke execute on function public.can_see_cellar(uuid) from public, anon;
grant execute on function public.can_see_cellar(uuid) to authenticated;

-- ============================================================
-- 3. Kept wines follow the switch
-- ============================================================
drop policy cellar_wines_select on public.cellar_wines;

create policy cellar_wines_select on public.cellar_wines
  for select to authenticated
  using (public.can_see_cellar(user_id));

commit;
