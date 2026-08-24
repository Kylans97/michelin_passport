-- Community Rankings Backend V1 — `restaurant_rankings`.
--
-- `RankingsRepository.getCommunityRankings()` (lib/data/repositories/
-- rankings_repository.dart) has queried this view since it was written,
-- but the view itself was never created — confirmed via a live,
-- read-only pg_constraint/information_schema audit and a full git-history
-- search of this migrations directory (neither found any prior
-- definition, ever). This is the first time it exists. Both Community's
-- "Hottest Places" hero and the Community Rankings screen depend on it;
-- until now both silently showed nothing (Hottest Places hides itself
-- gracefully; Community Rankings shows "No community data yet") because
-- the underlying query failed with `42P01: relation "restaurant_rankings"
-- does not exist`.
--
-- SOURCE FIELD: `visits.rating` (smallint, CHECK 1-10) is the correct
-- "overall rating" — confirmed via pg_constraint (`visits_rating_check`),
-- distinct from the independent, nullable sub-ratings (food/service/wine/
-- value/room/experience). `visits` has no formal FK to restaurants
-- (`entity_type`/`entity_id` is a polymorphic, unconstrained pointer into
-- either `restaurants` or `hotels`), so this view joins
-- `entity_id = restaurants_full.id` filtered `entity_type = 'restaurant'`.
--
-- ONE RATING PER USER PER RESTAURANT: `DISTINCT ON (user_id, entity_id)`
-- ordered by `visited_on DESC, id DESC` picks each user's single most
-- recent valid rating for a given restaurant. Live production data has
-- zero users with more than one visit to the same restaurant today, but
-- nothing in the schema prevents it (no unique constraint on
-- `(user_id, entity_id)`), so this is a defensive design choice, not a
-- reaction to an observed problem — a single frequent visitor must never
-- be able to contribute multiple ratings and dominate the average.
--
-- MINIMUM THRESHOLD: `HAVING COUNT(*) >= 3` unique raters. Chosen (not
-- assumed) after a full read-only production distribution audit: as of
-- this migration, exactly ONE restaurant (Parkheuvel) has any rating at
-- all, from exactly one rater — every threshold from 2 upward currently
-- yields zero qualifying restaurants. Both "Hottest Places" and Community
-- Rankings already handle an empty result gracefully (see
-- community_screen.dart / community_rankings_tab.dart) — this view will
-- start returning real rows the moment genuine community usage crosses
-- the threshold, with no further backend change required. A threshold of
-- 1 was explicitly considered and explicitly rejected: this project's own
-- rule is that a single rating must never be presented with the
-- authority of a community consensus (docs/Architecture/
-- COMMUNITY_RANKINGS_V1.md documents the full threshold-distribution
-- analysis this decision was based on).
--
-- ELIGIBILITY: only `restaurants_full.status = 'open'` restaurants are
-- exposed — closed/non-canonical restaurants never appear even if they
-- have historical ratings. `restaurants_full` itself (security_invoker,
-- established pattern) supplies name/city/flag/stars so this view doesn't
-- re-derive the cities/countries joins independently.
--
-- SORT ORDER: community_rating DESC, then total_visits DESC (more
-- community evidence wins ties), then name ASC (deterministic fallback).
-- Never Michelin stars/World's 50 Best/Gault&Millau — this ranking must
-- reflect the community's own opinion, never external guide prestige.
--
-- PRIVACY / SECURITY: `visits` RLS (`visits_read`) restricts SELECT to
-- the owning user or accepted friends with visibility='friends' — never
-- anonymous, never public, never in aggregate to strangers. This view is
-- deliberately NOT `security_invoker = true` (unlike restaurants_full,
-- which can safely use invoker semantics because its own base table is
-- fully public) — it needs definer semantics to legitimately aggregate
-- across every user's private visit rows while exposing ONLY the
-- resulting restaurant-level average and count. No user id, profile id,
-- visit id, or individual rating is ever selected by this view — the
-- output is restaurant-level aggregate data only, structurally incapable
-- of exposing which specific user(s) rated a restaurant or what any
-- individual rating was. Explicit grants only (no reliance on ambient
-- default privileges): SELECT to anon and authenticated, matching the
-- same public-discovery access `restaurants_full` already has, since
-- this is public community-discovery data, not private user data.
--
-- COLUMNS: intentionally match the shape
-- `RankingsRepository.getCommunityRankings()` /
-- `CommunityRankingEntry.fromJson` already expect (no Flutter code
-- change needed): restaurant_id, name, city, country_flag,
-- michelin_stars, community_rating, total_visits. `total_visits` here
-- means "unique community raters contributing to the average," not a raw
-- count of visit rows — this was the field's pre-existing name in the
-- already-shipped Dart model; renaming it would be an unrelated,
-- unnecessary Flutter change for a purely cosmetic SQL naming
-- preference, so the existing name was kept and is documented here
-- instead (see also docs/Architecture/COMMUNITY_RANKINGS_V1.md).
--
-- No year filtering, no historical snapshots: this represents the
-- current aggregated community opinion and naturally reflects rating
-- edits/deletions as they happen, by construction (a plain view, not a
-- materialized one — this dataset is far too small to need one, and a
-- materialized view would need manual refresh scheduling for no current
-- benefit).

begin;

create view public.restaurant_rankings
with (security_invoker = false)
as
with per_user_rating as (
  select distinct on (v.user_id, v.entity_id)
    v.entity_id as restaurant_id,
    v.rating
  from public.visits v
  where v.entity_type = 'restaurant'
    and v.rating is not null
  order by v.user_id, v.entity_id, v.visited_on desc, v.id desc
),
aggregated as (
  select
    restaurant_id,
    round(avg(rating)::numeric, 2) as community_rating,
    count(*)::integer as total_visits
  from per_user_rating
  group by restaurant_id
  having count(*) >= 3
)
select
  rf.id as restaurant_id,
  rf.name,
  rf.city_name as city,
  rf.flag_emoji as country_flag,
  rf.michelin_stars,
  a.community_rating,
  a.total_visits
from aggregated a
join public.restaurants_full rf on rf.id = a.restaurant_id
where rf.status = 'open'
order by a.community_rating desc, a.total_visits desc, rf.name asc;

revoke all on public.restaurant_rankings from public;
revoke all on public.restaurant_rankings from anon;
revoke all on public.restaurant_rankings from authenticated;
grant select on public.restaurant_rankings to anon;
grant select on public.restaurant_rankings to authenticated;

commit;
