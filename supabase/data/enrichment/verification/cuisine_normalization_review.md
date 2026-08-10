# Cuisine reference normalization review

The 10 cuisine names blocking restaurant field enrichment (§11 of the previous incremental-deployment report), checked against all 146 distinct cuisine values already present in the pre-enrichment catalogue — case, punctuation, singular/plural, transliteration, spelling variants, synonyms, and broader/narrower regional terms. Full per-row detail in `cuisine_normalization_review.csv`.

## Result: 7 GREEN_NEW, 3 AMBER, 0 GREEN_MAP_EXISTING, 0 RED

| Proposed name | Restaurant(s) | Classification |
|---|---|---|
| Asturian Creative | Casa Marcial (`rest_0341`) | **GREEN_NEW** |
| Creative | Disfrutar (`rest_0331`) | **GREEN_NEW** |
| Creative Seafood | Aponiente (`rest_0336`), RE-NAA (`rest_0431`) | **GREEN_NEW** |
| Kaiseki | Kikunoi Honten (`rest_0485`) | **GREEN_NEW** |
| Singaporean Contemporary | JL Studio (`rest_0463`) | **GREEN_NEW** |
| Taiwanese Contemporary | Taïrroir (`rest_0462`) | **GREEN_NEW** |
| Taizhou Chinese | Xin Rong Ji (`rest_0471`) | **GREEN_NEW** |
| French Haute Cuisine | Robuchon au Dôme (`rest_0434`) | **AMBER** |
| Italian Creative Contemporary | Casa Perbellini 12 Apostoli (`rest_0385`) | **AMBER** |
| Japanese / Edomae Sushi | Sushi Shikon (`rest_0445`) | **AMBER** |

## Why the 7 are safe

Each fits an **already-established naming pattern** in the existing 146-value table with zero exact or near-exact collision:

- **Asturian Creative** — the table already has `Catalan Creative`, `Spanish Creative`, `Dutch Creative`. A fourth `[Region] Creative` instance for a genuinely different Spanish region (Asturias ≠ Catalonia) is consistent, not redundant.
- **Creative Seafood** — the table already has `Adriatic Seafood`, `Basque Seafood`, `Dutch Seafood`, `French Seafood`. Same pattern, new descriptor.
- **Singaporean Contemporary** / **Taiwanese Contemporary** — the table already has 20+ `[Nationality] Contemporary` values. No existing Singaporean or Taiwanese instance.
- **Kaiseki** — zero word-overlap with any of the 146 existing values. Unambiguous.
- **Taizhou Chinese** — Taizhou is a specific Zhejiang region, clearly narrower than the existing `Contemporary Chinese`. Lexically resembles the Dutch-locale tag `Taiwanees` (used only for Netherlands-based restaurants throughout the table) but refers to something entirely different — flagged explicitly in the CSV as a case to **not** merge despite surface similarity, per the instruction's own example.
- **Creative** — a bare single-word tag. The table already tolerates equally generic standalone words (`Contemporary`, `Fusion`, `Seafood`, `Vegetarian`), so this isn't an unprecedented level of vagueness for this reference table.

## Why the 3 are AMBER, not GREEN_NEW

All three are real, defensible, evidence-backed cuisine descriptions — none is wrong or fabricated. Each sits close enough to an existing value that a **human, not this review, should decide** whether to keep it distinct or fold it into what's already there:

- **French Haute Cuisine** — the single most crowded cluster in the whole table (23 existing French-related values, including `Classic French`, `French Classic`, `Traditional French`, `Modern Classic French`). "Haute cuisine" is a real register, but the overlap risk here is the highest in the batch.
- **Italian Creative Contemporary** — near-identical to the existing `Italian Contemporary`, which this same research batch assigned to a *different* 3-star Italian restaurant (Da Vittorio, `rest_0379`) just a few rows earlier. That's a real signal of possible inconsistent labeling, not a confirmed one — worth a second pair of eyes rather than a guess in either direction.
- **Japanese / Edomae Sushi** — the closest structural near-duplicate of the batch: identical `Japanese / X` pattern to the existing `Japanese / Sushi`, with only the specific sushi style added. Edomae is a real, distinct traditional style, so the distinction is defensible — but so is preferring consistency with the tag already in use.

**None was force-merged and none was force-approved.** Per the instruction, accuracy took priority over getting all 10 through — 7 genuinely clear the bar, 3 do not, and no attempt was made to close that gap by guessing.

## What this changes about the deployment

The 3 AMBER restaurants' `cuisine_id` fields are **deferred**, not applied, in this pass — not blocked, not force-applied, held for a separate human decision. Everything else proceeds. See `scripts/README_IMPORT.md` for the exact resulting write counts.
