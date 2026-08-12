# Netherlands City Deployment Report

Executed 2026-08-12, on explicit user confirmation. Follow-up to `MANUAL_REVIEW_RESOLUTION_ADDENDUM.md`.

## What was deployed

`supabase/migrations/20260812150000_expand_netherlands_city_coverage.sql` — copied from the previously-prepared, not-yet-applied `verified_patch/prepared_nl_cities_migration.sql`, unchanged in content. Applied via `supabase db push --include-all`.

**Inserted:** 12 `public.cities` rows (country_code=NL): Schoorl, Noordwijk aan Zee, Wolvega, Zuidlaren, Gramsbergen, Holten, Hengelo (region=Overijssel), De Lutte, Noordeloos, Warmond, Den Hoorn (region=Noord-Holland), Cadzand-Bad. Idempotent `ON CONFLICT` insert, matching the schema's real unique index.

**Not touched:** `restaurants`, `award_history`, `hotels`, `hotel_restaurants` — this migration contains only the one `INSERT INTO public.cities` statement.

## Verification

- All 12 rows confirmed live post-deploy, with correct region tagging on the 2 homonym-risk cities (Hengelo/Overijssel, Den Hoorn/Noord-Holland).
- Every `city_id` now used in `ready_to_import.csv` was cross-checked against a fresh live query joining candidate→city by name — **15/15 `id_matches: true`**. (One manual transcription error was caught and fixed during this cross-check: Daalder's city_id was initially mistyped and has been corrected to the verified value before this report was written.)
- Production restaurant count: 774 total / 105 NL — **unchanged**.
- Production city count: 1,052 → **1,064** (+12, exactly as expected). NL cities: 70 → 82.
- `award_history`: 1,580 rows — **unchanged**.
- `supabase migration list`: local and remote now agree on `20260812150000` — applied cleanly, nothing else pending.
- No restaurant, award, or hotel row was inserted, updated, or deleted.
- Migration file is untracked in git (not committed, not pushed) — deployment was a database action via the Supabase CLI, independent of git history.

## Resulting state

| Population | Count |
|---|---|
| `READY_TO_IMPORT` | **15** |
| `LOCATION_READY_CITY_PENDING` | **0** |
| `MANUAL_REVIEW` | 0 (historical log retained) |
| `REMOVED_NOT_GENUINELY_MISSING` | **3** (Noble Kitchen, AIRrepublic, Pure C — not reintroduced) |

15 + 0 + 3 = 18. Re-validated: **31 OK, 0 ISSUES**.

This matches the expected final state exactly, with the 3 withdrawn candidates correctly excluded from the import-eligible population throughout.

## What remains

Restaurant rows themselves have **not** been inserted — this task stopped at city deployment, as scoped. The 15 `READY_TO_IMPORT` candidates in `ready_to_import.csv` (with real, verified `city_id`s, coordinates, and coordinate quality) are the actual next-step import payload, pending a separate explicit instruction to import.

---

`NETHERLANDS CITY DEPLOYMENT COMPLETE — 15 CANDIDATES READY, RESTAURANT IMPORT NOT YET PERFORMED`
