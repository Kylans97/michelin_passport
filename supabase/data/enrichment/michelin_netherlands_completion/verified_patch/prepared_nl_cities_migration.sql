-- PREPARED -- NOT APPLIED.
--
-- Netherlands 18-restaurant verified patch: city-only prerequisite for the
-- 11 LOCATION_READY_CITY_PENDING restaurants in location_ready_city_pending.csv
-- (see supabase/data/enrichment/michelin_netherlands_completion/verified_patch/
-- NETHERLANDS_VERIFIED_PATCH_REPORT.md).
--
-- Adds ONLY public.cities rows -- no restaurants, no award_history, no other
-- table touched. Source: proposed_cities.csv (12 rows), itself audited
-- against a live production cities snapshot immediately before this file
-- was written (2026-08-12, 0 drift from the parent workstream's earlier
-- audit).
--
-- Idempotent by construction: ON CONFLICT targets cities_unique_key
-- (country_code, name, coalesce(region, '')), the table's real unique
-- index -- safe to re-run/re-push without creating duplicates. Follows the
-- exact same pattern as
-- supabase/migrations/20260812100000_expand_michelin_city_coverage.sql
-- (the Belgium/France city-coverage precedent) -- that file was read for
-- convention reference only, never modified.
--
-- id: database-generated via cities.id's own default gen_random_uuid().
-- postal_municipality / michelin_guide_edition: left NULL, matching the
-- existing convention for every other NL cities row today.
-- region: populated ONLY for the 2 rows with a genuine homonym risk
-- (Hengelo: Overijssel vs. Gelderland; Den Hoorn: Texel/Noord-Holland vs.
-- Zuid-Holland/Delft-area) -- every other row matches the existing
-- convention of region = NULL. See proposed_cities.csv for full reasoning
-- per row.
--
-- THIS FILE HAS NOT BEEN APPLIED. It is not present under
-- supabase/migrations/ and `supabase db push` will not pick it up from
-- here. It is a reviewable artifact only, deliberately kept inside the
-- isolated verified_patch/ folder per this task's scope instructions.

insert into public.cities (country_code, name, region)
values
  ('NL', 'Schoorl', NULL),
  ('NL', 'Noordwijk aan Zee', NULL),
  ('NL', 'Wolvega', NULL),
  ('NL', 'Zuidlaren', NULL),
  ('NL', 'Gramsbergen', NULL),
  ('NL', 'Holten', NULL),
  ('NL', 'Hengelo', 'Overijssel'),
  ('NL', 'De Lutte', NULL),
  ('NL', 'Noordeloos', NULL),
  ('NL', 'Warmond', NULL),
  ('NL', 'Den Hoorn', 'Noord-Holland'),
  ('NL', 'Cadzand-Bad', NULL)
on conflict (country_code, name, coalesce(region, '')) do nothing;
