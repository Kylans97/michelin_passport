-- Written 2026-11-24. Product owner: "we moeten voor de mantelier selection
-- wel het type keuken voor alle 6 erin zetten", then "Yes, all five".
--
-- restaurant_cuisines took a cuisine only from MICHELIN, The World's 50 Best
-- or the legacy import. A Selection restaurant (inclusion_reason
-- 'editorial_selection') usually has neither guide, so it had no way to get
-- one. 'editorial' is our own reading of the restaurant's own words plus an
-- independent source, recorded like the others: source_url and the exact
-- phrase in source_label.
--
-- restaurant_cuisines_effective needs no change: it ranks michelin first,
-- worlds_50_best second and every other source third, so a guide's cuisine
-- still wins wherever a restaurant has one.
--
-- Numbered 20261101720000, after 20261101700000 (already on production from
-- the places-globe branch) and 20261101710000 (reserved, unapplied, on the
-- friends-cellar branch).
alter table public.restaurant_cuisines
  drop constraint restaurant_cuisines_source_check;
alter table public.restaurant_cuisines
  add constraint restaurant_cuisines_source_check
  check (source in ('michelin', 'worlds_50_best', 'legacy', 'editorial'));
