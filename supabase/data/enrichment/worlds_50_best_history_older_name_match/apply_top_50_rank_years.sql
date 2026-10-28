-- QA-250: World's 50 Best Top 50 rank-years 2002-2017, matched by NAME AND
-- CITY ONLY -- a deliberate exception to "never match on name", decided by
-- the product owner on 2026-10-29 for years with no other evidence left
-- (see README.md). Written 2026-10-29 (data/w50b-history-older). Generated
-- from top_50_rank_years.csv (apply=yes; each row's basis is there).
--
-- Every rank-year is from the official list for that year (archived
-- theworlds50best.com previous-list timeline, accepted by heading, winner
-- and an exact fingerprint against rows we already held). Look-alikes
-- were excluded or held by hand first. Keyed on restaurant_code; the name
-- is carried only to assert the code still means the same restaurant.
--
-- Guards (whole transaction aborts on any): every code exists and still
-- carries the expected name; no slot (year, rank) is already taken; no
-- restaurant already has a row for that year; exactly 51 rows inserted.
--
-- Run with: supabase db query --linked --file <absolute path to this file>

begin;

create temporary table v(code text, name text, year smallint, rank smallint) on commit drop;
insert into v values
    ('rest_1012', 'L''Ambroisie', 2002, 16),
    ('rest_0778', 'The Inn at Little Washington', 2002, 23),
    ('rest_0838', 'Comme chez Soi', 2003, 7),
    ('rest_1012', 'L''Ambroisie', 2003, 9),
    ('rest_1009', 'Pierre Gagnaire', 2003, 13),
    ('rest_1083', 'Auberge de l''Ill', 2003, 18),
    ('rest_1011', 'Guy Savoy', 2003, 30),
    ('rest_1009', 'Pierre Gagnaire', 2004, 5),
    ('rest_1011', 'Guy Savoy', 2004, 6),
    ('rest_1409', 'Troisgros - Le Bois sans Feuilles', 2004, 39),
    ('rest_1083', 'Auberge de l''Ill', 2004, 43),
    ('rest_1026', 'Tour d''Argent', 2004, 45),
    ('rest_1009', 'Pierre Gagnaire', 2005, 6),
    ('rest_1011', 'Guy Savoy', 2005, 16),
    ('rest_1003', 'Le Cinq', 2005, 29),
    ('rest_1083', 'Auberge de l''Ill', 2005, 37),
    ('rest_1409', 'Troisgros - Le Bois sans Feuilles', 2005, 40),
    ('rest_1009', 'Pierre Gagnaire', 2006, 3),
    ('rest_1003', 'Le Cinq', 2006, 17),
    ('rest_0988', 'Astrance', 2006, 22),
    ('rest_1409', 'Troisgros - Le Bois sans Feuilles', 2006, 24),
    ('rest_1371', 'La Colombe', 2006, 28),
    ('rest_1012', 'L''Ambroisie', 2006, 40),
    ('rest_0838', 'Comme chez Soi', 2006, 49),
    ('rest_1009', 'Pierre Gagnaire', 2007, 3),
    ('rest_0988', 'Astrance', 2007, 21),
    ('rest_1012', 'L''Ambroisie', 2007, 23),
    ('rest_1003', 'Le Cinq', 2007, 29),
    ('rest_0976', 'Le Taillevent', 2007, 48),
    ('rest_1009', 'Pierre Gagnaire', 2008, 3),
    ('rest_0988', 'Astrance', 2008, 11),
    ('rest_1003', 'Le Cinq', 2008, 24),
    ('rest_1009', 'Pierre Gagnaire', 2009, 9),
    ('rest_0988', 'Astrance', 2009, 11),
    ('rest_1270', 'Mirazur', 2009, 35),
    ('rest_1371', 'La Colombe', 2009, 38),
    ('rest_1371', 'La Colombe', 2010, 12),
    ('rest_1009', 'Pierre Gagnaire', 2010, 13),
    ('rest_0988', 'Astrance', 2010, 16),
    ('rest_0988', 'Astrance', 2011, 13),
    ('rest_1009', 'Pierre Gagnaire', 2011, 16),
    ('rest_1009', 'Pierre Gagnaire', 2012, 17),
    ('rest_0988', 'Astrance', 2012, 18),
    ('rest_1270', 'Mirazur', 2012, 24),
    ('rest_0988', 'Astrance', 2013, 23),
    ('rest_1270', 'Mirazur', 2013, 28),
    ('rest_1270', 'Mirazur', 2014, 11),
    ('rest_0988', 'Astrance', 2014, 38),
    ('rest_1270', 'Mirazur', 2015, 11),
    ('rest_0988', 'Astrance', 2015, 36),
    ('rest_0988', 'Astrance', 2017, 46);

do $$ declare n int; begin
  select count(*) into n from v join public.restaurants r on r.restaurant_code = v.code and r.name = v.name;
  if n <> 51 then raise exception 'identity: expected 51 code/name pairs, got %', n; end if;
  select count(*) into n from v join public.worlds_50_best w on w.year = v.year and w.rank = v.rank;
  if n <> 0 then raise exception 'slots already taken: %', n; end if;
  select count(*) into n from v join public.restaurants r on r.restaurant_code = v.code
    join public.worlds_50_best w on w.restaurant_id = r.id and w.year = v.year;
  if n <> 0 then raise exception 'restaurant already has a row that year: %', n; end if;
  insert into public.worlds_50_best (restaurant_id, year, rank, list_type)
    select r.id, v.year, v.rank, 'top_50' from v join public.restaurants r on r.restaurant_code = v.code;
  get diagnostics n = row_count;
  if n <> 51 then raise exception 'inserted: expected 51, got %', n; end if;
end $$;

commit;
