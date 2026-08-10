# Hotel Catalogue Expansion — Final Decision Report

**Status: research and review only. Nothing applied, nothing decided on your behalf.**

---

## 1. The 13 specifically-missing hotels, with recommendation per hotel

**The single biggest finding of this whole pass: essentially all 12 physical hotels behind these 13 listings already hold MICHELIN Keys.** They are not test cases for a new "Key OR World's 50 Best" rule at all — they are a data-collection gap in the *existing* rule. Full detail, evidence, and per-field confidence: `phase1_13_missing_hotels.csv`.

| Hotel | Confirmed Key status | Recommendation |
|---|---|---|
| **Passalacqua** | 3 Keys (high confidence) | ADD under the existing rule |
| **Four Seasons Firenze** | 3 Keys (medium-high) | ADD under the existing rule |
| Aman Tokyo | 1 Key (medium-high) | ADD under the existing rule |
| Bulgari Hotel Roma | 3 Keys (high) | ADD under the existing rule |
| Hotel Il Pellicano | 1 Key (high) | ADD under the existing rule |
| Borgo Santandrea | 2 Keys (high) | ADD under the existing rule |
| Hotel Cipriani, Venice | 3 Keys (high) | ADD under the existing rule |
| Rosewood São Paulo | 3 Keys (high) | ADD under the existing rule |
| Hotel das Cataratas | 3 Keys (high) | ADD under the existing rule |
| Hoshinoya Tokyo | Confirmed listed, exact tier unresolved | ADD once exact tier confirmed — do not guess |
| Six Senses Ibiza | Confirmed listed, exact tier unresolved | ADD once exact tier confirmed — do not guess |
| The Tokyo EDITION, Toranomon | Confirmed listed, exact tier unresolved | ADD once exact tier confirmed — do not guess |

**None of these 12 requires the proposed scope rule to justify adding it.** They require the same address/coordinates/Place ID research pass every other catalogue addition has always required, plus (for 3 of them) one more confirmation of the exact Key tier.

---

## 2. Missing hotels grouped by uncovered country

88 distinct hotels across 26 countries/territories. Full breakdown: `phase2_country_analysis.csv`.

**23 of 26 already have confirmed MICHELIN Key coverage** — most from the October 2025 global Keys reveal. Only **Malaysia** (confirmed not yet covered), **Oman**, and **Sweden** (both unresolved in this pass) remain genuine unknowns.

This means the same reframing from §1 very likely extends to most of these 88 hotels too: the country-level gap is much more likely a data-collection lag behind MICHELIN's own October 2025 expansion than a true "these hotels lack Keys" situation. That hypothesis is not verified per-hotel in this pass — see §9.

---

## 3. Recommended country expansion order

Ranked by 2025 Top 50 representation, then total historical World's 50 Best presence — not alphabetically, not by assumed market importance:

**Tier 1 (highest current-list impact):** United Kingdom (5 in current Top 50), France (4), Mexico (4), UAE (3), Thailand (3), Hong Kong (3).

**Tier 2:** United States (2), Australia (2), Indonesia (2), Morocco (2), India (1), Maldives (1), South Africa (1), Greece (1), China/mainland (1).

**Tier 3 (confirmed coverage, lower current visibility):** St. Barthélemy, Sri Lanka, French Polynesia, Fiji, Costa Rica, Peru, New Zealand, Turkey.

**Hold — not yet actionable:** Oman and Sweden (Key-coverage status unresolved), Malaysia (no Key data exists to collect yet).

Full reasoning, including why the UK/Mexico outrank the US/France despite smaller historical totals: `phase2_country_expansion_sequence.md`.

---

## 4. Proposed final Chasing Stars hotel inclusion rule

**Not decided — this report deliberately stops short of recommending a specific rule change**, for a reason the evidence itself surfaced: almost every concrete case examined (12 of 12 in Phase 1, 23 of 26 countries in Phase 2) turns out to already qualify under the *existing* Key-only rule once properly researched. The practical next step is a data-collection expansion under the current rule, not a scope-rule change — and that data-collection pass would itself answer the scope question empirically: whatever remains genuinely Key-less after full collection is the true, evidence-based size of what a widened rule would add, rather than today's inflated placeholder number (88, or 42, or 109 depending on scope) that's really measuring "not yet researched," not "does not qualify."

**If a rule is adopted later**, the restaurant precedent's shape (`has_michelin_star OR has_worlds_50_best_history`) is directly analogous and structurally sound per Phase 3 — but should be written and evaluated only after the data-collection pass above narrows it to real candidates, not before.

---

## 5. Schema changes required to support non-Key World's 50 Best hotels

Confirmed by direct code inspection (Phase 3), not assumed:

1. `hotels.michelin_keys` — drop `NOT NULL`, keep the `CHECK (1-3)`.
2. `hotels_master.csv` / `import_catalogue.py` — add a null-handling path for `michelin_keys`, mirroring `clean_stars()`'s existing 0→NULL restaurant-side conversion.
3. `Hotel.michelinKeys` (Dart) — `final int` → `final int?`; remove the currently-dead `?? 0` fallback in `Hotel.fromJson`, which would otherwise silently turn a real null into a fake zero.
4. 6 display call sites (`hotel_hero.dart`, `passport_hotel_card.dart`, `hotel_tile.dart` ×2, `hotel_ranking_card.dart`, `add_stay_sheet.dart`) — null-guard `KeyRow`/string-interpolation usage.
5. `HotelKeysFilter` (Explore) — one new case, mirroring `RestaurantAwardFilter.worlds50Best` exactly.
6. `HotelRepository.search()` — one new filter path, mirroring `RestaurantRepository.search()`'s independent `worlds50BestOnly` handling.
7. `hotels_full` — new derived `worlds_50_best_rank` column, mirroring `restaurants_full`'s existing one.

**Already built, needs nothing:** `award_history` (already polymorphic, already accepts `'michelin_keys'`), `AwardHistoryRepository.loadMichelinHistory()` (already branches on `entityType == 'hotel'`), Wishlist, Map.

None of this has been implemented. All of it is deferred pending the rule decision in §4.

---

## 6. Proposed `worlds_50_best_hotels` schema

Unchanged recommendation from the prior report, now with exact DDL: a new, additive table, `hotel_id` as a real FK, `list_type` restricted to `top_50`/`extended_51_100` only (no Hall of Fame — confirmed none exists), unique per `(hotel_id, year)`, partial-unique per `(year, rank)`. Full DDL and reasoning: `phase4_worlds_50_best_hotels_schema.md`. Not written as a migration file.

---

## 7. Exact data that would become eligible for import

Under the **existing** Key-only rule, once independently verified (address, coordinates, Place ID, and — for 3 hotels — exact Key tier):

- 12 hotels from Phase 1 (13 listing-string entries, 2 collapsing to 1 physical property).
- A large but currently unquantified number from the 23 confirmed-coverage countries in Phase 2 — genuinely unknown until each country's actual Key selection is captured, which is exactly why this report doesn't state a number here rather than repeat the placeholder 88/42/109 figures from earlier in this workstream.

Under a **future widened** rule (only if adopted): whatever, after full data collection, turns out to have World's 50 Best history but no Key — a number this report cannot respons­ibly state today, because most of what looks like that today is actually uncollected Key data, not a real gap.

---

## 8. GREEN / AMBER / RED

**GREEN — safe to act on now, no new scope needed:**
- Individually verifying and adding the 12 Phase 1 hotels under the existing Key rule (pending address/coordinates/Place ID research).
- Beginning country-by-country Key data collection for the Tier 1/Tier 2 countries in §3, under the existing rule.
- Preparing (not applying) the `worlds_50_best_hotels` migration exactly as designed in Phase 4, once someone is ready to review it.

**AMBER — needs a human decision before proceeding:**
- Whether to adopt the widened inclusion rule at all, and in what form.
- Which country to start data collection with first, if resourcing doesn't allow the full Tier 1 at once.
- Resolving Oman and Sweden's MICHELIN Key coverage status (more research needed, not a blocker to other work).
- Whether "Amalfi" vs. "Conca dei Marini" (Borgo Santandrea) and similar city-naming discrepancies should follow MICHELIN's own city label or the W50B source's, when the two disagree.

**RED — do not do:**
- Inventing a Hall of Fame mechanism for hotels. Confirmed, twice now, that none exists.
- Writing or applying the `worlds_50_best_hotels` migration in this pass. Explicitly out of scope.
- Guessing an exact Key tier for Hoshinoya Tokyo, Six Senses Ibiza, or The Tokyo EDITION Toranomon. Left unresolved instead.
- Assuming Oman's or Sweden's Key coverage either way.
- Treating the 88/42/109 "missing hotel" counts from earlier in this workstream as the real size of a future rule's impact — per §7, they aren't, and restating them without that caveat would mislead the next decision.

---

## 9. Unresolved questions requiring human decision

1. **Should the catalogue-expansion project proceed country-by-country under the existing rule first**, before any scope-rule conversation happens at all — given how much of today's "missing" picture (§1, §2) turned out to already qualify once actually researched?
2. **Exact Key tiers** for Hoshinoya Tokyo, Six Senses Ibiza, The Tokyo EDITION Toranomon — needs either a successful direct fetch of their `guide.michelin.com` pages (blocked in this environment) or a different research approach.
3. **Oman and Sweden's** MICHELIN Key coverage — genuinely unknown, not just unresolved by omission.
4. **If/when the widened rule is adopted**: does a Key-less World's 50 Best hotel need its own Hall-of-Fame-shaped safeguard against the list's much higher year-to-year volatility compared to MICHELIN Stars, or is the existing `worlds_50_best_hotels` design (no special-case beyond `top_50`/`extended_51_100`) sufficient?
5. **Borgo Santandrea's city** — "Amalfi" (W50B source, and the more recognizable name) vs. "Conca dei Marini" (MICHELIN's own listed city) — which should the catalogue use if/when this hotel is added?

---

## 10. Exact files created / changed

```
supabase/data/enrichment/worlds_50_best_hotels/catalogue_expansion/
  phase1_13_missing_hotels.csv          — new, 12 rows
  phase2_country_analysis.csv           — new, 26 rows
  phase2_country_expansion_sequence.md  — new
  phase3_architecture_review.md         — new
  phase4_worlds_50_best_hotels_schema.md — new
  PHASE5_FINAL_DECISION_REPORT.md       — new (this file)
```

Nothing outside this new subdirectory was created or modified. No `hotels_master.csv` change, no migration file, no Flutter file touched, no production connection, no commit, no push.
