# Local test of `prepared_w50b_2026_import.sql` (2026-11-16)

**Stack.** `supabase start` (CLI 2.122.0) on a scratch copy of `supabase/`
(`config.toml`, `seed.sql`, `migrations/`, `functions/`, `templates/`; no
`.temp/`, so nothing linked to production), own project id and ports.
All migrations up to `20261101380000_add_news_card_title.sql` replayed
without error.

**Fixture.** Read-only `json_agg` exports from production, loaded with
`session_replication_role = replica`:

| Table | Rows |
|---|---|
| `restaurants` — every row with a `worlds_50_best` row, plus the 9 matched rows that have none | 172 |
| `cities` for those restaurants and linked hotels (colliding migration-seeded cities replaced by production's ids) | 92 |
| `hotel_restaurants` / `hotels` for those restaurants | 19 / 18 |
| `worlds_50_best` (whole table) | 975 |

Baseline check, local against production, `restaurants_full`: 99 restaurants
with a current rank, 7 hall of fame — identical.

**Run 1.** Committed. All guards and post-checks passed.

| | Before | After |
|---|---|---|
| `worlds_50_best` rows | 975 | 1069 (+94) |
| 2025 ranked | 99 | 100 (No. 94 Meet the Bund) |
| 2026 top_50 / extended_51_100 / hall_of_fame | 0 / 0 / 0 | 49 / 43 / 1 |
| `restaurants_full` current ranks | 99 (2025) | 92 (2026) |
| `restaurants_full` hall of fame | 7 | 8 (+ Maido) |

Spot checks after: Asador Etxebarri current rank 1, Meet the Bund 21,
Neolokal 94, Aponiente 100; Maido and Disfrutar hall of fame, no current
rank. The 92 (rank, code, country) triples read back from the table are
identical to the matched rows of `w50b_2026_matches.csv`.

**Run 2.** Aborted at the first guard (`worlds_50_best already has 2026
rows`); row count unchanged at 1069.

**Not covered.** Production's other ~3,450 restaurants are not in the
fixture; they have no `worlds_50_best` rows, so they cannot change any
count above. The code + country lookup was tested against production's own
rows for every code the file uses.
