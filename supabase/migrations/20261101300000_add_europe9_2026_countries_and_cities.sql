-- MICHELIN CZ, HR, SI, HU, MT, LT, LV, EE, RS: country and city prerequisite for
-- supabase/data/enrichment/michelin_europe9_2026/prepared_europe9_2026.sql.
-- Written 2026-11-04 by build_sql.py from production's read-only export of that day.
-- Filename timestamp is a sequence number only (next after 20261101290000, Greece's slot,
-- which is not applied yet: apply that first, or use `supabase db push --include-all` for it).
-- Production has no `countries` row for CZ, EE, LT or LV (export 2026-11-04). Each zone is
-- present in production's pg_timezone_names (read 2026-11-04). Czechia is MICHELIN's own name.
-- Restaurant towns are MICHELIN's English listing names, hotel towns the hotel page's locality,
-- with MICHELIN's spelling kept by the product owner's decision of 2026-11-04 (QA-458). None
-- exists in production's export, compared accent- and case-insensitively. region and
-- postal_municipality NULL, as the existing rows.
-- Idempotent: ON CONFLICT targets countries_pkey and cities_unique_key.

begin;

insert into public.countries (country_code, name, flag_emoji, timezones)
values
  ('CZ', 'Czechia', '🇨🇿', array['Europe/Prague']),
  ('EE', 'Estonia', '🇪🇪', array['Europe/Tallinn']),
  ('LT', 'Lithuania', '🇱🇹', array['Europe/Vilnius']),
  ('LV', 'Latvia', '🇱🇻', array['Europe/Riga'])
on conflict (country_code) do nothing;

insert into public.cities (country_code, name, region)
values
  ('CZ', 'Carlsbad', NULL),
  ('CZ', 'Hlohovec', NULL),
  ('CZ', 'Mcely', NULL),
  ('CZ', 'Olomouc', NULL),
  ('CZ', 'Prague', NULL),
  ('CZ', 'Vysoký Újezd', NULL),
  ('CZ', 'Zlín', NULL),
  ('CZ', 'Šumperk', NULL),
  ('EE', 'Tallinn', NULL),
  ('HR', 'Jastrebarsko', NULL),
  ('HR', 'Korcula', NULL),
  ('HR', 'Mali Lošinj', NULL),
  ('HR', 'Novalja', NULL),
  ('HR', 'Porec', NULL),
  ('HR', 'Rijeka', NULL),
  ('HR', 'Sibenik', NULL),
  ('HR', 'Split', NULL),
  ('HU', 'Esztergom', NULL),
  ('HU', 'Őriszentpéter', NULL),
  ('LT', 'Radiškis', NULL),
  ('LT', 'Trakai', NULL),
  ('LT', 'Vilnius', NULL),
  ('LV', 'Riga', NULL),
  ('MT', 'Sliema', NULL),
  ('MT', 'St. Julian''s', NULL),
  ('RS', 'Novi Slankamen', NULL),
  ('SI', 'Bohinj', NULL),
  ('SI', 'Lasko', NULL),
  ('SI', 'Nova Gorica', NULL),
  ('SI', 'Petrovče', NULL),
  ('SI', 'Portorož', NULL),
  ('SI', 'Radovljica', NULL),
  ('SI', 'Vipava', NULL),
  ('SI', 'Zgornja Kungota', NULL),
  ('SI', 'Šentjošt nad Horjulom', NULL)
on conflict (country_code, name, coalesce(region, '')) do nothing;

commit;
