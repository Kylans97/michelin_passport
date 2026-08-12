# Michelin City Coverage — Production Import Report

Applied 2026-08-12. **Status: CITY IMPORT APPLIED TO PRODUCTION. No restaurants, awards, or recognition data touched.**

## Apply mechanism (deviation from the literal prepared-script path, approved before proceeding)

`apply_city_import.py` — like its Belgium/France/Gault&Millau siblings in this repo — only ever connects to a local Postgres DSN; none of them have ever had a remote credential, and `cities`' RLS policy (`cities_public_read`) grants `SELECT` only to `anon`/`authenticated`, so the anon key could not have written to production even if pointed at it. The only working, already-authenticated path to the real database was the Supabase CLI (`supabase db push --linked`, project `wcmxugunvwsrulcpeyrc`) — this project's own established mechanism for every prior schema/data change (12 prior migrations, all previously applied this way). Confirmed with the user before proceeding; approved.

**What was actually run:** a new migration, `supabase/migrations/20260812100000_expand_michelin_city_coverage.sql`, containing the exact `INSERT ... ON CONFLICT (country_code, name, coalesce(region,'')) DO NOTHING` logic `apply_city_import.py` already documented — same SQL, same idempotency guarantee, applied via the CLI instead of a bare script run. It runs as the Postgres role during migration apply, which is why RLS (an API-layer restriction) doesn't block it — this is expected, standard migration behavior, not a bypass introduced for this task.

## Pre-apply verification (steps 1–5)

1. **Final city dataset review:** `missing_cities.csv` = 397 rows (73 BE + 324 FR), `city_review.csv` = 0 rows, `city_coverage_audit.csv` = 632 rows (147 `CITY_MATCHED` + 485 `CITY_MISSING`) — all exactly as expected.
2. **Schema/RLS/FK verification:** `public.cities(id uuid pk default gen_random_uuid(), country_code char(2) not null fk→countries, name text not null, postal_municipality text, region text, michelin_guide_edition text)`. Unique index `cities_unique_key (country_code, name, coalesce(region,''))` confirmed live via `pg_indexes`, not just read from migration comments. Two dependents: `restaurants.city_id` and `hotels.city_id`, both `not null references cities(id)`. `countries` table confirmed to already contain `BE`/`FR`.
3. **Normalization re-check:** confirmed no spurious `Knokke`/`Dilsen` rows in `missing_cities.csv`; confirmed `Knokke-Heist`/`Dilsen-Stokkem` present/correctly routed (the former as an existing-row match, not a new insert); confirmed `Montreuil` (Seine-Saint-Denis), `Saint-Germain` (Ardèche), `Saint-Rémy` (Saône-et-Loire), `Saint-Médard` (Lot) all retained their verified `region` values.
4. **Fresh live reconciliation:** re-fetched `public.cities` for BE/FR immediately before apply — 26 rows, byte-identical to the audit's snapshot (zero drift). Classified all 397 proposed rows: **397 WOULD_INSERT, 0 ALREADY_EXISTS, 0 CONFLICT_REVIEW.**
5. **Production dry-run:** `apply_city_import.py --dry-run` → `INSERT: 397`, 0 blocked. Gate (`blocked = 0, review = 0`) passed.
6. **Extra safety step not in the original checklist:** before touching remote, ran the migration's exact SQL against the local Postgres instance inside a transaction, then rolled back — confirmed clean execution, 26→423 BE+FR rows (exact match), all 4 special-case regions correct, no spurious Knokke/Dilsen, then unconditionally rolled back (local DB left unchanged).

## Apply

`supabase db push --linked` — applied `20260812100000_expand_michelin_city_coverage.sql`. Output: `{"upToDate":false,"dryRun":false,"migrations":["20260812100000_expand_michelin_city_coverage.sql"],...,"message":"Finished supabase db push."}`.

## Remote verification (step 7)

| Check | Result |
|---|---|
| Pre-import city count (all countries) | **655** (exact count via `Prefer: count=exact`) |
| Post-import city count (all countries) | **1052** |
| Increase | **397** — exactly the proposed row count |
| Pre-import BE+FR count | 26 (22 BE + 4 FR) |
| Post-import BE+FR count | **423** (95 BE + 328 FR) |
| Belgium inserted | **73** (22 → 95) |
| France inserted | **324** (4 → 328) |
| Duplicate `(country_code, name, region)` keys among BE+FR rows | **0** |
| All city `id`s unique | **Yes** |
| `Knokke-Heist` | 1 row, **same `id`** as before apply (`7f38fb1d-...`) — untouched, not duplicated |
| Spurious `Knokke` row | **None found** |
| `Dilsen-Stokkem` | 1 new row created |
| Spurious `Dilsen` row | **None found** |
| `Montreuil` region | `Seine-Saint-Denis` ✓ |
| `Saint-Germain` region | `Ardeche` ✓ |
| `Saint-Rémy` region | `Saone-et-Loire` ✓ |
| `Saint-Médard` region | `Lot` ✓ |

## Post-import 632-candidate coverage re-run (step 8)

Re-ran the full city-coverage reconciliation from `city_coverage_audit.csv` against the fresh post-import production snapshot:

- **632 total candidates**
- **city_id resolved: 632 / 632**
- **CITY_MISSING: 0**
- **CITY_REVIEW: 0**

Target met exactly — every previously city-blocked restaurant candidate now resolves to a valid, existing `city_id`.

## Regression check (step 11)

- `restaurants` count: **774** (unchanged)
- `hotels` count: **775** (unchanged)
- Full orphan check (all 774 restaurant `city_id`s + all 775 hotel `city_id`s against the full 1052-row `cities.id` set, paginated to bypass the API's 1000-row page cap): **0 orphaned restaurants, 0 orphaned hotels**
- City row count changed by exactly the intended 397 inserts — no unexpected deltas.

## No restaurant import / no recognition changes (step 9)

- `restaurants` row count unchanged (774 before and after).
- `award_history` untouched — the migration's only statement is a single `INSERT INTO public.cities`.
- No Belgium or France Michelin candidates imported.
- La Durée / Ralf Berendsen: not read, not modified.
- No France star conflicts resolved.

## No bulk location enrichment (step 10)

Not run. Deferred to the next workstream, per instruction.

## Flutter validation (step 13)

- `git diff -- lib/`: empty.
- `flutter analyze`: **No issues found!**
- `flutter test`: **All 331 tests passed**, 0 failures.

## Files

- **New:** `supabase/migrations/20260812100000_expand_michelin_city_coverage.sql` (the applied migration).
- **New:** this report.
- Everything else relevant (`missing_cities.csv`, `city_review.csv`, `city_coverage_audit.csv`, `apply_city_import.py`, `CITY_COVERAGE_REPORT.md`) was already durable from the prior checkpoint and is unchanged by this pass.

## Rollback / recovery notes

Nothing unexpected occurred — no rollback was needed. For the record: because the migration uses `ON CONFLICT DO NOTHING`, it is safe to re-run (`supabase db push --linked`) at any point without creating duplicates. A genuine rollback, if ever needed, would require a new migration issuing `DELETE FROM public.cities WHERE id IN (...)` for the specific 397 inserted `id`s (captured in this pass's post-apply snapshot) — not a blind `DELETE` by name, since a future real restaurant/hotel import could come to depend on these rows once the location-enrichment workstream resumes.

---

**Next step, not taken here:** bulk per-restaurant address/coordinate enrichment for the 632 candidates (`../michelin_location_spike/SPIKE_REPORT.md` §29–33), now unblocked at the city layer. Not started, per instruction.
