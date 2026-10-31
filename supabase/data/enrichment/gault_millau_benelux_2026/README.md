# Gault&Millau Benelux — expansion batch 1

Written 2026-10-31. **APPLIED to production 2026-10-31** at the product
owner's explicit go-ahead: 218 rows, 41 → 259, verified row by row
afterwards (QA-377; changelog entry in
`docs/Architecture/Michelin_Database/CHANGELOG.md`). Sections 1–5 below
describe the state before the apply.

## 1. Where Gault&Millau stands today

Production (`gault_millau_awards`, read-only query 2026-10-31): **41 rows,
all `guide_year` 2026, all `recognition_type = 'scored'`** — AT 11, BE 9,
CH 7, FR 1, NL 13. `gault_millau_special_awards`: 58 rows.

| Market | Rows | score | toque_count | gault_millau_url |
|---|---|---|---|---|
| AT | 11 | 11 | 11 | 10 (Obauer NULL, QA-244) |
| BE | 9 | 9 | 9 | 9 |
| CH | 7 | 7 | 0 (Swiss pages carry no readable toques) | 7 |
| FR | 1 | 1 | 1 | 1 |
| NL | 13 | 13 | 13 | 13 |

Where they came from: `../gault_millau/` (2026-08-11). A research sample of
87 rows (the top ~15 per market taken from each site's score-sorted
listing), matched to the catalogue by a **name similarity score** plus city
(`gault_millau_matches.csv`, `name_score` column), imported with
`apply_gault_millau_production.py` (commit `f12a8ff`). Toques and the
Austrian links were completed later (QA-244, QA-245,
`../guide_source_links/`). The 41 were never a selection of the guide — they
were a top-of-the-list sample, which is why the count is small.

The tables need **no schema change** for this batch: one row per
restaurant per `guide_year`, score and toques independently nullable.

## 2. Plan — which markets first, from which sources

| Order | Market | Source (official, per-guide) | Edition used | Why now |
|---|---|---|---|---|
| 1 | NL | gault-millau.nl (875 entries online) | **2026** (launched 9 Feb 2026; 2027 launches 1 Feb 2027) | Current for 3 more months |
| 1 | LU | gaultmillau.lu (90 entries online) | **2027** (launched 26 Oct 2026: "90 restaurants et brasseries") | Online count equals the published 90 |
| 1 | BE | gaultmillau.be (1,332 entries online) | **2026** (23rd edition, launched 3 Nov 2025) | See timing note |
| 2 | FR, CH, AT | fr.gaultmillau.com, gaultmillau.ch, gaultmillau.at | — | Later batch; CH has no toques on its pages; AT has a sitemap |
| — | DE | gaultmillau.de | — | Deferred, unchanged (guide status unresolved) |

**Timing, Belgium:** the BE/LU 2027 guide launches on **9 November 2026**
(gaultmillau.be news, "9 Nov 2026 launch Gault&Millau Belux guide edition
2027"). The 2026 rows prepared here stay true as 2026 history — they are
never overwritten by a 2027 row, which is a new row (`unique (restaurant_id,
guide_year)`). The choice is the product owner's: apply BE 2026 now and add
BE 2027 after 9 Nov as a second batch, or leave BE out now and import only
2027 after 9 Nov. The SQL is split per tier, not per country; dropping BE
means regenerating from the CSV with BE filtered.

Only per-guide selections published by Gault&Millau itself are used. No
secondary-source total is used for anything; the only totals quoted are the
guides' own (908 NL at launch, 1,340+ BE, 90 LU) and they are context, not
inputs. The NL site lists 875 now against 908 at launch: the online
selection is maintained during the year (closures removed). What is
recorded is each restaurant's page as published on 2026-10-31.

## 3. Method

1. Every entry of each site's score-sorted listing was read (`_source/
   gm_listing_*.jsonl`), then every profile page (2,297 pages; parsed
   fields in `_source/gm_profiles_*.jsonl`). Score is taken from the
   page's own score block and must equal the page's schema.org
   `ratingValue` and the listing's score; toques are the count of toque
   icons in that same block and must equal the listing's count. **Toques
   are never derived from the score.** Any disagreement holds the row.
2. Each profile was compared with every NL/BE/LU catalogue row
   (`_source/catalogue_benelux_LIVE_20261031.csv`, read-only export) on
   three factual signals: **website domain**, **phone number** (last 9
   digits), **address** (postcode + house number, and for BE/LU also the
   street). G&M's map pin within 150 m of ours is used only as a
   corroborating signal — **on its own it never makes a candidate** (it
   paired Vermeer with MOS, CUE with Spectrum and Lastage with Zoldering).
3. **Names never make a match.** They are used only as a veto: a
   candidate whose name shares nothing with the G&M name is removed. This
   is what separates sibling venues that share a chef's website, phone or
   building (Goeie Louisa / Karel 5, Grand Bistro Echo / Wild Atelier,
   Sazanka and Serre / Yamazato and Ciel Bleu).
4. A code claimed by two G&M entries, or a G&M entry with two candidate
   codes, is held. The import keys on `restaurant_code` + `country_code`.
5. Restaurants not in `restaurants` are not created — listed in
   `gault_millau_benelux_2026_not_in_catalogue.csv`.

**Control.** All 22 BE/NL rows already in production were re-found by this
method and agree exactly with today's pages (score and toques, 22 of 22) —
so the method reproduces what was verified before, and the sites have not
re-scored those restaurants since August. Every G&M restaurant at 17/20 or
higher in the three markets is in the catalogue.

## 4. Result

`gault_millau_benelux_2026_staging.csv` — one row per G&M entry that touched
a catalogue row, with `source_url` (= the profile page), evidence and
decision:

| decision | rows |
|---|---|
| PROPOSE | **218** |
| ALREADY_IN_PROD | 22 (identical values, nothing to do) |
| HOLD | 45 (see `QA_LOG.md`) |

Proposed by tier (each tier is its own guarded section in the SQL):

| Tier | Evidence | NL | BE | LU | Total |
|---|---|---|---|---|---|
| A | address AND (website or phone) | 40 | 99 | 5 | 144 |
| A2 | website AND phone; our address differs from G&M's | 55 | 2 | — | 57 |
| A3 | website or phone AND map pin ≤150 m; address text differs | — | 4 | 5 | 9 |
| B | address only (no website or phone on our side to compare) | — | 6 | 2 | 8 |
| | | **95** | **111** | **12** | **218** |

After a full apply: **41 → 259** rows. Benelux coverage: of 276 NL/BE/LU
catalogue restaurants, 240 would carry a G&M row; the other 36 are listed in
`catalogue_without_gm_match.csv` (20 held for review, 16 with no G&M page —
mostly restaurants that lost their star or closed).

Toques in the proposed rows: 1×5, 43×4, 139×3, 35×2. Across all 2,297
pages the published bands are the same in all three markets — 12–12.5 → 1,
13–14.5 → 2, 15–16.5 → 3, 17–18.5 → 4, 19+ → 5, nothing listed below 12.
That settles the open NL discrepancy in `../gault_millau/
research_netherlands_belgium.md` §A2 in favour of the NL 2022 news post; it
is recorded as an observation, not used to derive anything.

## 5. Files

| File | What |
|---|---|
| `gault_millau_benelux_2026_staging.csv` | Reviewable batch, decision per row |
| `QA_LOG.md` | Held rows, catalogue findings, provisional issue list |
| `prepared_gault_millau_benelux_import.sql` | Guarded INSERT-only file, generated from the CSV |
| `dry_run_check.sql` | Read-only check against production (run 2026-10-31: 218 proposed, 218 resolve, 0 already present, 0 duplicate codes) |
| `catalogue_without_gm_match.csv` | Catalogue rows with no proposed or existing G&M row, and why |
| `gault_millau_benelux_2026_not_in_catalogue.csv` | 2,012 G&M entries with no catalogue row — not created |
| `_source/` | Catalogue export and the parsed listing/profile data |
| `tools/` | Crawl, parse, match, emit and SQL-generation scripts |

The raw HTML (≈230 MB) was not kept in the repo; `tools/crawl.sh` and
`tools/crawl_prof.sh` re-fetch it.

**Tested:** the SQL file ran on a scratch PostgreSQL 17 with the real
table definition and the 218 codes: 218 rows inserted (206 for 2026, 12
for 2027, no NULL toques); a second run aborts on the first guard with
nothing written. Not tested: RLS, the app's rendering of the new rows, and
the full production schema (the scratch had only the two tables involved).

## 6. Applying, after the go-ahead

```
supabase db query --linked --file <absolute path>/dry_run_check.sql
supabase db query --linked --file <absolute path>/prepared_gault_millau_benelux_import.sql
```

Done 2026-10-31: dry run 218/218 again, apply, then a read-only check of
all 218 rows against the staging CSV (all present, exact values, no
duplicate restaurant/year, `restaurants` unchanged). QA ids QA-377–QA-382.
No migration was needed. Re-running the file now aborts on its first guard
by design.
