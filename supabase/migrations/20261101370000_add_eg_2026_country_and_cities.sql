-- MICHELIN Key hotels in Egypt: country and city prerequisite for
-- supabase/data/enrichment/michelin_eg_2026/prepared_eg_2026.sql.
-- Written 2026-11-04 by build_eg.py from MICHELIN's hotel pages of that day.
-- Filename timestamp is a sequence number only (next after 20261101360000).
-- Production has no `countries` row for EG and no EG city (read 2026-11-04). Africa/Cairo is in
-- production's pg_timezone_names (read that day). Towns are the hotel page's locality, MICHELIN's
-- spelling. region and postal_municipality NULL, as the existing rows.
-- Idempotent: ON CONFLICT targets countries_pkey and cities_unique_key.

begin;

insert into public.countries (country_code, name, flag_emoji, timezones)
values ('EG', 'Egypt', '🇪🇬', array['Africa/Cairo'])
on conflict (country_code) do nothing;

insert into public.cities (country_code, name, region)
values
  ('EG', 'Alexandria', NULL),
  ('EG', 'Cairo', NULL),
  ('EG', 'El Gouna', NULL),
  ('EG', 'Giza', NULL),
  ('EG', 'Hurghada', NULL),
  ('EG', 'Luxor', NULL),
  ('EG', 'Sharm El Sheikh', NULL)
on conflict (country_code, name, coalesce(region, '')) do nothing;

commit;
