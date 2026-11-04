-- MICHELIN Greece: city-only prerequisite for
-- supabase/data/enrichment/michelin_gr/prepared_gr_2027.sql.
-- Written 2026-11-04 by build_gr_control.py from production's read-only export of that day.
-- Filename timestamp is a sequence number only (next after 20261101280000).
-- Towns are MICHELIN's localities, with Kastri and Mouzaki taken from the address where the
-- locality is a region (QA-432). None exists in production's export. region and
-- postal_municipality NULL, as the existing rows.
-- Idempotent: ON CONFLICT targets cities_unique_key.

begin;

insert into public.cities (country_code, name, region)
values
  ('GR', 'Amaliada', NULL),
  ('GR', 'Crete', NULL),
  ('GR', 'Ioannina', NULL),
  ('GR', 'Kastri', NULL),
  ('GR', 'Kefalonia', NULL),
  ('GR', 'Kos', NULL),
  ('GR', 'Kranidi', NULL),
  ('GR', 'Milos', NULL),
  ('GR', 'Monemvasia', NULL),
  ('GR', 'Mouzaki', NULL),
  ('GR', 'Mykonos', NULL),
  ('GR', 'Paros', NULL),
  ('GR', 'Patras', NULL),
  ('GR', 'Perdika', NULL),
  ('GR', 'Rhodes', NULL),
  ('GR', 'Santorini', NULL),
  ('GR', 'Syros', NULL),
  ('GR', 'Thessaloniki', NULL),
  ('GR', 'Zagori', NULL),
  ('GR', 'Zakynthos', NULL)
on conflict (country_code, name, coalesce(region, '')) do nothing;

commit;
