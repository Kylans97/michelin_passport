#!/bin/sh
# Test the Egypt migration and SQL on a throwaway local PostgreSQL 17 (2026-11-04), with geography
# stubbed: no Docker or PostGIS here. Never connects to production. Requires a real SQL error for
# every abort, so a server that isn't running can't pass (near-miss of the nine-country pass).
set -u
export LC_ALL=en_US.UTF-8
HERE=$(cd "$(dirname "$0")" && pwd)
MIG="$HERE/../../../migrations/20261101370000_add_eg_2026_country_and_cities.sql"
SQL="$HERE/prepared_eg_2026.sql"
PGD=$(mktemp -d); PORT=55440
initdb -D "$PGD" -U postgres --auth=trust -E UTF8 >/dev/null
pg_ctl -D "$PGD" -o "-p $PORT -k $PGD" -w -l "$PGD/log" start >/dev/null || { echo "FAIL server"; exit 1; }
trap 'pg_ctl -D "$PGD" -m immediate stop >/dev/null; rm -rf "$PGD"' EXIT
P="psql -h $PGD -p $PORT -U postgres -v ON_ERROR_STOP=1 -q"
fresh() {
  $P -d postgres -c "drop database if exists t" -c "create database t" 2>/dev/null
  $P -d t <<'E' || { echo "FAIL seed"; exit 1; }
create type geography as (lon float8, lat float8);
create function st_makepoint(float8, float8) returns geography language sql immutable as $$ select row($1, $2)::geography $$;
create function st_setsrid(geography, int) returns geography language sql immutable as $$ select $1 $$;
create type public.venue_status as enum ('open', 'temporarily_closed', 'permanently_closed');
create table public.countries (country_code text primary key, name text unique not null, flag_emoji text,
  timezones text[] not null check (cardinality(timezones) >= 1));
create table public.cities (id uuid primary key default gen_random_uuid(), country_code text not null references public.countries, name text not null, region text);
create unique index cities_unique_key on public.cities (country_code, name, coalesce(region, ''));
create table public.hotels (id uuid primary key default gen_random_uuid(), hotel_code text unique not null, name text not null,
  michelin_keys smallint check (michelin_keys between 1 and 3), city_id uuid not null references public.cities, country_code text not null references public.countries,
  address text, location geography, michelin_url text unique, status public.venue_status not null default 'open');
create table public.award_history (id uuid primary key default gen_random_uuid(), entity_type text not null, entity_id uuid not null, guide_year smallint not null,
  award_type text not null, award_value smallint, is_current boolean not null default false, announced_on date, unique (entity_type, entity_id, guide_year, award_type));
create unique index award_history_current_uidx on public.award_history (entity_type, entity_id, award_type) where is_current;
insert into countries values ('NL', 'Netherlands', null, array['Europe/Amsterdam']);
insert into cities (country_code, name) values ('NL', 'Amsterdam');
E
}
n() { $P -d t -At -c "select count(*) from hotels"; }
abort() {
  b=$(n); [ -n "$b" ] || { echo "FAIL $1: no database"; return; }
  if $P -d t -f "$SQL" >"$PGD/out" 2>&1; then echo "FAIL $1: ran"
  elif grep -q ERROR "$PGD/out"; then echo "ok   $1: $(grep -m1 ERROR "$PGD/out" | sed 's/.*ERROR: *//' | cut -c1-90)"
  else echo "FAIL $1: $(head -1 "$PGD/out")"; fi
  [ "$b" = "$(n)" ] && echo "ok   $1: nothing changed" || echo "FAIL $1: data changed"
}
fresh; abort "no migration"
fresh; $P -d t -f "$MIG" && $P -d t -f "$SQL" && echo "ok   applied"
$P -d t -At -c "select 'keys 2/1: ' || count(*) filter (where michelin_keys = 2) || '/' || count(*) filter (where michelin_keys = 1) from hotels where country_code = 'EG'" \
  -c "select 'award rows ' || count(*) || ', all 2026 current: ' || bool_and(guide_year = 2026 and is_current and announced_on = '2026-09-18') from award_history" \
  -c "select 'cities ' || count(*) from cities where country_code = 'EG'" \
  -c "select c.name || ': ' || count(*) from hotels h join cities c on c.id = h.city_id where h.country_code = 'EG' group by c.name order by c.name"
abort "re-run"
$P -d t -f "$MIG" && echo "ok   migration re-run: $($P -d t -At -c "select count(*) from cities where country_code='EG'") cities"
fresh; $P -d t -f "$MIG"; $P -d t -c "insert into hotels (hotel_code, name, city_id, country_code) select 'hotel_3121', 'Taken', id, 'NL' from cities where name = 'Amsterdam'"; abort "code taken"
fresh; $P -d t -f "$MIG"; $P -d t -c "insert into hotels (hotel_code, name, city_id, country_code, michelin_url) select 'hotel_1', 'Same id', id, 'NL', 'https://x/al-moudira-9477' from cities where name = 'Amsterdam'"; abort "MICHELIN id present"
