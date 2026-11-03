#!/usr/bin/env python3
"""Seed a scratch PostgreSQL with production's GR export and print the SQL that
builds it (GR pass, 2026-11-04; from ../michelin_pl_tr_2026). No PostGIS was available locally, so geography,
ST_MakePoint, ST_SetSRID and ST_DWithin are stubbed (a (lon, lat) composite and a
haversine distance): enough to exercise every guard in prepared_gr_2027.sql.

  python3 test_scratch.py > seed.sql && psql ... -f seed.sql
"""
import json, os

X = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), '_source/production_export_20261104.json')))


def q(v):
    return 'NULL' if v is None else "'" + str(v).replace("'", "''") + "'"


print("""
create extension if not exists pgcrypto;
create type geography as (lon float8, lat float8);
create function st_makepoint(float8, float8) returns geography language sql immutable as $$ select row($1, $2)::geography $$;
create function st_setsrid(geography, int) returns geography language sql immutable as $$ select $1 $$;
create function st_dwithin(a geography, b geography, d float8) returns boolean language sql immutable as $$
  select 12742000 * asin(sqrt(power(sin(radians(b.lat - a.lat) / 2), 2)
       + cos(radians(a.lat)) * cos(radians(b.lat)) * power(sin(radians(b.lon - a.lon) / 2), 2))) <= d $$;
create table public.cities (id uuid primary key default gen_random_uuid(), country_code text not null, name text not null,
  region text, postal_municipality text);
create unique index cities_unique_key on public.cities (country_code, name, coalesce(region, ''));
create table public.restaurants (id uuid primary key default gen_random_uuid(), restaurant_code text unique not null,
  name text not null, michelin_stars smallint check (michelin_stars between 1 and 3),
  inclusion_reason text not null default 'michelin_star' check (inclusion_reason in ('michelin_star', 'worlds_50_best', 'hall_of_fame', 'bib_gourmand', 'gault_millau', 'editorial_selection')), city_id uuid not null references public.cities,
  country_code text not null, address text not null, location geography not null, michelin_url text unique, website_url text, phone text,
  property_name text, google_place_id text unique, status text default 'open', updated_at timestamptz);
create table public.hotels (id uuid primary key default gen_random_uuid(), hotel_code text unique not null,
  name text not null, michelin_keys smallint check (michelin_keys between 1 and 3), city_id uuid not null references public.cities,
  country_code text not null, address text not null, location geography not null, michelin_url text unique, website_url text, phone text,
  google_place_id text unique, status text default 'open', updated_at timestamptz);
create table public.award_history (id uuid primary key default gen_random_uuid(), entity_type text, entity_id uuid,
  guide_year int, award_type text, award_value smallint, is_current boolean, announced_on date,
  unique (entity_type, entity_id, guide_year, award_type));
create unique index award_history_current_uidx on public.award_history (entity_type, entity_id, award_type) where is_current;
create table public.hotel_restaurants (hotel_id uuid references public.hotels, restaurant_id uuid references public.restaurants,
  link_confidence text not null check (link_confidence in ('exact', 'campus', 'manual_review')), evidence text,
  verified_at timestamptz, primary key (hotel_id, restaurant_id));
""")
for c in X['cities']:
    print(f"insert into public.cities (country_code, name, region) values ({q(c['country'])}, {q(c['name'])}, {q(c['region'])});")
for r in X['restaurants'] or []:
    print(f"""insert into public.restaurants (restaurant_code, name, michelin_stars, inclusion_reason, city_id, country_code, address,
  location, michelin_url, website_url, phone, property_name, google_place_id) values ({q(r['code'])}, {q(r['name'])}, {r['stars']},
  {q(r['inclusion_reason'])}, (select id from public.cities where country_code = {q(r['country'])} and name = {q(r['city'])}),
  {q(r['country'])}, {q(r['address'])}, st_makepoint({r['lon']}, {r['lat']}), {q(r['michelin_url'])}, {q(r['website_url'])},
  {q(r['phone'])}, {q(r['property_name'])}, {q(r['google_place_id'])});""")
    for h in r['history'] or []:
        print(f"""insert into public.award_history (entity_type, entity_id, guide_year, award_type, award_value, is_current, announced_on)
  select 'restaurant', id, {h['year']}, {q(h['type'])}, {'NULL' if h['value'] is None else h['value']}, {h['current']}, {q(h['announced_on'])}
  from public.restaurants where restaurant_code = {q(r['code'])};""")
for r in X['hotels']:
    print(f"""insert into public.hotels (hotel_code, name, michelin_keys, city_id, country_code, address, location, michelin_url,
  website_url, phone, google_place_id) values ({q(r['code'])}, {q(r['name'])}, {'NULL' if r['keys'] is None else r['keys']},
  (select id from public.cities where country_code = {q(r['country'])} and name = {q(r['city'])}), {q(r['country'])},
  {q(r['address'])}, st_makepoint({r['lon']}, {r['lat']}), {q(r['michelin_url'])}, {q(r['website_url'])}, {q(r['phone'])},
  {q(r['google_place_id'])});""")
    for h in r['history'] or []:
        print(f"""insert into public.award_history (entity_type, entity_id, guide_year, award_type, award_value, is_current, announced_on)
  select 'hotel', id, {h['year']}, {q(h['type'])}, {'NULL' if h['value'] is None else h['value']}, {h['current']}, {q(h['announced_on'])}
  from public.hotels where hotel_code = {q(r['code'])};""")
