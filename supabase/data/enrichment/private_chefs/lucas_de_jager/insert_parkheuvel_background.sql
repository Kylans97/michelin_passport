-- Lucas de Jager — Parkheuvel restaurant background (Step 2B).
--
-- STATUS: APPLIED to production 2026-08-18. Row id
-- ee0e36aa-ba1f-4b68-a6d9-f0e42bf8e5f1, restaurant_id
-- 90d2b4ae-2b39-4bed-beec-31d6008a7ea8 (Parkheuvel), role='Service',
-- period_text='2.5 years' — verified live post-apply.
--
-- Evidence: DIRECTLY_CONFIRMED_BY_CHEF — Lucas has directly confirmed
-- his Parkheuvel experience (front-of-house/service, not kitchen/chef)
-- and given explicit permission to mention it. See evidence.csv /
-- PROFILE_RESEARCH_REPORT.md §22 for the full evidence trail. This meets
-- PRIVATE_CHEFS.md's own publication standard for provenance evidence
-- (direct chef confirmation).
--
-- role='Service', period_text='2.5 years' are exactly what was
-- confirmed — no more specific title, no exact start/end dates, no
-- kitchen/chef responsibilities invented.
--
-- restaurant_id resolved fresh immediately before this file was
-- prepared (re-query, do not reuse a stale value):
--
--   select id, name, restaurant_code, city_id, country_code, status,
--          michelin_stars
--   from public.restaurants where name ilike '%parkheuvel%';
--
-- Expect exactly one row: Parkheuvel, Rotterdam, NL, status=open,
-- michelin_stars=2, restaurant_code=rest_0079. Its current
-- michelin_stars value is NOT written anywhere in this insert —
-- recognition is rendered dynamically from the live Restaurant row by
-- PrivateChefProvenanceRow, never duplicated into Private Chef tables
-- (PRIVATE_CHEFS.md §10/§17 — hard Michelin-attribution rule).
--
-- MANDATORY PRE-FLIGHT (run first, separately):
--
--   select h.id from public.private_chef_restaurant_history h
--   join public.private_chefs c on c.id = h.private_chef_id
--   where c.slug = 'lucas-de-jager';
--
-- Only proceed if that returns zero rows.

begin;

insert into public.private_chef_restaurant_history (
  private_chef_id, restaurant_id, restaurant_name_text, role, period_text,
  display_order
)
select
  c.id,
  r.id,
  null,
  'Service',
  '2.5 years',
  0
from public.private_chefs c
cross join (
  select id from public.restaurants where name = 'Parkheuvel'
) r
where c.slug = 'lucas-de-jager';

commit;
