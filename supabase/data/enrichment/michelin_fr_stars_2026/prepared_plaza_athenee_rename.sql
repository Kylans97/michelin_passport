-- PREPARED -- NOT APPLIED.
--
-- QA-222: rename rest_0972 Jean Imbert au Plaza Athénée to
-- La Grande Table du Plaza Athénée, decided by the product owner 2026-10-28
-- (a rename of the same restaurant, not a closure plus a new one).
-- Written 2026-10-28.
--
-- Evidence (MICHELIN, 2026-10-28): the old page is gone; the current page
-- https://guide.michelin.com/en/ile-de-france/paris/restaurant/la-grande-du-plaza-athenee
-- shows "La Grande Table du Plaza Athénée", one star, 25 avenue Montaigne,
-- 75008 Paris: the same address and the same star as rest_0972, which is
-- already linked to the Plaza Athénée (hotel_713).
--
-- Changes only name and michelin_url. The star, its 2026 award row and the
-- hotel link stay as they are. Phone stays NULL: MICHELIN's number has not
-- been checked on the restaurant's own site.
--
-- One transaction; aborts unless rest_0972 is still the old name and URL.

begin;

do $$
begin
  if not exists (
    select 1 from public.restaurants
     where restaurant_code = 'rest_0972' and country_code = 'FR' and michelin_stars = 1
       and name = 'Jean Imbert au Plaza Athénée'
       and michelin_url = 'https://guide.michelin.com/us/en/ile-de-france/paris/restaurant/jean-imbert-au-plaza-athenee'
  ) then
    raise exception 'rest_0972 is not the expected Jean Imbert au Plaza Athénée row any more -- re-check';
  end if;
  if exists (select 1 from public.restaurants
              where michelin_url = 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/la-grande-du-plaza-athenee') then
    raise exception 'the new michelin_url is already used by another row';
  end if;
end $$;

update public.restaurants
   set name = 'La Grande Table du Plaza Athénée',
       michelin_url = 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/la-grande-du-plaza-athenee',
       updated_at = now()
 where restaurant_code = 'rest_0972';

commit;
