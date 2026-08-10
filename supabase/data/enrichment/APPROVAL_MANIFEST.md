# Approval Manifest

Catalogue enrichment workstream — verification pass, 2026-08-07. This manifest is the merge-readiness classification for every proposed row across all six datasets in `supabase/data/enrichment/`. **Nothing listed here has been applied to `supabase/data/*.csv`, any migration, or any database.**

---

## How rows were classified

**GREEN — safe to merge automatically.** Additive, does not change any currently-live award value (`michelin_stars`, `michelin_keys`), does not create a new catalogue row, `confidence = high`, `status = proposed`. Historical `award_history`/`worlds_50_best` rows qualify for GREEN even at high confidence because they never touch `is_current` or the live star/Key value on `hotels`/`restaurants` — they're pure historical record, invisible to every existing query until a human deliberately reads history.

**AMBER — can probably be merged but deserves human review.** Either `confidence = medium`, or the row is factually sound but touches something worth a second pair of eyes (an address correction, a property-name resolution) without being award-bearing.

**RED — do not merge.** Any row that would change a currently-live `michelin_stars`/`michelin_keys` value, any row that creates a new venue (structurally incomplete without independently-verified coordinates — the schema requires `location NOT NULL`), any `status = unresolved` row, and any `confidence = low` row on a sensitive field.

Rows with `status = rejected` (investigated, no change needed) are excluded from all three counts — there is nothing to merge, and nothing pending. Review files (`worlds_50_best_review.csv`, `restaurant_history_unresolved.csv`, `hotel_history_unresolved.csv`) are excluded for the same reason — they were never proposals.

---

## GREEN — exact row counts by dataset

| Dataset | GREEN rows |
|---|---|
| P0 corrections | **0** — see note below |
| World's 50 Best history (incl. Hall of Fame status) | **736** (726 ranking rows + 10 Hall of Fame inductions, all `confidence = high`) |
| Restaurant MICHELIN history | **120** |
| Hotel MICHELIN Key history | **6** |
| Restaurant field enrichment | **108** |
| Hotel field enrichment | **41** |
| **Total GREEN** | **1,011** |

**P0 corrections deliberately contribute zero GREEN rows.** Every P0 item touches an award value, a new venue, an address, or a coordinate on a product whose own architecture documentation states an award value "is the product" and "the one error this product cannot afford." None of that category is being classified as auto-mergeable, regardless of confidence. See the P0 breakdown below.

## No GREEN dataset contains future-dated information

Checked explicitly, per the instruction. **None of the 1,011 GREEN rows reference a state that hasn't happened yet.** La Paix's future Corinthia-hotel link, Kyo Seika's uncertain reopening, and every other timing-sensitive item are P0-classified and sit in RED or `unresolved` — none reached the GREEN bucket. World's 50 Best history and the two MICHELIN history datasets are entirely retrospective (`guide_year`/`year` in the past, `is_current = false` throughout). Field enrichment (websites, MICHELIN URLs, cuisine) is static factual data with no time dimension.

---

## AMBER — exact row counts by dataset

| Dataset | AMBER rows |
|---|---|
| P0 corrections | 7 |
| World's 50 Best history (incl. Hall of Fame) | 37 (36 ranking rows + 1 Hall of Fame, `confidence = medium`) |
| Restaurant MICHELIN history | 54 |
| Hotel MICHELIN Key history | 30 |
| Restaurant field enrichment | 45 |
| Hotel field enrichment | 47 |
| **Total AMBER** | **220** |

---

## RED — exact row counts by dataset

| Dataset | RED rows | Composition |
|---|---|---|
| P0 corrections | 58 | 27 proposed rows that change a star/Key value or create a new venue + 31 `unresolved` rows |
| World's 50 Best history | 0 | — |
| Restaurant MICHELIN history | 3 | 1 `low`-confidence proposed row + 2 `unresolved` (ABaC 2018, Crissier 1975 — see `verification/historical_award_conflicts.md`) |
| Hotel MICHELIN Key history | 1 | Borgo Santo Pietro (`hotel_history_unresolved.csv`) — pre-2025 tier unconfirmed |
| Restaurant field enrichment | 0 | — |
| Hotel field enrichment | 5 | 4 `low`-confidence `booking_url` rows (homepage-with-widget, kept proposed but low-confidence) + 1 `unresolved` (Four Seasons Otemachi, unverified guessed URL) |
| **Total RED** | **67** | |

**Excluded from all three counts (informational, not merge candidates):** 9 P0 `rejected` rows, 8 hotel-field `rejected` booking_url rows, 908 World's 50 Best `worlds_50_best_review.csv` rows (unmatched/closed/ambiguous — by design, never proposals), 5 restaurant history + 1 hotel history unresolved-file rows already reflected above.

---

## What changed in this pass vs. the prior review report

- `p0_corrections.csv` grew from 68 to 74 rows (6 new: La Brezza star correction, Central Park coordinate fix, ABaC coordinate flag, Torre del Saracino, Il Piccolo Principe, Tre Olivi star correction).
- `restaurant_award_history.csv`: 2 rows (ABaC 2018, Crissier 1975) downgraded `proposed → unresolved` per the historical-conflict review.
- `hotels_3key_fields.csv`: 8 `booking_url` rows downgraded `proposed → rejected` (homepage-only, no confirmed booking mechanism), 1 downgraded `proposed → unresolved` (unverified guessed URL), 4 kept `proposed` with a confirmed-widget note added to their evidence.
- 3 new `verification/` files created for the shared-Place-ID audit, and 4 more for the remaining verification items.

No file outside `supabase/data/enrichment/` was touched to produce this manifest.
