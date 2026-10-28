-- QA-249: World's 50 Best 51-100 rank-years, 2021-2024, missing from
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
-- restaurant already has a row for that year; exactly 39 rows inserted.
--
-- Run with: supabase db query --linked --file <absolute path to this file>

begin;

create temporary table v(code text, name text, year smallint, rank smallint) on commit drop;
insert into v values
    ('rest_1757', 'Nerua Guggenheim Bilbao', 2021, 53),
    ('rest_0837', 'The Jane', 2021, 66),
    ('rest_1384', 'Oteque', 2021, 67),
    ('rest_1369', 'Alcalde', 2021, 68),
    ('rest_0842', 'Willem Hiele', 2021, 77),
    ('rest_1370', 'El Chato', 2021, 80),
    ('rest_0967', 'Épicure', 2021, 83),
    ('rest_0979', 'Le Clarence', 2021, 84),
    ('rest_1381', 'Mil', 2021, 90),
    ('rest_0913', 'La Grenouillère', 2021, 91),
    ('rest_1385', 'Fyn', 2021, 92),
    ('rest_0165', 'Hof van Cleve', 2023, 52),
    ('rest_1369', 'Alcalde', 2023, 54),
    ('rest_0474', 'Jordnær', 2023, 57),
    ('rest_1391', 'Burnt Ends', 2023, 65),
    ('rest_0979', 'Le Clarence', 2023, 67),
    ('rest_1385', 'Fyn', 2023, 75),
    ('rest_1384', 'Oteque', 2023, 76),
    ('rest_1410', 'Alléno Paris au Pavillon Ledoyen', 2023, 78),
    ('rest_1374', 'Nuema', 2023, 79),
    ('rest_1408', 'Flocons de Sel', 2023, 80),
    ('rest_0973', 'Kei', 2023, 93),
    ('rest_1394', 'Labyrinth', 2023, 97),
    ('rest_1375', 'Fu He Hui', 2023, 99),
    ('rest_1382', 'Leo', 2024, 53),
    ('rest_1385', 'Fyn', 2024, 60),
    ('rest_1374', 'Nuema', 2024, 61),
    ('rest_1369', 'Alcalde', 2024, 67),
    ('rest_1391', 'Burnt Ends', 2024, 68),
    ('rest_1375', 'Fu He Hui', 2024, 69),
    ('rest_1383', 'Le Doyenné', 2024, 70),
    ('rest_1408', 'Flocons de Sel', 2024, 76),
    ('rest_0913', 'La Grenouillère', 2024, 77),
    ('rest_1378', 'Masque', 2024, 78),
    ('rest_1410', 'Alléno Paris au Pavillon Ledoyen', 2024, 79),
    ('rest_1388', 'The Clove Club', 2024, 80),
    ('rest_0842', 'Willem Hiele', 2024, 83),
    ('rest_1372', 'Onjium', 2024, 96),
    ('rest_1376', 'Saint Peter', 2024, 98);

do $$ declare n int; begin
  select count(*) into n from v join public.restaurants r on r.restaurant_code = v.code and r.name = v.name;
  if n <> 39 then raise exception 'identity: expected 39 code/name pairs, got %', n; end if;
  select count(*) into n from v join public.worlds_50_best w on w.year = v.year and w.rank = v.rank;
  if n <> 0 then raise exception 'slots already taken: %', n; end if;
  select count(*) into n from v join public.restaurants r on r.restaurant_code = v.code
    join public.worlds_50_best w on w.restaurant_id = r.id and w.year = v.year;
  if n <> 0 then raise exception 'restaurant already has a row that year: %', n; end if;
  insert into public.worlds_50_best (restaurant_id, year, rank, list_type)
    select r.id, v.year, v.rank, 'extended_51_100' from v join public.restaurants r on r.restaurant_code = v.code;
  get diagnostics n = row_count;
  if n <> 39 then raise exception 'inserted: expected 39, got %', n; end if;
end $$;

commit;
