# Michelin City Coverage & Expansion — Audit + Prepared Import

Reviewed 2026-08-12. **Status: AUDIT + CLASSIFICATION ONLY. Nothing applied to any database. No commit, no push.**

## Purpose

Every one of the 632 `LOCATION_PENDING` Belgium (105) + France (527) restaurant candidates from the prior expansion pass (`../michelin_belgium_expansion/location_pending.csv`, `../michelin_france_manual_source/location_pending.csv`) is blocked from import by `restaurants.city_id uuid not null references cities(id)` — a resolved, **existing** city row. This workstream audits their `city` field against production, designs the missing-city set, and prepares (but does not apply) a safe import. This is a prerequisite to, and separate from, per-restaurant address/coordinate resolution (the completed `../michelin_location_spike/`, whose own §29–33 recommended exactly this as its own decoupled step).

## Scope

Exactly the 632 rows in the two `location_pending.csv` files — verified by an assertion in the audit script (`Total in-scope restaurant rows: 632`). `manual_review.csv` in either folder (12 BE + 16 FR = 28 rows, `MICHELIN_STATUS_REVIEW`) is **out of scope**: those restaurants are not yet Michelin-verified, so their city labels were not audited or staged this pass.

## Results

| Metric | Count |
|---|---|
| Restaurant rows audited | **632** (105 BE + 527 FR) |
| `CITY_MATCHED` (already resolvable against production) | **147** (76 BE + 71 FR) |
| `CITY_MISSING` (need a new city row) | **485** (29 BE + 456 FR) |
| Distinct production cities matched | **9** |
| Distinct missing cities designed | **397** (73 BE + 324 FR) |
| Cities routed to `city_review.csv` (unresolved, blocked from import) | **0** |

Production coverage before this pass: 22 BE cities, 4 FR cities (Antibes, Nice, Paris, Roquebrune-Cap-Martin) — confirmed via a fresh read-only `GET` against `public.cities` at audit time. France's near-total absence of city coverage (4 rows for 527 candidate restaurants) is the main driver of the 456 FR `CITY_MISSING` rows.

## Method

1. Fetched a fresh snapshot of `public.cities` for `country_code in (BE,FR)` (26 rows, read-only PostgREST `GET`).
2. Parsed both `location_pending.csv` files (632 rows), extracting each row's `city` field.
3. Applied normalization, in order: (a) verified corrections from the completed location spike, where real research already contradicted the raw Michelin-source label; (b) a fix for two data-formatting artifacts that looked like sub-municipality parentheticals but are actually single compound municipality names; (c) the general sub-municipality/parent-city parenthetical rule; (d) a BE native→production-spelling variant map for the 4 already-anglicized production cities; (e) a leading-article capitalization fix.
4. Matched each normalized name (accent- and case-insensitive) against production; unmatched names were deduplicated into a distinct missing-city set.
5. Ran 3 targeted homonym-risk checks (see below) and folded their results back into the missing-city set as verified `region` values.
6. Wrote `apply_city_import.py`, an idempotent, dry-run classification script, and ran it twice to confirm byte-identical output.

## Data-quality findings (would have caused real errors if unfixed)

1. **`Knokke(-Heist)` / `Dilsen(-Stokkem)` — compound-name bug.** These two BE rows (`be_042`, `be_052`, `be_063`) use a parenthesis to continue a single hyphenated municipality name (`Knokke-Heist`, `Dilsen-Stokkem`), not to reference a separate parent city — distinguishable from every genuine sub-municipality case by having **no space** before `(` and the parenthetical starting with `-`. My first pass mis-split these, which would have (a) created a spurious new "Knokke" city instead of matching the **existing** `Knokke-Heist` production row, and (b) truncated "Dilsen-Stokkem" to "Dilsen". Both fixed by detecting the `X(-Y)` signature before applying the general parenthetical rule. `Knokke(-Heist)` now correctly resolves to `CITY_MATCHED` against the existing production row (id `7f38fb1d-...`).
2. **`les Arcs` casing.** One FR row's screenshot-extracted city field had a lowercase leading article; corrected to `Les Arcs` (the real commune's actual capitalization) — the only such case found across all 632 rows.
3. **Parenthetical rule, evidence-based.** Every `"X (Y)"` city string in the dataset (31 distinct instances) follows one consistent pattern: `X` (before the parenthesis) is the real municipality/sub-municipality, `Y` is a nearby better-known place added for reader orientation — confirmed against 4 independently-researched cases in the location spike (Elverdinge/Ieper, Lichtaart/Kasterlee, Sint-Kruis/Brugge, Eghezée/Liernu) before being applied project-wide. `Y` is never used for matching or city creation, and is never collapsed into an existing city row named `Y` (e.g. `Sint-Kruis` was deliberately kept distinct from the existing `Bruges` row, matching the spike's own explicit precedent).

## Spike-verified corrections carried forward

- **`fr_0017` Assiette Champenoise:** Michelin's own source label says "Reims"; the location spike independently verified (postal code 51430, address corroboration) the true commune is **Tinqueux**. Staged as `Tinqueux`, not `Reims`.
- **`fr_0043` Villa9Trois:** "Montreuil" is a genuinely ambiguous French place name (this Seine-Saint-Denis Paris-suburb commune vs. the unrelated Montreuil-sur-Mer). The spike confirmed the Seine-Saint-Denis commune via postal code 93100. Staged as `Montreuil` with `region = Seine-Saint-Denis` populated specifically to disambiguate.

## New homonym-risk checks this pass

Bare `Saint-X` names (no `-sur-Y` / `-en-Z` suffix) are the single highest-risk French commune-homonym pattern — the same class of ambiguity as Montreuil. Three such names appear in the missing set: `Saint-Germain` (`fr_0357`), `Saint-Rémy` (`fr_0265`), `Saint-Médard` (`fr_0370`). Each was checked via WebSearch against the restaurant's own Michelin Guide page, which encodes the exact department in its URL slug:

| Name | Confirmed department | Restaurant |
|---|---|---|
| Saint-Germain | Ardèche (07170) | Auberge de Montfleury |
| Saint-Rémy | Saône-et-Loire (71100) | Cédric Burtin |
| Saint-Médard | Lot | Le Gindreau |

All three staged with `region` populated to the confirmed department, exactly matching Montreuil's precedent.

## Known, honestly-stated residual limitation

The 3 targeted checks above do not constitute a full audit of all ~324 French missing-city names for homonym collisions — that would be a research effort comparable in scale to the location spike itself, out of proportion to this workstream's scope. The unique index (`cities_unique_key`, `country_code, name, coalesce(region,'')`) means an *unnoticed* homonym pair sharing an identical bare name would, if both ever entered this backlog, resolve to the **same** city row rather than erroring — a silent-wrong-match risk, not a crash risk. Mitigation, not fixed by this pass: when a restaurant's real address is later resolved (the bulk-enrichment phase recommended by the location spike), a department/postal-code mismatch against its currently-assigned city will surface immediately and can be corrected by populating `region` on that city row at that time — the same mechanism that resolved Montreuil and the 3 Saint-X cases here. **This is reported honestly per instruction, not smoothed over or treated as already solved.**

## Deliverables

- `city_coverage_audit.csv` — 632 rows, one per restaurant: raw city, canonical name, parenthetical handling, match status, matched production city id where applicable.
- `missing_cities.csv` — **397 rows**, the designed missing-city set: `country_code, name, region, restaurant_count, candidate_ids, spelling_variants_collapsed, notes`. Ready to feed `apply_city_import.py`.
- `city_review.csv` — header only, **0 rows**. No genuinely unresolved ambiguous case survived this pass's checks (see limitation above for what "unresolved" does and doesn't cover).
- `apply_city_import.py` — idempotent, dry-run-by-default classification script (`--country BE|FR`, defaults to both). Real INSERT uses `ON CONFLICT (country_code, name, coalesce(region, '')) DO NOTHING` against the table's actual unique index — safe to run twice or after a partial prior apply. Ran twice this pass, byte-identical output both times (397 candidates → 397 `INSERT`, 0 blocked). Never opened a database connection.

## Next steps (not taken this pass)

1. Human review of `missing_cities.csv` (region-population choices especially) before any real apply.
2. Real apply of `apply_city_import.py` against a local/staging database first, per this project's established review → local apply → verify → remote apply sequence.
3. Only after cities exist: resume the location spike's own recommended next step — bulk per-restaurant address/coordinate resolution (`../michelin_location_spike/SPIKE_REPORT.md` §29–33) — which is what actually makes `production_location_ready` true for these restaurants. A resolved `city_id` alone does not satisfy `restaurants.address` / `restaurants.location`, both separately `NOT NULL`.

## Safety confirmations

- **Files created:** `city_coverage_audit.csv`, `missing_cities.csv`, `city_review.csv`, `apply_city_import.py`, `CITY_COVERAGE_REPORT.md` — all new, all inside this new `michelin_city_coverage/` folder.
- **Files modified:** none. `git status --short` on `supabase/data/enrichment/` shows only untracked (new) paths, no modifications to any prior workstream's files.
- **No Flutter changes:** `git diff --stat -- lib/` is empty.
- **No schema/migration changes:** `git diff --stat -- supabase/migrations/` is empty; the schema was only read.
- **Nothing written remotely:** the only production interaction this pass was one read-only `GET` against `public.cities` (26 rows). No `INSERT`/`UPDATE`/`DELETE` was ever sent. `apply_city_import.py` was run twice, both times printing "not connected to any database in this run."
- **Nothing committed or pushed:** `git add` was never run this task.

---

**STOP — as instructed.** No cities created in production. No restaurants imported. No commit. No push.
