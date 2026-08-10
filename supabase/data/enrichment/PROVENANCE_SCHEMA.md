# Provenance schema — shared by every CSV in this workspace

Every proposed or corrected value must be traceable. These columns are mandatory on every output CSV in `supabase/data/enrichment/` (extra columns may be added per file, these may not be dropped):

| Column | Values | Meaning |
|---|---|---|
| `confidence` | `high` \| `medium` \| `low` | `high` — primary source (MICHELIN card, official venue site, theworlds50best.com archive) directly confirms the value. `medium` — a credible secondary source confirms it, or a primary source confirms it indirectly (e.g. Google Places `website` field). `low` — best available source is inconclusive or conflicting. |
| `match_method` | `code_exact` \| `code_plus_country` \| `name_proposed_unconfirmed` | How a historical or external record was tied to a catalogue row. `name_proposed_unconfirmed` is **never** used on an accepted/proposed row — it only ever appears in a review/unmatched file, per the no-name-only-matching rule. |
| `evidence_source` | free text | The specific source: a URL, "MICHELIN Guide card, retrieved 2026-08-07", "theworlds50best.com archive, 2011 list", etc. Never blank on a `proposed` row. |
| `status` | `proposed` \| `unresolved` \| `rejected` | `proposed` — ready for human review, not yet applied anywhere. `unresolved` — could not be verified; parked for manual research, value is absent or blank, never guessed. `rejected` — investigated and found not applicable (e.g. a name match that turned out to be a different venue). |

## Matching discipline (binding on every agent and script in this workspace)

1. A name may **propose** a candidate match. Only a `restaurant_code`/`hotel_code`, confirmed by cross-checking address/city/country/award tier, may **accept** one — mirrors `DATABASE_ARCHITECTURE.md` §7 ("codes decide, names may only propose").
2. If a historical venue cannot be tied to an existing `restaurant_code`/`hotel_code` with `medium` or `high` confidence, it goes in the relevant `*_review.csv` file with a reason (`unmatched` / `renamed` / `relocated` / `closed` / `ambiguous`), not into the proposed-values file.
3. Renames, relocations and closures are recorded, not silently resolved — `DATA_UPDATE_PROCESS.md` §6–7 already has a human-in-the-loop procedure for each; this workspace stops at "flagged for that procedure," it does not run it.
4. Never overwrite a current award. Historical rows are always additional rows with `is_current = false` conceptually (this workspace produces CSV rows shaped for `award_history`/`worlds_50_best`, not writes) and a real `guide_year`/`year` — never the row-creation date.
