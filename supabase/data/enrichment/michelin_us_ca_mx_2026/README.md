# United States, Canada & Mexico: MICHELIN stars and 2026 Keys (research 2026-10-29)

Status: **APPLIED 2026-10-30** (ledger 114/114; see the Michelin_Database CHANGELOG). Generated from production's export of
2026-10-29 22:28 UTC. To apply, run in order:

1. `supabase/migrations/20261023160000_add_us_ca_mx_2026_star_and_key_cities.sql`
   (**adds the `countries` row for Canada**, then 166 US, 23 CA and 26 MX towns),
   with `supabase db push --linked`
2. `prepared_us_ca_mx_stars_2026.sql` (one transaction for all three countries;
   aborts on any check), with `supabase db query --linked -f <absolute path>`

Review `match_report.csv` first (rows labelled by country). Decided by the
product owner on 2026-10-30: the **CA country row** goes in (below), and the
hotel area towns stay, as for the UK (QA-306), and Sushi Sho's 2026 launch
row is dropped with its 2025 row made current (QA-301), Harbor House Inn is
linked to its inn after a check on the inn's own site (QA-307), and Rosewood
Mayakoba's match stands (QA-309). Nothing else waits on a decision.

| After applying | United States (US) | Canada (CA) | Mexico (MX) |
|---|---|---|---|
| Stars (3/2/1) | 16/40/223, exactly MICHELIN's live listing | 0/3/36, exactly MICHELIN's live listing | 0/2/27, exactly MICHELIN's live listing |
| … current rows by guide year | 2025: 6/22/87 (Northeast Cities); 2026: 10/18/136 | 2026: all | 2026: all |
| Restaurants before → added | 51 → +228 (`rest_3001`–`rest_3228`) | 0 → +39 (`rest_3229`–`rest_3267`) | 6 → +24 (`rest_3268`–`rest_3291`) |
| … new with a phone | 156 | 30 | 11 |
| … new with `property_name` | 1 (Le Coucou: 11 Howard) | 0 | 1 (Olivea Farm to Table: Casa Olivea) |
| … with a Google Place ID | **0** (QA-300) | **0** | **0** |
| Existing restaurants | 26 launch rows relabelled 2026 → 2025, Sushi Sho's dropped (2025 made current), 24 verified 2026; fill-only: 33 phones, 47 websites, 45 MICHELIN urls | — | 5 verified 2026; fill-only: 3 websites, 1 MICHELIN url; Arca (World's 50 Best, unstarred) untouched |
| Key hotels (3/2/1) | 15/78/266 = 359, exactly MICHELIN's 2026 Keys | 2/8/32 = 42, exactly | 3/21/73 = 97 (article: 98; QA-305) |
| Key hotels added | 349 (`hotel_1501`–`hotel_1849`) | 42 (`hotel_1850`–`hotel_1891`) | 90 (`hotel_1892`–`hotel_1981`) |
| … with website / phone | 266 / 269 | 33 / 32 | 58 / 61 |
| Existing hotels | 10 matched; San Ysidro Ranch gains 1 Key; fills: Hotel Bel-Air phone, 3 MICHELIN urls | — | 7 matched; Rosewood Mayakoba gains 2 Keys (+phone, website, url); Montage Los Cabos phone |
| Hotel links (0 before) | 9 (7 exact, 2 campus) | 0 | 1 (exact) |

Every starred US/CA/MX restaurant ends with exactly one current
`michelin_stars` row agreeing with `michelin_stars`, and the per-guide-year
counts above; every Key hotel with exactly one current 2026 `michelin_keys`
row agreeing with `michelin_keys`. All are post-conditions in the file.

## The new CA `countries` row (approved by the product owner, 2026-10-30)

Production has no `countries` row for CA (read-only check 2026-10-29) and held
no CA restaurant, hotel or city. The migration inserts it first, as
`20261023140000_add_gb_ie_2026_star_and_key_cities.sql` did for IE:

```sql
insert into public.countries (country_code, name, flag_emoji, timezones)
values ('CA', 'Canada', '🇨🇦', array['America/St_Johns', 'America/Halifax', ... , 'America/Vancouver'])  -- 23 zones
on conflict (country_code) do nothing;
```

`timezones` is NOT NULL with at least one zone since
`20261018120000_add_country_timezones.sql`. The 23 zones are every `CA` line of
this machine's tzdata 2025b `zone.tab`, in file order — the same convention
production's US and MX rows follow (both are exactly their `zone.tab` lines in
order). All 23 are in production's `pg_timezone_names` (checked 2026-10-29).
Restaurants and hotels here sit in America/Toronto, America/Vancouver,
America/Edmonton, America/Halifax and America/St_Johns.

## Sources (guide.michelin.com, read 2026-10-29, in the built-in browser)

MICHELIN publishes several guides here, at different times. Each restaurant's
guide year is its own page's JSON-LD `award.dateAwarded`; its guide follows
from the page's `addressRegion` and that year; the announcement date is that
guide's, from MICHELIN's own article (saved in `_source/michelin_article_*.txt`).
A region/year pair not in `build_research.py`'s `GUIDES` stops the build.

| Guide (edition) | Announced | MICHELIN's count | Live listing (3/2/1) | Article |
|---|---|---|---|---|
| Northeast Cities 2025 (NY, Chicago, DC + Virginia, Boston, Philadelphia) | 18 Nov 2025 (2026 ceremony: 14 Dec 2026) | — | 6/22/87 | `ny2025`, `chi2025`, `dc2025`, `bos2025`, `phl2025`, `ne2025host` |
| California 2026 | 24 Jun 2026 | 83 | 10/13/60 = 83 ✓ | `cal2026` |
| Florida 2026 | 28 May 2026 | 26 | 0/2/23 = 25 (QA-308) | `fl2026` |
| American Southwest 2026 (first) | 26 Aug 2026 | 5 | 0/1/4 = 5 ✓ | `sw2026` |
| Colorado 2026 | 14 Sep 2026 | 10 | 0/1/9 = 10 ✓ | `co2026` |
| Texas 2026 | 8 Oct 2026 | 19 | 0/0/19 = 19 ✓ | `tx2026` |
| American South 2026 (GA, LA, NC, SC, TN) | 21 Oct 2026 | — (no results article yet) | 0/1/21 = 22 | `south2026event` (date) |
| Mexico 2026 | 20 May 2026 | 29 | 0/2/27 = 29 ✓ | `mx2026` |
| Québec 2026 | 6 May 2026 | 13 | 0/1/12 = 13 ✓ | `qc2026` |
| Toronto & Region 2026 | 22 Sep 2026 | 15 | 0/1/14 = 15 ✓ | `tor2026` |
| Vancouver 2026 | 6 Oct 2026 | 11 | 0/1/10 = 11 ✓ | `van2026` |

- **Listings:** `/en/{us,ca,mx}/restaurants/{3-stars,2-stars,1-star}-michelin`
  (+ `/page/N`): US 16/40/223, CA 0/3/36, MX 0/2/27 = 347
  (`_source/michelin_restaurant_listing_20261029.json`; four Metro Manila cards
  served on a past-the-end Mexico page are ignored by their own country
  attribute). **Every page was read** (`_source/michelin_restaurant_pages_20261029.jsonl`:
  JSON-LD address, coordinates, phone, star rating, dateAwarded, plus the
  website and "Stay at the hotel" links); listing tier and page agree on all 347.
- **Absentees:** every restaurant linked from those articles but missing from
  the live listing was fetched (`_source/article_entries_not_in_listing_20261029.csv`):
  101 are Bib Gourmands or selected; 7 starred ones now 404 (QA-308). None is in
  production, none is added.
- **Keys:** MICHELIN's 2026 Key reveal, **18 September 2026**
  (`keys_us2026`, `keys_ca2026`, `keys_mx2026`, `keys_world2026`): US 359,
  Canada 42 (2/8/32), Mexico 98 (3/21/74). The hotel listings
  `/en/hotels-stays/{usa,canada,mexico}` (1,311 + 126 + 222; every card's
  `data-distinction`) give 498 Key cards; **each Key page was read** and its
  JSON-LD `award` agrees with the card on all 498
  (`_source/michelin_key_hotel_pages_20261029.json`). By `addressCountry`:
  US 15/78/266, CA 2/8/32, MX 3/21/73. Mexico's 98th, Diez Diez Collection
  (Mérida, new), has no MICHELIN page anywhere (QA-305).
  Key rows: `guide_year 2026`, `announced_on 2026-09-18`. The file aborts if
  any current Key row in production is not 2026.

## Production before (export 2026-10-29) and matching

- US 51 restaurants (16×3★, 35×2★), 11 hotels, 22 cities; MX 6 restaurants
  (2×2★, 3×1★, Arca unstarred), 8 hotels, 11 cities; CA nothing.
- **Restaurants:** 9 by MICHELIN slug and town segment; 1 by slug without
  MICHELIN's numeric id suffix (Sushi Sho, the only candidate; its stored
  address is 1,118 m off, QA-302); 46 (no stored `michelin_url`) by
  coordinates + name (3–396 m; the wider ones are Blue Hill at Stone Barns
  on its farm and the NY rows MICHELIN pins at the door). Never by name alone.
- **Launch rows:** every existing row's single current row is a launch row
  (`guide_year 2026`, `announced_on` NULL). Where MICHELIN's current edition is
  2026 (California, Florida, Mexico) all 29 agree with the live page: verified,
  left as is. Where it is the Northeast Cities 2025 edition, 26 agree with the
  2025 value and are **relabelled 2025** (Germany's precedent). Sushi Sho
  already has a 2025 history row (3, not current), so relabelling would
  collide: its launch row is **deleted and the 2025 row made current**
  (product owner, 2026-10-30; QA-301), guarded on both rows' exact values.
  No changes, corrections or losses.
- **Hotels:** 13 by MICHELIN's numeric hotel id; Amangiri, The Beverly Hills
  Hotel, The Fifth Avenue Hotel and Rosewood Mayakoba (no stored url) by
  coordinates + name (4–394 m; the builder stops if a new hotel would share
  a name with an unmatched existing row). San Ysidro Ranch and Rosewood
  Mayakoba were World's 50 Best rows without a Key and gain one; Equinox Hotel
  New York and Four Seasons Tamarindo have no Key and are untouched (QA-309).
  No existing hotel lost its Key. 16 of the 17 had no Key row in
  `award_history`; the file adds them, guarded by NOT EXISTS.

## Research per row

`{us,ca,mx}_research_2026.csv` (restaurants, with guide / guide_year /
announced_on); `{us,ca,mx}_key_hotels_2026.csv` (hotels), each with its
evidence.

### Phones (restaurants)

As for GB/IE: **confirmed** when MICHELIN's number is printed on the venue's
own site — first `check_restaurant_phones.py` on the home page and up to four
contact pages (219 of 319 MICHELIN numbers), then by hand for the rest
(`_source/research_brief_restaurant_phones.md`, results
`_source/restaurant_phone_confirmations.csv`: 18 more). Held back (QA-303): 10
where the site prints a different number, the Grand Velas resort line for
Cocina de Autor Riviera Maya, and the MICHELIN-only numbers. Many US sites
publish no number (Tock/Resy only).

### Hotels: website and phone

`_source/research_brief_hotels.md` (the UK brief, country parts changed); raw
results `{us,ca,mx}_key_hotel_contacts_research.csv`. Carried only when
`confirmed`, and a website only when the site showed **name + town + address**.
Held back: `group` lines, and any number the research gives to two hotels
(Blind Tiger Portland ×2, Belvedere and The Smith in Kingston, three Mexican
resorts). `reservations` lines (often toll-free) that are the hotel's only
number are kept and labelled, as for GB. Missing: QA-304 — mostly brand sites
that refuse automated access (Four Seasons, Marriott, Hyatt, Hilton,
Peninsula, Montage). Many trap domains were caught (parked, for sale, or
hijacked to gambling spam); see the CSV notes.

### Hotel links and property names

Never by name alone. A link needs one of:

- MICHELIN's restaurant page says **"Stay at the hotel"** for a Key hotel,
  identified by MICHELIN's hotel id (6: Auberge du Soleil, Auro, Caruso's,
  The Surf Club Restaurant, SingleThread, The Inn at Little Washington);
- MICHELIN's restaurant address **starts with the Key hotel's name** as its own
  digit-free first segment, and that hotel's MICHELIN pin is within 150 m
  (3: Atlas — The St. Regis Atlanta; Kappo Kappo — Austin Proper Hotel;
  Ixi'im — Chablé Yucatán). A street that shares a hotel's name ("342 Bowery"
  vs The Bowery Hotel) does not count — that near-miss is why the rule reads
  the first segment only.

There is no "Inside the …-Key" star article for these guides, so links are
fewer than for the UK. `exact` within 100 m, else `campus`. SingleThread and
The Inn at Little Washington had `property_name` set to their own inn; the
link replaces it (hotel scope rule 3), guarded on the stored value. A
"Stay at the hotel" link to a non-Key hotel goes in `property_name`.

One link is by hand (`VERIFIED_LINKS` in `build_prepared.py`, QA-307):
**Harbor House Inn**. MICHELIN gives no "Stay at the hotel" link, but the
site MICHELIN's restaurant page links to, theharborhouseinn.com, is one
business for the inn and the two-star restaurant (one address, one phone,
"our Michelin-starred restaurant" beside the inn's 11 rooms; read
2026-10-30); pins 97 m apart, `exact`. Its `property_name` gives way to the
link like the two above. Linked on the product owner's go-ahead.

### Place IDs — not done (QA-300)

No Places API access in this session; every new row carries NULL. The
coordinates in the research CSVs are ready for a find-place-id pass.

### Towns

MICHELIN's town names. Restaurant towns from the restaurant pages (Brooklyn,
Queens, Québec, Montréal); Mexico City's alcaldías go to production's
"Mexico City", Chocholá to production's "Chocholá, Yucatán". Hotel towns are
the hotel page's locality, often an area in the US (Los Angeles Area,
Napa / Sonoma Valleys, Island of Maui …; 29 such towns), as for GB; kept by
the product owner's decision of 2026-10-30 (QA-306);
"Washington D.C." goes to production's Washington (District of Columbia).
Cities resolve on (name, region); `region` is set only where one name is in
two states (Greensboro GA/NC, Portland ME/OR, Wilmington DE/NC, Washington
CT next to production's DC and Virginia rows).

## How the SQL is built

Generated, not hand-written:

```
python3 check_restaurant_phones.py ... (after fetch_restaurant_sites.py; site HTML not committed)
python3 build_research.py _source/restaurant_phone_check_20261029.json _source/restaurant_phone_confirmations.csv
python3 build_key_hotels.py
python3 build_prepared.py _source/export_20261029.json 3001 1501 20261023160000_add_us_ca_mx_2026_star_and_key_cities.sql
```

`_source/export_20261029.json` is the JSON cell of `export_us_ca_mx_query.sql`
(run with `supabase db query --linked -o json -f <abs path>`). Re-running on
that export reproduces both files byte for byte.

**Codes, migration and QA ids** were split with the parallel China/HK/MO/TW
session on 2026-10-29 (shared notes): this pass takes `rest_3001`+,
`hotel_1501`+, migration `20261023160000` and QA-300+; China took
`rest_2659`–`rest_2814`, `hotel_957`–`hotel_1007`, `20261023150000` and
QA-289–294, with HK/MO/TW continuing below `rest_3000`/`hotel_1500` and on
`20261023170000`. Production's highest codes at export: `rest_2658`,
`hotel_956`; `git grep` across every remote branch (2026-10-30) finds nothing
in `rest_3001`–`rest_3291` or `hotel_1501`–`hotel_1981`. The codes skip
`rest_2815`–`rest_3000` and `hotel_1008`–`hotel_1500` on purpose — gaps, not
collisions. The file aborts if any code in its ranges is taken. If
production changes, re-export and regenerate.

## Tested (2026-10-29/30)

`test_on_scratch.py` on a scratch PostgreSQL 17 (Homebrew): the six tables
rebuilt from **production's own catalog** (`_source/production_catalog_20261029.json`,
read-only query: columns, NOT NULLs, defaults, checks, unique and partial
indexes, `updated_at` triggers), PostGIS stubbed (geography as text), seeded
with the real export plus production's highest codes and a current 2026 Key row:

- **File without the migration:** aborts, nothing applied.
- **Migration + file:** applies; the counts in the table above, 10 links, CA
  country row with 23 zones, Eleven Madison Park 2012 → 2025 (current),
  Sushi Sho 2025 only (current; launch row gone), new rows with their guide's date.
- **Re-run of the file:** aborts. **Re-run of the migration:** no-op.
- **A renamed existing row:** aborts the whole file.
- **A restaurant code in the file's range taken:** aborts.

Not run against the real database, and not a full migration replay (PostGIS,
RLS, gist/trigram indexes and the other tables were not reproduced).

## Not done here

- Place IDs (QA-300).
- The Northeast Cities 2026 edition (14 Dec 2026) — a follow-up pass.
- The engineering CHANGELOG (`docs/Plannnig/CHANGELOG.md`) and the
  Michelin_Database CHANGELOG are written when the files are applied, as for
  the UK and Ireland.
- QA ids QA-300–QA-309.
