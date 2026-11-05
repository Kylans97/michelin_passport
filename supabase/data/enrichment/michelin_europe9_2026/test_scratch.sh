#!/bin/sh
# Test the migration and prepared_europe9_2026.sql on a throwaway local PostgreSQL 17 (2026-11-04).
# No PostGIS or Docker was available, so geography, ST_MakePoint, ST_SetSRID are stubbed. The
# schema repeats production's constraints that these statements can hit (read from production
# that day). Never connects to production.
#   sh test_scratch.sh
set -u
export LC_ALL=en_US.UTF-8   # postgres refuses to start on this Mac without it
HERE=$(cd "$(dirname "$0")" && pwd)
MIG="$HERE/../../../migrations/20261101300000_add_europe9_2026_countries_and_cities.sql"
SQL="$HERE/prepared_europe9_2026.sql"
PGD=$(mktemp -d)
PORT=55439
initdb -D "$PGD" -U postgres --auth=trust -E UTF8 >/dev/null
pg_ctl -D "$PGD" -o "-p $PORT -k $PGD" -w -l "$PGD/log" start >/dev/null || { tail -5 "$PGD/log"; echo "FAIL server did not start"; exit 1; }
trap 'pg_ctl -D "$PGD" -m immediate stop >/dev/null; rm -rf "$PGD"' EXIT
P="psql -h $PGD -p $PORT -U postgres -v ON_ERROR_STOP=1 -q"
fresh() {
  $P -d postgres -c "drop database if exists t" -c "create database t"
  python3 "$HERE/test_seed.py" | $P -d t >/dev/null || { echo "FAIL seed"; exit 1; }
}
snap() { $P -d t -At -c "select md5(string_agg(x::text, '|' order by x::text)) from (select restaurant_code, michelin_stars, status::text, michelin_url from restaurants union all select hotel_code, michelin_keys, status::text, michelin_url from hotels) x"; }
expect_abort() { # label, sql file
  before=$(snap)
  [ -n "$before" ] || { echo "FAIL $1: no snapshot"; return; }
  if $P -d t -f "$2" >"$PGD/out" 2>&1; then echo "FAIL $1: ran"
  elif grep -q "ERROR" "$PGD/out"; then echo "ok   $1: aborted: $(grep -m1 ERROR "$PGD/out" | sed 's/.*ERROR: *//' | cut -c1-110)"
  else echo "FAIL $1: no SQL error: $(head -1 "$PGD/out")"; fi
  [ "$before" = "$(snap)" ] && echo "ok   $1: nothing changed" || echo "FAIL $1: data changed"
}

echo "== without the migration"; fresh; expect_abort "no migration" "$SQL"

echo "== with it"; fresh; $P -d t -f "$MIG" && $P -d t -f "$SQL" && echo "ok   applied"
python3 "$HERE/test_verify.py" | $P -d t -At

echo "== re-runs"; expect_abort "file re-run" "$SQL"
$P -d t -f "$MIG" && echo "ok   migration re-run is a no-op: $($P -d t -At -c "select count(*) from countries where country_code in ('CZ','EE','LT','LV')") countries, $($P -d t -At -c "select count(*) from cities") cities"

echo "== guards"
fresh; $P -d t -f "$MIG" || exit 1; $P -d t -c "update restaurants set name = 'Renamed' where restaurant_code = 'rest_0428'"; expect_abort "renamed row" "$SQL"
fresh; $P -d t -f "$MIG"; $P -d t -c "update hotels set michelin_keys = 2 where hotel_code = 'hotel_280'"; expect_abort "changed Key" "$SQL"
fresh; $P -d t -f "$MIG"; $P -d t -c "insert into hotels (hotel_code, name, city_id, country_code) select 'hotel_3100', 'Taken', id, 'HR' from cities where name = 'Zagreb'"; expect_abort "code taken" "$SQL"
fresh; $P -d t -f "$MIG"; $P -d t -c "update restaurants set michelin_url = 'x' where restaurant_code = 'rest_0424'"; expect_abort "url present" "$SQL"
