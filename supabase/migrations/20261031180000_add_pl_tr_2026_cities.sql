-- MICHELIN Poland 2026 / Türkiye 2026 + 2026 Key hotels: city-only prerequisite for
-- supabase/data/enrichment/michelin_pl_tr_2026/prepared_pl_tr_2026.sql.
-- Written 2026-11-01 by build_pl_tr.py from production's read-only export of that day.
-- Filename timestamp is a sequence number only (next after 20261031170000).
-- Restaurant towns are MICHELIN's English listing names; hotel towns the hotel page's
-- locality with diacritics restored. None exists in production's export, compared
-- accent- and case-insensitively. region and postal_municipality NULL, as the existing rows.
-- Idempotent: ON CONFLICT targets cities_unique_key.

begin;

insert into public.cities (country_code, name, region)
values
  ('PL', 'Gdańsk', NULL),
  ('PL', 'Kościelisko', NULL),
  ('PL', 'Poznań', NULL),
  ('PL', 'Pszczyna', NULL),
  ('PL', 'Sienna', NULL),
  ('TR', 'Alaçatı', NULL),
  ('TR', 'Bozbük', NULL),
  ('TR', 'Büyükada', NULL),
  ('TR', 'Fethiye', NULL),
  ('TR', 'Hisarönü', NULL),
  ('TR', 'Izmir', NULL),
  ('TR', 'Nevşehir', NULL),
  ('TR', 'Ürgüp', NULL),
  ('TR', 'Şile', NULL)
on conflict (country_code, name, coalesce(region, '')) do nothing;

commit;
