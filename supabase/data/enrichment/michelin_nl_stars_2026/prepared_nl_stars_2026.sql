-- PREPARED -- NOT APPLIED.
--
-- MICHELIN Gids Nederland 2026 (announced 5 October 2026): bring every Dutch
-- restaurant's stars and award_history in line with MICHELIN's own published
-- selection. Written 2026-10-28.
--
-- SOURCE: MICHELIN only -- guide.michelin.com/en/nl/restaurants/all-starred
-- (119 restaurants: 1 x 3, 20 x 2, 98 x 1), cross-checked one-to-one against
-- MICHELIN's full-list articles for 2026 and 2025. Captures and the per-row
-- comparison are in this folder; see NL_STARS_2026_REPORT.md.
--
-- GUIDE YEAR (user decision, 2026-10-28, "option A"): MICHELIN labels this
-- selection 2026. The Dutch award_history rows seeded at launch also carry
-- guide_year = 2026 (DATABASE_ARCHITECTURE.md: "The rows seeded at launch all
-- carry guide_year = 2026 ... a launch limitation"), but their values are the
-- 2025 edition's -- verified against MICHELIN's 2025 full list, every row except
-- the two import errors below. Since UNIQUE (entity_type, entity_id,
-- guide_year, award_type) leaves no room for a real 2026 row beside them, step 1
-- relabels them to 2025. No award VALUE changes in that step. The 2026 edition
-- is then written as new rows where the value changed, closing the 2025 row
-- first, per DATA_UPDATE_PROCESS.md's cardinal rule. Unchanged restaurants keep
-- their (now 2025) row as current.
--
-- WHAT CHANGES
--   1. relabel: Dutch launch rows guide_year 2026 -> 2025 (118 rows)
--   2. losses ('rest_0029', 'rest_0032', 'rest_0043', 'rest_0098', 'rest_0783', 'rest_0144', 'rest_0149', plus De Woage rest_0788): close the 2025 row, write
--      2026 award_value NULL, restaurants.michelin_stars NULL. Rows are kept
--      (DATA_UPDATE_PROCESS.md section 3: "Keep the row ... do not delete").
--   3. import errors ('rest_0781', 'rest_0782' -- Graphite by Peter Gast, Zheng): in neither
--      MICHELIN's 2025 nor its 2026 list, yet imported in August with a 2026
--      one-star row. That row is corrected to 2026 = NULL (current) and stars
--      set NULL. QA log has the entry.
--   4. michelin_url corrected for 18 restaurants whose MICHELIN page moved to
--      a new address (same restaurant, same stars).
--   5. 9 newly starred restaurants added (rest_1396..rest_1404), each with a
--      2026 award_history row. Codes start above the World's 50 Best file's
--      reserved block (rest_1369..1395); the two can be applied in either
--      order.
--
-- PREREQUISITE: supabase/migrations/20261014140000_add_nl_2026_star_cities.sql
-- (Mierlo, Veeningen, Kortgene, Schin op Geul, Hoog Soeren). Every new
-- restaurant's city must exist (checked below; abort
-- names any that do not). One transaction; every check raises, rolling the
-- whole file back. Re-running after success aborts at the first check.

begin;

do $$
begin
  if exists (select 1 from public.restaurants
              where restaurant_code ~ '^rest_[0-9]+$'
                and substring(restaurant_code from 6)::int between 1396 and 1395 + 9) then
    raise exception 'codes rest_1396..rest_1404 are no longer free -- re-check';
  end if;
  if exists (select 1 from public.award_history ah
               join public.restaurants r on r.id = ah.entity_id
              where ah.entity_type = 'restaurant' and ah.award_type = 'michelin_stars'
                and r.country_code = 'NL' and ah.guide_year = 2025) then
    raise exception 'Dutch 2025 star rows already exist -- this file has run, or production changed since 2026-10-28';
  end if;
  if (select count(*) from public.award_history ah
        join public.restaurants r on r.id = ah.entity_id
       where ah.entity_type = 'restaurant' and ah.award_type = 'michelin_stars'
         and r.country_code = 'NL' and ah.guide_year = 2026) <> 120 then
    raise exception 'expected 120 Dutch 2026 star rows (export of 2026-10-28) -- production changed, re-check';
  end if;
end $$;

-- 1. relabel the launch rows (values unchanged)
update public.award_history ah set guide_year = 2025
  from public.restaurants r
 where r.id = ah.entity_id and ah.entity_type = 'restaurant'
   and ah.award_type = 'michelin_stars' and ah.guide_year = 2026
   and r.country_code = 'NL'
   and r.restaurant_code not in ('rest_0781', 'rest_0782');

-- 2. losses: close 2025, open 2026 = NULL
create temp table _losses (code text primary key) on commit drop;
insert into _losses select unnest(array['rest_0029', 'rest_0032', 'rest_0043', 'rest_0098', 'rest_0783', 'rest_0144', 'rest_0149', 'rest_0788']);

update public.award_history ah set is_current = false
  from public.restaurants r, _losses l
 where r.id = ah.entity_id and r.restaurant_code = l.code
   and ah.entity_type = 'restaurant' and ah.award_type = 'michelin_stars'
   and ah.guide_year = 2025;

insert into public.award_history
  (entity_type, entity_id, guide_year, award_type, award_value, is_current, announced_on)
select 'restaurant', r.id, 2026, 'michelin_stars', null, true, date '2026-10-05'
from public.restaurants r join _losses l on l.code = r.restaurant_code;

update public.restaurants r set michelin_stars = null, updated_at = now()
  from _losses l where r.restaurant_code = l.code;

-- 3. import errors: the 2026 one-star row was never true
update public.award_history ah
   set award_value = null, is_current = true, announced_on = date '2026-10-05'
  from public.restaurants r
 where r.id = ah.entity_id and r.restaurant_code in ('rest_0781', 'rest_0782')
   and ah.entity_type = 'restaurant' and ah.award_type = 'michelin_stars'
   and ah.guide_year = 2026;

update public.restaurants set michelin_stars = null, updated_at = now()
 where restaurant_code in ('rest_0781', 'rest_0782');

-- 4. moved MICHELIN pages
create temp table _urls (code text primary key, michelin_url text unique) on commit drop;
insert into _urls values
    ('rest_0005', 'https://guide.michelin.com/en/noord-brabant/oisterwijk/restaurant/alma-1188023'),
    ('rest_0009', 'https://guide.michelin.com/en/noord-holland/castricum/restaurant/apicius212340'),
    ('rest_0014', 'https://guide.michelin.com/en/noord-holland/amsterdam/restaurant/bolenius'),
    ('rest_0019', 'https://guide.michelin.com/en/zuid-holland/den-haag/restaurant/calla-s115041'),
    ('rest_0023', 'https://guide.michelin.com/en/noord-holland/heemstede/restaurant/cheval-blanc212552'),
    ('rest_0056', 'https://guide.michelin.com/en/utrecht/driebergen-rijsenburg/restaurant/la-provence212401'),
    ('rest_0070', 'https://guide.michelin.com/en/noord-brabant/cromvoirt/restaurant/noble-kitchen'),
    ('rest_0072', 'https://guide.michelin.com/en/groningen/groningen/restaurant/noor-1200050'),
    ('rest_0087', 'https://guide.michelin.com/en/limburg/gulpen/restaurant/l-atelier212517'),
    ('rest_0088', 'https://guide.michelin.com/en/zuid-holland/nootdorp/restaurant/calva'),
    ('rest_0089', 'https://guide.michelin.com/en/utrecht/linschoten/restaurant/de-burgemeester'),
    ('rest_0090', 'https://guide.michelin.com/en/utrecht/houten/restaurant/kasteel-heemstede'),
    ('rest_0092', 'https://guide.michelin.com/en/noord-brabant/breda/restaurant/wolfslaar'),
    ('rest_0093', 'https://guide.michelin.com/en/noord-holland/amsterdam/restaurant/rijks-r'),
    ('rest_0096', 'https://guide.michelin.com/en/noord-brabant/leende_2216558/restaurant/sabero-1209599'),
    ('rest_0110', 'https://guide.michelin.com/en/noord-brabant/heeze/restaurant/tribeca502881'),
    ('rest_0115', 'https://guide.michelin.com/en/noord-brabant/nl-willemstad/restaurant/vista488719'),
    ('rest_0119', 'https://guide.michelin.com/en/noord-holland/amsterdam/restaurant/yamazato115431');

do $$
declare bad text;
begin
  select string_agg(u.code, ', ') into bad from _urls u
    join public.restaurants r on r.michelin_url = u.michelin_url and r.restaurant_code <> u.code;
  if bad is not null then raise exception 'new michelin_url already used by another row: %', bad; end if;
end $$;

update public.restaurants r set michelin_url = u.michelin_url, updated_at = now()
  from _urls u where r.restaurant_code = u.code;

-- 5. newly starred restaurants
create temp table _new (code text, name text, stars smallint, city text, address text,
                        lon float8, lat float8, michelin_url text, website_url text,
                        phone text, property_name text) on commit drop;
insert into _new values
    ('rest_1396', 'Ambrozijn', 1::smallint, 'Valkenburg', 'Plenkertstraat 45, 6301 GL Valkenburg', 5.8268325, 50.8646459, 'https://guide.michelin.com/en/limburg/valkenburg/restaurant/ambrozijn', 'https://www.restaurantambrozijn.nl/', '+31 43 200 3068', NULL),
    ('rest_1397', 'Azurite', 2::smallint, 'Delft', 'Houttuinen 2, 2611 DX Delft', 4.3554226, 52.0092176, 'https://guide.michelin.com/en/zuid-holland/delft/restaurant/azurite', 'https://restaurantazurite.nl/', '+31 6 42771100', NULL),
    ('rest_1398', 'Bij Sidney', 1::smallint, 'Loenen aan de Vecht', 'Kerkstraat 5, 3632 EL Loenen aan de Vecht', 5.0231275, 52.2093364, 'https://guide.michelin.com/en/utrecht/loenen-aan-de-vecht/restaurant/bij-sidney', 'https://bijsidney.nl/', '+31 294 792 110', NULL),
    ('rest_1399', 'De Cuijt', 1::smallint, 'Mierlo', 'Burgemeester Termeerstraat 50, 5731 SE Mierlo', 5.6041599, 51.4477832, 'https://guide.michelin.com/en/noord-brabant/mierlo_2216676/restaurant/de-cuijt', 'https://www.restaurant-decuijt.nl/', '+31 492 661 323', NULL),
    ('rest_1400', 'Le Epifaan', 1::smallint, 'Veeningen', 'Bloemberg 5, 7924 PW Veeningen', 6.3457653, 52.6523874, 'https://guide.michelin.com/en/drenthe/veeningen_2214724/restaurant/le-epifaan', 'https://leepifaan.com/', '+31 522 463 116', NULL),
    ('rest_1401', 'Nassau', 1::smallint, 'Groningen', 'Martinikerkhof 23, 9712 JH Groningen', 6.5688416, 53.2207672, 'https://guide.michelin.com/en/groningen/groningen/restaurant/nassau', 'https://prinsenhof.nl/nl/restaurant-nassau/', '+31 50 317 6550', 'Hotel Prinsenhof Groningen'),
    ('rest_1402', 'Rozewied', 1::smallint, 'Kortgene', 'Hoofdstraat 35, 4484 CB Kortgene', 3.8019500, 51.5568836, 'https://guide.michelin.com/en/zeeland/kortgene_2215334/restaurant/rozewied', 'https://www.rozewied.nl/', '+31 6 38112035', NULL),
    ('rest_1403', 'SUIS', 2::smallint, 'Schin op Geul', 'Strucht 77, 6305 AH Schin op Geul', 5.8618460, 50.8520249, 'https://guide.michelin.com/en/limburg/schin-op-geul_2216951/restaurant/suis', 'https://suisralfberendsen.com/', NULL, NULL),
    ('rest_1404', 'Wild Atelier', 1::smallint, 'Hoog Soeren', 'Amersfoortseweg 86, 7346 AA Hoog Soeren', 5.8779577, 52.2332268, 'https://guide.michelin.com/en/gelderland/hoog-soeren_2216407/restaurant/wild-atelier', 'https://www.echoput.nl/gastronomie/wild-atelier', '+31 55 519 1248', 'De Echoput');

do $$
declare bad text;
begin
  select string_agg(n.name || ' (' || n.city || ')', ', ') into bad from _new n
   where (select count(*) from public.cities c where c.country_code = 'NL' and c.name = n.city) <> 1;
  if bad is not null then raise exception 'city does not resolve to exactly one NL row: %', bad; end if;
  select string_agg(n.name, ', ') into bad from _new n
    join public.restaurants r on r.michelin_url = n.michelin_url;
  if bad is not null then raise exception 'new restaurant already present (michelin_url): %', bad; end if;
end $$;

insert into public.restaurants
  (restaurant_code, name, michelin_stars, inclusion_reason, city_id, country_code,
   address, location, michelin_url, website_url, phone, property_name)
select n.code, n.name, n.stars, 'michelin_star',
       (select c.id from public.cities c where c.country_code = 'NL' and c.name = n.city),
       'NL', n.address, ST_SetSRID(ST_MakePoint(n.lon, n.lat), 4326)::geography,
       n.michelin_url, n.website_url, n.phone, n.property_name
from _new n;

insert into public.award_history
  (entity_type, entity_id, guide_year, award_type, award_value, is_current, announced_on)
select 'restaurant', r.id, 2026, 'michelin_stars', n.stars, true, date '2026-10-05'
from _new n join public.restaurants r on r.restaurant_code = n.code;

-- Post-conditions: production now equals MICHELIN's 2026 selection.
do $$
declare n int;
begin
  select count(*) into n from public.restaurants where country_code = 'NL' and michelin_stars is not null;
  if n <> 119 then raise exception 'expected 119 starred NL restaurants, found %', n; end if;
  select count(*) into n from public.restaurants where country_code = 'NL' and michelin_stars = 3;
  if n <> 1 then raise exception 'expected 1 three-star, found %', n; end if;
  select count(*) into n from public.restaurants where country_code = 'NL' and michelin_stars = 2;
  if n <> 20 then raise exception 'expected 20 two-star, found %', n; end if;
  select count(*) into n from public.restaurants where country_code = 'NL' and michelin_stars = 1;
  if n <> 98 then raise exception 'expected 98 one-star, found %', n; end if;
  -- every NL restaurant: exactly one current star row, agreeing with michelin_stars
  select count(*) into n from public.restaurants r
   where r.country_code = 'NL'
     and (select count(*) from public.award_history ah
           where ah.entity_type = 'restaurant' and ah.entity_id = r.id
             and ah.award_type = 'michelin_stars' and ah.is_current) <> 1;
  if n <> 0 then raise exception '% NL restaurants do not have exactly one current star row', n; end if;
  select count(*) into n from public.restaurants r
    join public.award_history ah on ah.entity_type = 'restaurant' and ah.entity_id = r.id
                                and ah.award_type = 'michelin_stars' and ah.is_current
   where r.country_code = 'NL' and ah.award_value is distinct from r.michelin_stars;
  if n <> 0 then raise exception '% NL restaurants disagree with their current award_history row', n; end if;
end $$;

commit;
