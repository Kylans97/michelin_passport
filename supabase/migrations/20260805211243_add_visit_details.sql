-- Add visit detail fields.
--
-- The production baseline (20260805141519_production_schema_v1.sql) shipped
-- public.visits with a single overall `rating` column. Implementing the
-- Flutter visit-logging repository surfaced that the agreed MVP also needs
-- per-aspect sub-ratings and a menu-type flag, none of which existed yet.
-- This migration adds them. `rating` is untouched and remains the overall
-- rating; it is not renamed.
--
-- All new columns are optional, matching how a visit is actually logged: a
-- user may record only an overall rating, some sub-ratings, all of them, or
-- none. Adding nullable columns with no default is a metadata-only change
-- in PostgreSQL, safe to apply to a populated table without a rewrite.

begin;

alter table public.visits
  add column food_rating smallint
    constraint visits_food_rating_valid
    check (food_rating between 1 and 10),
  add column service_rating smallint
    constraint visits_service_rating_valid
    check (service_rating between 1 and 10),
  add column wine_rating smallint
    constraint visits_wine_rating_valid
    check (wine_rating between 1 and 10),
  add column value_rating smallint
    constraint visits_value_rating_valid
    check (value_rating between 1 and 10),
  add column menu_type text
    constraint visits_menu_type_valid
    check (menu_type in ('tasting_menu', 'a_la_carte', 'both'));

commit;
