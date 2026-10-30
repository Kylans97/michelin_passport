# Hong Kong, Macau, Taiwan: MICHELIN stars and Keys (research 2026-10-29/30)

Status: **APPLIED 2026-10-30** (ledger 114/114; see the Michelin_Database CHANGELOG). This pass was added to scope by the product
owner on 2026-10-29 ("yes let's do them next after China"). The files were
generated from production's export of 2026-10-29 23:11 UTC, which was unchanged
from the 22:55 export the research started from. Apply in order:

1. `supabase/migrations/20261023170000_add_hk_mo_tw_2026_star_and_key_cities.sql`
   (5 Taiwan towns) with `supabase db push --linked`. The migration sorts after
   US/CA/MX's `20261023160000` and China's `20261023150000`. If either of those
   is still unapplied, the push order follows the filenames.
2. `prepared_hk_mo_tw_stars_2026.sql` (one transaction, with HK, MO and TW
   blocks; it aborts on any check) with `supabase db query --linked -f <absolute path>`.

Review `match_report.csv` first (rows are labelled by country). These decisions
are waiting for you:

- **QA-296:** nine `property_name` values are cleared, and two hosts are not linked.
- **QA-297:** JL Studio is matched by hand, and has probably moved.
- **QA-295:** the phone numbers that differ from MICHELIN's.

| After applying | Hong Kong (HK) | Macau (MO) | Taiwan (TW) |
|---|---|---|---|
| Stars (3/2/1) | 7/13/57, exactly MICHELIN's live listing | 2/6/13, exactly MICHELIN's live listing | 3/9/49, exactly MICHELIN's live listing |
| Production before | 7/13/1, plus Wing (World's 50 Best, no star) | 2/5/0 | 3/7/0 |
| Restaurants added | 56 (`rest_2815`–`rest_2870`) | 14 (`rest_2871`–`rest_2884`) | 51 (`rest_2885`–`rest_2935`) |
| … with a phone / website | 37 / 48 | 11 / 14 | 16 / 29 |
| … with `property_name` | 6 | 3 | 6 |
| Key hotels (3/2/1) | 1/4/5 (10 live; the Key article says 9, QA-298) | 1/4/4 | 0/1/7 |
| Key hotels added | 5 (`hotel_1008`–`hotel_1012`) | 9 (`hotel_1013`–`hotel_1021`) | 8 (`hotel_1022`–`hotel_1029`) |
| … with website / phone | 4 / 4 | 8 / 8 | 6 / 5 |
| Key change | Four Seasons Hong Kong (`hotel_717`) 1 → 2 | — | — |
| Hotel links (0 before) | 15 | 7 (2 to Wynn Palace, which has no Key) | 2 |
| `property_name` cleared (now linked) | 8 | 1 | — |
| Existing rows filled (fill-only) | 20: `michelin_url`, phone, website | 7 | 10, plus Molino de Urdániz's `property_name` (Hotel MVSA) |

**Post-conditions in the file:**

- Every row that holds or held a star ends with exactly one current
  `michelin_stars` row, and that row agrees with `michelin_stars`.
- Every Key hotel ends with exactly one current 2026 `michelin_keys` row, and it
  agrees with `michelin_keys`. None of the HK/MO hotels had a Key row before.
  That is the gap the August World's 50 Best import left, and the UK file
  closed it for GB.
- No restaurant has both a link and a `property_name`.
- The link count per country matches.

## Sources (guide.michelin.com, read 2026-10-29 in the built-in browser)

**Restaurant listings:** `/en/{hk,mo,tw}/restaurants/{3-stars,2-stars,1-star}-michelin`.
The headers read "Hong Kong SAR : 7 / 13 / 57", "Macau SAR : 2 / 6 / 13" and
"Taiwan Region : 3 / 9 / 49". All 159 restaurant pages were read
(`_source/michelin_hk_mo_tw_restaurant_pages_20261029.jsonl`), and every one
has `dateAwarded "2026"`.

**Editions:**

- **MICHELIN Guide Hong Kong & Macau 2026** (18th edition) was announced on
  **19 March 2026** at Grand Lisboa Palace, Macau. Its article gives HK 7/13/57
  and MO 2/6/13, the same as the live listing.
- **MICHELIN Guide Taiwan 2026** (9th edition) was announced on
  **21 July 2026**. Its article gives 3/9/49, the same as the live listing.
- Each announcement date is the article's `datePublished`, and it agrees with
  the date printed in the article. The articles are in `_source/`.
- Every award row is `guide_year 2026`. The production launch rows are labelled
  2026, and each one holds MICHELIN's 2026 value (`CURRENT ROW VERIFIED` ×38),
  so no relabel is needed.

**Keys:** `/en/hotels-stays/{hong-kong,macau,taiwan}?distinction=all-keys`.

- The Hong Kong listing is "Hong Kong SAR and surroundings : 16". Six of those
  are in Shenzhen, which belongs to the CN pass, so they are excluded.
- Macau has 9 and Taiwan has 8.
- Every page's JSON-LD `award` was read
  (`_source/michelin_hk_mo_tw_hotel_pages_20261029.json`).
- Key rows are `guide_year 2026` and `announced_on 2026-09-18`, the date of the
  2026 global reveal.

## Matching existing rows

Never by name alone.

- **By MICHELIN slug (8 rows).** These are the rows that carry a `michelin_url`.
- **By coordinates plus name (31 rows):** 1–195 m apart with name similarity
  at least 0.6. There is no GCJ-02 offset outside mainland China: MICHELIN's
  pins and production's points agree.
- **JL Studio (`rest_0463`), by hand (QA-297).** This is `MANUAL_MATCH`, with
  the evidence written into the report:
  - it is the only JL Studio in MICHELIN's Taiwan listing, in the same city;
  - it has held three stars continuously;
  - the Taiwan 2026 article says JL Studio in Taichung kept its three stars;
  - MICHELIN's address, 59 Cunzhong Street, is 3.3 km from the stored address,
    689 Yifeng Road. That points to a move, and its own site is a placeholder.

  Its address and point are not changed.
- **Wing (`rest_0301`).** It is a World's 50 Best row with stars NULL and no
  award history, and it is not in MICHELIN's starred listing. It is left
  untouched.
- **Hotels** are matched by MICHELIN's numeric hotel id. The 5 existing HK
  hotels sit 2–133 m from MICHELIN's pin. Wynn Palace (`hotel_798`, World's
  50 Best) carries no Key and keeps none.

## Hotel links and property names

The evidence, in order:

1. **MICHELIN's "Stay at the hotel" section.** Seven restaurant pages have
   one. Amber and Ya Ge point to Key hotels; the rest point to non-Key hotels
   and go into `property_name`.
2. **MICHELIN's own printed restaurant address.** For example, "6F, Four
   Seasons Hotel, 8 Finance Street" (`HOSTS` in `build_research.py`).

**Link** requires all of these:

- the restaurant is inside a Key hotel, or inside Wynn Palace, which is already
  in `hotels`;
- the hotel's own MICHELIN page, or production's row for Wynn Palace, gives
  the same street. That means the same street number, or every distinctive
  word of an unnumbered street ("Salisbury Road", "Rua do Tiro",
  "Estrada do Istmo");
- the two points are within 300 m.

All 24 links are `exact`.

**Not linked (QA-296):**

- **Alain Ducasse at Morpheus.** MICHELIN's Morpheus pin is 1.2 km from the
  restaurant. Its existing `property_name` "Morpheus" is kept for now, although
  Morpheus enters `hotels` here.
- **Zuicho.** It is 356 m from The Karl Lagerfeld inside the Grand Lisboa
  Palace resort.

**Cleared `property_name` (9).** These existing rows named a hotel that is, or
now becomes, a row in `hotels`, which hotel scope rule 3 forbids. The link
replaces each one. The `update` matches the exported value exactly, and the
post-condition aborts if a changed value would leave both a link and a
`property_name`. A test confirms this.

**`property_name` (15 new, plus Molino de Urdániz):** written as MICHELIN
prints it ("The Langham Hotel", "Island Shangri-La Hotel", "Regent Taipei"…).

## Contacts

**Restaurant phones (QA-295).** Only MICHELIN's number confirmed on the venue's
own site is used:

- 77 were confirmed by the automated check (`check_restaurant_phones.py`; HK and
  MO have no trunk prefix, TW's national form starts with 0).
- 16 more were confirmed by hand (`_source/hk_mo_tw_restaurant_phone_confirmations.csv`).
- Held back:
  - 4 that differ from MICHELIN's number;
  - Sushi Wadatsumi, whose own page prints two numbers;
  - Tien Hsiang Lo, whose only number is the hotel switchboard;
  - every number on a site that blocked automated access, and every
    MICHELIN-only number.

**Hotels (QA-295).** Researched with `_source/research_brief_hk_mo_tw_hotels.md`.

- 18 of 22 have a confirmed website, and 17 a confirmed phone.
- Macau resort hotels use the hotel's own page on the resort site (Galaxy,
  Londoner, Grand Lisboa Palace).
- Morpheus's only own number is its reservations line, which is kept and
  labelled.
- Banyan Tree Macau, The Lalu and The One Nanyuan carry the hotel's own line.
  MICHELIN prints a reservations or booking-centre line for them.
- Hoshinoya Guguan's only local number is a "Night/Emergency" line, so it is
  held back.

**Place IDs** were not looked up, because there is no Places API key (QA-295).

## Towns

MICHELIN's restaurant towns are Hong Kong, Macau, Taipei, Taichung, Kaohsiung,
Tainan and Hsinchu County.

Hotel localities are written the same way:

- Hong Kong Island and Kowloon become Hong Kong.
- Cotai becomes Macau.
- Da'an and Songshan District become Taipei (their `addressRegion`).
- "Kaohsiung City" and "Taichung City" become Kaohsiung and Taichung.

Sun Moon Lake (The Lalu) and Xinpu (The One Nanyuan) are areas, and they stay
as they are, as for GB and Spain. The 5 new TW towns are Hsinchu County,
Kaohsiung, Sun Moon Lake, Tainan and Xinpu.

## How the SQL is built

```
python3 build_research.py _source/hk_mo_tw_restaurant_phone_check_20261029.json _source/hk_mo_tw_restaurant_phone_confirmations.csv
python3 build_key_hotels.py
python3 build_prepared.py <export.json> 2815 1008 20261023170000_add_hk_mo_tw_2026_star_and_key_cities.sql
```

`export.json` is the JSON cell of `export_hk_mo_tw_query.sql`.

**Codes.** These continue straight after China's (`rest_2814` / `hotel_1007`)
and stay inside the block the US/CA/MX session left (up to `rest_3000` /
`hotel_1500`). No remote branch claims them, and the file aborts if any of them
is taken.

**Coordinates.** `gcj02.py` (from `../michelin_cn_2026`) is used only for its
distance function.

## Tested (2026-10-30)

The test ran on the same scratch PostgreSQL 17 mirror as China, seeded with the
real HK/MO/TW export.

- **Migration + file applies.** Afterwards:
  - stars and Keys are exactly the table above;
  - links are HK 15, MO 7, TW 2;
  - every new award row is 2026, announced 2026-03-19 or 2026-07-21;
  - Wing is untouched, and Four Seasons Hong Kong has 2 Keys.
- **Without the migration:** aborts, and nothing is applied.
- **Re-run of the file:** aborts. **Re-run of the migration:** no-op.
- **These also abort the whole file:**
  - a renamed existing row;
  - a code in range already taken;
  - a `property_name` edited since the export.

It was not run against the real database. It was not a full migration replay:
PostGIS, RLS and the other tables were not reproduced.

## Not done here

- Place IDs (QA-295).
- The CHANGELOGs, which are written when the files are applied.
- QA ids: QA-295–QA-298. QA-299 is left free.
