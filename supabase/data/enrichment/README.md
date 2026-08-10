# Catalogue Enrichment — Review Workspace

**Status: research only. Nothing in this directory has been imported into any database.**

This directory holds the parallel database-enrichment workstream approved 2026-08-07, scoped to:

1. P0 data-quality corrections (4 critical value conflicts, 10 Place ID/identity issues, 3 confirmed-missing venues, La Paix)
2. World's 50 Best historical data (2002–2024, extended 51–100, Hall of Fame completion)
3. MICHELIN award history for the premium subset (121 current 3-star restaurants, 36 current 3-Key hotels)
4. Existing-field enrichment (`cuisine_id`, `website_url`, `michelin_url`, `booking_url`) — no new columns

**Guardrails in force for every file here:**

- No `supabase db push`, no SQL against production, no migrations.
- No changes to `supabase/data/*.csv` (the production masters) or to any file under `supabase/migrations/`.
- No changes to `lib/` (Flutter application code).
- Nothing in this directory is committed or pushed until explicitly approved.
- No historical value overwrites a current award. Every proposed row is additive or a row-level correction proposal, never applied automatically.
- No venue is matched to a historical record by name alone — see `PROVENANCE_SCHEMA.md`.
- Where a fact cannot be verified from a credible source, it is left **unresolved** in a review file rather than guessed.

## Layout

| Path | Contents |
|---|---|
| `_source/` | Read-only extracts from the production masters, used as match targets — never edited |
| `p0_data_quality/` | Corrections for the 4 value conflicts, 10 identity issues, 3 missing venues, La Paix |
| `worlds_50_best_history/` | Historical ranking rows, extended-list rows, Hall of Fame status, and the unmatched/ambiguous review list |
| `michelin_history_premium/` | Historical `award_history`-shaped rows for the 121 three-star restaurants and 36 three-Key hotels, plus an unresolved list |
| `field_enrichment/` | Proposed values for existing sparse columns, tiered 3★/3-Key → 2★/2-Key → remainder |

## Provenance

See `PROVENANCE_SCHEMA.md`. Every proposed value in every CSV here carries a source, a confidence level, and a status. A value with no traceable source is not written as a proposal — it goes in a review/unresolved list instead.

## Review checkpoint

Nothing here merges into `supabase/data/*.csv` or the database until a human reviews:

- every `confidence: low` or `status: unresolved` row,
- every ambiguous/renamed/relocated/closed match in the World's 50 Best review list,
- every P0 correction (all four are award-adjacent or address-adjacent and none is auto-applied regardless of confidence).
