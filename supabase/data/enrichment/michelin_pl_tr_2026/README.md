# Poland + Türkiye: MICHELIN stars and Key hotels 2026 (2026-11-01)

Status: **APPLIED 2026-11-01**, at the product owner's request. The migration went in with `supabase db push --linked`; the ledger is 127, with local and remote in agreement. The SQL file passed every check. Every staged row was re-checked against a fresh export (`_source/production_after_apply_20261101.json`): PL ends at 0/1/10 stars and 0/5/9 Keys, TR at 0/2/15 stars and 1/3/19 Keys. The product owner accepted the Jaskółka/Bristol correction in place. Originally prepared, not applied —

Apply in this order:

1. `supabase/migrations/20261031180000_add_pl_tr_2026_cities.sql` (14 towns),
   with `supabase db push --linked`
2. `prepared_pl_tr_2026.sql` (one transaction; it aborts on any failed check),
   with `supabase db query --linked -f <absolute path>`

## Result

| | MICHELIN live (3/2/1) | Production before | Production after |
|---|---|---|---|
| PL stars | 0/1/10 = 11 | 0/1/0 = 1 | 0/1/10 |
| TR stars | 0/2/15 = 17 | 0/2/2 = 4 (Araka wrongly 2) | 0/2/15 |
| PL Keys | 0/5/9 = 14 | 0/7/4 = 11 | 0/5/9 |
| TR Keys | 1/3/19 = 23 | 0/1/0 = 1 | 1/3/19 |

The Key totals equal MICHELIN's global Key article of 18 Sep 2026 ("Poland – 14",
"Türkiye – 23"). The PL and TR star totals equal MICHELIN's edition articles.

## Sources (guide.michelin.com only, all saved in `_source/`)

- **Star listings:** `/en/pl/restaurants/all-starred` and `/en/tr/restaurants/all-starred`.
  The four Philippine cards that appear on every listing are not counted.
- **Restaurant pages:** every page's JSON-LD reads `dateAwarded "2026"`.
- **Editions:**
  - Poland 2026 was announced on 27 May 2026 (article `michelin-guide-poland-2026-news`).
  - Türkiye 2026 was announced on 4 Dec 2025 (article `the-michelin-guide-turkiye-reveals-its-2026-restaurant-selection`).
  - Türkiye 2025 is the article of 6 Dec 2024, used for Araka.
- **Hotel listings:** `/en/hotels-stays/poland` and `/en/hotels-stays/turkey`, plus each
  Key hotel's own page. The JSON-LD award agrees with the card on all 37. The Little
  Nell (Aspen) and the empty template cards are not counted.
- **Poland Key article of 9 Oct 2025** (2025 edition): Zamek Łeba and Altus Palace each
  have 1 Key.

## What the SQL does

1. **Corrects 4 PL Keys in place** (QA-405). The stored 2026 launch row contradicts
   MICHELIN's 2026 page:
   - Jaskółka 1 → 2
   - Zamek Łeba 2 → 1
   - Altus Palace 2 → 1
   - Bristol 2 → 1

   Łeba and Altus also had 1 Key in 2025, so the stored 2 matches no edition. For
   Jaskółka and Bristol no 2025 source was found. Correcting the row in place asserts
   no 2025 value. **Decision for you:** accept that, or keep their old value as a 2025
   row once a source turns up.
2. **Adds 25 Key hotels** (`hotel_2901`–`hotel_2925`): PL 3, TR 22. Each gets a current
   2026 Key row, announced 2026-09-18.
3. **Corrects Araka's stars in place** from 2 to 1 (QA-404). MICHELIN gives it one
   star in both 2025 and 2026.
4. **Adds 23 starred restaurants** (`rest_3901`–`rest_3923`): PL 10, TR 13. Each gets a
   current 2026 row with its edition's announcement date.
   - 19 have a phone. In every case it is MICHELIN's number and it is printed on the
     restaurant's own site.
   - All 23 have a website: MICHELIN's link, which loads and names the restaurant.
5. **Existing restaurants:**
   - **Fill-only:** 3 phones and 4 websites, each confirmed on the venue's own site.
   - **`michelin_url`:** 5 values move from old `nl/nl` pages to MICHELIN's current
     page. The slug is the same, and the update is guarded on the old value.
   - **Location and address** (QA-406), guarded on the old point and address. These
     4 points were 1.2–11.8 km from MICHELIN's pin:
     - Araka, Sankai by Nagaya and Turk Fatih Tutak moved. Their stored address is
       the old one.
     - Bottiglieria 1881's address was right; its point was mis-geocoded.
6. **Links 2 restaurants to hotels**, each with MICHELIN's own wording as evidence.
   No PL or TR restaurant page has a "Stay at the hotel" section, so these come from
   the reviews and the hotel pages:
   - Casa Lavanda → Casa Lavanda Boutique Hotel (new Key hotel)
   - Maçakızı → `hotel_758` Maçakızı (World's 50 Best)
7. **Sets `property_name` on 2 restaurants.** Their host hotels are not in `hotels`:
   - Revithia → Kayakapi Premium Caves - Cappadocia
   - Kitchen By Osman Sezener → The Bodrum EDITION
8. **Post-conditions:**
   - Each country's star and Key tiers equal MICHELIN.
   - Each row has exactly one current award row equal to its value.
   - No restaurant has both a hotel link and a `property_name`.

## Not written (logged)

- **No Google Place ID** for any new row (QA-407). This session had no Google
  access: there is no Places API key, and scripted use of Google's demo page was
  refused. The stored Place IDs of the three Istanbul restaurants that moved may
  belong to the pre-move record (QA-406).
- **New hotels have no phone or website** (QA-407). MICHELIN's hotel pages carry no
  website link. The MICHELIN phone is recorded in `pl_tr_key_hotels_2026.csv` but not
  written.
- **4 restaurant phones are left blank** because the number is not on the venue's
  own site: hub.praga, Alon Omakase, Kitchen By Osman Sezener and Teruar Urla.
  Neolokal's stored phone differs from MICHELIN's (QA-408).
- **`hotel_758` Maçakızı has no award rows at all.** It is a World's 50 Best hotel
  with no Key now (QA-409).
- **Towns** (QA-410):
  - Restaurants follow MICHELIN's listing city, so Urla's four restaurants are under
    Izmir.
  - Hotels follow the page's locality with diacritics restored (Nevşehir, Alaçatı,
    Şile).
  - Aliée's locality, Beyoğlu, is filed under Istanbul.
  - Narımor's and Mikla's host hotels get no `property_name`: MICHELIN does not name
    them.

## Files

- **`pl_tr_restaurants_2026.csv` and `pl_tr_key_hotels_2026.csv`:** per row, with action,
  source and each value held back.
- **`match_report.csv`:** every judgement call.
- **`build_pl_tr.py`:** writes the CSVs, the migration and the SQL from `_source/`.
- **`fetch_michelin.py`:** fetches from MICHELIN (curl, 2.5 s pacing, no throttling
  met).
- **`check_sites.py`:** checks the official websites and phones.
- **`export_pl_tr_query.sql`:** production's read-only export, saved as
  `_source/production_export_20261101.json`.

## Tested

Tested on scratch PostgreSQL 17, seeded with the export by `test_scratch.py`. PostGIS
was not available, so the geography type and functions are stubbed.

- **Without the migration**, the file aborts with nothing applied.
- **With it**, the result is the table above, with 28 restaurants and 2 links.
- **A re-run** aborts. The migration is idempotent.
- **A renamed exported row** aborts the whole file.

Then applied to the real database (see Status).
