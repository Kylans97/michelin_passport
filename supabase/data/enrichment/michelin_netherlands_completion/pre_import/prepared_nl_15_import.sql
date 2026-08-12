-- PREPARED -- NOT APPLIED.
--
-- Netherlands 18-restaurant verified patch: the restaurant + award_history
-- import for the 15 candidates in READY_TO_IMPORT after city deployment
-- (see supabase/data/enrichment/michelin_netherlands_completion/pre_import/
-- NETHERLANDS_15_PRE_IMPORT_REPORT.md).
--
-- Deliberately NOT placed under supabase/migrations/ -- an unrelated
-- `supabase db push` must not be able to apply this by accident. This file
-- is only ever meant to be run explicitly and reviewed first, e.g.:
--   supabase db query --linked --file prepared_nl_15_import.sql
--
-- SCHEMA CONVENTIONS FOLLOWED (verified live against the actual production
-- schema in this session, not assumed from memory):
--   - restaurants.location: geography(Point,4326), built via
--     ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography --
--     longitude FIRST, matching scripts/import_catalogue.py's own
--     insert_restaurants() (the project's original, only-ever-used loader).
--   - restaurants.id: left to its own `default gen_random_uuid()` -- no
--     deterministic/hash-based UUID scheme exists anywhere in this codebase
--     (confirmed by reading michelin_catalogue_reconciliation's own
--     apply_restaurant_catalogue_expansion.py, which documents the same
--     rule and is this file's structural precedent).
--   - restaurant_code: NOT hardcoded. Computed live inside this statement
--     from `max(restaurant_code) + row_number()`, exactly matching the
--     established rule ("next-available must always be computed live from
--     max(restaurant_code), never assumed from count(*)") -- restaurant_code
--     values are NOT contiguous with row count in this database (774 rows,
--     max code was rest_0779 at last live check), and other concurrent
--     workstreams may add rows between now and whenever this is actually
--     applied, so any hardcoded value here would risk becoming stale/wrong.
--   - inclusion_reason = 'michelin_star' for all 15 -- creation provenance
--     only, matches every source row's own inclusion_reason field. Current
--     recognition is represented separately via restaurants.michelin_stars
--     (the documented fast-path denormalisation) AND a matching
--     award_history row, kept in sync per DATABASE_ARCHITECTURE.md 3.5.
--   - award_history: guide_year=2026, award_type='michelin_stars',
--     is_current=true, announced_on=NULL -- verified as the EXACT pattern
--     used by all 105 existing NL award_history rows in production today
--     (live-checked: 105/105 existing NL current rows use this same
--     guide_year/award_type/is_current/announced_on combination).
--   - cuisine_id, property_name, google_place_id, booking_url: left NULL.
--     No cuisine was independently verified for any of these 15; no formal
--     hotel_id link was verified in production's hotels table (checked
--     live, 0/17 NL hotels matched any of the 5 plausible-property
--     candidates); no Google Place ID was ever collected (this environment
--     has no reliable Place ID lookup capability, established repeatedly
--     across this project); no booking URL was collected. None of these
--     are required NOT NULL columns.
--
-- IDEMPOTENCY: protected via `on conflict (michelin_url) do nothing` --
-- michelin_url is UNIQUE on public.restaurants, and every one of these 15
-- rows carries a distinct, real, already-verified Michelin Guide URL
-- (live-checked: 0/15 collide with any existing production restaurant).
-- Re-running this exact file after a successful apply inserts 0 new
-- restaurant rows; because the award_history insert below is driven by a
-- RETURNING clause on the restaurants insert (which only returns rows that
-- were ACTUALLY inserted, never the ones skipped by ON CONFLICT), a re-run
-- also inserts 0 new award_history rows. Nothing here relies on restaurant
-- name for deduplication.
--
-- TRANSACTION SAFETY: this is ONE SQL statement (a single `with` chaining
-- two data-modifying CTEs). PostgreSQL executes an entire statement, CTEs
-- included, atomically -- there is no possible intermediate state where
-- restaurants are inserted but award_history is not, or vice versa. No
-- explicit BEGIN/COMMIT is needed or added.
--
-- SCOPE: 15 restaurant rows, 15 award_history rows. Zero hotel_restaurants
-- rows (0 verified links, per NETHERLANDS_15_PRE_IMPORT_REPORT.md section
-- "HOTEL"). Zero changes to any existing restaurant, city, hotel, or
-- award_history row. Zero rows for Noble Kitchen, AIRrepublic, or Pure C --
-- confirmed absent from this file (grep-verifiable).

with next_code_base as (
  select coalesce(max(substring(restaurant_code from 6)::int), 0) as base
  from public.restaurants
  where restaurant_code ~ '^rest_[0-9]+$'
),
proposed (seq, name, michelin_stars, city_id, address, lon, lat,
          michelin_url, website_url) as (
  values
    (1,  'Basiliek',               1, '7aef4999-82cc-4ffe-b4b3-4db5b04ed88a'::uuid, 'Vischmarkt 57, 3841 BE Harderwijk',                      5.6212898, 52.3512612, 'https://guide.michelin.com/us/en/gelderland/harderwijk/restaurant/basiliek-1203189',        'https://restaurantbasiliek.nl'),
    (2,  'Graphite by Peter Gast', 1, '3736b37d-e6b0-4786-b427-e85f5a47be16'::uuid, 'Paardenstraat 15III, 1017 CX Amsterdam',                 4.8982866, 52.3664899, 'https://guide.michelin.com/us/en/noord-holland/amsterdam/restaurant/graphite-by-peter-gast', NULL),
    (3,  'Zheng',                  1, 'c74bc361-156b-41ca-a001-b5b607d3dd4a'::uuid, 'Prinsestraat 33, 2513 CA Den Haag',                      4.3060842, 52.0787602, 'https://guide.michelin.com/us/en/zuid-holland/den-haag/restaurant/zheng',                   'https://restaurantzheng.com'),
    (4,  'Daalder',                1, '3736b37d-e6b0-4786-b427-e85f5a47be16'::uuid, 'Lindengracht 90, 1015 KK Amsterdam',                     4.8856647, 52.3805171, 'https://guide.michelin.com/nl/nl/noord-holland/amsterdam/restaurant/daalder-1200903',       'https://daalderamsterdam.nl'),
    (5,  'Merlet',                 1, '3c49ca2d-cfeb-414e-ae74-a796590fc2d0'::uuid, 'Duinweg 15, 1871 AC Schoorl',                            4.6942853, 52.6996668, 'https://guide.michelin.com/us/en/noord-holland/schoorl/restaurant/merlet',                  'https://merlet.nl'),
    (6,  'Latour',                 1, '53b58ee7-81d3-4685-a530-b0cb6303fd1b'::uuid, 'Koningin Astrid Boulevard 5, 2202 BK Noordwijk aan Zee', 4.4276191, 52.2412489, 'https://guide.michelin.com/us/en/zuid-holland/noordwijk-aan-zee/restaurant/latour',          'https://restaurantlatour.nl'),
    (7,  'Restaurant Smink',       1, '95567e78-4697-460c-9b80-6010ca8efba7'::uuid, 'Van Harenstraat 37, 8471 JC Wolvega',                    5.9995125, 52.8753130, 'https://guide.michelin.com/us/en/fryslan/wolvega/restaurant/restaurant-smink',              'https://jansmink.com'),
    (8,  'De Vlindertuin',         1, '6af0130e-4adf-48c7-87c5-c40cdc94cb97'::uuid, 'Stationsweg 41, 9471 GK Zuidlaren',                      6.6801383, 53.0925510, 'https://guide.michelin.com/us/en/drenthe/zuidlaren/restaurant/de-vlindertuin',              'https://restaurant-devlindertuin.nl'),
    (9,  'De Woage',                1, '43f2b224-6255-4776-b639-1d466ac312f9'::uuid, 'Meiboomplein 1, 7783 AT Gramsbergen',                   6.6724803, 52.6107177, 'https://guide.michelin.com/us/en/overijssel/gramsbergen/restaurant/de-woage',               NULL),
    (10, 'De Swarte Ruijter',      1, 'a4478d1b-aa0c-4d85-97f9-b041784998e8'::uuid, 'Holterbergweg 7, 7451 JL Holten',                        6.4208221, 52.2946330, 'https://guide.michelin.com/us/en/overijssel/holten/restaurant/de-swarte-ruijter',           'https://swarteruijter.nl'),
    (11, '''t Lansink',            1, '29c91a22-006f-4ed7-960a-0a57b5cb0cdc'::uuid, 'C.T. Storkstraat 18, Hengelo (Overijssel)',              6.7822588, 52.2596727, 'https://guide.michelin.com/us/en/overijssel/hengelo/restaurant/t-lansink',                  'https://hotellansink.nl'),
    (12, 'De Bloemenbeek',         1, '853d98f6-c3f6-4e28-9a9f-a9dcb671b3a1'::uuid, 'Beuningerstraat 6, 7587 LD De Lutte',                    6.9989749, 52.3198876, 'https://guide.michelin.com/us/en/overijssel/de-lutte/restaurant/de-bloemenbeek',            'https://bloemenbeek.nl'),
    (13, 'De Gieser Wildeman',     1, 'a6b0d1bb-8efa-40e1-8aad-f5823e531306'::uuid, 'Botersloot 1, 4225 PR Noordeloos',                       4.9392283, 51.9016837, 'https://guide.michelin.com/us/en/zuid-holland/noordeloos/restaurant/de-gieser-wildeman',    'https://degieserwildeman.nl'),
    (14, 'De Moerbei',             1, '27076b42-4d8d-4d1a-ada4-613596a981c2'::uuid, 'Dorpsstraat 5A, 2361 AK Warmond',                        4.5028113, 52.1952490, 'https://guide.michelin.com/us/en/zuid-holland/warmond/restaurant/de-moerbei',               'https://demoerbeiwarmond.nl'),
    (15, 'Bij Jef',                1, 'e604d26a-3798-40f8-850b-d41deb00711d'::uuid, 'Herenstraat 34, 1797 AJ Den Hoorn, Texel',               4.7498821, 53.0247743, 'https://guide.michelin.com/us/en/noord-holland/den-hoorn/restaurant/bij-jef',               'https://bijjef.nl')
),
new_restaurants as (
  insert into public.restaurants
    (restaurant_code, name, michelin_stars, inclusion_reason, city_id,
     country_code, address, location, michelin_url, website_url)
  select
    'rest_' || lpad((b.base + p.seq)::text, 4, '0'),
    p.name,
    p.michelin_stars,
    'michelin_star',
    p.city_id,
    'NL',
    p.address,
    ST_SetSRID(ST_MakePoint(p.lon, p.lat), 4326)::geography,
    p.michelin_url,
    p.website_url
  from proposed p
  cross join next_code_base b
  on conflict (michelin_url) do nothing
  returning id, michelin_stars
)
insert into public.award_history
  (entity_type, entity_id, guide_year, award_type, award_value, is_current)
select
  'restaurant', nr.id, 2026, 'michelin_stars', nr.michelin_stars, true
from new_restaurants nr;
