# World's 50 Best Restaurants — Historical Enrichment Report (2002–2024)

Research-only workstream. Nothing in this directory has been imported into any database. All matched rows carry `status: proposed` and are awaiting human review per `PROVENANCE_SCHEMA.md`.

Sourced from `theworlds50best.com/list/past-lists/<year>` (primary archive) with press corroboration (restaurantonline.co.uk, hot-dinners.com, gourmandbreaks.com, and others) for the extended 51-100/51-120 lists, retrieved 2026-08-07. Matched against `supabase/data/enrichment/_source/all_restaurants_index.csv` (774-row catalogue universe).

## 1. Years collected

**22 of 23 candidate years (2002-2024) were successfully retrieved.**

| Segment | Years | Notes |
|---|---|---|
| Top 50 | 2002-2019, 2021-2024 | 22 years, 50 restaurants each (1,100 rows) |
| Top 50 — **not available** | **2020** | The 2020 awards were formally postponed by the publisher due to COVID-19; no ranking was ever released (voting was completed but never revealed). No row was fabricated for this year. |
| Extended 51-100 | 2013-2019, 2021-2024 | 11 years found reliably (see §3) |
| Extended — **not available** | 2002-2012, 2020 | The 51-100 extended list did not exist before 2013 (verified via press archives — no extended list is referenced anywhere before the 2013 edition). 2020 has no list of any kind. |

## 2. Row counts and match rate

| Segment | Rows processed | Matched (proposed) | Sent to review | Match rate |
|---|---:|---:|---:|---:|
| Top 50 (22 years) | 1,100 | 534 | 566 | 48.5% |
| Extended 51-100/120 (11 years) | 570 | 228 | 342 | 40.0% |
| **Total** | **1,670** | **762** | **908** | **45.6%** |

- `worlds_50_best_history.csv`: **762 rows**, one per `(restaurant_code, year)` pair, verified unique (no duplicates against the production table's own uniqueness constraint).
  - Confidence: 726 `high`, 36 `medium`, 0 `low`.
  - `match_method`: all `code_plus_country` (name alone was never sufficient to accept a match, per the binding matching discipline).
- `worlds_50_best_review.csv`: **908 rows**. Breakdown by reason:
  - `unmatched` — 811 (no adequately similar catalogue candidate; includes ~148 rows where the listed country has zero restaurants in the catalogue at all, e.g. Australia, Canada, India, Russia, South Africa, Monaco — years/countries the catalogue simply does not cover).
  - `closed` — 64 (restaurant identified as permanently closed via independent corroboration — e.g. El Bulli 2011, Charlie Trotter's 2012, Taillevent 2020, Fäviken 2019, Manresa 2023, Relae 2021, Amass 2023, Combal Zero 2019, L'Astrance 2022, Coi 2023, Restaurant André 2018, Can Fabes 2013, WD~50 2014, Ultraviolet by Paul Pairet 2020, Viajante 2013, Momofuku Seiobo 2019, and repeat appearances of these across years).
  - `ambiguous` — 33 (a plausible-looking candidate exists in the catalogue but name/city similarity was judged insufficient to accept — e.g. "Masa" (NYC) vs. catalogue's unrelated "Aska"; "Sukiyabashi Jiro" (original Ginza restaurant) correctly NOT matched to catalogue's different "Sukiyabashi Jiro Roppongiten" branch; "Gaa" vs. "Gaggan" — different Bangkok restaurants; "Le Clarence", "Epicure", "Manresa", "Il Canto", "Marea", "Ishikawa", "Sushi Saito", "Spago" confirmed absent from the catalogue by direct lookup).
  - The `country_as_listed` and `notes` columns are populated on every review row; nothing was silently dropped.

The overall match rate rises steadily by year (from 3/50 in 2002 to 44/50 in 2024) because the catalogue is a curated set of restaurants with *current* stars/standing — older lists are dominated by restaurants that have since closed, relocated, rebranded, or were never covered by this catalogue's country scope (the catalogue has zero entries for Australia, Canada, India, Russia, Monaco, Ireland, Iceland, Kenya, Barbados, South Africa, Greece, Ecuador, Panama — all of which appear repeatedly across the historical lists).

## 3. Extended 51-100 list coverage by year

| Year | Extended list found? | Highest rank | Source |
|---|---|---|---|
| 2002-2012 | **No** | — | The 51-100 concept did not exist yet; verified absent from all archives searched. |
| 2013 | Yes | 100 | restaurantonline.co.uk |
| 2014 | Yes | 100 | restaurantonline.co.uk |
| 2015 | Yes | 100 | restaurantonline.co.uk |
| 2016 | Yes | 100 | gourmandbreaks.com (cross-checked against hot-dinners.com and theworlds50best.com past-lists for the top 50 to resolve a rank-18/rank-37 gap in the raw archive page) |
| 2017 | Yes | 100 | restaurantonline.co.uk |
| 2018 | Yes | 100 | restaurantonline.co.uk |
| 2019 | Yes | **120** | theworlds50best.com — one-off expansion to 51-120 (S.Pellegrino 120th-anniversary partnership) |
| 2020 | **No** | — | No list published at all (COVID postponement) |
| 2021 | Yes | 100 | theworlds50best.com |
| 2022 | Yes | 100 | theworlds50best.com |
| 2023 | Yes | 100 | theworlds50best.com |
| 2024 | Yes | 100 | theworlds50best.com |

Two minor data-quality notes on the extended lists, disclosed rather than silently smoothed over:
- The 2016 top-50 archive page had ranks 18 and 37 missing from a naive read (likely a page-rendering gap on the source site); both were recovered and cross-verified as White Rabbit (18) and Nahm (37) against two independent secondary sources before being accepted.
- The 2015 and 2016 extended lists carry one tied rank pair each (rank 65 shared by two restaurants in 2016; rank 88 shared by two in 2015) as published by the source — reproduced as-is, not renumbered.

## 4. Hall of Fame ("Best of the Best") resolution — `hall_of_fame_status.csv`

All **11 of 11** known Hall of Fame members received a derived induction year, verified rather than copied uncritically from MA-075's working assumption.

**Verification finding:** the Hall of Fame / "Best of the Best" mechanism — under which a restaurant that reaches No.1 is permanently retired from future rankings — was formally introduced in **2019**. The seven restaurants that had already won No.1 before 2019 (El Bulli, The French Laundry, The Fat Duck, Noma's 2010-2014 wins, El Celler de Can Roca, Osteria Francescana, Eleven Madison Park) were retroactively inducted at that point, since the retirement rule did not exist when they originally won. Mirazur (2019) was the first restaurant inducted immediately/live under the new rule, followed by Geranium (2022), Central (2023), and Disfrutar (2024) — each inducted in their win year.

**Noma is a documented exception**: it won No.1 a fifth time in 2021, after already being retroactively inducted in 2019 for its earlier wins. 50 Best's own ruling treated the 2021 restaurant as sufficiently different (new location, concept, and ownership since its 2016 closure/relocation) to be re-eligible. `induction_year_derived` is recorded as 2019 (primary/retroactive date, consistent with the other six pre-2019 winners) with the 2021 re-entry documented in `evidence_source`; confidence is `medium` for this one row specifically because the "one induction year" framing is inherently an interpretation of a genuinely unusual case, not a clean fact.

| Catalogue status | Count | Names |
|---|---:|---|
| `in_catalogue` | 6 | The French Laundry (rest_0735), El Celler de Can Roca (rest_0337), Osteria Francescana (rest_0078), Eleven Madison Park (rest_0045), Geranium (rest_0473), Disfrutar (rest_0331) |
| `not_in_catalogue` | 5 | El Bulli, The Fat Duck, Noma, Mirazur, Central — all independently reconfirmed absent from the 774-row catalogue via direct name/country lookup, consistent with the project's existing MA-074 finding |

All 11 rows carry `confidence: high` except Noma (`medium`, see above), `match_method` is not applicable to this file (it is not a per-restaurant catalogue match table beyond the existing 6 codes), and `status: proposed` throughout — ready for human review, nothing applied.

## 5. What was deliberately NOT done

- No rank or year was invented anywhere. Every row traces to a specific dated archive fetch, listed in `evidence_source`.
- No restaurant was matched on name alone; every accepted row required country agreement plus city/address corroboration (or, for a small curated set of 16 well-documented name/city variants — e.g. "Steirereck" vs. "Steirereck im Stadtpark", "Mugaritz" listed loosely as "San Sebastian" instead of Errenteria, "RyuGin" vs. "Nihonryori RyuGin" — a verified real-world explanation for the string mismatch, documented individually in that row's `evidence_source`).
- Genuinely different venues that merely share a name fragment were kept apart: e.g. the original Ginza "Sukiyabashi Jiro" was **not** matched to the catalogue's "Sukiyabashi Jiro Roppongiten" (a different branch); "Gaa" (chef Garima Arora) was **not** matched to "Gaggan" (different Bangkok restaurant, different chef).
