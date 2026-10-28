# Peru: MICHELIN Keys and World's 50 Best (2026-10-28)

Status: **APPLIED 2026-10-28.** See the Michelin_Database CHANGELOG.
Applied via `../APPLY_FR_PE_2026.md`.

| File | What it does |
|---|---|
| `supabase/migrations/20261019130000_add_pe_key_hotel_cities.sql` | 5 Peruvian cities the new hotels need. Moved into `supabase/migrations/` with your go-ahead, 2026-10-28; not applied. |
| `prepared_pe_keys_and_w50b.sql` | 14 new Key hotels, the missing Key row for Palacio Nazarenas, Central as a hall-of-fame member with its rank history, and Mil's 2024 rank |
| `pe_key_hotels.csv` | The 15 Key hotels with source, website and phone evidence |
| `central_w50b_history.csv` | Central's and Mil's added ranking rows with their sources |
| `_source/michelin_pe_key_hotels.json` | MICHELIN's structured data for the 15 hotels |

Order: the cities migration, then the data file. It aborts without the cities
and names the hotels that need them.

## MICHELIN restaurants: none in Peru

`guide.michelin.com/en/pe/restaurants/all-starred` says, on 2026-10-28, that
there are "no selected restaurants" in Peru. There is nothing to add or
correct. Peru's restaurants in the catalogue are there for World's 50 Best,
and that is correct.

## MICHELIN Keys

MICHELIN lists 36 Peruvian hotels. **15 hold Keys**: 1 three-Key, 4 two-Key and 10 one-Key.
Two independent views of MICHELIN agree exactly:

- each hotel's own page, from its structured-data `award`;
- the Peru listing filtered by Key level (3 Keys: 1, 2 Keys: 4, 1 Key: 10).

The other 21 have no award. Their pages do contain the words "Three MICHELIN
Keys", but only in a site-wide lookup table. A text search would have counted
them as Keys.

Production had **one** of the 15, Palacio Nazarenas (`hotel_745`, One Key,
correct). The file adds the other 14 as `hotel_804`–`hotel_817`:

| Keys | Hotels |
|---|---|
| 3 | Las Casitas, A Belmond Hotel |
| 2 | Titilaka by Andean, CIRQA by Andean, Inkaterra Hacienda Urubamba, Inkaterra La Casona |
| 1 | Hotel B, Atemporal by Andean, Fausto by Andean, Monasterio, Miraflores Park, Rio Sagrado, Antigua Casona San Blas, explora Valle Sagrado, Tambo del Inka (plus Palacio Nazarenas, existing) |

Name, address, coordinates and MICHELIN URL come from each hotel's MICHELIN
page. Every coordinate falls inside Peru. Hotel B's address follows the
hotel's own site. Google Place IDs are left empty because this session has no
Places API key.

Every Key hotel gets a current Key row in `award_history`. Its year is the
same as every other current Key row (2026); the file checks there is only one
such year.

**Palacio Nazarenas** has its Key on the hotel row but no Key row in
`award_history`. The file adds that row. It also moves its `michelin_url` from
an `/ie/en/` locale variant with an old slug to MICHELIN's current page.

### Phones

These follow the BE/LU rule: a phone is set only when MICHELIN's number also
appears on the hotel's own site. That holds for **2 of 14** new hotels.

| | Hotels |
|---|---|
| Confirmed | Hotel B (+51 1 206 0800), explora Valle Sagrado (+51 84 300000) |
| MICHELIN gives Belmond's US reservations line (+1 646 732 5250) | Monasterio, Miraflores Park, Rio Sagrado |
| Site shows only a group line, different from MICHELIN's | Titilaka, CIRQA, Atemporal, Fausto (Andean, +51 1 700 5100) |
| MICHELIN's number is a shared group line | Inkaterra Hacienda Urubamba, Inkaterra La Casona (+51 1 610 0400, Lima) |
| Site and MICHELIN disagree | Las Casitas |
| No official site reachable | Antigua Casona San Blas, Tambo del Inka (marriott.com refused the download) |

For the three Belmond hotels, each site shows its own local number. That
number is a candidate if you decide that the hotel's own site is enough for a
hotel line. The rule as it stands was not met, so they stay empty.

## World's 50 Best

The catalogue completion applied this morning
(`../worlds_50_best_2025_2026/`) already covers Peru's current entries. This
was re-checked against the50.com today, and production matches exactly:

| | |
|---|---|
| Restaurants 2025 | Maido 1, Kjolle 9, Mérito 26, Mayta 39, Mil 75 |
| Hotels 2026 / 2025 | Palacio Nazarenas 54 / 87 |

The current restaurants list is still the 2025 edition. The site says the
list is renamed "The 50 Best Restaurants" from 2026, but no 2026 list exists
yet. When one is published, Maido (No.1 in 2025) moves into the Best of the
Best.

All of Maido's, Kjolle's (2023–2025), Mayta's and Mérito's historical ranks
in production agree with the official previous lists. Kjolle's 2021 and 2022
ranks (95, 68) could not be checked: the archive only carries 51–100 for 2023
and 2024.

### Added

- **Central** (`rest_1578`), `inclusion_reason = 'hall_of_fame'`. It was No.1
  in 2023 and is now in the Best of the Best, which the scope rule admits. The
  August hall-of-fame file marked it "not in catalogue" because Peru has no
  MICHELIN guide, but the hall-of-fame clause exists for exactly this case.
  - Ranks from the official previous lists: 2013 No.50, 2014 15, 2015 4,
    2016 4, 2017 5, 2018 6, 2019 6, 2021 4, 2022 2, 2023 1.
  - Hall-of-fame row in 2024. That follows production's own pattern:
    Geranium (No.1 2022) has its row in 2023, and Disfrutar (No.1 2024) in
    2025.
  - Address and phone come from the Best of the Best page, and the phone also
    appears on Central's own site. That site also lists +51 1 242-8575, which
    is the number production holds for Kjolle (same building), so it was not
    used.
  - Coordinates come from OpenStreetMap's record for Central at Av. Pedro de
    Osma 301. There is no Place ID and no MICHELIN URL.
- **Mil**: 2024 No.73 (51–100). Production only had 2025.

## Findings, logged here (QA ids to be assigned)

`qa_issues.csv` is a tracked file shared with your other workstream, so these
are not appended to it yet.

1. **Key rows missing for 75 hotels.** All 75 came from the August World's
   50 Best import (created 2026-08-10). They hold `michelin_keys` on the hotel
   row but have no current `michelin_keys` row in `award_history`. Palacio
   Nazarenas is one; this file fixes only that one. The other 74 need their
   own file. Query:
   `hotels h where michelin_keys is not null and not exists (current michelin_keys row)`.
2. **Kjolle's location** (`rest_0135`) is stored at (-12.145, -77.0211), and
   the values look rounded. Kjolle shares Central's building at Av. Pedro de
   Osma 301, which OpenStreetMap places at (-12.15257, -77.02254), about 880 m
   away. Not changed here.
3. **Mil 2024, two official sources disagree.** The previous-lists page says
   No.73; Central's Best of the Best profile says "No.63". The list page was
   used.
4. **City names.** MICHELIN uses "Arequipa" (for Las Casitas, which is
   actually in Yanque, Colca Canyon) and "City of Arequipa" (for CIRQA) as two
   destinations, and "Urubamba" next to "Sacred Valley". They are kept as
   MICHELIN names them, per the city rule.
5. **explora Valle Sagrado's** MICHELIN street address is "Unnamed Rd". It was
   kept, because no better address was found from a primary source.

## Decisions for you

- **Cities:** moved into `supabase/migrations/` (decided 2026-10-28).
- **Arequipa:** keep "Arequipa" and "City of Arequipa" as two city rows, as
  MICHELIN has them? The alternative is putting Las Casitas under a Yanque or
  Colca city, which breaks the MICHELIN-destination rule.
- **Belmond phones:** use the hotel's own local number when MICHELIN only
  gives Belmond's US line?

## Testing

Both files were run on a scratch PostgreSQL 17 database seeded with
production's cities, hotels, restaurants, Key rows and World's 50 Best rows,
exported read-only on 2026-10-28. PostGIS was stubbed.

- **Data file without the cities.** It aborts and names the 7 hotels that
  need them. Nothing changes.
- **Cities, then the data file.** Peru has 15 Key hotels (1 / 4 / 10); every
  one has exactly one current Key row agreeing with the hotel row. Award rows
  go from 711 to 726, and ranking rows from 831 to 843. Central reads
  2013:50 … 2023:1, 2024 hall of fame. Hall-of-fame rows go from 6 to 7.
- **Re-run.** It aborts at the code check.

Neither file was run against the real database.

## Not done

- Google Place IDs for the 14 hotels and Central: no API key in this session.
  The method is in `../michelin_fr_stars_2026/PLACE_ID_HANDOFF.md`. Note that
  for hotels the record must be the accommodation, not a restaurant inside it.
- The Michelin_Database CHANGELOG entry is written once this is applied.
- Nothing is committed: you have another workstream running.
