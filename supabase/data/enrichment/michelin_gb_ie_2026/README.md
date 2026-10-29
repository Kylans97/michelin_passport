# United Kingdom & Ireland: MICHELIN 2026 stars and Keys (research 2026-10-29)

Status: **APPLIED 2026-10-29** (ledger 109/109; see the Michelin_Database CHANGELOG). Generated from production's export of
2026-10-29 19:55 UTC. To apply, run in order:

1. `supabase/migrations/20261023140000_add_gb_ie_2026_star_and_key_cities.sql`
   (**adds the `countries` row for Ireland**, then 132 GB and 24 IE towns),
   with `supabase db push --linked`
2. `prepared_gb_ie_stars_2026.sql` (one transaction; aborts on any check),
   with `supabase db query --linked -f <absolute path>`

Review `match_report.csv` first (GB and IE rows are labelled by country).
Still for review at apply: **the new IE country row** (below). Decided by the
product owner on 2026-10-29, following the proposals here: Estelle Manor stays
at 1 Key with the optional loss block commented out (QA-281), the Channel
Islands stay out (QA-282), the hotel area towns stay (QA-286), and Gravetye
Manor was checked and linked (QA-285). Ireland was added to
scope by the product owner on 2026-10-29.

| After applying | United Kingdom (GB) | Ireland (IE) |
|---|---|---|
| Stars (3/2/1) | 10/23/163, exactly MICHELIN's live 2026 UK listing without the Channel Islands | 0/5/18, exactly MICHELIN's live 2026 listing |
| Restaurants added | 191 (`rest_2445`–`rest_2635`) | 23 (`rest_2636`–`rest_2658`) |
| … with a phone | 163 (+1 filled on Alain Ducasse) | 21 |
| … with `property_name` (non-Key host hotel) | 16 | 3 |
| … with a Google Place ID | **0** (QA-280) | **0** (QA-280) |
| Key hotels (3/2/1) | 9/42/78, exactly MICHELIN's 2026 Keys; plus Estelle Manor, left at 1 for a decision (QA-281) | 2/5/12, exactly MICHELIN's 2026 Keys |
| Key hotels added | 120 (`hotel_818`–`hotel_937`) | 19 (`hotel_938`–`hotel_956`) |
| … with website / phone | 117 / 115 | 19 / 19 |
| Hotel links (0 before) | 32 (23 exact, 9 campus) | 7 (5 exact, 2 campus) |
| Existing rows filled (fill-only) | phones for The Newt, The Savoy, NoMad; websites for Ikoyi and KOL; phone for Alain Ducasse | — |

Every GB and IE restaurant ends with exactly one current `michelin_stars`
row agreeing with `michelin_stars`; every Key hotel (except Estelle Manor,
which has none today) with exactly one current `michelin_keys` row agreeing
with `michelin_keys`. Both are post-conditions in the file.

## The new IE `countries` row — call-out for review

Production has no `countries` row for IE (read-only check 2026-10-29), and
held no IE restaurant, hotel or city. Every IE row references one, so the
migration inserts it first, as `20261016120000_add_worlds_50_best_countries_and_cities.sql`
did for EC, PA and VN:

```sql
insert into public.countries (country_code, name, flag_emoji, timezones)
values ('IE', 'Ireland', '🇮🇪', array['Europe/Dublin'])
on conflict (country_code) do nothing;
```

`timezones` has been NOT NULL with at least one zone since
`20261018120000_add_country_timezones.sql` (that migration says any later
country must carry its zones). EC/PA/VN and GB all carry theirs on
production (GB `{Europe/London}`). IE's zone is from this machine's tzdata
2025b `zone.tab` (`IE  +5320-00615  Europe/Dublin`, the only IE entry), and
`Europe/Dublin` is in production's `pg_timezone_names`.

## Sources (guide.michelin.com, read 2026-10-29, in the built-in browser)

- **UK listing:** `/en/gb/restaurants/{3-stars,2-stars,1-star}-michelin`:
  10/23/165 = 198. Every restaurant page was read (JSON-LD: address,
  coordinates, phone, cuisine, star rating, `dateAwarded "2026"` on all 198;
  plus the website and "Stay at the hotel" links). Saved:
  `_source/michelin_gb_listing_20261029.json`,
  `_source/michelin_gb_restaurant_pages_20261029.jsonl`.
- **Ireland listing:** `/en/ie/restaurants/...`: 0/5/18 = 23, all
  `dateAwarded "2026"`. `_source/michelin_ie_*`.
- **Edition:** MICHELIN Guide Ceremony Great Britain & Ireland 2026,
  Convention Centre Dublin, **9 February 2026**: "A total of 1,210
  restaurants – including 230 Starred ones". The full-list article marks 9 UK
  entries "[now closed]" (QA-288), and 230 − 9 = 221 = 198 + 23 live. ✓
  Every new 2026 row gets `announced_on 2026-02-09`. Saved:
  `_source/michelin_article_*_gbi_2026.txt`.
- **Channel Islands:** MICHELIN files Bohemia (Jersey) and Vraic (Guernsey)
  under the UK listing. They are Crown Dependencies, not the UK, and there
  is no JE/GG country row, so they are left out (QA-282). Hence GB has 163
  one-stars, not 165.
- **Keys:** MICHELIN's 2026 UK & Ireland Key launch, **18 September 2026**:
  "11 Three-Key hotels, 47 Two-Key hotels and 92 One-Key hotels"
  (`_source/michelin_article_keys_uki_2026.json`). The hotel listing
  `/en/hotels-stays/uk` (458 hotels, 462 pages read) and `/en/hotels-stays/ireland`
  (59, plus the article's Irish Keys) were read page by page; the listing's
  Key filter is client-side only, so each page's JSON-LD `award` decides.
  - UK: 9/42/78; Channel Islands 0/0/2 (excluded); Ireland 2/5/12.
    9+42+78 + 2 + 19 = 150. ✓ Every Key page matches the article's list.
  - Key rows: `guide_year 2026`, `announced_on 2026-09-18`. The file aborts if
    production's current Key rows are not all 2026.
- **Ireland vs UK in MICHELIN's selection:** counted separately throughout;
  MICHELIN publishes them as one guide.

## Production before (export 2026-10-29)

- GB: 5 restaurants (Alain Ducasse 3, Ikoyi 2, The Clove Club 2, KOL 1,
  Mountain 1); 10 hotels; 4 cities; no links. IE: nothing, no country row.
- **The 5 restaurants:** all matched by MICHELIN slug and town segment
  (1–130 m). Their launch rows are labelled 2026 and hold exactly MICHELIN's
  live 2026 value, so no relabel, change or loss (none dropped). They keep
  `announced_on` NULL, as for Italy.
- **The 10 hotels:** matched by MICHELIN's numeric hotel id; all within 175 m.
  9 agree with MICHELIN's 2026 Key exactly. **Estelle Manor** (hotel_763, 1 Key)
  carries no Key on MICHELIN's page and is not in the 2026 Key article
  (QA-281). It is left untouched; an optional, commented-out block at the end
  of the SQL records the loss if you confirm it. Removing the row is not
  prepared.
- 9 of the 10 had no Key row in `award_history` (the August World's 50 Best
  import gap, PE_REPORT finding 1); the file adds them, guarded by NOT EXISTS.

## Research per row

`gb_research_2026.csv`, `ie_research_2026.csv` (restaurants);
`gb_key_hotels_2026.csv`, `ie_key_hotels_2026.csv` (hotels), each with its
evidence.

### Phones (restaurants)

- **Confirmed** when MICHELIN's number is printed on the venue's own site:
  first an automated check of the home page and up to four contact pages
  (`check_restaurant_phones.py`; GB 161, IE 20), then by hand in a browser
  for the rest (GB 8, IE 2; `_source/*_restaurant_phone_confirmations.csv`).
- **Held back** (QA-283): GB 19, IE 2. Ten GB sites print a different number
  from MICHELIN's (one for you to choose); Cycene's and The Morrison Room's
  numbers are a building line and the Carton House switchboard (the
  Germany/Italy rule leaves switchboards out); the rest are on MICHELIN only.
  Ten GB restaurants have no phone on MICHELIN at all (Black Swan's site says
  it has no phone line).
- Format: international, as MICHELIN prints it.

### Hotels: website and phone

Researched per hotel with the brief the Spain Key-hotel session used
(`_source/research_brief_{uk,ie}_hotels.md`; raw results
`{gb,ie}_key_hotel_contacts_research.csv`): the hotel's **own** site
(property page for brands), confirmed on name + town + address; the hotel's
own number as printed there. MICHELIN's hotel number is a cross-check only;
it is often a booking line (The Connaught's, 100 Princes Street's US
toll-free). Carried only when `confirmed`; a `group` line and Padstow
Townhouse's number (beside the Paul Ainsworth group email) are held back.
Five `reservations` lines and two restaurant-with-rooms single lines (Moor
Hall, LYLA) are the hotel's only number and are kept, labelled in the CSV.
Missing: QA-284.

### Hotel links and property names

Never by name alone. A link needs one of:

- MICHELIN's restaurant page says **"Stay at the hotel"** for a Key hotel;
  the hotel is identified by MICHELIN's hotel id (the same page the hotel row
  is built from). 22 GB + 2 IE.
- MICHELIN's 2026 star article says **"Inside the …-MICHELIN-Key <hotel>"**
  for this restaurant's own entry, and that hotel's MICHELIN pin is within
  500 m with a matching name. 10 GB + 5 IE (Mauro Colagreco at The OWO, 1890
  at The Savoy, Woven at Coworth Park, The Oak Room at Adare Manor, …).

**Gravetye Manor (QA-285, resolved).** MICHELIN's restaurant and hotel pins
were 1,854 m apart. The hotel's own site gives one address (Vowels Lane,
West Hoathly, RH19 4LJ) and one phone for the hotel and "our dining room";
OpenStreetMap's Gravetye Manor hotel (way 177959405) is 6 m from MICHELIN's
*restaurant* pin. So MICHELIN's hotel pin (rounded to 4 decimals) is the wrong
one: the new hotel row takes the restaurant pin (`COORD_FIX` in
`build_key_hotels.py`), and the restaurant is linked `exact`.

`exact` when the two pins are within 100 m, else `campus`. A host hotel
MICHELIN shows without a Key (a "Stay at the hotel" link to a non-Key page,
or "Inside the MICHELIN-Selected …") goes in `property_name`. "Affiliated
with" and "Across the road from" make neither.

### Place IDs — not done (QA-280)

This session had no Places API access, and Google Maps' internal search
endpoints were refused, so **no Place ID was looked up** for the 214 new
restaurants and 139 new hotels. They are NULL rather than guessed; the
coordinates in the research CSVs are ready for a find-place-id pass.

### Towns

MICHELIN's town names, as for Germany and Italy (Leith, Bray,
Brighton and Hove). Council-area localities are written as the town:
Glasgow City → Glasgow, City of Bristol → Bristol, Dublin City → Dublin,
Galway City → Galway. Towns compare accent-, case-, space- and
hyphen-insensitively ("Hampton in Arden" / "Hampton-in-Arden" is one town).
Hotel towns are the hotel page's locality, which is sometimes an area
(The Lake District, Hampshire, Berkshire, Rutland, Stirlingshire, Isle of
Skye, County Cork), as Spain does for hotels (QA-286).

## How the SQL is built

Generated, not hand-written:

```
python3 build_research.py gb _source/gb_restaurant_phone_check_20261029.json _source/gb_restaurant_phone_confirmations.csv
python3 build_research.py ie _source/ie_restaurant_phone_check_20261029.json _source/ie_restaurant_phone_confirmations.csv
python3 build_key_hotels.py gb
python3 build_key_hotels.py ie
python3 build_prepared.py <export.json> 2445 818 20261023140000_add_gb_ie_2026_star_and_key_cities.sql
```

`export.json` is the JSON cell of `export_gb_ie_query.sql` (run with
`supabase db query --linked -o json -f <abs path>`). Re-running on the
2026-10-29 export reproduces both files byte for byte. Codes: production's
highest are `rest_2444` and `hotel_817`; no branch claims anything higher
(checked with `git grep` across all remote branches, 2026-10-29). The file
aborts if any code in its ranges is taken. If production changes, re-export
and regenerate with fresh first codes.

## Tested (2026-10-29)

On a scratch PostgreSQL 17 with PostGIS stubbed (geography as text),
mirroring production's columns, constraints, unique and partial indexes and
triggers for `countries`, `cities`, `restaurants`, `hotels`,
`hotel_restaurants` and `award_history` (read from production's catalog),
seeded with the real export:

- **Migration + file:** applies; GB 10/23/163 and 9/42/78 (+Estelle Manor),
  IE 0/5/18 and 2/5/12, IE country row with `{Europe/Dublin}`, 39 links,
  one current award row each.
- **Without the migration:** aborts, nothing applied.
- **Re-run of the file:** aborts. **Re-run of the migration:** no-op.
- **A renamed existing row:** aborts the whole file.

Not run against the real database, and not a full migration replay
(PostGIS, RLS and the other tables were not reproduced).

## Not done here

- Place IDs (QA-280).
- The engineering CHANGELOG (`docs/Plannnig/CHANGELOG.md`) and the
  Michelin_Database CHANGELOG are written when the files are applied, as for
  Germany and Italy.
- QA ids QA-280–QA-288; QA-264–279 were left for the parallel Key-hotel
  contacts session.
