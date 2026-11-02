-- cuisines.slug becomes unique. Written 2026-11-01.
--
-- 20261101150000 added the generated slug without a unique index, because
-- production's legacy labels had two colliding pairs ("French / Asian" and
-- "French-Asian", "French / Classic" and "French Classic"). The data load
-- supabase/data/enrichment/restaurant_cuisines_2026/prepared_restaurant_cuisines.sql
-- replaces the legacy vocabulary with MICHELIN's and removes both pairs, so
-- this goes to production only after that load. On a fresh replay the table
-- holds only the six labels 20260923120000 inserts, which do not collide.

begin;

drop index public.cuisines_slug_idx;
create unique index cuisines_slug_key on public.cuisines (slug);

commit;
