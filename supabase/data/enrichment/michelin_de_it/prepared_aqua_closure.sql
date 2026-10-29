-- QA-253: Aqua (rest_0186, Wolfsburg) permanently closed.
-- Written 2026-10-29. The product owner chose to enable the optional block at
-- the end of prepared_de_it_stars_2026.sql; it is run from this file, after
-- that one, so the generated file stays exactly as reviewed.
--
-- Evidence (from the Germany/Italy pass, 2026-10-29): "Nach 25 Jahren:
-- Drei-Sterne-Restaurant 'Aqua' in Wolfsburg schliesst", last services in
-- March 2026 (ms-aktuell.de; chef Sven Elverfeld's own announcement via
-- foodle.pro); MICHELIN's page returns "Restaurant not found". The exact last
-- day is not confirmed, so status_since stays NULL rather than a guessed date.
-- The star loss (2026 = NULL) is written by the main file; this sets only the
-- status.
--
-- Courtier (rest_0230) is not closed here: the timing of its reported closure
-- is unclear.
--
-- One transaction; aborts unless Aqua is still open and the main file has run.

begin;

do $$
begin
  if not exists (
    select 1 from public.restaurants r
     where r.restaurant_code = 'rest_0186' and r.name = 'Aqua' and r.country_code = 'DE'
       and r.status = 'open' and r.michelin_stars is null
       and exists (select 1 from public.award_history ah
                    where ah.entity_type = 'restaurant' and ah.entity_id = r.id
                      and ah.award_type = 'michelin_stars' and ah.guide_year = 2026
                      and ah.is_current and ah.award_value is null)
  ) then
    raise exception 'rest_0186 is not an open Aqua with its 2026 loss recorded -- run prepared_de_it_stars_2026.sql first, or re-check';
  end if;
end $$;

update public.restaurants
   set status = 'permanently_closed',
       status_note = 'Closed after 25 years; last services March 2026 (exact date not confirmed)',
       updated_at = now()
 where restaurant_code = 'rest_0186' and name = 'Aqua' and country_code = 'DE';

commit;
