-- Guía Repsol 2026: drop the closing "Restaurants with 1 Sol follow." from
-- the coverage note (product owner, 2026-11-17: "haal die laatste zin bij
-- Repsol: Restaurants with 1 sol follow maar weg"). One row; the note is
-- otherwise unchanged. Refuses unless exactly that row matches.
begin;

do $$
declare n int;
begin
  update public.guide_coverage
     set note = 'Shown for the restaurants in our catalogue with 3 or 2 Soles: all 46 with three, 113 of 173 with two.'
   where guide_code = 'guia_repsol' and country_code = 'ES' and edition_year = 2026
     and note = 'Shown for the restaurants in our catalogue with 3 or 2 Soles: all 46 with three, 113 of 173 with two. Restaurants with 1 Sol follow.';
  get diagnostics n = row_count;
  if n <> 1 then
    raise exception 'expected 1 row, updated %', n;
  end if;
end $$;

commit;
