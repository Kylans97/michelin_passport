-- The 50 Best Restaurants 2026: city prerequisite for
-- supabase/data/enrichment/worlds_50_best_2026/prepared_w50b_2026_import.sql.
-- Written 2026-11-16. Filename timestamp is a sequence number only (next
-- after 20261101380000).
-- Naar (No. 49) is in Kasauli, Himachal Pradesh; production has no IN city
-- of that name (read 2026-11-16). The other seven new restaurants use cities
-- that exist (São Paulo, Singapore, Seoul, Bangkok, Giza, Valle de
-- Guadalupe). region NULL, as the existing IN rows.
-- Idempotent: ON CONFLICT targets cities_unique_key.

begin;

insert into public.cities (country_code, name, region)
values ('IN', 'Kasauli', NULL)
on conflict (country_code, name, coalesce(region, '')) do nothing;

commit;
