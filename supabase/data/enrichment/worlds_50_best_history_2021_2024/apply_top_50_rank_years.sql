-- QA-246: World's 50 Best rank-years missing from worlds_50_best, 2021-2024
-- Top 50. Written 2026-10-28 (data/w50b-history-gaps). Generated from
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
-- restaurant already has a row for that year; exactly 29 rows inserted.
--
-- Run with: supabase db query --linked --file <absolute path to this file>

begin;

create temporary table v(code text, name text, year smallint, rank smallint) on commit drop;
insert into v values
    ('rest_1386', 'A Casa do Porco', 2021, 17),
    ('rest_1388', 'The Clove Club', 2021, 32),
    ('rest_1391', 'Burnt Ends', 2021, 34),
    ('rest_0165', 'Hof van Cleve', 2021, 36),
    ('rest_1410', 'Alléno Paris au Pavillon Ledoyen', 2021, 41),
    ('rest_1373', 'Nobelhart & Schmutzig', 2021, 45),
    ('rest_1382', 'Leo', 2021, 46),
    ('rest_1386', 'A Casa do Porco', 2022, 7),
    ('rest_1373', 'Nobelhart & Schmutzig', 2022, 17),
    ('rest_0837', 'The Jane', 2022, 23),
    ('rest_0165', 'Hof van Cleve', 2022, 27),
    ('rest_1388', 'The Clove Club', 2022, 35),
    ('rest_1385', 'Fyn', 2022, 37),
    ('rest_0474', 'Jordnær', 2022, 38),
    ('rest_1384', 'Oteque', 2022, 47),
    ('rest_1382', 'Leo', 2022, 48),
    ('rest_1386', 'A Casa do Porco', 2023, 12),
    ('rest_1370', 'El Chato', 2023, 33),
    ('rest_1388', 'The Clove Club', 2023, 38),
    ('rest_0837', 'The Jane', 2023, 39),
    ('rest_1382', 'Leo', 2023, 43),
    ('rest_1373', 'Nobelhart & Schmutzig', 2023, 45),
    ('rest_0913', 'La Grenouillère', 2023, 48),
    ('rest_1370', 'El Chato', 2024, 25),
    ('rest_1386', 'A Casa do Porco', 2024, 27),
    ('rest_0837', 'The Jane', 2024, 36),
    ('rest_1384', 'Oteque', 2024, 37),
    ('rest_1373', 'Nobelhart & Schmutzig', 2024, 43),
    ('rest_1371', 'La Colombe', 2024, 49);

do $$ declare n int; begin
  select count(*) into n from v join public.restaurants r on r.restaurant_code = v.code and r.name = v.name;
  if n <> 29 then raise exception 'identity: expected 29 code/name pairs, got %', n; end if;
  select count(*) into n from v join public.worlds_50_best w on w.year = v.year and w.rank = v.rank;
  if n <> 0 then raise exception 'slots already taken: %', n; end if;
  select count(*) into n from v join public.restaurants r on r.restaurant_code = v.code
    join public.worlds_50_best w on w.restaurant_id = r.id and w.year = v.year;
  if n <> 0 then raise exception 'restaurant already has a row that year: %', n; end if;
  insert into public.worlds_50_best (restaurant_id, year, rank, list_type)
    select r.id, v.year, v.rank, 'top_50' from v join public.restaurants r on r.restaurant_code = v.code;
  get diagnostics n = row_count;
  if n <> 29 then raise exception 'inserted: expected 29, got %', n; end if;
end $$;

commit;
