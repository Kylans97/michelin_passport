-- Cuisines for the Mantelier Selection, 2026-11-24 (product owner: "Yes, all
-- five"). Needs migration 20261101720000. Sources per restaurant in
-- selection_cuisines_sources.csv beside this file: the restaurant's own
-- site plus one independent source (AmsterdamNow, Bart's Boekje, the
-- MICHELIN Guide), except Petit Péché, which rests on its own site alone and
-- was approved as such. Troef keeps its MICHELIN cuisine (Modern French).
-- Fills only restaurants with no cuisine yet; stops as a whole otherwise.
begin;
do $$ begin
  if exists (select 1 from public.restaurant_cuisines where restaurant_id in (
    '00dd9bed-bb47-4df6-a4a2-6f38b69e36c1','1978dcc8-8bf9-4a4e-a269-039c634c764d',
    '44c6af1d-e1cf-4699-8ff1-41f4dd555257','ce114784-5999-4cdc-8534-0eafb07d01d8',
    'd516ceda-bb19-45a8-a64b-53ee218b6aaa')) then
    raise exception 'a Selection restaurant already has a cuisine';
  end if;
end $$;
insert into public.restaurant_cuisines (restaurant_id, cuisine_id, position, source, source_url, source_label, verified_on) values
  ('00dd9bed-bb47-4df6-a4a2-6f38b69e36c1', 197, 1, 'editorial', 'https://www.camarat.nl/', 'met invloeden uit Frankrijk en Scandinavië', date '2026-11-24'), -- Camarat: French
  ('00dd9bed-bb47-4df6-a4a2-6f38b69e36c1', 411, 2, 'editorial', 'https://www.camarat.nl/', 'met invloeden uit Frankrijk en Scandinavië', date '2026-11-24'), -- Camarat: Scandinavian
  ('1978dcc8-8bf9-4a4e-a269-039c634c764d', 392, 1, 'editorial', 'https://www.bartsboekje.com/en/dame-aan-de-kade-amsterdam-2/', 'Mediterranean-European menu full of comfort food', date '2026-11-24'), -- Dame aan de Kade: Mediterranean Cuisine
  ('44c6af1d-e1cf-4699-8ff1-41f4dd555257', 321, 1, 'editorial', 'https://www.restaurantmontblanc.nl/', 'Proef het beste uit de Savoie', date '2026-11-24'), -- Mont Blanc: Alpine
  ('ce114784-5999-4cdc-8534-0eafb07d01d8', 412, 1, 'editorial', 'https://www.petitpecheamsterdam.nl/', 'uitgesproken gerechten met krachtige smaken, seizoensproducten', date '2026-11-24'), -- Petit Péché: Seasonal Cuisine
  ('d516ceda-bb19-45a8-a64b-53ee218b6aaa', 197, 1, 'editorial', 'https://tacite.nl/', 'seizoensmenu met Franse basis', date '2026-11-24'), -- Tacite: French
  ('d516ceda-bb19-45a8-a64b-53ee218b6aaa', 412, 2, 'editorial', 'https://tacite.nl/', 'seizoensmenu met Franse basis', date '2026-11-24'); -- Tacite: Seasonal Cuisine
-- The single cuisine column older builds read, set only where empty.
update public.restaurants set cuisine_id = 197 where id = '00dd9bed-bb47-4df6-a4a2-6f38b69e36c1' and cuisine_id is null; -- Camarat
update public.restaurants set cuisine_id = 392 where id = '1978dcc8-8bf9-4a4e-a269-039c634c764d' and cuisine_id is null; -- Dame aan de Kade
update public.restaurants set cuisine_id = 321 where id = '44c6af1d-e1cf-4699-8ff1-41f4dd555257' and cuisine_id is null; -- Mont Blanc
update public.restaurants set cuisine_id = 412 where id = 'ce114784-5999-4cdc-8534-0eafb07d01d8' and cuisine_id is null; -- Petit Péché
update public.restaurants set cuisine_id = 197 where id = 'd516ceda-bb19-45a8-a64b-53ee218b6aaa' and cuisine_id is null; -- Tacite
do $$ begin
  if (select count(*) from public.restaurant_cuisines where source = 'editorial') <> 7 then
    raise exception 'expected 7 editorial cuisine rows';
  end if;
end $$;
commit;
