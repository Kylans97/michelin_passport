#!/usr/bin/env python3
"""Test the migration + prepared file on a scratch PostgreSQL (written 2026-10-29).

Usage:
  python3 test_on_scratch.py <catalog.json> <export.json> <psql connection args...>

<catalog.json> is production's catalog for the six tables the file touches
(countries, cities, restaurants, hotels, hotel_restaurants, award_history:
columns, constraints, indexes, triggers), read with a read-only query on
2026-10-29; <export.json> is the export the file was generated from. PostGIS
is stubbed (geography is a text domain; ST_SetSRID/ST_MakePoint build WKT),
and the gist / trigram indexes and the foreign keys to tables outside the six
(cuisines, missing_listing_reports) are left out. Everything else -- column
types, NOT NULLs, defaults, checks, unique and partial indexes, the
updated_at triggers -- is production's.

Runs, each on a fresh copy:
  1. the prepared file without the migration       -> must abort, nothing applied
  2. migration, then the file                       -> must succeed; prints counts
  3. then the file again                            -> must abort
  4. then the migration again                       -> no-op
  5. an exported restaurant renamed before the file -> must abort
  6. a restaurant code in the file's range taken    -> must abort
"""
import json, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
MIG = os.path.join(HERE, '../../../migrations/20261023160000_add_us_ca_mx_2026_star_and_key_cities.sql')
SQL = os.path.join(HERE, 'prepared_us_ca_mx_stars_2026.sql')
TABLES = ['countries', 'cities', 'restaurants', 'hotels', 'hotel_restaurants', 'award_history']


def q(v):
    if v is None:
        return 'NULL'
    if isinstance(v, bool):
        return 'true' if v else 'false'
    if isinstance(v, (int, float)):
        return str(v)
    return "'" + str(v).replace("'", "''") + "'"


def schema(C):
    out = ["drop schema if exists public cascade; create schema public; set search_path = public;",
           "create domain geography as text;",
           "create function st_setsrid(g text, s int) returns text language sql immutable as $$ select g $$;",
           "create function st_makepoint(x float8, y float8) returns text language sql immutable as $$ select 'POINT(' || x || ' ' || y || ')' $$;",
           "create type venue_status as enum ('open', 'temporarily_closed', 'permanently_closed');",
           "create function set_updated_at() returns trigger language plpgsql as $$ begin new.updated_at := now(); return new; end; $$;"]
    tmap = {'uuid': 'uuid', 'text': 'text', 'int2': 'smallint', 'bool': 'boolean', 'date': 'date', 'bpchar': 'char(2)',
            '_text': 'text[]', 'timestamptz': 'timestamptz', 'geography': 'geography', 'venue_status': 'venue_status', '_int2': 'smallint[]'}
    for t in TABLES:
        cols = [c for c in C['columns'] if c['t'] == t]
        out.append(f"create table {t} (" + ', '.join(
            f"{c['c']} {tmap[c['type']]}" + (' not null' if c['null'] == 'NO' else '') + (f" default {c['def']}" if c['def'] else '') for c in cols) + ");")
    cons = sorted(C['constraints'], key=lambda c: (0 if 'PRIMARY' in c['def'] else 1 if 'UNIQUE' in c['def'] or 'CHECK' in c['def'] else 2))
    for c in cons:
        if 'cuisines' in c['def'] or 'missing_listing_reports' in c['def']:
            continue
        out.append(f"alter table {c['t']} add constraint {c['name']} {c['def']};")
    names = {c['name'] for c in C['constraints']}
    for i in C['indexes']:
        if i['name'] in names or 'gist' in i['def'] or 'gin_trgm' in i['def']:
            continue
        out.append(i['def'] + ';')
    for t in C['triggers']:
        out.append(f"create trigger {t['name']} {t['timing']} {t['event']} on {t['t']} for each row {t['action']};")
    return '\n'.join(out)


def seed(X):
    out = ["""insert into countries values ('US', 'United States', '🇺🇸', array['America/New_York']),
  ('MX', 'Mexico', '🇲🇽', array['America/Mexico_City']), ('GB', 'United Kingdom', '🇬🇧', array['Europe/London']);"""]
    for c in X['cities']:
        out.append(f"insert into cities (country_code, name, region, postal_municipality) values ({q(c['country'])}, {q(c['name'])}, {q(c['region'])}, {q(c['postal_municipality'])});")
    # the highest codes production holds elsewhere, and one current 2026 Key row on a GB hotel
    out.append("insert into cities (country_code, name) values ('GB', 'London');")
    out.append(f"insert into restaurants (restaurant_code, name, city_id, country_code, address, location) select 'rest_{X['max_restaurant_code']}', 'max code', id, 'GB', 'x', 'POINT(0 0)' from cities where name = 'London';")
    out.append(f"insert into hotels (hotel_code, name, michelin_keys, city_id, country_code, address, location) select 'hotel_{X['max_hotel_code']}', 'max code', 1, id, 'GB', 'x', 'POINT(0 0)' from cities where name = 'London';")
    out.append(f"insert into award_history (entity_type, entity_id, guide_year, award_type, award_value, is_current) select 'hotel', id, 2026, 'michelin_keys', 1, true from hotels where hotel_code = 'hotel_{X['max_hotel_code']}';")
    for r in X['restaurants']:
        out.append(f"""insert into restaurants (restaurant_code, name, michelin_stars, inclusion_reason, city_id, country_code, address, location, google_place_id, phone, michelin_url, website_url, property_name)
 select {q(r['code'])}, {q(r['name'])}, {q(r['stars'])}, {q(r['inclusion_reason'])}, id, {q(r['country'])}, {q(r['address'])}, 'POINT({r['lon']} {r['lat']})', {q(r['google_place_id'])}, {q(r['phone'])}, {q(r['michelin_url'])}, {q(r['website_url'])}, {q(r['property_name'])}
 from cities where country_code = {q(r['country'])} and name = {q(r['city'])} and region is not distinct from {q(r['region'])};""")
        for h in r['history'] or []:
            out.append(f"insert into award_history (entity_type, entity_id, guide_year, award_type, award_value, is_current, announced_on) select 'restaurant', id, {h['year']}, 'michelin_stars', {q(h['value'])}, {q(h['current'])}, {q(h['announced_on'])} from restaurants where restaurant_code = {q(r['code'])};")
    for h in X['hotels']:
        out.append(f"""insert into hotels (hotel_code, name, michelin_keys, city_id, country_code, address, location, google_place_id, phone, michelin_url, website_url)
 select {q(h['code'])}, {q(h['name'])}, {q(h['keys'])}, id, {q(h['country'])}, {q(h['address'] or 'x')}, 'POINT({h['lon']} {h['lat']})', {q(h['google_place_id'])}, {q(h['phone'])}, {q(h['michelin_url'])}, {q(h['website_url'])}
 from cities where country_code = {q(h['country'])} and name = {q(h['city'])} limit 1;""")
        for a in h.get('key_history') or []:
            out.append(f"insert into award_history (entity_type, entity_id, guide_year, award_type, award_value, is_current, announced_on) select 'hotel', id, {a['year']}, 'michelin_keys', {q(a['value'])}, {q(a['current'])}, {q(a['announced_on'])} from hotels where hotel_code = {q(h['code'])};")
    return '\n'.join(out)


COUNTS = """select r.country_code, r.michelin_stars, ah.guide_year, count(*) from restaurants r
  left join award_history ah on ah.entity_type = 'restaurant' and ah.entity_id = r.id and ah.award_type = 'michelin_stars' and ah.is_current
 where r.country_code in ('US','CA','MX') group by 1, 2, 3 order by 1, 2 desc, 3;
select country_code, michelin_keys, count(*) from hotels where country_code in ('US','CA','MX') group by 1, 2 order by 1, 2 desc;
select country_code, count(*) filter (where phone is not null) phones, count(*) filter (where website_url is not null) websites, count(*) from hotels where country_code in ('US','CA','MX') group by 1 order by 1;
select count(*) as links from hotel_restaurants;
select country_code, name, timezones[1], cardinality(timezones) from countries where country_code = 'CA';
select r.restaurant_code, r.name, ah.guide_year, ah.award_value, ah.is_current, ah.announced_on from restaurants r join award_history ah on ah.entity_id = r.id
 where r.restaurant_code in ('rest_0045', 'rest_0102', 'rest_0735', 'rest_3001') order by 1, 3;"""


def main():
    C, X = json.load(open(sys.argv[1])), json.load(open(sys.argv[2]))
    psql = ['psql', '-X', '-q', '-v', 'ON_ERROR_STOP=1'] + sys.argv[3:]

    def run(label, *parts, expect_ok=True, show=False):
        p = subprocess.run(psql + ['-c', 'set client_min_messages = warning'] + sum((['-f', x] if os.path.exists(x) else ['-c', x] for x in parts), []),
                           capture_output=True, text=True)
        ok = p.returncode == 0
        err = [l for l in p.stderr.splitlines() if 'ERROR' in l][:1]
        print(f"{'PASS' if ok == expect_ok else 'FAIL'}  {label}: {'ok' if ok else 'aborted ' + (err[0] if err else p.stderr[-200:])}")
        if show:
            print(p.stdout)
        return ok

    sch, sd = schema(C), seed(X)
    reset = lambda: run('reset + seed', sch, sd)
    reset(); run('1. file without the migration', SQL, expect_ok=False)
    run('   nothing applied', "do $$ begin if (select count(*) from restaurants where country_code in ('US','CA','MX')) <> 57 or exists (select 1 from countries where country_code = 'CA') then raise exception 'changed'; end if; end $$;")
    reset(); run('2. migration', MIG); run('   prepared file', SQL); run('   counts', COUNTS, show=True)
    run('3. file again', SQL, expect_ok=False)
    run('4. migration again', MIG)
    reset(); run('5. renamed existing row', MIG, "update restaurants set name = name || ' (renamed)' where restaurant_code = 'rest_0745';")
    run('   file', SQL, expect_ok=False)
    reset(); run('6. code in range taken', MIG, "insert into restaurants (restaurant_code, name, city_id, country_code, address, location) select 'rest_3100', 'squatter', id, 'GB', 'x', 'POINT(0 0)' from cities where name = 'London';")
    run('   file', SQL, expect_ok=False)


if __name__ == '__main__':
    main()
