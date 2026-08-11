-- Two independent, additive fixes from the 2026-08-11 catalogue
-- architecture review (docs/Architecture/Michelin_Database/
-- GAULT_MILLAU_CATALOGUE_ARCHITECTURE_REVIEW.md). This is the reviewed,
-- production-shaped migration derived from that review's SQL sketch
-- (supabase/data/enrichment/gault_millau/proposed_catalogue_architecture_fix.sql)
-- -- this file, not the sketch, is what would actually be applied.
--
-- PREPARED — NOT APPLIED. Do not run against any database, local or
-- remote, until reviewed. No supabase db push. No production connection.
--
-- inclusion_reason semantics, unchanged by this migration, restated for
-- anyone reading this file cold: it records the PRIMARY reason a
-- restaurant row was ORIGINALLY CREATED -- a single, historical,
-- write-once-in-practice fact. It is creation provenance, never a live
-- summary of every source that currently recognizes the restaurant, and
-- must never be read to derive CURRENT guide recognition of any kind.
-- Current recognition belongs exclusively to the dedicated per-source
-- tables: award_history (Michelin), worlds_50_best (World's 50 Best,
-- including Hall of Fame membership), and gault_millau_awards. See the
-- architecture review's §3/§7 for the full reasoning.

-- ============================================================
-- 1. Widen restaurants.inclusion_reason to permit 'gault_millau'
-- ============================================================
--
-- Unblocks creating a restaurant whose ONLY current recognition is
-- Gault&Millau (today: inclusion_reason is NOT NULL with a closed
-- 4-value CHECK -- michelin_star / worlds_50_best / hall_of_fame /
-- bib_gourmand -- none of which is true for such a restaurant).
--
-- Deliberately NOT adding 'chasing_stars_editorial' here -- no editorial
-- feature exists yet, nothing would ever write that value today, and
-- widening this CHECK later costs exactly the same seconds of work as
-- widening it now (architecture review §4/§11/§18). Add it in its own
-- reviewed migration when that feature is actually built.
--
-- All 4 currently-valid values are preserved unchanged; no existing row's
-- inclusion_reason value is rewritten by this migration -- this only
-- widens what future INSERTs may write.
alter table public.restaurants
  drop constraint inclusion_reason_valid;

alter table public.restaurants
  add constraint inclusion_reason_valid
    check (inclusion_reason in ('michelin_star', 'worlds_50_best',
                                 'hall_of_fame', 'bib_gourmand',
                                 'gault_millau'));

comment on column public.restaurants.inclusion_reason is
  'Creation provenance only: the primary reason this row was originally '
  'created (michelin_star / worlds_50_best / hall_of_fame / bib_gourmand / '
  'gault_millau). A single historical fact, written once at insert and '
  'never rewritten as recognition changes. MUST NOT be read to derive '
  'current guide recognition of any kind -- current recognition lives in '
  'award_history, worlds_50_best, and gault_millau_awards. See '
  'docs/Architecture/Michelin_Database/GAULT_MILLAU_CATALOGUE_ARCHITECTURE_REVIEW.md.';

-- ============================================================
-- 2. Fix Hall of Fame derivation on restaurants_full (bug fix)
-- ============================================================
--
-- Confirmed during the architecture review: inclusion_reason currently has
-- ZERO rows with the value 'hall_of_fame' anywhere in the catalogue (all 6
-- real Hall of Fame members -- Disfrutar, El Celler de Can Roca, Eleven
-- Madison Park, Geranium, Osteria Francescana, The French Laundry -- carry
-- 'michelin_star' instead, because they all also hold 3 Michelin stars and
-- scripts/import_catalogue.py's insert_restaurants() can only ever write
-- 'michelin_star' or 'worlds_50_best'). Restaurant.isHallOfFame
-- (previously `inclusionReason == 'hall_of_fame'`) has therefore always
-- returned false for every real Hall of Fame restaurant -- the Hall of
-- Fame badge and the Explore Hall of Fame filter have been silently
-- non-functional against real data.
--
-- Fix: stop deriving Hall of Fame membership from inclusion_reason
-- entirely. Derive it the same way worlds_50_best_rank already is --
-- from the authoritative fact table itself (worlds_50_best.list_type =
-- 'hall_of_fame'), which insert_hall_of_fame() has always populated
-- correctly. This is the view's only change: one new derived column
-- added. Every existing column, join, and semantic (Michelin stars pass
-- through unchanged from restaurants; World's 50 Best rank derivation
-- unchanged; is_in_hotel, hotel_name, hotel_id, city/country/flag lookups
-- unchanged) is preserved verbatim from the current definition
-- (supabase/migrations/20260807140000_add_venue_coordinates.sql), so this
-- is purely additive to restaurants_full -- no existing consumer of any
-- other column is affected, and no consumer of restaurants_full needs to
-- change to keep working exactly as it does today.
--
-- is_hall_of_fame is placed LAST in the SELECT list, after longitude, not
-- in the more narratively-obvious spot next to worlds_50_best_rank.
-- PostgreSQL's CREATE OR REPLACE VIEW can only ever APPEND a new output
-- column -- inserting one anywhere but the end shifts every later
-- column's ordinal position, which Postgres treats as an attempt to
-- rename the column that used to occupy that position (here: latitude),
-- and refuses with "cannot change name of view column" (SQLSTATE 42P16).
-- This was caught by an actual failed remote apply attempt during this
-- migration's rollout, not proactively -- the local dev database's
-- restaurants_full happened to tolerate a mid-list insert in every prior
-- test because each test ran inside a transaction that was always rolled
-- back to the exact same pre-migration baseline, so the local checks
-- never actually exercised a second CREATE OR REPLACE against an
-- already-existing latitude/longitude tail the way the real deploy does.
-- Confirmed the remote attempt's failure rolled back atomically (the
-- whole statement, and therefore the whole migration transaction, never
-- partially applied) before this fix was written.
--
-- security_invoker = true is preserved unchanged (RLS on the underlying
-- restaurants/worlds_50_best/etc. tables continues to govern who can read
-- through this view -- this migration grants no new access and revokes
-- none; it adds one column to an already-public-read view, per
-- DATABASE_ARCHITECTURE.md §15.2, which restaurants_full already inherits
-- from restaurants' own RLS policy).
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
  st_y(r.location::geometry)                          as latitude,
  st_x(r.location::geometry)                          as longitude,
  exists (
    select 1 from public.worlds_50_best hof
    where hof.restaurant_id = r.id and hof.list_type = 'hall_of_fame'
  )                                                    as is_hall_of_fame
from public.restaurants r
join public.cities ci on ci.id = r.city_id
join public.countries co on co.country_code = r.country_code
left join public.hotel_restaurants hr on hr.restaurant_id = r.id
left join public.hotels h on h.id = hr.hotel_id
left join public.worlds_50_best w
  on w.restaurant_id = r.id
 and w.year = (select max(year) from public.worlds_50_best where rank is not null);

comment on view public.restaurants_full is
  'Read model for the Flutter app -- every restaurants column plus '
  'derived is_in_hotel/hotel_name/hotel_id/city_name/region/country_name/'
  'flag_emoji/worlds_50_best_rank/is_hall_of_fame/latitude/longitude. '
  'is_hall_of_fame is derived from worlds_50_best.list_type = '
  '''hall_of_fame'', never from restaurants.inclusion_reason -- see the '
  'column comment on restaurants.inclusion_reason for why.';

-- Not part of this migration (see architecture review §14/§17/§18,
-- CAN DEFER / separate-scope items):
--   - Paired Flutter change (Restaurant.isHallOfFame reading
--     is_hall_of_fame, restaurantFullColumns gaining the column) -- a
--     Flutter change, implemented alongside this migration in the same
--     review pass but as separate, non-SQL files.
--   - Cleaning up scripts/import_catalogue.py's insert_restaurants(),
--     whose inclusion_reason expression can still never produce
--     'hall_of_fame' -- harmless now that nothing reads that case from
--     inclusion_reason, but still worth a follow-up cleanup.
--   - Adding 'chasing_stars_editorial' to the CHECK -- deferred, §1 above.
--   - Renaming inclusion_reason to a more provenance-explicit column name
--     -- deferred, cosmetic, no functional benefit alone.
--   - hotels: no equivalent inclusion_reason column exists there at all,
--     and no equivalent bug was found -- no hotel-side change proposed.
