-- QA-250: World's 50 Best Top 50 rank-years missing from worlds_50_best,
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
-- restaurant already has a row for that year; exactly 13 rows inserted.
--
-- Run with: supabase db query --linked --file <absolute path to this file>

begin;

create temporary table v(code text, name text, year smallint, rank smallint) on commit drop;
insert into v values
    ('rest_1270', 'Mirazur', 2017, 4),
    ('rest_1388', 'The Clove Club', 2017, 26),
    ('rest_1410', 'Alléno Paris au Pavillon Ledoyen', 2017, 31),
    ('rest_1270', 'Mirazur', 2018, 3),
    ('rest_1410', 'Alléno Paris au Pavillon Ledoyen', 2018, 29),
    ('rest_1388', 'The Clove Club', 2018, 33),
    ('rest_1270', 'Mirazur', 2019, 1),
    ('rest_1410', 'Alléno Paris au Pavillon Ledoyen', 2019, 25),
    ('rest_1388', 'The Clove Club', 2019, 27),
    ('rest_1757', 'Nerua Guggenheim Bilbao', 2019, 32),
    ('rest_1386', 'A Casa do Porco', 2019, 39),
    ('rest_1382', 'Leo', 2019, 49),
    ('rest_0979', 'Le Clarence', 2022, 28);

do $$ declare n int; begin
  select count(*) into n from v join public.restaurants r on r.restaurant_code = v.code and r.name = v.name;
  if n <> 13 then raise exception 'identity: expected 13 code/name pairs, got %', n; end if;
  select count(*) into n from v join public.worlds_50_best w on w.year = v.year and w.rank = v.rank;
  if n <> 0 then raise exception 'slots already taken: %', n; end if;
  select count(*) into n from v join public.restaurants r on r.restaurant_code = v.code
    join public.worlds_50_best w on w.restaurant_id = r.id and w.year = v.year;
  if n <> 0 then raise exception 'restaurant already has a row that year: %', n; end if;
  insert into public.worlds_50_best (restaurant_id, year, rank, list_type)
    select r.id, v.year, v.rank, 'top_50' from v join public.restaurants r on r.restaurant_code = v.code;
  get diagnostics n = row_count;
  if n <> 13 then raise exception 'inserted: expected 13, got %', n; end if;
end $$;

commit;
