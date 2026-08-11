# Gault&Millau — Proposed Data Model

**Status: design for review. Migration prepared (`supabase/migrations/20260811120000_create_gault_millau_awards.sql`), NOT applied anywhere.**

## Why not the task's own illustrative example, verbatim

The task suggested something like a single `gault_millau_awards` table with `score`, `toque_count`, `distinction/category` as one flat set of columns — and explicitly said not to treat that as mandatory. Research surfaced three concrete reasons a single flat table would misrepresent real data:

1. **France's "Toques d'Or" (Gault&Millau Academy, ~10 restaurants) have no numeric score by design** — not a data gap, a structural feature of the system. A `score numeric not null` column would be actively wrong for these rows.
2. **Germany abolished numeric scoring entirely in 2022.** Every German restaurant has toques only, permanently. Any schema assuming a universal 0–20 score across markets breaks on Germany specifically.
3. **Germany's toques also carry a colour tier (red vs. black) at the same count** — a 5-red and a 5-black restaurant are not equally ranked in Germany's own system. This is a genuinely separate fact, not a formatting detail, and none of the other 5 markets researched publish an equivalent distinction.
4. **Belgium's H!P (and Switzerland/Croatia's POP) is a structurally separate, permanently unscored casual-dining selection** — not a lower tier of the same scored guide, a different list entirely, with its own URL namespace on Belgium's own site (`/en/hip/` vs `/en/restaurants/`).

## Two tables, not one

### `gault_millau_awards` — core restaurant recognition, one row per restaurant per guide_year

Mirrors `worlds_50_best`'s shape (annual snapshot, current = `max(guide_year)` per restaurant, rows never overwritten) rather than `award_history`'s (`is_current` flag) — Gault&Millau publishes one full annual edition per market, matching `worlds_50_best`'s model more closely.

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid primary key` | |
| `restaurant_id` | `uuid not null references restaurants(id) on delete cascade` | Hard FK — mirrors `worlds_50_best.restaurant_id`. **Only a matched restaurant can have an award row.** A new candidate stays in `gault_millau_new_restaurant_candidates.csv` until it's actually added to `restaurants` and gets a real id — exactly the same discipline used for the World's 50 Best Hotels expansion. |
| `guide_year` | `smallint not null` | The edition year, e.g. 2026. |
| `score` | `numeric(3,1)`, nullable, `check (0-20)` | Independently nullable — never derived from toque_count. |
| `toque_count` | `smallint`, nullable, `check (0-5)` | Independently nullable — never derived from score, even though an official score→toque mapping exists for most markets researched (see below). |
| `toque_colour` | `text`, nullable, `check (black/red)` | Germany-only distinction. Null everywhere else. |
| `recognition_type` | `text not null default 'scored'`, `check (scored / unscored_top_tier / unscored_casual)` | See below. |
| `distinction_label` | `text`, nullable | Free text for a named tier worth preserving verbatim ("Toques d'Or", "Tables d'exception", "H!P of the Year 2026") — never parsed back into score/toques. |
| `gault_millau_url` | `text`, nullable | The restaurant's official G&M profile page for this edition — a real, useful display field (like `michelin_url`/`website_url` on `restaurants`), not just provenance. |
| | `unique (restaurant_id, guide_year)` | One row per restaurant per year. |

**On not deriving toques from score, despite finding an official mapping:** the task's own instruction is explicit — "Do not derive toque count from numeric score unless Gault&Millau officially defines that mapping for the relevant market." Research *did* find a consistent, officially-published mapping (10-10.5=0, 11-12.5=1, 13-14.5=2, 15-16.5=3, 17-18.5=4, 19-19.5=5), corroborated by live data in every market checked — but with a caveat serious enough to keep the columns independent anyway: (a) it's confirmed published on the France/international/Austria arms specifically, but NOT independently confirmed as separately republished on the Netherlands or Belgium country domains themselves; (b) the Netherlands' own news post describes a boundary that doesn't cleanly match the international table (12-12.5→1 toque, not 11-12.5→1), an unresolved discrepancy; (c) it doesn't apply to Germany at all (no score) or to France's Toques d'Or (no score). Storing both independently, populated only from what was actually published per-restaurant, is the only choice that doesn't risk silently overwriting a real discrepancy with an assumption.

**`recognition_type` — why three values, not a boolean "is_scored":**
- `scored` — the default case, a numeric score (and usually a toque count) was published.
- `unscored_top_tier` — France's Toques d'Or. The *highest* tier, deliberately removed from scoring — must never be confused with a missing/low-quality row.
- `unscored_casual` — Belgium's H!P / the POP pattern. A parallel, continuously-updated casual list, structurally separate from the main scored guide.

Distinguishing these three matters because "no score" means three different things depending on which one applies, and collapsing them into a single nullable `score` column with no type flag would make "no score" ambiguous between "top honour" and "casual list" and "data not found."

### `gault_millau_special_awards` — editorial awards, separate table

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid primary key` | |
| `restaurant_id` | `uuid references restaurants(id) on delete set null` | **Nullable.** An award winner's restaurant may not exist in the Chasing Stars catalogue yet. `ON DELETE SET NULL`, not `CASCADE` — removing a restaurant must never silently delete the historical fact that someone won an award there. |
| `country_code` | `char(2) not null references countries` | Kept even though `restaurant_id` usually implies a country, because `restaurant_id` can be null — this is then the only reliable market scope. |
| `guide_year` | `smallint not null` | |
| `award_category` | `text not null` | **Open vocabulary, not a fixed enum.** Confirmed by research: award taxonomy is not standardized globally — France's "Grand de Demain de l'Année" and Czechia's "Young Talent of the Year" are recognisably the same *kind* of honour but never the same string. A CHECK-constrained enum would misrepresent this. |
| `award_category_local_name` | `text`, nullable | Original-language name, e.g. "Cuisinier de l'Année". |
| `winner_name` | `text`, nullable | Person's name. |
| `restaurant_name_at_time` | `text`, nullable | Free text, in case the linked restaurant later changes name/closes — preserves what was actually announced. |
| `gault_millau_url` / `source_url` | `text`, nullable | |

**No uniqueness constraint.** Confirmed necessary: Switzerland's "Entdeckung des Jahres" (Discovery of the Year) has multiple simultaneous winners; Belgium runs three regional "Young Chef" winners (Flanders/Wallonia/Brussels) in one edition. A `unique(country_code, guide_year, award_category)` constraint would be actively wrong, not merely unused.

**Why separate from core recognition, beyond the task's own instruction:** a restaurant can hold zero G&M score/toques in a given market/year and still have staff who won a personal award that year (a sommelier moving between restaurants, for instance) — these are facts about a *person's* year, only sometimes anchored to a specific restaurant, never a restaurant's own guide placement.

## Historical principle — how "current" would be derived

Neither table has an `is_current` flag. Exactly like `worlds_50_best_rank` on `restaurants_full` (`left join worlds_50_best w on w.restaurant_id = r.id and w.year = (select max(year) from worlds_50_best where rank is not null)`), a future `restaurants_full` exposure of "current Gault&Millau standing" would follow the identical pattern: join on `guide_year = (select max(guide_year) from gault_millau_awards where restaurant_id = r.id)`. **This view change is not part of this migration** — it's a natural next step once real data exists, following the exact precedent already set for World's 50 Best (restaurants) and World's 50 Best Hotels, not invented fresh here.

No row is ever overwritten. A restaurant's 2024, 2025, and 2026 scores all remain three separate rows, permanently — this is what makes "how has this restaurant's G&M score moved over time" a real, answerable query rather than a lost fact, and is also, per research, information the *live Gault&Millau sites themselves don't expose* (no historical archive was found on any official market site) — meaning if Chasing Stars builds this, it becomes strictly more complete than the source's own website for this specific question.
