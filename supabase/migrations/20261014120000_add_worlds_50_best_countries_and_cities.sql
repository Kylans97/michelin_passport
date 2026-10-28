-- World's 50 Best catalogue completion: countries and cities prerequisite.
--
-- Written 2026-10-28. Filename timestamp is a sequence number only (named
-- after the highest existing migration, 20261013120000 -- the
-- friend-request backfill, already applied), not this date.
--
-- Adds ONLY public.countries and public.cities rows -- no venue, award or
-- ranking row. It is the prerequisite for
-- supabase/data/enrichment/worlds_50_best_2025_2026/prepared_w50b_new_venues_import.sql,
-- which adds the World's 50 Best Restaurants 2025 (51-100) and World's 50
-- Best Hotels 2025/2026 entries still missing from the catalogue.
--
-- Checked against production on 2026-10-28 (read-only queries run by the
-- user in the SQL editor, results in this session):
--   - countries EC, PA, VN do not exist; every other country used exists.
--   - none of the cities below exist under this name, an accent-less
--     spelling, or a local-language variant (Bogota, Merida, Bressanone,
--     Shanghai/Shenzhen variants, Mpumalanga, Nayarit all checked).
--   - two wanted cities resolved to EXISTING rows instead and are
--     deliberately not created here: Axpe -> Atxondo (Txispa, same
--     municipality as Asador Etxebarri) and Moray -> Cusco (Mil, same
--     region as Palacio Nazarenas).
--
-- City names are the MICHELIN Guide destination names where MICHELIN
-- covers the venue, otherwise the World's 50 Best city. region and
-- postal_municipality are left NULL, matching the convention of the
-- existing rows in these countries.
--
-- Idempotent: countries on its primary key, cities on cities_unique_key
-- (country_code, name, coalesce(region, '')).

begin;

insert into public.countries (country_code, name, flag_emoji)
values
  ('EC', 'Ecuador', '🇪🇨'),
  ('PA', 'Panama',  '🇵🇦'),
  ('VN', 'Vietnam', '🇻🇳')
on conflict (country_code) do nothing;

insert into public.cities (country_code, name, region)
values
  ('CN', 'Shanghai', NULL),
  ('CN', 'Shenzhen', NULL),
  ('CO', 'Bogotá', NULL),
  ('EC', 'Quito', NULL),
  ('FR', 'Saint-Vrain', NULL),
  ('IN', 'Bisalpur', NULL),
  ('IN', 'Udaipur', NULL),
  ('IT', 'Brixen', NULL),
  ('MV', 'Dhipparufushi Island', NULL),
  ('MX', 'Guadalajara', NULL),
  ('MX', 'Lo de Marcos', NULL),
  ('MX', 'Mérida', NULL),
  ('NZ', 'Queenstown', NULL),
  ('PA', 'Panama City', NULL),
  ('VN', 'Hanoi', NULL),
  ('ZA', 'Kruger National Park', NULL)
on conflict (country_code, name, coalesce(region, '')) do nothing;

commit;
