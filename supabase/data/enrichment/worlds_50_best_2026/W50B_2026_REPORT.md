# The 50 Best Restaurants 2026 — catalogue import (2026-11-16)

Status: **APPLIED to production 2026-11-16** with the product owner's approval; verified there (see the Michelin_Database CHANGELOG).

## What and why

The 2026 list (announced 2026-11-05 in Lima) is not in production yet:
`worlds_50_best` stops at 2025, so the app, the Guides and the hidden site
still show 2025 as current. This pass brings 2026 in **complete, 100 of
100** — adding the 8 ranked restaurants the catalogue did not have (the
product owner's decision, 2026-11-16: add them first rather than load 92) —
and closes the one known gap in the 2025 list (no rank 94, QA-194).

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
| Added as new restaurants | **8** (`rest_4200`–`rest_4207`, QA-473) |
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
separate rows; Enigma ≠ Enigma Yorkville; Mosu Seoul ≠ Mosu Hong Kong.

City-name differences, same place: Jordnær (official Copenhagen, catalogue
Gentofte), Willem Hiele (Oudenburg on both; its older 50 Best URL still
says Koksijde).

All 92 matched rows are `status = open`.

## The 8 new restaurants (QA-473)

None was staged anywhere in the repo (all branches searched). Each was
researched from its 50 Best page, its own MICHELIN page where it has one,
and its own website. Every field's source is in
`w50b_2026_new_restaurants.csv`.

| Code | Rank | Restaurant | City | Stars (MICHELIN page) | `inclusion_reason` | In property |
|---|---|---|---|---|---|---|
| rest_4200 | 49 | Naar | Kasauli, IN | — (no guide in India) | `worlds_50_best` | Amaya |
| rest_4201 | 54 | Nelita | São Paulo, BR | listed, no star | `worlds_50_best` | |
| rest_4202 | 64 | Seroja | Singapore | 2 (2026) | `michelin_star` | |
| rest_4203 | 72 | Eatanic Garden | Seoul, KR | 1 (2026) | `michelin_star` | Josun Palace |
| rest_4204 | 78 | Mosu | Seoul, KR | 2 (2026) | `michelin_star` | |
| rest_4205 | 90 | Baan Tepa | Bangkok, TH | 2 (2027) | `michelin_star` | |
| rest_4206 | 97 | Khufu's | Giza, EG | — (no restaurant guide) | `worlds_50_best` | |
| rest_4207 | 99 | Fauna | Valle de Guadalupe, MX | Bib Gourmand only | `worlds_50_best` | Bruma Wine Resort |

- **Stars** come only from each venue's own MICHELIN page; NULL means no
  star, never zero. Fauna's Bib Gourmand is not recorded (out of scope).
  The four starred get one current `award_history` row each, with the year
  their page shows. **Baan Tepa's page already shows the Thailand 2027
  guide**, so its row is `guide_year = 2027`; the six Thai restaurants
  already in production are still at 2026, so Thailand 2027 has not been
  loaded for them (not part of this pass).
- **Property.** Josun Palace, Amaya and Bruma Wine Resort are not in
  `hotels`, so per the hotel-scope rule they go in `property_name` (no hotel
  row, no link). Fauna's own domain redirects to the resort, which takes
  room bookings; Naar's 50 Best page says "Located in Amaya" and its own
  map link points at Amaya.
- **Points.** MICHELIN's pin for the six with a MICHELIN page (Nelita's own
  map link agrees to 12 m). Khufu's: the plus code in 50 Best's address,
  with an OpenStreetMap restaurant node 7 m away. Two are weaker, QA-476:
  **Naar** has one source only (its own map link); **Fauna**'s MICHELIN pin
  is 1.2 km from Bruma's own map link, and nothing settled which is right.
- **Phones** where the venue's own site or MICHELIN confirms the 50 Best
  number, except: Nelita uses its own site's number (= MICHELIN), not 50
  Best's; Khufu's is 50 Best's only (its site shows none); **Fauna is
  NULL** — three sources, three numbers.
- **Websites**: the venue's own. Eatanic Garden uses MICHELIN's link (the
  hotel's restaurant page) because 50 Best's eatanicgarden.com did not load.
- **50 Best URL** (`worlds_50_best_url`) is the discovery profile where one
  exists; Eatanic Garden and Khufu's have none, so NULL.
- **Google Place ID: NULL for all eight** — no Places lookup available in
  this session (QA-476), as on earlier passes (QA-280).
- **Addresses** as MICHELIN writes them where it has a page; Baan Tepa's
  differs from 50 Best's (561 against 2369 Ramkhamhaeng Road, QA-474).
- **City.** Kasauli is new: `supabase/migrations/20261101390000_add_w50b_2026_cities.sql`.
  The other seven cities exist.

## 2025 No. 94 (QA-194)

The official 2025 list gives **94 Meet the Bund, Shanghai**. It was held
back on 2026-10-28 because the staged record was M on the Bund, a different
restaurant. The MICHELIN China pass has since added the real one as
`rest_2739` "Meet the Bund (Zhongshan Dong Er Road)"; its address equals the
50 Best page's (S301, 3F, South Mall, The Bund Finance Center, 600 Zhongshan
Dong Er Road). The SQL adds its 2025 row (94, `extended_51_100`), which
makes 2025 complete at 100, and it gets its 2026 row (21) too. QA-194 closes
on apply.

## Files and apply order

| # | File | What |
|---|---|---|
| 1 | `supabase/migrations/20261101390000_add_w50b_2026_cities.sql` | Kasauli (IN) city row; `supabase db push --linked` |
| 2 | `prepared_w50b_2026_import.sql` (this folder) | 8 restaurants, 4 award_history rows, 100 + 1 rows for 2026, 1 for 2025; `supabase db query --linked --file …` |

The SQL is one transaction. Guards abort if 2026 rows or 2025 No. 94
already exist, if any new code, MICHELIN URL or 50 Best URL is already
taken, if a city does not resolve (migration 1 missing), if any existing
code fails to resolve on code + country, or if rank and list type
disagree. Post-checks: 8 new rows and 4 award rows; 2026 at 50 / 50 / 1;
2025 at 100 ranked; 100 current ranks in `restaurants_full`; Etxebarri
current No. 1; Maido hall of fame. The hall-of-fame row follows 2025
(Disfrutar) and 2024 (Central): one row in the year a restaurant enters.

### How "current" moves to 2026

`restaurants_full.worlds_50_best_rank` joins the row whose year is
`max(year) where rank is not null`. The moment this commits, 2026 is
current: 100 restaurants show a 2026 rank, and the 17 ranked in 2025 but not
in 2026 (Sézanne, Table by Bruno Verjus, Lido 84, Orfali Bros, Pujol,
Quique Dacosta, Tantris, Mountain, Leo, Oteque, A Casa do Porco, The
Clove Club, Mugaritz, Le Bernardin, Atelier Crenn, César, Amisfield) no
longer show a current rank; their history rows stay and Award History
still lists them. Maido moves to the hall of fame. The app's 50 Best guide
reads the years in the table, so 2026 appears in its year selector; the
hidden site picks the newest year on its next build. No code change needed.

## Tested, and not

- **Tested:** both files on a local Supabase stack replayed from every
  migration in the repo, seeded with production's own rows. See
  `LOCAL_TEST.md`.
- **Not tested:** against production itself (only after approval). The new
  rows' Place IDs are missing and two points rest on weak evidence
  (QA-476). Other sessions are filling MICHELIN coverage gaps in Asia; if
  one adds Seroja, Eatanic Garden, Mosu or Baan Tepa first, the MICHELIN-URL
  guard stops this file rather than creating a duplicate.
