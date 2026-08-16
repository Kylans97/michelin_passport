-- Add Hotel's two additional rating dimensions: Room, Experience.
--
-- UI Consistency Step 1E gives Hotel Detail the same five-dimension score
-- presentation Restaurant already has. Restaurant's five (Overall/Food/
-- Service/Wine/Value) already exist as columns on public.visits
-- (production_schema_v1.sql + 20260805211243_add_visit_details.sql).
-- Hotel currently only persists three (rating/service_rating/value_rating,
-- reusing the restaurant-shared columns where the concept overlaps) — this
-- migration adds the two Hotel-specific ones Chasing Stars' product
-- direction calls for: Room and Experience. Neither is a restaurant
-- concept, so — mirroring how food_rating/wine_rating stay NULL on every
-- hotel row — room_rating/experience_rating stay NULL on every restaurant
-- row; both share the one polymorphic `visits` table (entity_type
-- discriminates), not a new hotel-only table, matching how every other
-- rating dimension here already works.
--
-- Same shape as every existing sub-rating: nullable smallint, 1-10,
-- no default. Adding a nullable column with no default is a metadata-only
-- change in PostgreSQL, safe to apply to a populated table without a
-- rewrite — every existing row (restaurant and hotel alike) gets
-- room_rating = NULL, experience_rating = NULL, which is the historically
-- correct state: nobody rated a dimension that didn't exist yet. No
-- backfill, no fabricated values.
--
-- No RLS change: visits_read/visits_insert/visits_update/visits_delete
-- (see production_schema_v1.sql and
-- 20260814120000_social_foundation_step2_visit_visibility.sql) are all
-- row-level policies keyed on user_id/visibility — they apply to every
-- column on the row equally and need no changes for a new column, exactly
-- like food_rating/wine_rating required none when they were added. No new
-- index: same reasoning as every existing rating column — these are never
-- filtered or sorted on, only read back per-row alongside the rest of the
-- visit.
--
-- DEPLOYED to production (Step 1E Backend Deployment task): applied via
-- `supabase db push --linked` after a rollback-tested dry run, with the
-- app's read/write paths for both columns verified live together
-- (schema, PostgREST cache, and a controlled Hotel-stay round-trip all
-- confirmed post-deploy — see the Step 1E Backend Deployment report).

begin;

alter table public.visits
  add column room_rating smallint
    constraint visits_room_rating_valid
    check (room_rating between 1 and 10),
  add column experience_rating smallint
    constraint visits_experience_rating_valid
    check (experience_rating between 1 and 10);

commit;
