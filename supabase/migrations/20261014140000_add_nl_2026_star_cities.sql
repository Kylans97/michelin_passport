-- MICHELIN Gids Nederland 2026: city-only prerequisite for five of the nine
-- newly starred restaurants in
-- supabase/data/enrichment/michelin_nl_stars_2026/prepared_nl_stars_2026.sql.
--
-- Written 2026-10-28. Filename timestamp is a sequence number only (named
-- after the highest existing migration, 20261014130000), not this date.
--
-- Adds ONLY public.cities rows -- no restaurant, award or other row. Checked
-- against production on 2026-10-28 (read-only query run by the user): these
-- five returned 0 matches by exact name in NL; Valkenburg, Delft, Loenen aan
-- de Vecht and Groningen already exist and are not touched. Names are the
-- MICHELIN destination names from each restaurant's guide.michelin.com page
-- (mierlo, veeningen, kortgene, schin-op-geul, hoog-soeren), written as the
-- towns spell themselves.
--
-- region and postal_municipality are left NULL, matching the convention of
-- every other NL cities row (20260812150000_expand_netherlands_city_coverage
-- .sql): none of the five has a Dutch homonym. Hoog Soeren lies in the
-- municipality of Apeldoorn and Schin op Geul in Valkenburg aan de Geul;
-- per that convention neither is recorded as postal_municipality.
--
-- Idempotent: ON CONFLICT targets cities_unique_key
-- (country_code, name, coalesce(region, '')).

begin;

insert into public.cities (country_code, name, region)
values
  ('NL', 'Mierlo', NULL),
  ('NL', 'Veeningen', NULL),
  ('NL', 'Kortgene', NULL),
  ('NL', 'Schin op Geul', NULL),
  ('NL', 'Hoog Soeren', NULL)
on conflict (country_code, name, coalesce(region, '')) do nothing;

commit;
