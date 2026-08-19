-- Lucas de Jager — De Rooi Pannen education background (Step 2B).
--
-- STATUS: APPLIED to production 2026-08-18. Row id
-- f5facd4b-720c-4520-997c-3c3bf2ca3681 — verified live post-apply.
--
-- Evidence: USER_CONFIRMED directly by Lucas. institution and program
-- are exactly what was confirmed. period_text is deliberately NULL —
-- degree level, diploma type, graduation year, campus, city, honours,
-- and qualification equivalence were not independently confirmed and
-- are not inferred just to make the row fuller.
--
-- display_order=0 within this table — the merged BACKGROUND section
-- renders all private_chef_restaurant_history rows first, then all
-- private_chef_education rows (PrivateChefDetailScreen._backgroundSection,
-- Step 2B), so this table's own ordering only matters relative to other
-- education rows for the same chef, of which there are currently none.
--
-- MANDATORY PRE-FLIGHT (run first, separately):
--
--   select e.id from public.private_chef_education e
--   join public.private_chefs c on c.id = e.private_chef_id
--   where c.slug = 'lucas-de-jager';
--
-- Only proceed if that returns zero rows.

begin;

insert into public.private_chef_education (
  private_chef_id, institution, program, period_text, display_order
)
select
  c.id,
  'De Rooi Pannen',
  'Horeca Ondernemend Management',
  null,
  0
from public.private_chefs c
where c.slug = 'lucas-de-jager';

commit;
