"""Builds apply_top_50_rank_years.sql (batch 2) from top_50_rank_years.csv (apply=yes).
Regenerate rather than hand-edit.  usage: python3 -I generate_apply_sql.py <this folder>"""
import csv, sys

D = sys.argv[1]
q = lambda s: "'" + s.replace("'", "''") + "'"
rows = [r for r in csv.DictReader(open(f'{D}/top_50_rank_years.csv')) if r['apply'] == 'yes']
vals = ',\n'.join(f"    ({q(r['code'])}, {q(r['name'])}, {r['year']}, {r['rank']})" for r in rows)
n = len(rows)
sql = f"""-- QA-250: World's 50 Best Top 50 rank-years missing from worlds_50_best,
-- batch 2 (2017-2019 and Le Clarence 2022). Written 2026-10-28
-- (data/w50b-history-gaps). Generated from
-- top_50_rank_years.csv; README.md says how each row was proven.
--
-- Every row is confirmed by the official list for that year (archived
-- theworlds50best.com list page; its No.1 fixes the year) AND tied to our
-- restaurant by something other than its name: the official entry page's
-- phone, own website or street address, or our own verified World's 50
-- Best profile stating that exact rank-year. Keyed on restaurant_code;
-- the name is carried only to assert the code still means the same
-- restaurant.
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
    select r.id, v.year, v.rank, 'top_50' from v join public.restaurants r on r.restaurant_code = v.code;
  get diagnostics n = row_count;
  if n <> {n} then raise exception 'inserted: expected {n}, got %', n; end if;
end $$;

commit;
"""
open(f'{D}/apply_top_50_rank_years.sql', 'w').write(sql)
print(n)
