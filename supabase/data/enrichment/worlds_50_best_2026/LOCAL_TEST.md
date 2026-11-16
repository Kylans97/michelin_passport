# Local test of the 2026 import (2026-11-16)

**Stack.** `supabase start` (CLI 2.122.0) on a scratch copy of `supabase/`
(`config.toml`, `seed.sql`, `migrations/`, `functions/`, `templates/`; no
`.temp/`, so nothing linked to production), own project id and ports.
Every migration replayed without error, up to and including the new
`20261101390000_add_w50b_2026_cities.sql` (Kasauli present afterwards).

**Fixture.** Read-only `json_agg` exports from production, loaded with
`session_replication_role = replica`:

| Table | Rows |
|---|---|
| `restaurants` — every row with a `worlds_50_best` row, plus the 9 matched rows that have none | 172 |
| `cities` for those restaurants, linked hotels and the new restaurants' cities (colliding migration-seeded cities replaced by production's ids) | 94 |
| `hotel_restaurants` / `hotels` for those restaurants | 19 / 18 |
| `worlds_50_best` (whole table) | 975 |

Baseline, local against production, `restaurants_full`: 99 restaurants with
a current rank, 7 hall of fame — identical.

**Run 1 of `prepared_w50b_2026_import.sql`.** Committed; every guard and
post-check passed.

| | Before | After |
|---|---|---|
| `restaurants` | 172 | 180 (+8, rest_4200..4207) |
| `worlds_50_best` rows | 975 | 1077 (+102) |
| 2025 ranked | 99 | 100 (No. 94 Meet the Bund) |
| 2026 top_50 / extended_51_100 / hall_of_fame | 0 / 0 / 0 | 50 / 50 / 1 |
| `restaurants_full` current ranks | 99 (2025) | 100 (2026) |
| `restaurants_full` hall of fame | 7 | 8 (+ Maido) |

The 100 (rank, code, country) triples read back from the table are
identical to `w50b_2026_matches.csv`. The 8 new rows read back through
`restaurants_full` with the CSV's stars, inclusion reason, property name
(`is_in_hotel` true for Naar, Eatanic Garden and Fauna), point, phone and
award year (2026 for Seroja, Eatanic Garden, Mosu; 2027 for Baan Tepa; none
for the other four).

**Run 2.** Aborted at the first guard (`worlds_50_best already has 2026
rows`); counts unchanged.

**Not covered.** The guards for a taken code / URL and a missing city were
not triggered on purpose. Production's other ~3,450 restaurants are not in
the fixture; they have no `worlds_50_best` rows and none uses the new codes,
MICHELIN URLs or 50 Best URLs (checked against production on 2026-11-16),
so they cannot change any count above.
