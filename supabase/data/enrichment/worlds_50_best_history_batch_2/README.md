# World's 50 Best history, batch 2: 2002–2019 and Le Clarence (QA-250)

2026-10-28, `data/w50b-history-gaps`. **Applied to production
2026-10-28** after review: 13 rows inserted, all guards passed (872 → 885
rows); recorded in the Michelin_Database CHANGELOG. Follows
`../worlds_50_best_history_2021_2024/` (batch 1, applied), with the same
proof standard.

## Official lists, 2002–2019

The archived `theworlds50best.com/previous-list/<year>` page carries every
year in one timeline widget, one block per year, each headed "The World's
50 Best Restaurants <year>". The per-year addresses all serve the same
page, so a page's address proves nothing about its year. Each block was
accepted only when:

- its heading names the year;
- its No.1 is that year's winner; and
- every row we already hold for that year sits at the same rank on it.

All 17 accepted years are in `official_lists_2002_2019.csv`. The only
difference was a naming one: "L'Hotel de Ville - Philippe Rochat" for our
Restaurant de l'Hôtel de Ville, 2008–2010.

**2016 is excluded.** The official block itself is mis-numbered: two
No.22s, two No.23s, and no No.18 or No.37. Nothing between those ranks
can be trusted from it.

These blocks cover the Top 50 only, so 51–100 for 2013–2019 isn't covered
here.

## Applied rows (`top_50_rank_years.csv`, `apply=yes`): 13

| Restaurant | Years added |
|---|---|
| Mirazur | 2017 No.4, 2018 No.3, 2019 No.1 |
| The Clove Club | 2017 No.26, 2018 No.33, 2019 No.27 |
| Alléno Paris au Pavillon Ledoyen | 2017 No.31, 2018 No.29, 2019 No.25 |
| Nerua Guggenheim Bilbao | 2019 No.32 |
| A Casa do Porco | 2019 No.39 |
| Leo | 2019 No.49 |
| Le Clarence | 2022 No.28 |

**2017–2019:** the archive kept the official entry pages under
year-specific addresses (`/The-List-2019/1-10/Mirazur.html`), so the year
is in the address and the rank is on the page. Identity, as in batch 1,
comes from our phone, own website or street + house number on that page.

**Le Clarence 2022** was held back from batch 1. Its entry page gives "31
Av. Franklin Delano Roosevelt, 75008 Paris", ours "31 Avenue Franklin
Delano Roosevelt, 75008 Paris". Only the abbreviation differs; it was
checked by hand.

A read-only dry run passed: 13/13 codes carry their expected name, no
(year, rank) place is taken, and no restaurant has a row that year.
Mirazur has no 2019 Hall of Fame row to collide with.

## Not applied: `top_50_name_city_review.csv`, 61 places

These are Top 50 places in 2002–2019 whose name and city match a
restaurant in our catalogue, with no further proof:

- **2002–2016:** the archive has no entry pages, so name and city is all
  the official list gives.
- **2017 Astrance:** its entry page shows none of our contact details. The
  restaurant has since moved.

Clear false matches were removed before the file was written:

- Sukiyabashi Jiro (Ginza) vs our Roppongi branch;
- Pierre Gagnaire vs Gaya par Pierre Gagnaire;
- Alain Ducasse au Plaza Athénée vs La Grande Table du Plaza Athénée, its
  successor;
- "AT".

Others in the file may hide the same kind of trap. Applying any of them
needs a rule decision, not more searching (see QA-249/QA-250).
