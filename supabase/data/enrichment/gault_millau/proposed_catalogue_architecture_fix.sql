-- PREPARED — NOT APPLIED. Sketch only, for review alongside
-- docs/Architecture/Michelin_Database/GAULT_MILLAU_CATALOGUE_ARCHITECTURE_REVIEW.md.
-- Do not run against any database, local or remote, until reviewed. No
-- supabase db push. No production connection. Not part of the Gault&Millau
-- migration (20260811120000_create_gault_millau_awards.sql), which stays
-- deliberately restaurants-table-agnostic — this file is the two small,
-- independent, additive changes that review's §6 found missing on the
-- EXISTING public.restaurants / public.restaurants_full objects.
--
-- Two independent concerns, written as two sections so they can be applied,
-- reviewed, or reverted separately if wanted. Both are additive: no column
-- is dropped, no existing row's stored value changes, no existing Flutter
-- code path breaks by this SQL alone (the Flutter change that CONSUMES
-- section 2's new column is a separate, later, explicitly-approved step —
-- see the review doc's §21).

-- ============================================================
-- 1. Widen restaurants.inclusion_reason to permit 'gault_millau'
-- ============================================================
--
-- Unblocks the literal Gault&Millau production-readiness blocker: a
-- restaurant whose ONLY current recognition is Gault&Millau cannot be
-- inserted today (inclusion_reason is NOT NULL with a closed 4-value
-- CHECK: michelin_star / worlds_50_best / hall_of_fame / bib_gourmand).
--
-- Deliberately NOT adding 'chasing_stars_editorial' in this same
-- migration: no editorial feature exists yet, nothing would ever write
-- that value today, and widening a text CHECK constraint later is exactly
-- as cheap as widening it now (an ALTER TABLE ... DROP/ADD CONSTRAINT,
-- seconds of work, no data migration) — so there is no "lock-in" cost to
-- waiting until the editorial feature is actually being built. See review
-- doc §11/§18.
--
-- Semantics, unchanged from today, made explicit: inclusion_reason
-- records the PRIMARY reason THIS ROW WAS ORIGINALLY CREATED — a single,
-- historical, write-once-in-practice fact — never a live summary of every
-- source that currently recognizes the restaurant. A restaurant inserted
-- because Gault&Millau recognized it, that later also earns a Michelin
-- star, keeps inclusion_reason = 'gault_millau' forever; its current
-- Michelin recognition lives in restaurants.michelin_stars / award_history
-- instead, exactly as a restaurant originally catalogued for a Michelin
-- star that later also makes the Gault&Millau guide keeps
-- inclusion_reason = 'michelin_star' forever, with its G&M recognition
-- living in gault_millau_awards. This was already implicitly true for the
-- 4 existing values (see the review doc §1: "records the primary reason
-- the row exists, not the complete set") — this migration does not change
-- that meaning, only widens the permitted vocabulary.
alter table public.restaurants
  drop constraint inclusion_reason_valid;

alter table public.restaurants
  add constraint inclusion_reason_valid
    check (inclusion_reason in ('michelin_star', 'worlds_50_best',
                                 'hall_of_fame', 'bib_gourmand',
                                 'gault_millau'));

-- ============================================================
-- 2. Fix Hall of Fame derivation on restaurants_full (bug fix)
-- ============================================================
--
-- Found during this review, not something this review was looking for:
-- inclusion_reason currently has ZERO rows with the value 'hall_of_fame'
-- in the catalogue mirror this review queried (774 restaurants; the
-- distribution is exactly {michelin_star: 767, worlds_50_best: 7} — no
-- hall_of_fame, no bib_gourmand at all). All 6 real Hall of Fame members
-- (found via worlds_50_best.list_type = 'hall_of_fame': Disfrutar, El
-- Celler de Can Roca, Eleven Madison Park, Geranium, Osteria Francescana,
-- The French Laundry) carry inclusion_reason = 'michelin_star' instead,
-- because scripts/import_catalogue.py's insert_restaurants() computes
-- inclusion_reason as "michelin_star if michelin_stars is not None else
-- worlds_50_best" — a two-branch expression that can never produce
-- 'hall_of_fame', and no other code path in that script writes it either
-- (insert_hall_of_fame() only ever writes to worlds_50_best, correctly).
--
-- Consequence: Restaurant.isHallOfFame (lib/models/restaurant.dart:83,
-- `inclusionReason == 'hall_of_fame'`) currently returns false for every
-- real Hall of Fame restaurant, so the Hall of Fame badge
-- (restaurant_awards_card.dart) and the Explore "Hall of Fame" filter
-- (restaurant_repository.dart:85, hallOfFameOnly) are silently
-- non-functional for real data today — exactly the failure mode
-- docs/Architecture/Michelin_Database/ENGINEERING_REVIEW.md's finding M1
-- warned about ("a filter that returns wrong rows"), now confirmed to
-- have actually happened. This was found in the local dev catalogue
-- mirror, seeded by this exact deterministic import script — not
-- independently re-verified against a live production connection, which
-- this review does not make, but the same bug is expected there too since
-- the logic is identical and deterministic.
--
-- Fix: stop deriving Hall of Fame membership from inclusion_reason at
-- all. Derive it the same way worlds_50_best_rank already is two lines
-- below in this same view -- from the fact table itself, which is always
-- correct because insert_hall_of_fame() writes it correctly. Purely
-- additive: one new column, nothing removed, nothing renamed, every
-- existing restaurants_full consumer keeps working unchanged until it
-- deliberately opts in.
create or replace view public.restaurants_full
  with (security_invoker = true)
  as
select
  r.*,
  (hr.id is not null or r.property_name is not null) as is_in_hotel,
  coalesce(h.name, r.property_name)                  as hotel_name,
  h.id                                                as hotel_id,
  ci.name                                             as city_name,
  ci.region                                           as region,
  co.name                                             as country_name,
  co.flag_emoji                                       as flag_emoji,
  w.rank                                              as worlds_50_best_rank,
  exists (
    select 1 from public.worlds_50_best hof
    where hof.restaurant_id = r.id and hof.list_type = 'hall_of_fame'
  )                                                    as is_hall_of_fame,
  st_y(r.location::geometry)                          as latitude,
  st_x(r.location::geometry)                          as longitude
from public.restaurants r
join public.cities ci on ci.id = r.city_id
join public.countries co on co.country_code = r.country_code
left join public.hotel_restaurants hr on hr.restaurant_id = r.id
left join public.hotels h on h.id = hr.hotel_id
left join public.worlds_50_best w
  on w.restaurant_id = r.id
 and w.year = (select max(year) from public.worlds_50_best where rank is not null);

-- Not included here, deliberately (see review doc §17/§18 CAN DEFER):
--   - The paired Flutter change (Restaurant.isHallOfFame reading
--     is_hall_of_fame instead of inclusion_reason, restaurantFullColumns
--     gaining 'is_hall_of_fame') -- a Flutter/UI change, explicitly out of
--     scope for this architecture-review task.
--   - Fixing scripts/import_catalogue.py's insert_restaurants() to stop
--     writing a now-provably-never-'hall_of_fame' expression -- a script
--     change, also out of scope here; low urgency once section 2 above
--     means nothing actually reads that value's 'hall_of_fame' case
--     anymore, but still worth cleaning up so the script doesn't keep
--     writing a value that documents an intent it never fulfills.
--   - Renaming inclusion_reason to something more provenance-explicit
--     (e.g. creation_source) -- cosmetic, no functional benefit alone,
--     and a breaking rename of a column 8+ call sites read by name.
--   - A restaurant_catalogue_sources normalized table -- reviewed and
--     rejected as likely duplicating award_history / worlds_50_best /
--     gault_millau_awards, see review doc §6.
--   - Any Gault&Millau-specific column on restaurants_full (current
--     score/toques) -- no UI consumer exists yet; building it now would
--     be speculative, per the same "do not build the view unless clearly
--     required" conclusion already reached in
--     supabase/data/enrichment/gault_millau/PRODUCTION_READINESS_REVIEW.md §7.
