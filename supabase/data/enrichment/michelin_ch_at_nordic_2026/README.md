# Switzerland, Austria & the Nordic Countries: MICHELIN stars and 2026 Keys (research 2026-10-30)

Status: **PREPARED — NOT APPLIED.** Generated from production's export of
2026-10-29 23:12 UTC (`export_ch_at_nordic_query.sql`). To apply, run in order:

1. `supabase/migrations/20261023180000_add_ch_at_nordic_star_and_key_cities.sql`
   (**adds the `countries` row for Iceland**, then the new towns), with
   `supabase db push --linked`
2. `prepared_ch_at_nordic_stars_2026.sql` (one transaction; aborts on any
   check), with `supabase db query --linked -f <absolute path>`

Review `match_report.csv` first (rows labelled by country) and the decisions
below. **Switzerland's 2026 edition is announced on 2 November 2026**, three
days after this pass (QA-360): read that section before deciding when to apply.

| After applying | CH | AT | DK | FO | SE | NO | FI | IS |
|---|---|---|---|---|---|---|---|---|
| Stars (3/2/1) | 4/27/103 | 2/19/78 | 3/6/32 | 0/1/0 | 1/5/18 | 2/2/17 | 0/2/6 | 0/0/3 |
| … vs MICHELIN live | live 4/24/103 + 3 kept (QA-362) | exact | exact | exact | live 1/4/18 + Aloë untouched (QA-363) | exact | exact | exact |
| Star edition | **2025** | 2026 | 2026 | 2026 | 2026 | 2026 | 2026 | 2026 |
| Restaurants added | 103 | 79 | 32 | 0 | 18 | 18 | 7 | 3 |
| … with a phone | 98 | 74 | 30 | — | 15 | 11 | 7 | 1 |
| … with a Google Place ID | **0** | **0** | **0** | — | **0** | **0** | **0** | **0** |
| Key hotels (3/2/1), MICHELIN 2026 exactly | 10/31/48 | 2/21/49 | 0/1/8 | — | 0/1/10 | 0/2/14 | 0/0/3 | 0/1/4 |
| Key hotels added (website/phone NULL, QA-368) | 47 | 24 | 9 | — | 10 | 16 | 3 | 5 |
| Key changes on existing hotels (QA-366) | 4 | 1 | — | — | — | — | — | — |
| Hotel links added (17 before) | 13 | 3 | 1 | — | — | 2 | — | — |
| `property_name` (non-Key host hotel) | 1 new + 3 existing | — | 1 | — | — | — | — | — |
| Existing rows filled (fill-only): phone / website / `michelin_url` | 24 / 27 / 25 | 18 / 20 / 18 | 4 / 9 / 5 | 1 / 1 / 1 | 3 / 5 / 4 | 2 / 2 / 2 | 1 / 1 / 1 | — |
| New towns (migration) | 64 | 49 | 18 | — | 6 | 14 | 3 | 5 + country row |

Codes: restaurants `rest_3501`–`rest_3760` (260), hotels `hotel_2501`–`hotel_2614` (114).

Every restaurant in these countries ends with exactly one current
`michelin_stars` row agreeing with `michelin_stars`, none labelled after its
guide's edition; every Key hotel with exactly one current 2026 `michelin_keys`
row agreeing with `michelin_keys`. Both are post-conditions in the file.

## Decisions waiting for you

- **QA-360 — Switzerland is the 2025 edition; the 2026 one lands on 2 Nov 2026.**
  MICHELIN's live Swiss selection is the **MICHELIN Guide Switzerland 2025**
  (announced 20 October 2025, Lausanne; every live page carries
  `dateAwarded "2025"`). MICHELIN's own article of 5 October 2026 announces
  the 2026 selection for **2 November 2026** in Andermatt
  (`_source/michelin_article_ch_ceremony_andermatt_2026_it.txt`). So:
  - All 31 Swiss launch rows (labelled 2026, `announced_on` NULL) hold 2025
    values: 30 agree with the 2025 edition exactly and are **relabelled 2025,
    values unchanged** (the QA-217 rule, as for the Netherlands and Germany);
    La Brezza Arosa is the exception (QA-361). Without the relabel, the real
    2026 rows on 2 November would have nowhere to go.
  - The 103 new Swiss restaurants get `guide_year 2025`,
    `announced_on 2025-10-20`.
  - Applying now and then running a 2026 pass after 2 November is safe: the
    restaurants, towns, phones and links carry over, and 2026 becomes a set of
    changes. Waiting and regenerating against the 2026 listing is equally
    possible (`build_prepared.py` is re-runnable; set CH to 2026 in `GUIDES`).
- **QA-361 — La Brezza (Arosa), `rest_0240`: production 3 stars, MICHELIN 2.**
  The 2025 edition lists Arosa's La Brezza among the two-star restaurants, and
  its live page gives Two Stars. The launch value 3 matches no MICHELIN edition:
  corrected in place to 2 (and relabelled 2025). Ascona's La Brezza
  (`rest_0241`, 2) is a separate restaurant, matched by its own pin (54 m).
- **QA-362 — IGNIV by Andreas Caminada (Bad Ragaz) `rest_0243`, Stucki – Tanja
  Grandits (Basel) `rest_0245`, Skin's – the restaurant (Lenzburg) `rest_0251`.**
  All three are two-star in the 2025 edition (MICHELIN's full 2025 list,
  `_source/michelin_article_ch_all_starred_2025_de.txt`), but their MICHELIN
  pages now return 404 and they are not in the live listing. **Kept at 2025 = 2**
  (relabelled launch rows): a 2026 loss row would anticipate an edition that
  is not published yet, and a 404 does not prove closure. The 2 November pass
  settles them; if you know they closed, `status` is the place for it.
- **QA-363 — Aloë (Stockholm) `rest_0482`, 2 stars in production.** Not in
  MICHELIN's 2026 Nordic list, and its page returns 404. Its launch row is
  labelled 2026, which is wrong either way, but the 2025 value needed to
  relabel it could not be verified (no 2025 full list found on MICHELIN's
  site; the Internet Archive refused the lookup with HTTP 429). **Left
  untouched**, so SE ends at 1/5/18 (MICHELIN live: 1/4/18). If you confirm it
  was two-star in the 2025 Nordic edition (16 June 2025), the record is:

  ```sql
  update public.award_history ah set guide_year = 2025 from public.restaurants r
   where r.restaurant_code = 'rest_0482' and r.name = 'Aloë' and ah.entity_id = r.id
     and ah.entity_type = 'restaurant' and ah.award_type = 'michelin_stars'
     and ah.guide_year = 2026 and ah.is_current and ah.award_value = 2;
  update public.award_history ah set is_current = false from public.restaurants r
   where r.restaurant_code = 'rest_0482' and ah.entity_id = r.id and ah.award_type = 'michelin_stars' and ah.is_current;
  insert into public.award_history (entity_type, entity_id, guide_year, award_type, award_value, is_current, announced_on)
  select 'restaurant', id, 2026, 'michelin_stars', NULL, true, date '2026-06-01' from public.restaurants where restaurant_code = 'rest_0482';
  update public.restaurants set michelin_stars = NULL, updated_at = now() where restaurant_code = 'rest_0482';
  ```
- **QA-364 — VYN `rest_0142` (stored as Skillinge) moved.** Matched to
  MICHELIN's VYN page by its phone, +46 414 204 00, exactly the stored one;
  MICHELIN's pin and address (Höga vägen 72, 272 92 Simrishamn) are 2,359 m from
  the stored Fiskaregatan 2, Skillinge point. Its 2026 value (2) agrees, so its
  award row is verified; **the stored address and point are left for you**
  (fill-only rule). MICHELIN's separate "Vyn Food & Wine Bar" (Simrishamn,
  2026 addition, no star) is another venue.
- **QA-367 — hotel towns.** Hotel pages give the locality, which is sometimes
  an area (as for Spain and the UK, QA-286). Two new hotels get MICHELIN's own
  town instead: Hotel Continental → Oslo (MICHELIN's 2025 Nordic Key article,
  "Oslo: Hotel Continental"), Lieperts Café Dinner Rooms → Leutschach an der
  Weinstraße (same street address as MICHELIN's Lieperts restaurant page). Three
  keep MICHELIN's area-level locality, for review: **Hotel Brosundet and Nusfjord
  Village & Resort ("Norway")** and **DasPosthotel ("Tyrol")** — MICHELIN prints
  no town for them anywhere found. Their postcodes are in the address.
- **QA-374 — Ecco (Ascona).** MICHELIN's page says "Stay at the hotel" →
  Giardino Mountain, which is in St. Moritz (the same link Ecco St. Moritz
  carries). Not used: no link, no `property_name` (`decisions.json`).
- **QA-370 — new `countries` row for Iceland.** Below.

## The new IS `countries` row — call-out for review

Production has no `countries` row for IS (read-only check 2026-10-30) and holds
no IS restaurant, hotel or city. MICHELIN's Nordic Countries guide covers
Iceland (2026: DILL, Moss, ÓX at one star; 5 Key hotels), so the migration
inserts it first, as `20261023140000` did for Ireland:

```sql
insert into public.countries (country_code, name, flag_emoji, timezones)
values ('IS', 'Iceland', '🇮🇸', array['Atlantic/Reykjavik'])
on conflict (country_code) do nothing;
```

The zone is the only IS entry in this machine's tzdata 2025b `zone.tab`
(`IS  +6409-02151  Atlantic/Reykjavik`), and `Atlantic/Reykjavik` is in
production's `pg_timezone_names` (checked 2026-10-30). The Faroe Islands
(`FO`, `{Atlantic/Faroe}`) and Denmark already have rows. MICHELIN files no
starred restaurant or Key hotel in Greenland (`/en/gl/restaurants/*` and
`/en/hotels-stays/greenland` list none), so no GL row.

## Sources (guide.michelin.com, read 2026-10-30, in the built-in browser)

Saved in `_source/`.

| Guide | Edition, announced | Published totals | Live listing (3/2/1) |
|---|---|---|---|
| Switzerland | 2025, 20 Oct 2025 (Lausanne) | 145: 4/27/114 | 131: 4/24/103 |
| Austria | 2026, 18 Mar 2026 | 101: 2/20/79 | 99: 2/19/78 |
| Nordic Countries | 2026, 1 Jun 2026 (Copenhagen) | 6/15/78 | DK 3/6/32, FO 0/1/0, SE 1/4/18, NO 2/2/17, FI 0/2/6, IS 0/0/3 |
| Keys (all) | 2026, global launch 18 Sep 2026 | CH 89, AT 72, NO 16, SE 11, DK 9, IS 5, FI 3 | identical |

- **Listings:** `/en/{ch,at,dk,se,no,fi,is}/restaurants/{3-stars,2-stars,1-star}-michelin`,
  every page (`michelin_listing_20261030.json`; cards of other countries that
  MICHELIN mixes into a page are listed there, not counted). `/en/fo/...` is
  404: MICHELIN files **PAZ** (Tórshavn) under Denmark; its page's
  `addressRegion` "Faroe Islands" puts it in FO.
- **Every restaurant page** (327) was read: JSON-LD address, coordinates,
  phone, cuisine, stars, `dateAwarded` (CH all 2025, the rest all 2026), the
  website link and the "Stay at the hotel" link
  (`michelin_restaurant_pages_20261030.jsonl`). Stars agree with the listing on
  every page.
- **Published vs live:** the restaurants in an edition's article but not live
  (Switzerland 14, Austria 2 — including Die Weinbank, a new two-star in the
  article —, Norway 2 including Bar Amour "now closed") are not added, as for
  Spain and Italy. Of them, only the four in QA-362/363 exist in production.
- **Articles:** `michelin_article_*.txt` — the Swiss 2025 full list and new
  stars (German), the Swiss 2025 announcement, the Andermatt 2026 date, the
  Austrian 2026 full list, the Nordic 2026 full list, winners and additions,
  the Nordic 2025 winners, and the Key articles (2025 Switzerland, 2025
  Austria, 2025 Nordic, 2026 global).
- **Keys:** the country hotel listings (`/en/hotels-stays/<country>`, every
  page, `michelin_hotel_listing_20261030.json`) carry the Key on each card;
  every Key hotel's page was then read and its JSON-LD `award` decides
  (`michelin_hotel_pages_20261030.json`). Card and page agree on all 205, and
  the counts equal MICHELIN's 2026 global Key article per country.
- **Liechtenstein** (Torkel, Vaduz, in the Swiss 2025 list; Key hotels new in
  2026) is out: not Switzerland and no LI country row, like the Channel Islands
  for the UK (QA-371).

## Production before (export 2026-10-29 23:12 UTC)

| | CH | AT | DK | FO | SE | NO | FI | IS |
|---|---|---|---|---|---|---|---|---|
| Restaurants (3/2/1) | 5/26/0 | 2/18/0 | 3/6/0 | 0/1/0 | 1/5/0 | 2/1/0 | 0/1/0 | — |
| Key hotels | 42 | 48 | 0 | 0 | 1 | 0 | 0 | — |

- **Restaurants** matched by MICHELIN slug and town segment (any locale prefix)
  where a URL is stored, else coordinates within 200 m and a name check (3–81 m
  here), VYN by phone (QA-364). Never by name alone.
- **AT and Nordic launch rows** (labelled 2026) hold exactly MICHELIN's live 2026
  value on every matched row, including Kadeau's 2026 promotion to three stars:
  verified, left as is, `announced_on` NULL. No relabel. Aloë is the exception
  (QA-363).
- **Hotels** matched by MICHELIN's numeric hotel id. Production's CH and AT Key
  rows are all labelled 2026; 85 of 90 agree with MICHELIN's 2026 Key and are
  verified. **Five changed in 2026 (QA-366):** Beau-Rivage Palace 2 → 3, Kulm
  Hotel St. Moritz 2 → 3, Beau-Rivage Geneva 3 → 2, Hotel Villa Honegg 2 → 1,
  Schlosshotel Fiss 1 → 2. Each launch value is exactly the hotel's Key in
  MICHELIN's 2025 country Key article, so the launch row is relabelled 2025
  (non-current) and a 2026 row is written. The one SE hotel (Ett Hem) had no
  Key row at all and gets one.
- Two stored hotel points are ~800 m from MICHELIN's (Fairmont Le Montreux
  Palace, Scheiblhofer THE RESORT; QA-373), reported, not changed.

## Research per row

`<cc>_research.csv` (restaurants, `build_research.py`) and `<cc>_key_hotels.csv`
(hotels, `build_key_hotels.py`), each with its evidence.

### Phones (restaurants)

- **Confirmed** when MICHELIN's number is printed on the venue's own site:
  first an automated check of the home page and up to four contact pages
  (`fetch_restaurant_sites.py`, `check_restaurant_phones.py`: 251 of the 322
  pages with a MICHELIN number), then by hand for the other 71
  (`_source/research_brief_restaurant_phones.md`, results
  `_source/restaurant_phone_confirmations.csv`): 45 confirmed, of which
  Rouge Noir is held back (the number is only in the contact page's meta
  description).
- **Held back (QA-369):** 8 sites print a different number from MICHELIN's
  (Colonnade, Tsé Fung, The Japanese at Gütsch, Chesa Stüva Colani, Capri,
  Ikarus, Lukas Kapeller, PM & Vänner — each in the CSV, for you to choose);
  14 sites print no number (two have no website); 4 sites refused the fetch
  (7132 Silver, Pramerl & the Wolf, Frantzén, Moss). On new rows that leaves
  24 of 260 without a phone; existing rows only ever get a confirmed one.
- Where the site gives the hotel's main line for the restaurant (Ecco at
  Giardino Mountain, Griggeler Stuba, Paznaunerstube, Alpin Gourmet Stube,
  L'OURS), it is kept, labelled in the CSV notes.
- Format: international, as MICHELIN prints it.

### Key hotels: website and phone — not researched (QA-368)

The new Key hotels' website and phone are **NULL**. MICHELIN's hotel number is
often a booking line, and the Key-hotel contact rules
(`../michelin_key_hotel_contacts/`, the hotel's own site read per hotel) are a
pass of their own; MICHELIN's number is kept in the CSV (`michelin_phone`) as a
lead only. The existing CH/AT Key hotels already carry contacts from that work.

### Hotel links and property names

A link only where MICHELIN's restaurant page says **"Stay at the hotel"** and
that hotel is a 2026 Key hotel, identified by MICHELIN's hotel id; `exact`
within 100 m, else `campus`. A "Stay at the hotel" link to a hotel without a
Key goes in `property_name` (OZ → Casa Caminada, Dragsholm Slot Gourmet →
Dragsholm Slot). No other source is used, so a restaurant inside a Key hotel
whose MICHELIN page has no such section (Memories at Grand Resort Bad Ragaz,
for one) gets no link here.

### Place IDs — not done (QA-365)

No Places API access in this session, so **no Place ID was looked up** for the
new restaurants and hotels: NULL rather than guessed, coordinates ready for a
find-place-id pass.

### Towns

MICHELIN's English listing names for restaurants (Zurich, Geneva, Vienna,
Copenhagen, Gothenburg), as production writes towns; where production already
holds the municipality under another spelling, that one is used (Berne → Bern,
Saint Moritz → St. Moritz, Sankt Gallen → St. Gallen, Sankt Anton am Arlberg →
St. Anton am Arlberg, Sankt Veit im Pongau → St. Veit im Pongau, Maria Alm →
Maria Alm am Steinernen Meer; for hotels Luzern → Lucerne). Hotel towns are the
hotel page's locality (QA-367 above). Addresses keep the page's own locality
(Zürich, Wien, København), as production's do. Towns compare accent-, case-,
space- and hyphen-insensitively.

## How the SQL is built

Generated, not hand-written:

```
python3 fetch_restaurant_sites.py _source/michelin_restaurant_pages_20261030.jsonl <sites_dir>
python3 check_restaurant_phones.py _source/michelin_restaurant_pages_20261030.jsonl <sites_dir> _source/restaurant_phone_check_20261030.json
python3 build_research.py _source/restaurant_phone_check_20261030.json _source/restaurant_phone_confirmations.csv
python3 build_key_hotels.py
python3 build_prepared.py <export.json> 3501 2501 20261023180000_add_ch_at_nordic_star_and_key_cities.sql
```

`export.json` is the JSON cell of `export_ch_at_nordic_query.sql` (run with
`supabase db query --linked -o json -f <abs path>`). Every by-hand judgement is
in `decisions.json`, with its evidence. Re-running on the 2026-10-29 export
reproduces both files byte for byte.

**Codes and ids** (checked 2026-10-30 against production — highest `rest_2658`,
`hotel_956` — and with `git grep` across all 22 remote branches, and claimed in
the session notes): restaurants `rest_3501`–`rest_3760`, hotels `hotel_2501`–`hotel_2614` (above the China,
US/Canada/Mexico and French Key blocks); migration `20261023180000` (between
China/HK/MO/TW `170000` and French Keys `190000`, the slot left for this pass);
QA-360–QA-374. The file aborts if any code in its ranges is taken. If
production changes, re-export and regenerate.

## Tested (2026-10-30)

On a scratch PostgreSQL 17 with PostGIS stubbed (geography as text), mirroring
production's columns, constraints, unique and partial indexes and triggers for
`countries`, `cities`, `restaurants`, `hotels`, `hotel_restaurants` and
`award_history` (read from production's catalog), seeded with the real export:

- **Without the migration:** aborts at the first hotel city; nothing applied.
- **Migration + file:** applies; the per-country stars and Keys above, the IS
  country row with `{Atlantic/Reykjavik}`, 19 new links (36 in all), one
  current award row each; the five Key changes end with a non-current 2025 row
  and a current 2026 row; the 31 Swiss launch rows are 2025 (La Brezza Arosa 2).
- **Re-run of the file:** aborts. **Re-run of the migration:** no-op.
- **A renamed existing row:** aborts the whole file. **A code in the range
  already taken** (restaurant or hotel): aborts the whole file.

Not run against the real database, and not a full migration replay (PostGIS,
RLS and the other tables were not reproduced).

## New QA ids

| Id | What |
|---|---|
| QA-360 | Switzerland's live selection is the 2025 edition; 31 launch rows relabelled 2025; re-run after 2 Nov 2026 |
| QA-361 | La Brezza (Arosa) launch row 3 is an import error; MICHELIN 2025 gives 2 |
| QA-362 | IGNIV Bad Ragaz, Stucki, Skin's: two-star in 2025, MICHELIN page 404; kept |
| QA-363 | Aloë: not in 2026, 2025 value unverified; left untouched for a decision |
| QA-364 | VYN moved Skillinge → Simrishamn; matched by phone; stored address and point stale |
| QA-365 | No Place IDs for the new rows (no Places API) |
| QA-366 | Five CH/AT Key launch rows hold the 2025 Key; relabelled 2025, 2026 changes written |
| QA-367 | Hotel localities that are a region or the country; two resolved from MICHELIN, three kept |
| QA-368 | New Key hotels' website and phone not researched |
| QA-369 | Restaurant phones held back (MICHELIN only, or the site prints another number) |
| QA-370 | New `countries` row for Iceland |
| QA-371 | Liechtenstein entries in the Swiss guide left out (no LI country row) |
| QA-372 | Edition totals vs live listings: entries no longer live are not added |
| QA-373 | Two stored CH/AT hotel points ~800 m from MICHELIN's |
| QA-374 | MICHELIN's Ecco (Ascona) page gives Giardino Mountain (St. Moritz) as its hotel; not used |

## Not done here

- Place IDs (QA-365) and Key-hotel contacts (QA-368).
- The engineering CHANGELOG (`docs/Plannnig/CHANGELOG.md`) and the
  Michelin_Database CHANGELOG are written when the files are applied, as for
  Germany/Italy and the UK.
