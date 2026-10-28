-- MICHELIN Guide Belgium & Luxembourg 2026: city-only prerequisite for the
-- 13 starred Belgian restaurants missing from the catalogue, added by
-- supabase/data/enrichment/michelin_be_lu_stars_2026/prepared_be_lu_stars_2026.sql.
--
-- Written 2026-10-28. Filename timestamp is a sequence number only (named
-- after the highest existing migration, 20261016140000), not this date.
--
-- Adds ONLY public.cities rows. Checked against production on 2026-10-28
-- (read-only query run by the user): these seven returned 0 matches by exact
-- name in BE. Antwerp, Ghent, Heverlee, Liège and Sint-Denijs-Westrem already
-- exist and are used as stored (production writes "Antwerp"/"Ghent", not
-- MICHELIN's "Antwerpen"/"Gent"). Names are MICHELIN's destination towns as
-- printed on each restaurant's guide.michelin.com page. Only the exact name
-- was checked, not other-language variants (Louvain, Sint-Pieters-Woluwe):
-- the nearest existing BE row is Woluwe-Saint-Lambert, a different
-- municipality.
--
-- region and postal_municipality are left NULL, matching the BE convention
-- (20260812100000_expand_michelin_city_coverage.sql). None of the seven has
-- a Belgian homonym.
--
-- Idempotent: ON CONFLICT targets cities_unique_key
-- (country_code, name, coalesce(region, '')).

begin;

insert into public.cities (country_code, name, region)
values
  ('BE', 'Comblain-au-Pont', NULL),
  ('BE', 'Leuven', NULL),
  ('BE', 'Modave', NULL),
  ('BE', 'Ninove', NULL),
  ('BE', 'Saint-Georges-sur-Meuse', NULL),
  ('BE', 'Strombeek-Bever', NULL),
  ('BE', 'Woluwe-Saint-Pierre', NULL)
on conflict (country_code, name, coalesce(region, '')) do nothing;

commit;
