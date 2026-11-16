# The 50 Best Restaurants 2026 — catalogue import (2026-11-16)

Status: **PREPARED — NOTHING APPLIED.** Waits on the product owner's approval.

## What and why

The 2026 list (announced 2026-11-05 in Lima) is not in production yet:
`worlds_50_best` stops at 2025, so the app, the Guides and the hidden site
still show 2025 as current. The same pass closes the one known gap in the
2025 list (no rank 94, QA-194).

From 2026 the organisers publish it as **"The 50 Best Restaurants"** (their
Best of the Best page: "from 2026, the annual list of The 50 Best
Restaurants"). Same list, same 1–100 shape; see QA-475 for the label question.

## Source

Only the official site, `the50.com` (`theworlds50best.com` redirects there),
read in a browser on 2026-11-16:

| What | URL |
|---|---|
| 2026, 1–50 (each entry links its own venue page) | https://www.the50.com/restaurants/best-in-the-world/list/1-50 |
| 2026, 51–100 (no venue links on the list) | https://www.the50.com/restaurants/best-in-the-world/list/51-100 |
| Best of the Best (hall of fame) | https://www.the50.com/restaurants/best-in-the-world/best-of-the-best |
| 2025 full list (for No. 94) | https://www.the50.com/restaurants/best-in-the-world/previous-list/2025 |

Both 2026 pages carry the same 100 entries; 100 distinct ranks. Capture:
`_source/official_restaurants_2026_1-100.csv`. No. 1 is Asador Etxebarri,
Atxondo, matching what CNN/CNBC reported.

## Result

| | Count |
|---|---|
| 2026 entries | 100 |
| Matched to an existing catalogue row | **92** (49 of 1–50, 43 of 51–100) |
| Not in the catalogue | **8** (QA-473) |
| Lookups returning a wrong record | 0 |
| Hall of fame 2026 | Maido (rest_0134, PE) — 2025's No. 1 |
| 2025 No. 94 | Meet the Bund (rest_2739, CN) — added |

Per-entry detail with source URL, catalogue code + country and match basis:
`w50b_2026_matches.csv`.

### How entries were matched

Names were used only to find candidates. A match was accepted on one of:

- **prior_rank_row (80)** — the candidate row already carries 50 Best ranks
  (almost all 2025), and the city and country are the same. That identity
  was settled when those ranks were loaded.
- **address (12)** — no earlier rank on the row, so the address on the
  official 50 Best page (venue page for 1–50, the50.com discovery page for
  51–100) was compared with the catalogue address: Meet the Bund, Le
  Coquillage, Ru Yuan, Le Louis XV, Ling Long, Caprice (whose 2013/2014
  ranks are on the row), The Ledbury, Eliane, FZN, Lamdre. Two carry a
  source discrepancy, logged as QA-474: Ling Long (50 Best's location field
  says 57 South Shanxi Road, but its own text and MICHELIN place it in the
  Waldorf Astoria on the Bund, as the catalogue does) and Lamdre (Room 01
  against the catalogue's Room 04, same block and courtyard).

Look-alikes ruled out: Wing ≠ Wing Lei (Macau); Kadeau ≠ Kadeau Bornholm;
Jan (Munich) ≠ JAN (Nice); Narisawa Tokyo ≠ Narisawa Shanghai; Huniik ≠ La
Barra de Huniik; Frantzén (Stockholm, #58) and FZN (Dubai, #88) are two
separate rows; Enigma ≠ Enigma Yorkville.

City-name differences, same place: Jordnær (official Copenhagen, catalogue
Gentofte), Willem Hiele (Oudenburg on both; its older 50 Best URL still
says Koksijde).

All 92 matched rows are `status = open`.

### Not in the catalogue (QA-473)

| Rank | Entry | Country | Proposed `inclusion_reason` |
|---|---|---|---|
| 49 | Naar, Kasauli | IN | `worlds_50_best` (no MICHELIN Guide in India) |
| 54 | Nelita, São Paulo | BR | `worlds_50_best` unless its own MICHELIN page shows a star |
| 64 | Seroja, Singapore | SG | `michelin_star` — 2 stars in the 2026-10-31 MICHELIN export; confirm on its page |
| 72 | Eatanic Garden, Seoul | KR | `michelin_star` — 1 star in that export; confirm |
| 78 | Mosu, Seoul | KR | `michelin_star` — 2 stars in that export; confirm |
| 90 | Baan Tepa, Bangkok | TH | `michelin_star` — 2 stars in that export; confirm |
| 97 | Khufu's, Giza | EG | `worlds_50_best` |
| 99 | Fauna, Valle de Guadalupe | MX | `worlds_50_best` unless its own MICHELIN page shows a star |

None was staged anywhere in the repo (all branches searched). Adding them
is a separate identity pass — address, coordinates, Place ID, city row,
MICHELIN page — the same work as the 2026-10-28 completion. Their 2026
rank rows go in with them. Until then 2026 holds 92 of 100 and the hidden
site shows those 8 ranks as "Not in our data yet".

## 2025 No. 94 (QA-194)

The official 2025 list gives **94 Meet the Bund, Shanghai**. It was held
back on 2026-10-28 because the staged record was M on the Bund, a different
restaurant. The MICHELIN China pass has since added the real one as
`rest_2739` "Meet the Bund (Zhongshan Dong Er Road)"; its address equals the
50 Best page's (S301, 3F, South Mall, The Bund Finance Center, 600 Zhongshan
Dong Er Road). The SQL adds its 2025 row (94, `extended_51_100`), which
makes 2025 complete at 100, and it gets its 2026 row (21) too. QA-194 closes
on apply.

## What the SQL does — `prepared_w50b_2026_import.sql`

One transaction, `worlds_50_best` only:

- 92 rows `year = 2026`, `list_type` `top_50` (1–50) / `extended_51_100` (51–100);
- 1 row `year = 2026`, `list_type = 'hall_of_fame'`, rank NULL: Maido — the
  same convention as 2025 (Disfrutar) and 2024 (Central): one row in the
  year the restaurant enters;
- 1 row `year = 2025`, rank 94: Meet the Bund.

Every row is resolved on `restaurant_code` + `country_code`. Guards abort if
2026 rows or 2025 No. 94 already exist, if any staged code fails to resolve,
or if rank and list type disagree. Post-checks: 49/43/1 for 2026, 100 ranked
for 2025, 92 current ranks in `restaurants_full`, Etxebarri current No. 1,
Maido hall of fame.

No restaurant, award_history or schema change. No migration.

### How "current" moves to 2026

`restaurants_full.worlds_50_best_rank` joins the row whose year is
`max(year) where rank is not null`. The moment this commits, 2026 is
current: 92 restaurants show a 2026 rank, and the 17 ranked in 2025 but not
in 2026 (Sézanne, Table by Bruno Verjus, Lido 84, Orfali Bros, Pujol,
Quique Dacosta, Tantris, Mountain, Leo, Oteque, A Casa do Porco, The
Clove Club, Mugaritz, Le Bernardin, Atelier Crenn, César, Amisfield) no
longer show a current rank; their history rows stay and Award History
still lists them. Maido moves to the hall of fame.
`is_hall_of_fame` is true for any row with a hall-of-fame entry, so Maido
gains it. The app's 50 Best guide reads the years in the table, so 2026
appears in its year selector; the hidden site picks the newest year on its
next build. No code change needed.

## Tested, and not

- **Tested:** the SQL on a local Supabase stack replayed from every
  migration in the repo (`supabase start` on a scratch copy without
  `.temp/`), seeded with production's own rows for the 172 restaurants
  involved, their cities and hotel links, and the whole `worlds_50_best`
  table (975 rows). Result recorded in `LOCAL_TEST.md`.
- **Not tested:** against production itself (only after approval). The
  8 missing restaurants are not researched beyond the list and the
  MICHELIN export.
