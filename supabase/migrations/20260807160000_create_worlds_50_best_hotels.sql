-- Ranking history for hotels appearing in The World's 50 Best Hotels
-- (2023-2025). Additive only: public.worlds_50_best (restaurants) is not
-- touched by this migration in any way -- it keeps its own
-- 'hall_of_fame' list_type value, which has no hotel equivalent (confirmed
-- during research: The World's 50 Best Hotels publishes no Hall of Fame /
-- Best-of-the-Best mechanism, unlike the restaurant list). Inventing one
-- here would misrepresent a program that does not exist.
--
-- Shape mirrors public.worlds_50_best exactly (same id/FK/year/rank/
-- list_type/unique/index pattern), with list_type's CHECK deliberately
-- restricted to the two values hotels' source data actually has.
--
-- Design history: supabase/data/enrichment/worlds_50_best_hotels/
-- catalogue_expansion/phase4_worlds_50_best_hotels_schema.md (original
-- design) and phase8_production_readiness_report.md (this migration).
--
-- PREPARED, NOT APPLIED.

create table public.worlds_50_best_hotels (
  id         uuid primary key default gen_random_uuid(),
  hotel_id   uuid not null references public.hotels(id) on delete cascade,
  year       smallint not null,
  rank       smallint,
  list_type  text not null default 'top_50'
    check (list_type in ('top_50', 'extended_51_100')),
  unique (hotel_id, year)
);

-- No two hotels may claim the same numbered rank within the same year.
-- Matches worlds_50_best_year_rank_uidx exactly; NULL ranks are excluded
-- from the uniqueness check by the partial WHERE clause, same as the
-- restaurant table.
create unique index worlds_50_best_hotels_year_rank_uidx
  on public.worlds_50_best_hotels (year, rank)
  where rank is not null;

-- Reverse lookup: "every ranking for this hotel" -- the query the future
-- Hotel Detail / Hotel Award History screen needs, mirroring
-- worlds_50_best_restaurant_idx.
create index worlds_50_best_hotels_hotel_idx
  on public.worlds_50_best_hotels (hotel_id);
