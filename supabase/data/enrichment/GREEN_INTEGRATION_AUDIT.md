# GREEN Integration Audit

Catalogue enrichment workstream — integration of GREEN-approved rows into the master catalogue, 2026-08-07. Source of truth for what qualified: `supabase/data/enrichment/APPROVAL_MANIFEST.md`. Every count below was computed from the actual resulting files, not copied from the manifest.

**Result: 1,011 / 1,011 GREEN rows accounted for. 0 AMBER integrated. 0 RED integrated. 0 P0 integrated.**

---

## 1. Where each dataset went — architecture determination

Before writing anything, `supabase/data/`, `supabase/migrations/`, and `DATABASE_ARCHITECTURE.md` were inspected to find the canonical destination for each GREEN dataset, per your instruction not to invent a parallel source of truth.

| GREEN dataset | Canonical destination | Why |
|---|---|---|
| Restaurant field enrichment | `supabase/data/restaurants_master.csv` (existing columns) | `cuisine`, `website_url`, `michelin_url`, `booking_url` are already columns on the existing master file — no new file needed, just filling blank cells. |
| Hotel field enrichment | `supabase/data/hotels_master.csv` (existing columns) | Same reasoning. |
| World's 50 Best ranking history | New `supabase/data/worlds_50_best_history.csv` | No canonical file existed for historical (pre-2025) rankings — `award_history`/`worlds_50_best` were only ever seeded from *current* master data. `worlds_50_best_hall_of_fame.csv` already establishes the project's own pattern for a supplemental historical CSV feeding a dedicated import-script function; this follows it. |
| Restaurant MICHELIN star history | New `supabase/data/restaurant_award_history.csv` | Same reasoning — no prior historical-award CSV existed. |
| Hotel MICHELIN Key history | New `supabase/data/hotel_award_history.csv` | Same reasoning. |

---

## 2. Important finding: Hall of Fame required zero new data

The manifest counted 10 Hall of Fame rows inside the 736 GREEN World's 50 Best total. Investigating where they belonged surfaced that **the existing architecture already produces this exact data correctly** — `supabase/data/worlds_50_best_hall_of_fame.csv` plus `insert_hall_of_fame()`'s `compute_induction_year()` (both pre-existing, unmodified by any enrichment workstream) already seed all 6 catalogue-resolvable Hall of Fame members whenever the import script runs.

Cross-checking the enrichment workspace's `hall_of_fame_status.csv` against the existing script's computation found **a discrepancy in 4 of the 10 GREEN rows**: Mirazur, Geranium, Central and Disfrutar were recorded with the win year itself as the induction year, but `DATA_UPDATE_PROCESS.md` §4 is explicit that induction happens "when the *following* year's list publishes" — worked examples given there ("Disfrutar won in 2024 and was elevated in 2025; Central won in 2023 and was elevated in 2024") match the *existing* script's `compute_induction_year()` exactly, not the enrichment workspace's derived values.

**Action taken: no new Hall of Fame file was created.** The existing, already-correct mechanism was left as the sole source of truth. This is not a P0 correction being smuggled in — it's recognizing this specific slice of the 736 GREEN rows was already fully and correctly covered by pre-existing architecture that predates this enrichment effort, and duplicating it with a value known to be wrong in 4 of 10 cases would have made things worse, not better.

This means the 736 GREEN "World's 50 Best" total is accounted for as **726 new file rows + 10 rows already produced correctly by pre-existing, unmodified code** — not 736 new rows written. See §10 for why this is not a shortfall.

---

## 3. Per-dataset results

### World's 50 Best history

| | |
|---|---|
| Expected GREEN | 736 (726 ranking + 10 Hall of Fame) |
| Actually integrated as new data | 726 |
| Already covered by existing architecture (no action needed) | 10 — see §2 |
| Destination | `supabase/data/worlds_50_best_history.csv` (new file) |
| Rows written | 726 |
| Rows skipped | 0 |
| `list_type` breakdown | 513 `top_50`, 213 `extended_51_100` |
| Year range | 2002–2024 (2025 explicitly excluded — already seeded separately from current master data; confirmed 0 rows with `year = 2025`) |
| Restaurants represented | 106 distinct `restaurant_code` values, all resolved against the 774-row catalogue index |
| Uniqueness | 0 duplicate `(restaurant_code, year)` pairs (matches the production `UNIQUE(restaurant_id, year)` constraint); 0 duplicate `(year, rank)` collisions (matches the production partial unique index) |

### Restaurant MICHELIN history

| | |
|---|---|
| Expected GREEN | 120 |
| Actually integrated | 120 |
| Destination | `supabase/data/restaurant_award_history.csv` (new file) |
| Rows written | 120 |
| Rows skipped | 0 |
| `award_type` | `michelin_stars` on every row |
| `guide_year` range | 1978–2025 (0 rows at 2026 — the current year, which stays exclusively owned by the existing `insert_award_history()`) |
| `award_value` domain | 1–3 on every row |
| Current `michelin_stars` on `restaurants_master.csv` | **Unchanged on all 774 rows** — verified by diff against the pre-integration backup |

### Hotel MICHELIN Key history

| | |
|---|---|
| Expected GREEN | 6 |
| Actually integrated | 6 |
| Destination | `supabase/data/hotel_award_history.csv` (new file) |
| Rows written | 6 |
| Rows skipped | 0 |
| `award_type` | `michelin_keys` on every row |
| `guide_year` range | 2024–2025 (0 rows at 2026) |
| Current `michelin_keys` on `hotels_master.csv` | **Unchanged on all 687 rows** |

### Restaurant field enrichment

| | |
|---|---|
| Expected GREEN | 108 |
| Actually integrated | 108 |
| Destination | `supabase/data/restaurants_master.csv` (existing columns, blank cells only) |
| Cells written | 108 — `cuisine` 23, `michelin_url` 43, `website_url` 42, `booking_url` 0 |
| Rows skipped | 0 |
| Overwrite guard | Every one of the 108 target cells was confirmed empty immediately before writing; 0 were skipped for already being non-empty |
| Non-enrichment columns touched | 0 (checked against all 21 other columns) |

### Hotel field enrichment

| | |
|---|---|
| Expected GREEN | 41 |
| Actually integrated | 41 |
| Destination | `supabase/data/hotels_master.csv` (existing columns, blank cells only) |
| Cells written | 41 — `website_url` 26, `booking_url` 15, `michelin_url` 0 |
| Rows skipped | 0 |
| Overwrite guard | Same as above — 0 skipped for non-empty |
| Non-enrichment columns touched | 0 |

### P0 corrections

| | |
|---|---|
| GREEN | 0 |
| Integrated | **0 — nothing was applied.** |

No P0 row was written anywhere. Explicitly reverified after integration: `rest_0240` (La Brezza) still reads `michelin_stars = 3`; `rest_0394` (Tre Olivi) still reads `michelin_stars = 2`. Neither the Château Neercanne/Central Park/ABaC coordinate proposals, nor the Torre del Saracino/Il Piccolo Principe missing-venue rows, nor La Paix's future state, were written anywhere in `supabase/data/`.

---

## 4. AMBER / RED integrated

**AMBER integrated: 0. RED integrated: 0. P0 integrated: 0.**

Every row written to `supabase/data/*.csv` was filtered by the exact rule `confidence == 'high' AND status == 'proposed'` against the *current* state of each enrichment-workspace CSV (i.e., after the verification pass's edits — the 2 downgraded historical-conflict rows and the 9 downgraded booking_url rows were correctly excluded automatically because their `status` no longer read `proposed`).

---

## 5. Validation results

All checks below were run against the actual resulting files, not asserted from expectation.

| Check | Result |
|---|---|
| Every CSV parses cleanly (2 modified masters + 3 new files) | Pass — 5/5 |
| No duplicate `restaurant_code`/`hotel_code` introduced | Pass — row counts unchanged (774 restaurants, 687 hotels) |
| Every `restaurant_code` in the 3 new files resolves against the catalogue | Pass — 0 unresolved |
| Every `hotel_code` in the new hotel file resolves against the catalogue | Pass — 0 unresolved |
| `worlds_50_best_history.csv` uniqueness: `(restaurant_code, year)` | Pass — 0 duplicates |
| `worlds_50_best_history.csv` uniqueness: `(year, rank)` where rank present | Pass — 0 collisions |
| `restaurant_award_history.csv` / `hotel_award_history.csv` uniqueness: `(code, guide_year)` | Pass — 0 duplicates in either file |
| Current `michelin_stars` unchanged (774/774 rows) | Pass |
| Current `michelin_keys` unchanged (687/687 rows) | Pass |
| Current `address`, `latitude`, `longitude`, `google_place_id` unchanged on both masters | Pass — 0 changed cells on any of these columns |
| `property_name`, `located_in_hotel` unchanged | Pass |
| `hotel_restaurant_links.csv` unchanged | Pass — 0-line diff |
| Every field-enrichment write traces to a GREEN-classified row | Pass — 0 untraceable writes on either master |
| Every field-enrichment write targeted a cell that was empty beforehand | Pass — 0 overwrites of non-empty cells |
| `import_catalogue.py` new code — syntax | Pass (`py_compile`) |
| `import_catalogue.py` new code — insert-shaping logic | Pass, tested offline against the real 3 new CSVs with a mock cursor (no database connection made; `psycopg` stubbed only so the module could be imported) |
| **Actual imported GREEN total vs. expected 1,011** | **1,011 / 1,011 — matches exactly** (726 + 120 + 6 + 108 + 41 = 1,001 new file/cell writes, plus 10 Hall of Fame rows already correctly produced by pre-existing, unmodified code — see §2) |

No discrepancy was found that required stopping. The one thing that looked like it might be a shortfall (Hall of Fame) turned out, on inspection, to be full coverage through a different, already-correct mechanism — documented in §2 rather than silently absorbed into a "matches" checkbox.

---

## 6. Files created / changed by this integration

| File | Change |
|---|---|
| `supabase/data/restaurants_master.csv` | 108 cells filled (blank → GREEN value), 774 rows unchanged in count |
| `supabase/data/hotels_master.csv` | 41 cells filled, 687 rows unchanged in count |
| `supabase/data/worlds_50_best_history.csv` | New, 726 rows |
| `supabase/data/restaurant_award_history.csv` | New, 120 rows |
| `supabase/data/hotel_award_history.csv` | New, 6 rows |
| `scripts/import_catalogue.py` | Extended: 3 new path constants, 3 new record dataclasses, 3 new loaders, 3 new insert functions, wired into `run_import()` after the existing Hall of Fame seeding step. Not executed against any database. |
| `supabase/data/enrichment/_backups/pre_green_integration_20260807/` | New — pre-integration snapshot of both master CSVs |
| `supabase/data/enrichment/GREEN_INTEGRATION_AUDIT.md` | This file |
