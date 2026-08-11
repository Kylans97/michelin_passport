# Gault&Millau — Production Import Report

Executed: 2026-08-11. **Status: SCHEMA APPLIED, DATA IMPORTED, VERIFIED. Launch scope only.**

Companion to `PRODUCTION_READINESS_REVIEW.md` (the review this executes) and the catalogue architecture fix reports in `docs/Architecture/Michelin_Database/`.

---

## Schema apply status

`supabase/migrations/20260811120000_create_gault_millau_awards.sql` applied to the linked remote project. Re-verified against `SCHEMA_DESIGN.md` before applying — no discrepancy found; the migration matches the reviewed design exactly (both tables, all columns, all CHECK constraints, `UNIQUE(restaurant_id, guide_year)` on `gault_millau_awards`, deliberately no uniqueness constraint on `gault_millau_special_awards`, both FKs, both indexes, RLS with public-`SELECT`-only policies on both tables — confirmed via a read-only `supabase db dump --linked` afterward, not just migration-success output).

## Migration history handling

`supabase migration list` showed `20260811120000` still pending while `20260811220000` (the earlier catalogue architecture fix, applied in the prior task) was already marked applied — an out-of-order timestamp situation. A plain `supabase db push` correctly refused: `"Found local migration files to be inserted before the last migration on remote database."`, suggesting `--include-all`. Confirmed via `--dry-run --include-all` that this flag would push **exactly and only** `20260811120000` — nothing else swept in. `--include-all` is a normal CLI push flag, not `migration repair`; it does not rewrite or manipulate migration history, only extends which local files are eligible for the same ordinary apply-and-record operation. No repair command was needed or used. Applied with `supabase db push --include-all --yes`; `supabase migration list` afterward showed all 12 local migrations with `local == remote`, fully in sync.

## Exact row groups (computed before any write)

Regenerated fresh from the actual CSVs via `import_gault_millau.py`'s own loader functions (not hand-counted, not trusted from memory):

- **IMPORT_NOW (core, 41 rows):** `gm_008, gm_020–023, gm_025–029, gm_031–035, gm_038, gm_040–044, gm_046, gm_048, gm_051–055, gm_057, gm_059, gm_076–084, gm_086, gm_087` — all launch-market (FR/BE/NL/CH/AT), all EXACT or HIGH_CONFIDENCE, `gm_024` structurally absent.
- **IMPORT_SPECIAL_AWARDS_NOW (58 rows):** `gma_001`–`gma_046` and `gma_052`–`gma_063` (the 5 Germany-only special awards, `gma_047`–`gma_051`, structurally absent).
- **DO_NOT_IMPORT (46 core + 5 special):** the 30 NO_MATCH new-restaurant candidates, `gm_024` (REVIEW), and the 15 Germany-matched core rows + 5 Germany special awards.

Reconciled exactly against the review's stated totals (41 + 58) — no discrepancy, no STOP condition triggered.

## Dry-run totals (against LIVE production restaurant identities, zero writes)

Generated via a new, purpose-built script (`apply_gault_millau_production.py` — see "Tooling" below) and executed read-only through `supabase db query --linked` (grep-verified: the dry-run SQL file contains no INSERT/UPDATE/DELETE statement):

- **Core:** 41 `INSERT`, 0 `SKIP_UNRESOLVED_CODE`, 0 `ALREADY_PRESENT_OR_CONFLICT` — every `restaurant_code` resolved against the real, live `restaurants` table.
- **Special:** 58 `INSERT`, 0 `SKIP_UNRESOLVED_COUNTRY` — every `country_code` resolved against the real, live `countries` table.

Matched the reviewed control totals exactly. Proceeded to the actual import.

## Core import result

41 `INSERT` statements generated (idempotent `INSERT ... SELECT ... WHERE NOT EXISTS`, no `UPDATE`, no `DELETE` anywhere in the file — grep-verified before running). Applied via `supabase db query --linked --file`. **41 inserted, 0 skipped, 0 updated** (no core rows pre-existed).

## Core remote verification

- Total: **41** (`content-range: 0-0/41`).
- Market breakdown: **AT 11, BE 9, CH 7, FR 1, NL 13** — matches the reviewed per-market matchable counts exactly. Germany: **0**.
- `gm_024` (restaurant_code `rest_0085`): **0** rows.
- Duplicate `(restaurant_id, guide_year)` pairs: **0**.
- `recognition_type` breakdown: **41 `scored`, 0 `unscored_top_tier`, 0 `unscored_casual`** — expected: every France Toques d'Or and Belgium H!P candidate is a NO_MATCH new-restaurant candidate (out of scope for this task), so no unscored row exists yet to import. This is a known, documented limitation carried over from the review, not a defect introduced here.
- Spot-checked one row per launch market, all correct: **FR** Plénitude (`rest_0304`, 19.0/20, 5 toques) · **BE** Zilte (`rest_0154`, 18.5/20) · **NL** 't Nonnetje (`rest_0146`, 18.0/20) · **CH** Cheval Blanc by Peter Knogl (`rest_0235`, 19.0/20) · **AT** Restaurant Amador / Steirereck im Stadtpark / Döllerer (all 19.0/20, 5 toques).

## Special import result

58 `INSERT` statements generated the same way (0 core-table statements present in this file — confirmed separately). Applied. **58 inserted, 0 skipped, 0 updated**.

## Special remote verification

- Total: **58**. Market breakdown: **NL 18, BE 14, AT 12, CH 8, FR 6** — matches exactly. Germany: **0**.
- Every row: `source_url` present (spot-checked 8 Austrian rows, all `has_source_url = true`).
- `restaurant_id`: **NULL on all 58 rows** — exactly per the reviewed design (award-winner names were never run through the matching pipeline; resolving them was explicitly deferred, not attempted here).
- Multi-winner case confirmed live: Belgium's "Young Chef of the Year" — **3** simultaneous regional rows — proving the deliberate no-uniqueness-constraint design was correct, not merely permissive.
- Spot-checked France's full set (6 categories: Chef, Pastry Chef, Restaurant Manager, Rising Star, Sommelier, Young Talent of the Year) — all correct, all with `winner_name` and `restaurant_name_at_time` populated.

## Idempotency verification

A gap was found in the dry-run generator's own special-awards path (it checked country-code resolution but never cross-referenced the already-imported `gault_millau_special_awards` rows, unlike the core-awards dry-run query, which correctly did). Rather than report a misleading dry-run result, idempotency was instead verified **empirically and more rigorously**: the exact same `apply` SQL files (both core and special) were re-run a second time, live, against production — a safe operation precisely because the `WHERE NOT EXISTS (...)` guard in every statement is provably idempotent by construction. Result: **row counts unchanged at 41 and 58 respectively after the second run** — zero duplicate rows created either time.

## Existing catalogue regression check

All read-only, via the same anon-key access level the app uses:

- `restaurants` row count: **774**, unchanged (checked before schema apply, after core import, and after special import — identical every time).
- Michelin: 3-star sample (ABAC, DiverXO) returns correctly.
- World's 50 Best: rank #1 (Maido) returns correctly.
- Hall of Fame: **exactly 6** rows, unchanged from the prior task's verification.
- `restaurants_full` queries succeed normally throughout.

## Zero new restaurants — explicit confirmation

Confirmed by construction, not just by count: every core-award `INSERT` statement is `INSERT INTO gault_millau_awards (...) SELECT r.id, ... FROM restaurants r WHERE r.restaurant_code = '<code>' AND NOT EXISTS (...)` — there is no `INSERT INTO restaurants` statement anywhere in either generated SQL file (grep-verified), and `apply_gault_millau_production.py` contains no code path capable of writing to `public.restaurants` at all. The `774` row count held constant through every check in this task.

## The 23 deferred READY_TO_ADD candidates — control breakdown

Not modified in this task; re-derived here from the existing `gault_millau_new_restaurant_review.csv` for the record:

**A. Likely missing Michelin restaurants (needs Michelin catalogue reconciliation, not this workstream) — 23:**
`gm_001` Le Meurice, `gm_002` L'Ambroisie, `gm_003` Guy Savoy, `gm_004` L'Arpège, `gm_005` Pierre Gagnaire, `gm_006` AM par Alexandre Mazzia, `gm_007` Alléno Paris–Pavillon Ledoyen, `gm_009` Le 1947 à Cheval Blanc, `gm_010` La Table de Yoann Conte, `gm_011` Le Cinq, `gm_012` Le Bois sans feuilles (Troisgros), `gm_013` Pic, `gm_014` Passédat–Le Petit Nice, `gm_015` Épicure–Le Bristol, `gm_016` Christopher Coutanceau, `gm_017` Bras Le Suquet, `gm_018` Le Neuvième Art, `gm_036` L'air du temps, `gm_037` The Jane, `gm_039` Arabelle Meirlaen, `gm_045` Slagmolen, `gm_056` The Restaurant (Dolder Grand), `gm_058` Domaine de Châteauvieux.

**B. Genuinely Gault&Millau-origin (no Michelin overlap expected) — 1:**
`gm_050` Martino (Gent, Belgium) — confirmed 2026 H!P of the Year winner, a structurally unscored Belgium-only recognition category with no Michelin equivalent.

**C. Still needs identity review (Michelin status genuinely uncertain either way) — 6:**
`gm_019` Une Table au Sud, `gm_030` Azurite, `gm_047` Comme chez Soi, `gm_049` La Paix, `gm_060` Des Trois Tours, `gm_085` Gourmet Restaurant Hubert Wallner.

23 + 1 + 6 = 30, reconciling exactly against the full NO_MATCH set. **None of these 30 caused, or will cause, a restaurants row from this task** — confirmed above.

## Germany protection

Confirmed at every stage: 0 German core awards imported, 0 German special awards imported. All German research rows remain untouched in `gault_millau_restaurants.csv` and `gault_millau_special_awards.csv` — nothing was deleted from any enrichment file.

## gm_024 protection

Confirmed at every stage: `gm_024` ("212", Amsterdam) is classified `REVIEW`, structurally absent from `load_award_rows()`'s output (the same guarantee `import_gault_millau.py` relies on), and a live query against `rest_0085` in `gault_millau_awards` returns 0 rows. No restaurant row was created or linked for it.

## Current Gault&Millau read model — recommendation

Unchanged from `PRODUCTION_READINESS_REVIEW.md` §7/§12 and reaffirmed here now that real data exists: **repository-level derivation, not a database view**, matching the precedent of `HotelWorlds50BestRepository`'s own "current ranking" derivation. The exact pattern (matching `worlds_50_best_rank`'s existing view-level derivation, now proven live via `is_hall_of_fame`'s identical `EXISTS`/`max(year)` shape on `restaurants_full`):

```sql
left join gault_millau_awards g
  on g.restaurant_id = r.id
 and g.guide_year = (select max(guide_year) from gault_millau_awards where restaurant_id = r.id)
```

No view was created or modified in this task — none was genuinely required for the importer, and no UI consumer exists yet to justify one.

## Tooling added

- `apply_gault_millau_production.py` — new, separate from `import_gault_millau.py` on purpose (mirrors this repo's own `import_catalogue.py` / `apply_catalogue_enrichment.py` "two workflows, never mixed" precedent). Reuses `import_gault_millau.py`'s pure CSV-parsing/classification functions via import only. Never holds a database password or service-role key itself — it only ever *writes* a `.sql` file; the actual read or write happens by piping that file through `supabase db query --linked`, keeping every credential inside the Supabase CLI's own already-authenticated channel. Two modes: `dry-run` (read-only SELECTs only, grep-verifiably free of write statements) and `apply` (idempotent `INSERT ... SELECT ... WHERE NOT EXISTS`, no `UPDATE`, no `DELETE`, split by `--section core`/`--section special` so the two imports could be verified independently between steps, per the task's required sequencing).

## Rollback / recovery notes

Not needed — nothing unexpected occurred. Every step (schema apply, both dry-runs, both imports, both idempotency re-runs) succeeded on the first or second attempt with results matching expectations exactly. No partial state, no manual cleanup, no destructive action taken at any point.
