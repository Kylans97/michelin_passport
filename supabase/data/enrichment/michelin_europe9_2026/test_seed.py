#!/usr/bin/env python3
"""Print the SQL that seeds a scratch PostgreSQL with production's export (see test_scratch.sh).
Adapted from ../michelin_pl_tr_2026/test_scratch.py; constraints as read from production 2026-11-04."""
import json, os

X = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), '_source/production_export_20261104.json')))


def q(v):
    return 'NULL' if v is None else "'" + str(v).replace("'", "''") + "'"


print("""
create type geography as (lon float8, lat float8);
create function st_makepoint(float8, float8) returns geography language sql immutable as $$ select row($1, $2)::geography $$;
create function st_setsrid(geography, int) returns geography language sql immutable as $$ select $1 $$;
create type public.venue_status as enum ('open', 'temporarily_closed', 'permanently_closed');
create table public.countries (country_code text primary key, name text unique not null, flag_emoji text,
  timezones text[] not null constraint countries_timezones_not_empty check (cardinality(timezones) >= 1));
create table public.cities (id uuid primary key default gen_random_uuid(), country_code text not null references public.countries,
  name text not null, region text, postal_municipality text);
create unique index cities_unique_key on public.cities (country_code, name, coalesce(region, ''));
create table public.restaurants (id uuid primary key default gen_random_uuid(), restaurant_code text unique not null,
  name text not null, michelin_stars smallint constraint michelin_stars_valid check (michelin_stars is null or michelin_stars between 1 and 3),
  inclusion_reason text not null check (inclusion_reason in ('michelin_star', 'worlds_50_best', 'hall_of_fame', 'bib_gourmand', 'gault_millau', 'editorial_selection')),
  city_id uuid not null references public.cities, country_code text not null references public.countries, address text, location geography,
  michelin_url text unique, website_url text, phone text, property_name text, google_place_id text unique,
  status public.venue_status not null default 'open', status_since date, status_note text, updated_at timestamptz);
create table public.hotels (id uuid primary key default gen_random_uuid(), hotel_code text unique not null,
  name text not null, michelin_keys smallint check (michelin_keys between 1 and 3), city_id uuid not null references public.cities,
  country_code text not null references public.countries, address text, location geography, michelin_url text unique, website_url text, phone text,
  google_place_id text unique, status public.venue_status not null default 'open', updated_at timestamptz);
create table public.award_history (id uuid primary key default gen_random_uuid(),
  entity_type text not null check (entity_type in ('hotel', 'restaurant')), entity_id uuid not null,
  guide_year smallint not null, award_type text not null check (award_type in ('michelin_keys', 'michelin_stars')), award_value smallint,
  is_current boolean not null default false, announced_on date, unique (entity_type, entity_id, guide_year, award_type));
create unique index award_history_current_uidx on public.award_history (entity_type, entity_id, award_type) where is_current;
create table public.hotel_restaurants (id uuid primary key default gen_random_uuid(), hotel_id uuid not null references public.hotels on delete cascade,
  restaurant_id uuid not null references public.restaurants on delete cascade,
  link_confidence text not null check (link_confidence in ('exact', 'campus', 'manual_review')), evidence text,
  verified_at timestamptz, unique (hotel_id, restaurant_id));
""")
for c in X['countries']:
    tz = ', '.join(q(z) for z in c['timezones'])
    print(f"insert into public.countries values ({q(c['country_code'])}, {q(c['name'])}, {q(c['flag_emoji'])}, array[{tz}]);")
for c in X['cities']:
    print(f"insert into public.cities (country_code, name, region) values ({q(c['country'])}, {q(c['name'])}, {q(c['region'])});")
for kind, rows, tbl, code, val in (('restaurant', X['restaurants'], 'restaurants', 'restaurant_code', 'stars'), ('hotel', X['hotels'], 'hotels', 'hotel_code', 'keys')):
    for r in rows:
        extra = (', inclusion_reason, property_name', f", {q(r.get('inclusion_reason'))}, {q(r.get('property_name'))}") if kind == 'restaurant' else ('', '')
        vcol = 'michelin_stars' if kind == 'restaurant' else 'michelin_keys'
        print(f"""insert into public.{tbl} ({code}, name, {vcol}, city_id, country_code, address, location, michelin_url, website_url, phone,
  google_place_id, status{extra[0]}) values ({q(r['code'])}, {q(r['name'])}, {'NULL' if r[val] is None else r[val]},
  (select id from public.cities where country_code = {q(r['country'])} and name = {q(r['city'])}), {q(r['country'])}, {q(r['address'])},
  st_makepoint({r['lon']}, {r['lat']}), {q(r['michelin_url'])}, {q(r['website_url'])}, {q(r['phone'])}, {q(r['google_place_id'])}, {q(r['status'])}{extra[1]});""")
        for h in r['history'] or []:
            print(f"""insert into public.award_history (entity_type, entity_id, guide_year, award_type, award_value, is_current, announced_on)
  select '{kind}', id, {h['year']}, {q(h['type'])}, {'NULL' if h['value'] is None else h['value']}, {h['current']}, {q(h['announced_on'])}
  from public.{tbl} where {code} = {q(r['code'])};""")
for l in X['links']:
    print(f"""insert into public.hotel_restaurants (hotel_id, restaurant_id, link_confidence)
  select h.id, r.id, {q(l['confidence'])} from public.hotels h, public.restaurants r where h.hotel_code = {q(l['hotel_code'])} and r.restaurant_code = {q(l['restaurant_code'])};""")
