# Gault&Millau — Final Production-Readiness Review

Reviewed: 2026-08-11. **Status: REVIEW COMPLETE. Nothing applied to production.** This supersedes the numbers in `FINAL_REPORT.md` where they differ (match classifications changed during this review — see §4).

---

## 1. Schema review

`supabase/migrations/20260811120000_create_gault_millau_awards.sql` + `SCHEMA_DESIGN.md` checked line by line against the 12-item requirement list. All confirmed correct **except one gap, now fixed** (RLS, see below):

| Requirement | Supported by |
|---|---|
| `restaurant_id` | `gault_millau_awards.restaurant_id`, hard FK |
| `guide_year` | both tables |
| market/country | `gault_millau_special_awards.country_code`; `gault_millau_awards` gets it transitively via `restaurant_id → restaurants.country_code` |
| numeric score where published | `gault_millau_awards.score`, independently nullable |
| toque count where published | `gault_millau_awards.toque_count`, independently nullable |
| toque colour where relevant | `gault_millau_awards.toque_colour` (`red`/`black`, Germany-only, null elsewhere) |
| unscored distinctions (Toques d'Or) | `recognition_type = 'unscored_top_tier'` |
| Belgium H!P-style recognition | `recognition_type = 'unscored_casual'` |
| Germany red/black if added later | `toque_colour`, already present and populated in the collected data, just not yet imported (Germany deferred, §3) |
| official/source URL | `gault_millau_url` on both tables; `source_url` on special awards |
| provenance | carried in the CSVs (`source_url`, `retrieval_date`, `confidence`), not duplicated into the schema itself — consistent with how `award_history`/`worlds_50_best` also carry no provenance columns |
| multiple annual editions | `UNIQUE(restaurant_id, guide_year)`, one row per year, never overwritten |
| historical preservation | same — no `UPDATE` path exists anywhere in `import_gault_millau.py` |

**Confirmed: the schema does NOT assume score→toque conversion.** Both columns are populated only from what was independently published per restaurant; no code path derives one from the other (verified by re-reading `import_gault_millau.py`'s `_parse_toques`/`_parse_score` — two separate functions, never call each other, never touch the same source column).

**Gap found and fixed:** the original migration draft had **no Row Level Security at all** on either table — `DATABASE_ARCHITECTURE.md` §15.2 requires every catalogue table to enable RLS with a public-read-only policy (without it, the `anon` key embedded in the Flutter binary could write directly to the table). Added during this review (migration §3, see below); re-verified via a rolled-back local transaction — `relrowsecurity = true` on both tables, exactly one `SELECT`-only policy each, confirmed via `pg_policies`.

## 2. Two-table model review

**Confirmed correct, unchanged.** `gault_millau_awards` (core recognition, one row per restaurant per year) vs `gault_millau_special_awards` (Chef of the Year and similar) remain the right split:

- A restaurant's core recognition is a fact about *the restaurant*, always resolvable to a `restaurant_id`, one row per year, uniqueness-constrained.
- A special award is a fact about *a person's year*, sometimes only loosely tied to a restaurant (a sommelier who moves between jobs), confirmed to have genuine multi-winner years in real data (Switzerland's Discovery of the Year, Belgium's 3 regional Young Chef winners) — which is exactly why it has no uniqueness constraint and why forcing it into the same table as core recognition would either fabricate a fake restaurant tie or break the `UNIQUE(restaurant_id, guide_year)` constraint outright.
- Special awards never distort the primary catalogue: `gault_millau_special_awards.restaurant_id` is nullable and every import row currently sets it to `NULL` (see §10) — a special award can never silently attach itself to the wrong restaurant, or to any restaurant at all, without a deliberate future decision.

## 3. Launch market decision

**Confirmed as specified: INCLUDE France, Belgium, Netherlands, Switzerland, Austria. DEFER Germany.** Reasoning unchanged from the original research (`research_dach.md`): no live 2026 German edition, site down (SSL error), unresolved licensing dispute with no successor publisher named, and a structurally incompatible scoring system (no numeric score at all since 2022) even once the site returns. German rows are fully preserved in `gault_millau_restaurants.csv`/`gault_millau_special_awards.csv` — nothing was deleted — and `import_gault_millau.py` now excludes them **by default** via `DEFERRED_COUNTRY_CODES = {"DE"}`, overridable with `--include-deferred-markets` for a future re-run once Germany's situation resolves.

**Exact row counts, launch scope only (FR+BE+NL+CH+AT):**

| Market | Restaurants researched | Matchable (→ award rows) | New candidates (NO_MATCH) | Special awards |
|---|---|---|---|---|
| France | 19 | 1 | 18 | 6 |
| Belgium | 16 | 9 | 7 | 14 |
| Netherlands | 15 | 13 (+1 REVIEW, excluded) | 1 | 18 |
| Switzerland | 10 | 7 | 3 | 8 |
| Austria | 12 | 11 | 1 | 12 |
| **Launch total** | **72** | **41** | **30** | **58** |
| Germany (deferred) | 15 | 15 | 0 | 5 |
| **Grand total** | **87** | **56** | **30** | **63** |

(Verified two ways: hand-derived from `gault_millau_matches.csv`/`gault_millau_special_awards.csv`, and live via `import_gault_millau.py --dry-run` against a local dev database, which reported exactly 41 award-row inserts and 58 special-award inserts with Germany excluded, and exactly 56/63 with `--include-deferred-markets` — see §10.)

## 4. Match review

**EXACT matching rule is genuinely deterministic:** byte-identical name after Unicode/case/diacritic normalization, plus an exact city match (including the documented alias table — Wien→Vienna, München→Munich, etc. — and the "an der X"/"am X" Austrian geographic-suffix strip). No fuzzy scoring, no threshold, no randomness — the same input always produces the same classification. Re-verified by re-reading the matching logic; unchanged since the original workstream.

**Second-pass HIGH_CONFIDENCE review, using address/website/name signals** (Google Place ID was not available in the GM-side data for any of these 11, so it could not be cross-checked; noted as a limitation):

| Row | Decision | Evidence |
|---|---|---|
| gm_008 Plénitude | **PROMOTED → EXACT** | Identical address (8 Quai du Louvre, 75001 Paris), matching website domain (chevalblanc.com) |
| gm_028 GEM. | **PROMOTED → EXACT** | Identical address (Kasteellaan 1, Gemert), matching website domain (restaurantgem.com) |
| gm_053 La Brezza (Ascona) | **PROMOTED → EXACT** | Identical address; correctly distinct from gm_054's same-named restaurant in a different city |
| gm_054 La Brezza (Arosa) | **PROMOTED → EXACT** | Identical address; correctly distinct from gm_053 |
| gm_055 Restaurant de l'Hôtel de Ville de Crissier | **PROMOTED → EXACT** | Identical address, matching website domain (restaurantcrissier.com) |
| gm_077 Amador | **PROMOTED → EXACT** | Address matches except a street-abbreviation formatting difference ("Straße" vs "Str."), matching website domain (restaurant-amador.com) |
| gm_042 Hertog Jan | **NOT promoted, kept HIGH_CONFIDENCE** | Address differs (Lange Gasthuisstraat 51 vs Leopoldstraat 26). Plausibly explained by chef Gert De Mangeleer's known relocation into the Botanic Sanctuary Antwerp (the catalogue name "at Botanic" is consistent with this) — but that explanation is not independently source-cited *within this dataset*, so it was **not** upgraded on inference alone. |
| gm_062 Vendôme | **NOT promoted, kept HIGH_CONFIDENCE** | No address/website in the GM source (`gaultmillau.de` unreachable) — no corroborating signal available. Moot for this launch: Germany deferred. |
| gm_072 Rutz | **NOT promoted, kept HIGH_CONFIDENCE** | Same as above. Moot: Germany deferred. |
| gm_075 Tim Raue | **NOT promoted, kept HIGH_CONFIDENCE** | Same as above. Moot: Germany deferred. |
| **gm_024 "212" (Amsterdam)** | **DOWNGRADED → REVIEW** | **Genuine address conflict**: GM source gives Amstel 212, 1017 AH Amsterdam; catalogue gives Amsteldijk 212, 1079 LK Amsterdam — different streets, different postal codes, several km apart in Amsterdam. The name match ("212" vs "Restaurant 212") is exact, but a real address discrepancy is stronger counter-evidence than name-only agreement is confirming evidence. Not resolved here — needs a human check (e.g. comparing Google Place IDs) before any award data is written against `rest_0085`. |

No row was downgraded or upgraded to improve the statistics — each decision above cites the specific corroborating or conflicting evidence found. `gault_millau_matches.csv` was updated in place with these 7 changes (6 promotions + 1 downgrade), each with a dated note explaining the change; `validate_gault_millau.py` was re-run and confirms internal consistency (15/15 checks, 0 issues — see `CONTROL_REPORT.md`).

**Post-review tally: EXACT 52, HIGH_CONFIDENCE 4, REVIEW 1, NO_MATCH 30** (was 46/11/0/30).

## 5. New restaurant candidates

All 30 reviewed; full detail + reasoning in the new `gault_millau_new_restaurant_review.csv`.

- **READY_TO_ADD (23):** complete identity data (full street address, and/or official website) plus a confirmed Gault&Millau source and recognition. Listed in full in the CSV.
- **NEEDS_REVIEW (3):** `gm_014` (Passédat), `gm_019` (Une Table, au Sud) — address captured only as city+postal code, no street, no website; and `gm_050` (Martino) — the confirmed 2026 H!P of the Year winner, but zero address/website collected. Worth a targeted follow-up lookup, not a rejection.
- **DO_NOT_ADD (4):** `gm_047` (Comme chez Soi), `gm_049` (La Paix), `gm_060` (Des Trois Tours), `gm_085` (Gourmet Restaurant Hubert Wallner) — no address, no website, nothing beyond name+city. Real, known restaurants in some cases, but this dataset carries no identity anchor sufficient to safely create a canonical record — recommend a dedicated re-collection pass, not adding on name recognition alone.

**Important caveat surfaced during this review, not present in the original workstream:** the large majority of the 23 READY_TO_ADD candidates (Le Meurice, L'Ambroisie, Guy Savoy, L'Arpège, Le Cinq, Bras, Troisgros, Pic, and most of the rest) are widely recognized as **current Michelin-starred restaurants**. Their NO_MATCH status against the 774-row catalogue mirror most likely reflects **incomplete French/Benelux/Swiss Michelin coverage in the current catalogue**, not genuine Gault&Millau exclusivity. This is flagged per-row in `gault_millau_new_restaurant_review.csv` (`likely_already_michelin_starred` column) and carried forward as the central finding of §6 below — it changes what "READY_TO_ADD" should actually mean for most of these rows: verify Michelin status first; if already Michelin-recognized, route through the existing Michelin catalogue-expansion process instead of this workstream. Only `gm_030` (Azurite, Delft) was flagged `unsure` rather than `likely` — the strongest candidate for genuine Gault&Millau exclusivity in the batch, but not independently confirmed either way.

## 6. Existing restaurant model impact — **STOP, architectural gap found**

**Confirmed: the current `restaurants` table architecture CANNOT safely represent a Gault&Millau-only restaurant today.**

`docs/Architecture/Michelin_Database/DATABASE_ARCHITECTURE.md` §3.3:

```sql
CONSTRAINT inclusion_reason_valid
    CHECK (inclusion_reason IN ('michelin_star', 'worlds_50_best',
                                'hall_of_fame', 'bib_gourmand'))
```

`inclusion_reason` is `NOT NULL` and closed to exactly these 4 values. The document's own "Scope rule" (§3.3) is explicit: a restaurant qualifies for a row under exactly 3 conditions (a MICHELIN star, current World's 50 Best listing, or Hall of Fame membership), with `bib_gourmand` reserved for a known future case. **There is no fifth value, and no value that means "Gault&Millau recognized."**

Concretely: `INSERT INTO restaurants (..., inclusion_reason) VALUES (..., 'gault_millau')` would fail the CHECK constraint outright. The only two ways around it today would be to either (a) misuse `'michelin_star'` or `'bib_gourmand'` as a false flag — exactly what this task's brief explicitly forbids ("do not misuse Michelin-specific fields as catalogue-membership flags") — or (b) leave `michelin_stars` NULL and pick an existing `inclusion_reason` that doesn't describe the truth. Neither is acceptable.

**Per the task's own instruction, this STOPS new-restaurant insertion here.** No restaurant should be inserted from this workstream — not even the 23 READY_TO_ADD candidates by identity-completeness — until a **separate, explicitly-reviewed migration** widens `inclusion_reason`'s CHECK constraint (e.g. adding `'gault_millau'`). That migration touches the shared, production `restaurants` table used by Michelin, World's 50 Best, Guides UI, Passport, and Explore — it is cross-cutting in a way this isolated workstream's own migration is not, and is deliberately **not drafted here**. `import_gault_millau.py` correspondingly has **no restaurant-creation code path at all** — it only ever resolves an *already-existing* `restaurant_code`, by design, not as an oversight (see §10).

This also interacts directly with §5's finding: most READY_TO_ADD candidates are likely already Michelin-starred and simply missing from the catalogue — for those, the correct fix may be completing Michelin coverage (a different, existing process) rather than widening `inclusion_reason` at all. Both paths need resolving before any of the 23 candidates can move.

## 7. Current vs. historical recognition

**Confirmed: annual snapshot rows, never overwritten; current = latest applicable `guide_year` row per restaurant.** No `UPDATE` path exists anywhere in `import_gault_millau.py` — every write is an `INSERT`, gated by `UNIQUE(restaurant_id, guide_year)`.

**View vs. repository-level derivation:** recommend **repository-level derivation, not a database view, for now** — matching the precedent already set by `HotelWorlds50BestRepository` (World's 50 Best Hotels), which derives "current ranking" via a join in the Dart repository layer rather than a SQL view, even though `worlds_50_best_rank` on `restaurants_full` *does* use a view for the restaurant-side W50B case. Given Gault&Millau has no UI consumer yet (this workstream is data-only) and the exact query shape a future Guide screen needs isn't settled, building a view now would be premature — the correct future pattern (once a UI consumer exists) is a `left join gault_millau_awards g on g.restaurant_id = r.id and g.guide_year = (select max(guide_year) from gault_millau_awards where restaurant_id = r.id)`, documented in `SCHEMA_DESIGN.md` but **not built**, per the task's own "do not build the view unless clearly required."

## 8. Duplicate / constraint review

- **`gault_millau_awards`**: `UNIQUE(restaurant_id, guide_year)` prevents any duplicate. No evidence found anywhere in research of a restaurant receiving two distinct core recognitions in the same market/year — the constraint is correct as-is.
- **`gault_millau_special_awards`**: deliberately **no** uniqueness constraint — confirmed necessary, not just permissive: Switzerland's Discovery of the Year and Belgium's 3 regional Young Chef awards are real, sourced, simultaneous multi-winner cases (see `research_dach.md`, `research_netherlands_belgium.md`). A constraint here would reject real data.
- **FK/delete semantics:** `gault_millau_awards.restaurant_id` uses `ON DELETE CASCADE`, matching `worlds_50_best.restaurant_id`'s existing precedent exactly. Per `DATABASE_ARCHITECTURE.md` §4, "the catalogue is append-and-amend only... no process deletes a catalogue row" — this makes the cascade a dead path in normal operation, not a live risk, and diverging from the established precedent here would be inconsistent for no benefit. `gault_millau_special_awards.restaurant_id` uses `ON DELETE SET NULL` instead (deliberately different from the awards table) so that a restaurant's removal can never silently delete the historical fact that someone won a personal award there. Both confirmed intentional, not defaults.

## 9. RLS / client access — gap found and fixed

**Confirmed the correct principle (public read, no client write) and confirmed the original draft did not implement it.** Added to the migration during this review, directly copying the exact pattern from `DATABASE_ARCHITECTURE.md` §15.2 (`hotels_public_read`):

```sql
alter table public.gault_millau_awards enable row level security;
create policy gault_millau_awards_public_read on public.gault_millau_awards
  for select to anon, authenticated using (true);
-- (identical policy on gault_millau_special_awards)
```

**No `INSERT`/`UPDATE`/`DELETE` policy on either table** — absence of a policy is the denial, exactly as documented for every other catalogue table; only `service_role` (which bypasses RLS) can ever write here. Verified via a rolled-back local transaction: `relrowsecurity = true` on both tables, exactly the two `SELECT`-only policies present, nothing else. **Not applied to any real database.**

## 10. Import script review

All confirmed against the current `import_gault_millau.py`:

| Requirement | Status |
|---|---|
| Idempotent | Confirmed live: a second `--apply` run against a local dev database produced 0 new inserts, 41/58 `ALREADY_PRESENT` |
| Deterministic | Same CSV input always classifies to the same outcome; no randomness, no wall-clock dependency beyond `created_at` defaults |
| Dry-run support | Default behavior; `--dry-run` also accepted explicitly |
| No destructive deletion | No `DELETE` or `UPDATE` statement exists anywhere in the file — grep-verified |
| Upsert keys correct | `(restaurant_id, guide_year)` for awards; `(country_code, guide_year, award_category, winner_name, restaurant_name_at_time)` self-checked for special awards (no DB constraint backs the latter — see §8) |
| Rejects ambiguous matches | REVIEW/NO_MATCH rows have no code in `load_matchable_codes()`'s output map — structurally, not by a runtime check that could be bypassed. Re-verified after `gm_024`'s downgrade: confirmed excluded live (41 awards, not 42) |
| Creates new restaurants only from approved READY_TO_ADD rows | **Does not create restaurants at all, by design** — per §6's architectural-gap finding, no restaurant should be inserted from this workstream yet, so no such code path was built. This is deliberate, not a missing feature ("do not add features beyond what the task requires") |
| Can exclude Germany | **Added during this review**: `DEFERRED_COUNTRY_CODES = {"DE"}`, excluded by default, overridable with `--include-deferred-markets`. Verified live: default run inserts exactly 41/58 rows (Germany excluded); `--include-deferred-markets` inserts 56/63 (Germany included) |
| Logs exactly what would be inserted/updated/skipped | Confirmed — every run prints per-table `INSERT`/`ALREADY_PRESENT`/`CONFLICT`/`SKIP_UNRESOLVED_CODE` counts and full detail on any non-trivial outcome |

**Not run against production at any point** — the file has no `--target remote` option at all, not even a gated one.

## 11. Production dry-run plan (NOT executed)

Adapted from the task's example to the actual implementation built here:

1. Confirm `git status` clean of unrelated changes; confirm on the correct branch.
2. **Resolve the §6 architectural gap first** — draft and separately review a migration widening `restaurants.inclusion_reason`'s CHECK constraint, *if and only if* new-restaurant insertion is still wanted after re-checking Michelin status per §5. This is a prerequisite, not a step that can be skipped for the "matched restaurants only" launch.
3. Resolve `gm_024`'s address conflict (§4) — confirm or reject the match manually.
4. Apply `20260811120000_create_gault_millau_awards.sql` (with RLS) to a staging/production target via the normal `supabase db push` process.
5. Verify: both tables exist, both indexes exist, RLS is enabled with exactly the two read-only policies, `service_role` can still write (bypasses RLS), `anon`/`authenticated` cannot write (policy absence).
6. Run `import_gault_millau.py --dry-run` against the real target's DSN (would require deliberately adding a gated remote-target option first — does not exist today, on purpose) — review the full classification output, confirm 0 `CONFLICT`, 0 `SKIP_UNRESOLVED_CODE`.
7. Review the exact row counts against §13's control totals below — any mismatch stops the rollout.
8. Apply matched award rows only (`--apply`, Germany still excluded by default): expect 41 `gault_millau_awards` INSERTs, 58 `gault_millau_special_awards` INSERTs.
9. **New-restaurant insertion (READY_TO_ADD, post-Michelin-verification, post-§6-fix) is a separate future rollout, not bundled into this one** — inserting restaurants and inserting awards for already-matched restaurants are different risk profiles and should not share a rollout step.
10. Validate: `SELECT count(*) FROM gault_millau_awards` = 41, `SELECT count(*) FROM gault_millau_special_awards` = 58, spot-check 3–5 rows per market against the source CSVs.
11. Confirm `restaurants.michelin_stars`, `worlds_50_best`, `award_history` row counts are byte-identical before/after (this migration is additive-only and should touch nothing there) — same invariant-snapshot pattern already used by `apply_catalogue_enrichment.py`.
12. Re-evaluate Germany on its own schedule once the guide situation resolves (§3) — not part of this rollout.

## 12. Guide UI readiness (data only — no Flutter code written)

Once imported, a future Gault&Millau Guide screen would have available per restaurant (via a join on `gault_millau_awards.restaurant_id`, latest `guide_year`):

- `name`, `city_name`, `country_name`, `flag_emoji` — via the existing `restaurants_full` view, unchanged
- `score` (nullable — e.g. `18.5`) and `toque_count` (nullable, 0–5) — independently, never one derived from the other
- `toque_colour` (`red`/`black`, Germany only — not relevant to the launch scope)
- `recognition_type` — `scored` / `unscored_top_tier` / `unscored_casual`, for choosing the right badge
- `distinction_label` — free text, e.g. "Toques d'Or", when present
- `gault_millau_url` — deep link to the official profile

**Recommended card hierarchy**, consistent with how the existing Michelin-star / W50B-rank badges are already surfaced on `restaurants_full`: restaurant name primary; city/country secondary line; a single recognition badge as the tertiary highlight — "18.5 · 4 toques" for a normal scored row, "Toques d'Or" as a standalone badge with no score shown (never "— / 20"), "H!P" as a standalone badge, never a numeric one. This is a recommendation for a future implementation, not something built in this pass.

## 13. Control totals (launch scope, FR+BE+NL+CH+AT — acceptance criteria for the future import)

- **Core award rows to insert:** 41
- **Restaurants matched (EXACT + HIGH_CONFIDENCE, launch markets):** 41 (40 EXACT + 1 HIGH_CONFIDENCE — Belgium's `gm_042` Hertog Jan)
- **New restaurants to add:** 0 in this rollout (blocked by §6; 23 READY_TO_ADD once unblocked, pending Michelin-status verification per §5)
- **Special award rows to insert:** 58
- **Rows excluded due to Germany:** 15 award rows + 5 special award rows = 20
- **Rows excluded due to ambiguity/data quality:** 1 (`gm_024`, REVIEW-tier address conflict)

All 5 figures independently reproduced via a live `import_gault_millau.py --dry-run` run against a local dev database (§10) and via the CSV-only `validate_gault_millau.py` (`CONTROL_REPORT.md`) — both agree exactly.

## 14. Scope protection

Confirmed via `git status`: only files under `supabase/data/enrichment/gault_millau/` and the single migration file `supabase/migrations/20260811120000_create_gault_millau_awards.sql` were touched this review. No Flutter/`lib/` file, no Guides/Explore/Passport/navigation code, no Michelin or World's 50 Best data file, and no production Supabase connection were touched. Nothing was staged or committed from the concurrent Guides Step 2C workstream.

## 15. Final checkpoint

1. **Final schema recommendation:** approved as designed, unchanged in shape; RLS added (§1, §9).
2. **Migration changes recommended:** RLS section added (applied to the draft file, still PREPARED — NOT APPLIED); header comment updated to record the review and to explicitly note `restaurants.inclusion_reason` is out of scope for this file.
3. **Final launch markets:** France, Belgium, Netherlands, Switzerland, Austria.
4. **Germany exclusion details:** deferred — no live 2026 edition, site down, unresolved licensing dispute, structurally incompatible no-score system. 15 award rows + 5 special-award rows preserved but excluded by default (`import_gault_millau.py --include-deferred-markets` to override later).
5. **Final EXACT matches:** 52 (was 46; +6 promoted this review).
6. **Final HIGH_CONFIDENCE matches:** 4 (was 11; −6 promoted, −1 downgraded to REVIEW).
7. **New restaurants READY_TO_ADD:** 23 (by identity-data completeness) — **but blocked from insertion by the §6 architectural gap**, and most likely already Michelin-starred pending verification (§5).
8. **New restaurants NEEDS_REVIEW:** 3 (`gm_014`, `gm_019`, `gm_050`).
9. **New restaurants DO_NOT_ADD:** 4 (`gm_047`, `gm_049`, `gm_060`, `gm_085`).
10. **Expected core award rows (launch scope):** 41.
11. **Expected special award rows (launch scope):** 58.
12. **Current-recognition derivation:** annual snapshot rows, never overwritten; current = latest `guide_year` per restaurant, derived at the repository level when a UI consumer exists — no database view built now (§7).
13. **RLS recommendation:** public read (`anon`, `authenticated`) via `SELECT ... USING (true)`, no write policy on either table — added to the migration this review (§9).
14. **Import safety assessment:** idempotent, deterministic, dry-run by default, INSERT-only, structurally rejects ambiguous matches, cannot create restaurants (by design, pending §6), can exclude Germany, fully logged. Local-only — no remote/production target exists in the script (§10).
15. **Exact proposed production rollout sequence:** 12 steps, §11 — **not executed**.
16. **Final control totals:** §13 above — 41 award rows / 41 matched restaurants / 0 new restaurants this rollout / 58 special awards / 20 rows excluded for Germany / 1 row excluded for ambiguity.
17. **Guide UI data readiness:** name/city/country/score/toque_count/toque_colour/recognition_type/distinction_label/URL all available post-import; card hierarchy recommended, not built (§12).
18. **Explicit confirmation nothing was applied remotely:** Confirmed. Every database interaction in this review connected only to a local development Postgres instance (`127.0.0.1:54322`), each time cleaned up immediately after (test tables dropped, confirmed empty via `information_schema.tables`). `git status` shows only the isolated `gault_millau/` folder and the one migration file changed, all uncommitted. **No `supabase db push`, no remote connection string, no production write, no commit, no push occurred at any point in this review.**

**STOP — as instructed. Awaiting explicit further instruction before the migration is applied, data is imported, or anything here is committed.**
