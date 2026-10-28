-- Moved into supabase/migrations on 2026-10-28 with the product owner's
-- go-ahead. Not yet applied. Filename timestamp is a sequence number only
-- (named after the highest existing migration, 20261019120000), not a date.
--
-- Peru: city-only prerequisite for 8 of the 14 MICHELIN Key hotels in
-- supabase/data/enrichment/michelin_pe_2026/prepared_pe_keys_and_w50b.sql.
-- Written 2026-10-28.
--
-- Adds ONLY public.cities rows. Checked read-only against production on
-- 2026-10-28: Peru holds two cities (Lima, Cusco); none of these five exists.
-- Names are MICHELIN's destination names, from the path of each hotel's
-- guide.michelin.com page (lake-titicaca, city-of-arequipa, arequipa,
-- sacred-valley, urubamba):
--   Lake Titicaca     Titilaka by Andean
--   City of Arequipa  CIRQA by Andean
--   Arequipa          Las Casitas, A Belmond Hotel (the hotel itself is in
--                     Yanque, Colca Canyon, ~160 km from the city; MICHELIN
--                     files it under the region-level destination "Arequipa")
--   Sacred Valley     Inkaterra Hacienda Urubamba, Rio Sagrado, explora
--   Urubamba          Tambo del Inka
--
-- MICHELIN uses both "Arequipa" and "City of Arequipa" as separate
-- destinations, and "Sacred Valley" next to "Urubamba". They are kept as
-- MICHELIN names them (the city rule: MICHELIN destination, not postal
-- municipality); see PE_REPORT.md, "Decisions for you".
--
-- region and postal_municipality are left NULL, like the two existing PE rows.
--
-- Idempotent: ON CONFLICT targets cities_unique_key
-- (country_code, name, coalesce(region, '')).

begin;

insert into public.cities (country_code, name, region)
values
  ('PE', 'Lake Titicaca', NULL),
  ('PE', 'City of Arequipa', NULL),
  ('PE', 'Arequipa', NULL),
  ('PE', 'Sacred Valley', NULL),
  ('PE', 'Urubamba', NULL)
on conflict (country_code, name, coalesce(region, '')) do nothing;

commit;
