-- MICHELIN Guide Czechia, second national selection (MICHELIN dates the
-- stars 2027), announced 20 November 2026. QA-537..QA-539.
--
-- APPLIED 2026-11-22, on the product owner's explicit go. Written
-- 2026-11-22. One transaction; the post-conditions abort it if
-- anything is off.
--
-- MICHELIN's live Czech list (guide.michelin.com/en/cz/restaurants/all-starred,
-- read 2026-11-22): 13 starred, 1 two-star + 12 one-star, every page
-- carrying dateAwarded 2027. The nine already in the catalogue keep their
-- stars; four Prague restaurants are new. Evidence: candidates.csv.

begin;

-- 1. The nine unchanged: close the 2026 row, open a 2027 row, same value.
create temp table _kept (code text primary key, stars smallint) on commit drop;
insert into _kept values
    ('rest_4100', 2), ('rest_4101', 1), ('rest_4102', 1), ('rest_4103', 1),
    ('rest_4104', 1), ('rest_4105', 1), ('rest_4106', 1), ('rest_4107', 1),
    ('rest_4108', 1);

do $$
declare n int;
begin
  select count(*) into n from public.restaurants r join _kept k
    on k.code = r.restaurant_code and r.country_code = 'CZ' and r.michelin_stars = k.stars;
  if n <> 9 then raise exception 'expected 9 unchanged CZ rows at their stars, found %', n; end if;
end $$;

update public.award_history ah set is_current = false
  from public.restaurants r, _kept k
 where r.id = ah.entity_id and r.restaurant_code = k.code
   and ah.entity_type = 'restaurant' and ah.award_type = 'michelin_stars'
   and ah.guide_year = 2026 and ah.is_current;

insert into public.award_history (entity_type, entity_id, guide_year, award_type, award_value, is_current, announced_on)
select 'restaurant', r.id, 2027, 'michelin_stars', k.stars, true, date '2026-11-20'
  from public.restaurants r join _kept k on k.code = r.restaurant_code;

-- 2. Four new one-star restaurants, Prague. Codes claimed in the shared notes.
create temp table _newr (code text primary key, name text, address text, lat float8, lon float8,
                         michelin_url text, website_url text, phone text, place_id text) on commit drop;
insert into _newr values
    ('rest_4212', 'Zlatá Praha', 'Pařížská 30, 110 00 Prague', 50.0914553, 14.4187323,
     'https://guide.michelin.com/en/prague/prague/restaurant/zlata-praha',
     'https://www.zlatapraharestaurant.cz/', '+420292333207', 'ChIJoWkhrcKUC0cR6bKnaUrgs0M'),
    ('rest_4213', 'Taro', 'Národní 10, 110 00 Prague', 50.0816049, 14.416724,
     'https://guide.michelin.com/en/prague/prague/restaurant/taro-1217153',
     'https://www.taro.cz/', null, 'ChIJtc9SeFeUC0cROXx_GqFm5D0'),
    ('rest_4214', 'Salabka', 'K Bohnicím 849/2a, 171 00 Prague', 50.1208919, 14.4099143,
     'https://guide.michelin.com/en/prague/prague/restaurant/salabka',
     'https://www.salabka.cz/', '+420778019002', 'ChIJUQb3NtHqC0cRfrJUIITVkjU'),
    ('rest_4215', 'Reason', 'Na Florenci 2139/2, 110 00 Prague', 50.0882697, 14.4338736,
     'https://guide.michelin.com/en/prague/prague/restaurant/reason',
     'https://www.reasonrestaurant.cz/en', '+420226886692', 'ChIJUY2IGwCVC0cRx9txzjvx0-0');

do $$
declare n int;
begin
  select count(*) into n from public.restaurants r
   where r.restaurant_code in (select code from _newr)
      or r.google_place_id in (select place_id from _newr)
      or r.michelin_url in (select michelin_url from _newr)
      or exists (select 1 from _newr x
                  where st_dwithin(r.location, st_setsrid(st_makepoint(x.lon, x.lat), 4326)::geography, 50));
  if n <> 0 then raise exception '% existing rows clash with the new ones', n; end if;
end $$;

insert into public.restaurants (restaurant_code, name, michelin_stars, inclusion_reason, city_id, country_code,
                                address, location, michelin_url, website_url, phone, google_place_id, status)
select x.code, x.name, 1, 'michelin_star', '2ff46c24-a301-431f-8054-c5cdf396edad', 'CZ',
       x.address, st_setsrid(st_makepoint(x.lon, x.lat), 4326)::geography,
       x.michelin_url, x.website_url, x.phone, x.place_id, 'open'
  from _newr x;

insert into public.award_history (entity_type, entity_id, guide_year, award_type, award_value, is_current, announced_on)
select 'restaurant', r.id, 2027, 'michelin_stars', 1, true, date '2026-11-20'
  from _newr x join public.restaurants r on r.restaurant_code = x.code;

-- 3. Zlatá Praha is the Fairmont Golden Prague's rooftop restaurant.
insert into public.hotel_restaurants (hotel_id, restaurant_id, link_confidence, evidence, verified_at)
select h.id, r.id, 'exact',
       'MICHELIN: rooftop restaurant on the ninth floor at Pařížská 30; the restaurant''s own site footer names Fairmont Golden Prague, Pařížská 30; hotel_3105 at the same address, 2026-11-22.',
       now()
  from public.hotels h, public.restaurants r
 where h.hotel_code = 'hotel_3105' and h.country_code = 'CZ'
   and r.restaurant_code = 'rest_4212'
on conflict (hotel_id, restaurant_id) do nothing;

-- 4. Post-conditions: MICHELIN's live Czech list exactly.
do $$
declare n int;
begin
  select count(*) into n from public.restaurants where country_code = 'CZ' and michelin_stars = 2;
  if n <> 1 then raise exception 'expected 1 CZ two-star, found %', n; end if;
  select count(*) into n from public.restaurants where country_code = 'CZ' and michelin_stars = 1;
  if n <> 12 then raise exception 'expected 12 CZ one-stars, found %', n; end if;
  select count(*) into n from public.award_history ah join public.restaurants r on r.id = ah.entity_id
   where ah.entity_type = 'restaurant' and ah.award_type = 'michelin_stars' and ah.is_current
     and r.country_code = 'CZ' and ah.guide_year = 2027 and ah.award_value = r.michelin_stars;
  if n <> 13 then raise exception 'expected 13 current 2027 CZ star rows, found %', n; end if;
  select count(*) into n from (
    select ah.entity_id from public.award_history ah join public.restaurants r on r.id = ah.entity_id
     where ah.entity_type = 'restaurant' and ah.award_type = 'michelin_stars' and ah.is_current
       and r.country_code = 'CZ' group by 1 having count(*) > 1) d;
  if n <> 0 then raise exception '% CZ restaurants have more than one current star row', n; end if;
  select count(*) into n from public.hotel_restaurants hr join public.restaurants r on r.id = hr.restaurant_id
   where r.restaurant_code = 'rest_4212';
  if n <> 1 then raise exception 'expected the Zlatá Praha hotel link, found %', n; end if;
end $$;

commit;
