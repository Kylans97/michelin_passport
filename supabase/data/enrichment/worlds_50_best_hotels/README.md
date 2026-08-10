# World's 50 Best Hotels — Research Workspace

**Status: research and local data preparation only. Nothing here has been applied to production, and no migration exists yet.**

## Files

| File | Contents |
|---|---|
| `worlds_50_best_hotels_raw.csv` | 200 rows — every published rank, 2023–2025, exactly as sourced. No production IDs. Full provenance per row. |
| `worlds_50_best_hotels_history.csv` | 34 rows — matched only, `hotel_code`-resolved, ready for the same kind of human-reviewed deployment the restaurant World's 50 Best history went through. |
| `worlds_50_best_hotels_review.csv` | 166 rows — everything not confidently matched, with an explicit reason for every single one. Nothing was silently dropped. |
| `SCHEMA_DESIGN_PROPOSAL.md` | Option A (polymorphic `worlds_50_best`) vs. Option B (new `worlds_50_best_hotels` table), full tradeoff table, recommendation. No migration written. |
| `CATALOGUE_GAPS_AND_PRODUCT_QUESTION.md` | Every missing hotel explained, and the "Key hotels only vs. Key + World's 50 Best" scope question assessed with exact numbers. No catalogue rule changed. |

## Why this exists

Chasing Stars' hotel catalogue (`hotels`, `hotels_full`) currently holds 687 Michelin Key hotels across 21 countries. World's 50 Best Hotels is a separate, non-Michelin ranking that launched in 2023. This workspace prepares the historical ranking data and the matching work needed to eventually support it in the app — without touching anything live.

## What's confirmed vs. what's a coverage gap

The single most important finding in this pass: **most of the "missing" hotels are missing because their country isn't in the catalogue's current 21-country footprint at all**, not because a specific hotel was individually evaluated and excluded. `CATALOGUE_GAPS_AND_PRODUCT_QUESTION.md` §1 explains this in full — read it before drawing conclusions from the raw match/no-match counts.

## Matching discipline

Every accepted match required country agreement plus city (or equivalent geographic/brand) corroboration — never name alone. Several near-misses were deliberately rejected despite a plausible-looking name overlap: Aman Tokyo ≠ Aman Kyoto, Hoshinoya Tokyo ≠ Hoshinoya Kyoto, Borgo Santandrea ≠ Borgo Santo Pietro, Hotel Cipriani (Venice) ≠ Casa Cipriani Milano — same brand family in three of four cases, genuinely different properties in all four. Two ties (Raffles Singapore vs. Raffles Sentosa Singapore; Splendido vs. Splendido Mare) were resolved using known, distinct branding rather than guessed — both documented explicitly in `worlds_50_best_hotels_history.csv`'s `evidence` column.

## Guardrails held

No production Supabase connection, no `db push`, no SQL against production, no Flutter changes, no current Michelin Key data touched, no migration created, nothing committed or pushed.
