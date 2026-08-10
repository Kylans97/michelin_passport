# `worlds_50_best_hotels` — Exact Schema Proposal

**Status: design for review. Not written as a migration file. Not applied anywhere.**

Continues the recommendation from the prior report's `SCHEMA_DESIGN_PROPOSAL.md`: a separate, additive table, `public.worlds_50_best` (restaurants) untouched. That recommendation still holds — nothing found in Phases 1–3 changes the underlying reasoning (the MVP is still actively shipping; the migration-risk asymmetry between "new table" and "ALTER on a live table `restaurants_full` already depends on" is unchanged; hotels still have no Hall of Fame equivalent to reconcile against a shared `list_type` vocabulary).

**No Hall of Fame mechanism is included.** Per the prior report's confirmed research: none exists for hotels. Nothing here invents one.

---

## Exact DDL (illustrative — not a migration to run)

```sql
create table public.worlds_50_best_hotels (
  id         uuid primary key default gen_random_uuid(),
  hotel_id   uuid not null references public.hotels(id) on delete cascade,
  year       smallint not null,
  rank       smallint,
  list_type  text not null default 'top_50'
    check (list_type in ('top_50', 'extended_51_100')),
  unique (hotel_id, year)
);

-- Mirrors worlds_50_best_year_rank_uidx exactly: no two hotels share a rank
-- within the same year (NULL rank is never compared, so this doesn't
-- restrict how many hotels can lack a rank in principle — though this
-- table's list_type vocabulary has no rank-less case today; the partial
-- index is still correct and future-proof to include).
create unique index worlds_50_best_hotels_year_rank_uidx
  on public.worlds_50_best_hotels (year, rank)
  where rank is not null;

-- Carries the reverse lookup ("every ranking for this hotel") the same way
-- worlds_50_best_restaurant_idx does today.
create index worlds_50_best_hotels_hotel_idx
  on public.worlds_50_best_hotels (hotel_id);
```

### Why each piece is shaped this way

| Element | Reasoning |
|---|---|
| `id uuid primary key default gen_random_uuid()` | Identical convention to every other table in the schema. |
| `hotel_id uuid not null references hotels(id) on delete cascade` | Real, Postgres-enforced FK — the concrete integrity advantage Option B has over generalizing `worlds_50_best`, confirmed again here. `on delete cascade` matches `worlds_50_best.restaurant_id`'s own behavior exactly, though per `DATA_UPDATE_PROCESS.md` the catalogue is append-and-amend only, so this cascade is a safety net, not an expected code path. |
| `year smallint not null` | Matches `worlds_50_best.year` exactly. |
| `rank smallint` (nullable) | Matches `worlds_50_best.rank` exactly — nullable because a hotel could in principle appear in a future list_type with no rank, mirroring the restaurant table's own defensive design even though hotels have no Hall of Fame today. |
| `list_type text not null default 'top_50' check (...)` | **Deliberately only two values**, not three — the asymmetry with hotels having no Hall of Fame is expressed by omission from this `CHECK`, not by a cross-column rule that has to be remembered. This is the exact reasoning already given in the prior `SCHEMA_DESIGN_PROPOSAL.md` §3, reconfirmed here. |
| `unique (hotel_id, year)` | Matches `worlds_50_best`'s own constraint — one row per hotel per year, exactly. |
| `worlds_50_best_hotels_year_rank_uidx` partial unique index | Matches `worlds_50_best_year_rank_uidx` exactly — no two hotels can claim the same numbered rank in the same year. |
| `worlds_50_best_hotels_hotel_idx` | Matches `hotel_restaurants_restaurant_idx`'s reverse-lookup role — needed for "show this hotel's full ranking history," the Hotel Detail feature this whole workstream exists to eventually support. |

---

## How this supports every stated requirement

- **hotel** — `hotel_id`, real FK.
- **year** — `year smallint not null`.
- **rank** — `rank smallint`, nullable, partial-unique per year.
- **Top 50 / extended 51–100** — the `list_type` `CHECK`, identical vocabulary (minus Hall of Fame) to the restaurant table.
- **historical querying** — `unique(hotel_id, year)` plus the reverse-lookup index make "this hotel's full history" and "this year's full list" both single indexed queries, no different from the restaurant side today.
- **Rankings** (the Flutter feature) — same shape `RankingsRepository`/`AwardHistoryRepository` already consume for restaurants; a hotel-side `loadWorlds50BestHistory(hotelId)` would be a near-identical sibling method to the existing restaurant one, not a new pattern.
- **hotel Award History** — this table is deliberately independent of `award_history`. A hotel's Key history (`award_history`, already polymorphic and already hotel-ready per Phase 3) and its World's 50 Best ranking history (this new table) remain two separate, non-overlapping facts about the same hotel — exactly how `award_history` and `worlds_50_best` are already kept separate for restaurants today, and for the same reason given in `DATABASE_ARCHITECTURE.md` §3.6: a Key tier is an ordinal award where higher is better, a rank is a position where lower is better, and folding opposed scales into one structure is the mistake the existing schema already deliberately avoids.

## `hotels_full` exposure (illustrative, not applied)

Once the table exists, `hotels_full` would need the same treatment `restaurants_full` already has for `worlds_50_best_rank` — a derived column via a left join to the current year's ranking:

```sql
-- illustrative addition to hotels_full, not applied
left join public.worlds_50_best_hotels w
  on w.hotel_id = h.id
 and w.year = (select max(year) from public.worlds_50_best_hotels where rank is not null)
-- ... and w.rank as worlds_50_best_rank in the select list
```

This is the same `CREATE OR REPLACE VIEW`-shaped, additive-only change pattern the concurrent MVP work already used for `20260807140000_add_venue_coordinates.sql` — no precedent needs to be invented for this step either.
