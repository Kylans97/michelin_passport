-- MICHELIN 2026 Key hotels, Portugal: city prerequisite for the Key hotels added by
-- supabase/data/enrichment/michelin_keys_pt_2026/prepared_pt_key_hotels_2026.sql.
-- Written 2026-11-01; the filename timestamp is a sequence number only (after
-- 20261031160000_add_pt_2026_star_cities.sql, which must run first: the hotels
-- reuse 13 of its towns and production's Lisbon). Names are the hotel page's
-- locality, except where noted in pt_key_hotels_2026.csv (town_note): the island
-- "Madeira" -> Funchal and the region "Norte" -> Vidago from the hotel's own street
-- address, and two diacritics MICHELIN's English data drops. None exists in
-- production (export of 2026-11-01) or in the stars migration, compared accent-,
-- case-, space- and hyphen-insensitively. "Santa Cruz" here is the one near Torres
-- Vedras (Areias do Seixo, 2560-046), not Madeira's. region/postal_municipality NULL.
-- Idempotent: ON CONFLICT targets cities_unique_key.

begin;

insert into public.cities (country_code, name, region)
values
  ('PT', 'Aljezur', NULL),
  ('PT', 'Alporchinhos', NULL),
  ('PT', 'Altura', NULL),
  ('PT', 'Armamar', NULL),
  ('PT', 'Armação de Pêra', NULL),
  ('PT', 'Aveiro', NULL),
  ('PT', 'Beja', NULL),
  ('PT', 'Castelo de Paiva', NULL),
  ('PT', 'Comporta', NULL),
  ('PT', 'Encarnação', NULL),
  ('PT', 'Lamego', NULL),
  ('PT', 'Loulé', NULL),
  ('PT', 'Manteigas', NULL),
  ('PT', 'Melides', NULL),
  ('PT', 'Mesão Frio', NULL),
  ('PT', 'Monforte', NULL),
  ('PT', 'Monsaraz', NULL),
  ('PT', 'Ponta Delgada', NULL),
  ('PT', 'Salvaterra de Magos', NULL),
  ('PT', 'Santa Cruz', NULL),
  ('PT', 'Santo Tirso', NULL),
  ('PT', 'Seia', NULL),
  ('PT', 'Vidago', NULL),
  ('PT', 'Vidigueira', NULL),
  ('PT', 'Vila Nova de Cacela', NULL)
on conflict (country_code, name, coalesce(region, '')) do nothing;

commit;
