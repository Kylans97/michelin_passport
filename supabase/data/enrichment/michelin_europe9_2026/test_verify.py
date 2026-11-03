#!/usr/bin/env python3
"""Print SQL that compares the scratch database with every control-file row and prints each mismatch
(see test_scratch.sh). Independent of the post-conditions inside prepared_europe9_2026.sql."""
import csv, glob, os

HERE = os.path.dirname(os.path.abspath(__file__))


def q(v):
    return 'NULL' if v in (None, '') else "'" + v.replace("'", "''") + "'"


print("create temp table want (kind text, code text, cc text, name text, award smallint, url text, town text, phone text, web text, prop text, hotel text, guide_year smallint, announced date, action text);")
R = [r for f in sorted(glob.glob(os.path.join(HERE, 'controle', '*.csv'))) for r in csv.DictReader(open(f))]
for r in R:
    print(f"insert into want values ({q(r['kind'])}, {q(r['code'])}, {q(r['country'])}, {q(r['name'])}, {r['award'] or 'NULL'}, {q(r['michelin_url'])}, {q(r['town'])}, "
          f"{q(r['phone'])}, {q(r['website'])}, {q(r['property_name'])}, {q(r['hotel_code'])}, {r['guide_year'] or 'NULL'}, {q(r['announced_on'])}, {q(r['action'])});")
print("""
select 'rows compared: ' || count(*) from want;
select 'MISMATCH award ' || w.code from want w left join restaurants r on r.restaurant_code = w.code left join hotels h on h.hotel_code = w.code
 where coalesce(r.michelin_stars, h.michelin_keys) is distinct from w.award;
select 'MISMATCH new restaurant ' || w.code from want w join restaurants r on r.restaurant_code = w.code join cities c on c.id = r.city_id
 where w.action = 'new' and (r.name, r.michelin_url, c.name, r.country_code, coalesce(r.phone, ''), coalesce(r.website_url, ''), coalesce(r.property_name, ''))
    is distinct from (w.name, w.url, w.town, w.cc, coalesce(w.phone, ''), coalesce(w.web, ''), coalesce(w.prop, ''));
select 'MISMATCH new hotel ' || w.code from want w join hotels h on h.hotel_code = w.code join cities c on c.id = h.city_id
 where w.action = 'new' and (h.name, h.michelin_url, c.name, h.country_code) is distinct from (w.name, w.url, w.town, w.cc);
select 'MISMATCH url ' || w.code from want w left join restaurants r on r.restaurant_code = w.code left join hotels h on h.hotel_code = w.code
 where w.code <> 'rest_0427' and coalesce(r.michelin_url, h.michelin_url) is distinct from w.url;
select 'MISMATCH current row ' || w.code from want w join restaurants r on r.restaurant_code = w.code
  join award_history a on a.entity_type = 'restaurant' and a.entity_id = r.id and a.is_current
 where w.action = 'new' and (a.guide_year, a.award_value, a.announced_on) is distinct from (w.guide_year, w.award, w.announced);
select 'MISMATCH current key row ' || w.code from want w join hotels h on h.hotel_code = w.code
  join award_history a on a.entity_type = 'hotel' and a.entity_id = h.id and a.is_current
 where w.action = 'new' and (a.guide_year, a.award_value, a.announced_on) is distinct from (w.guide_year, w.award, w.announced);
select 'MISMATCH link ' || w.code from want w where w.kind = 'restaurant' and w.hotel is not null
   and not exists (select 1 from hotel_restaurants hr join hotels h on h.id = hr.hotel_id join restaurants r on r.id = hr.restaurant_id
                    where h.hotel_code = w.hotel and r.restaurant_code = w.code);
select 'tiers ' || r.country_code || ' stars 3/2/1 ' || count(*) filter (where michelin_stars = 3) || '/' || count(*) filter (where michelin_stars = 2) || '/' || count(*) filter (where michelin_stars = 1)
  from restaurants r group by r.country_code order by 1;
select 'tiers ' || h.country_code || ' keys  3/2/1 ' || count(*) filter (where michelin_keys = 3) || '/' || count(*) filter (where michelin_keys = 2) || '/' || count(*) filter (where michelin_keys = 1) || ', no Key ' || count(*) filter (where michelin_keys is null)
  from hotels h group by h.country_code order by 1;
select 'history ' || coalesce(h.hotel_code, r.restaurant_code) || ': ' || string_agg(a.guide_year || '=' || coalesce(a.award_value::text, 'NULL') || case when a.is_current then ' current' else '' end, ', ' order by a.guide_year)
  from award_history a left join hotels h on a.entity_id = h.id left join restaurants r on a.entity_id = r.id
 where coalesce(h.hotel_code, r.restaurant_code) in ('hotel_277', 'hotel_280', 'hotel_260', 'hotel_267', 'hotel_301', 'hotel_305', 'rest_0427', 'rest_0428', 'hotel_259', 'rest_0424')
 group by coalesce(h.hotel_code, r.restaurant_code) order by 1;
select 'Platán: ' || status || ', stars ' || coalesce(michelin_stars::text, 'NULL') || ', link kept ' ||
       exists (select 1 from hotel_restaurants hr where hr.restaurant_id = restaurants.id) from restaurants where restaurant_code = 'rest_0427';
select 'links total ' || count(*) from hotel_restaurants;
""")
