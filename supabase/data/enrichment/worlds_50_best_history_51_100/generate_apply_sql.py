"""Builds apply_51_100_rank_years.sql from rank_years.csv (apply=yes).
Regenerate rather than hand-edit.  usage: python3 -I generate_apply_sql.py <this folder>"""
import csv, sys

D = sys.argv[1]
q = lambda s: "'" + s.replace("'", "''") + "'"
rows = [r for r in csv.DictReader(open(f'{D}/rank_years.csv')) if r['apply'] == 'yes']
vals = ',\n'.join(f"    ({q(r['code'])}, {q(r['name'])}, {r['year']}, {r['rank']})" for r in rows)
n = len(rows)
sql = f"""-- QA-249: World's 50 Best 51-100 rank-years, 2021-2024, missing from
-- worlds_50_best. Written 2026-10-29 (data/w50b-history-older). Generated
-- from rank_years.csv (apply=yes); README.md says how each was proven.
--
-- Every rank-year is on the official list for that year, and the
-- official 51-100 announcement story for that year links that ranked
-- entry to a the50.com profile that is tied to our restaurant by phone,
-- own website or street address (never by name). Keyed on
-- restaurant_code; the name is carried only to assert the code still
-- means the same restaurant.
--
-- Guards (whole transaction aborts on any): every code exists and still
-- carries the expected name; no slot (year, rank) is already taken; no
-- restaurant already has a row for that year; exactly {n} rows inserted.
--
-- Run with: supabase db query --linked --file <absolute path to this file>

begin;

create temporary table v(code text, name text, year smallint, rank smallint) on commit drop;
insert into v values
{vals};

do $$ declare n int; begin
  select count(*) into n from v join public.restaurants r on r.restaurant_code = v.code and r.name = v.name;
  if n <> {n} then raise exception 'identity: expected {n} code/name pairs, got %', n; end if;
  select count(*) into n from v join public.worlds_50_best w on w.year = v.year and w.rank = v.rank;
  if n <> 0 then raise exception 'slots already taken: %', n; end if;
  select count(*) into n from v join public.restaurants r on r.restaurant_code = v.code
    join public.worlds_50_best w on w.restaurant_id = r.id and w.year = v.year;
  if n <> 0 then raise exception 'restaurant already has a row that year: %', n; end if;
  insert into public.worlds_50_best (restaurant_id, year, rank, list_type)
    select r.id, v.year, v.rank, 'extended_51_100' from v join public.restaurants r on r.restaurant_code = v.code;
  get diagnostics n = row_count;
  if n <> {n} then raise exception 'inserted: expected {n}, got %', n; end if;
end $$;

commit;
"""
open(f'{D}/apply_51_100_rank_years.sql', 'w').write(sql)
print(n)
