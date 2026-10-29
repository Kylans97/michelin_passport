# Mainland China: MICHELIN stars and Keys (research 2026-10-29)

Status: **PREPARED, NOT APPLIED.** Generated from production's export of
2026-10-29 22:53 UTC (unchanged from the 22:22 export the research started
from). To apply, run in order:

1. `supabase/migrations/20261023150000_add_cn_2026_star_and_key_cities.sql`
   (21 towns), with `supabase db push --linked`
2. `prepared_cn_stars_2026.sql` (one transaction; aborts on any check),
   with `supabase db query --linked -f <absolute path>`

Review `match_report.csv` first. **The decisions waiting for you:**

- **The coordinate datum (QA-290).** This one matters most. See "Coordinates" below.
- **Fu Chun Ju (QA-291).** It is not linked to The PuXuan.
- **Amanfayun (QA-292).** It is MICHELIN's missing 55th Key.
- **Phones held back for venues without a website (QA-289).**

| After applying | Mainland China (CN) |
|---|---|
| Stars (3/2/1) | 4/24/131, exactly MICHELIN's live "Chinese Mainland" listing |
| Restaurants added | 156 (`rest_2659`–`rest_2814`) |
| … with a phone / website | 40 / 78 |
| … with `property_name` (non-Key host hotel) | 24 |
| … with a Google Place ID | **0** (QA-289) |
| Key hotels (3/2/1) | 2/11/41, exactly MICHELIN's live Key listing (the 2026 reveal says 55: QA-292) |
| Key hotels added | 51 (`hotel_957`–`hotel_1007`) |
| … with website / phone | 28 / 28 |
| Key change on an existing hotel | Mandarin Oriental Qianmen (`hotel_704`): NULL → 3 Keys, plus its 2026 Key row |
| Hotel links (0 before) | 15, all `exact` |
| Existing rows filled (fill-only) | `michelin_url` for Xin Rong Ji (Xinyuan South Road) and King's Joy; King's Joy's website |
| Cities | 3 → 24 |

Every CN restaurant ends with exactly one current `michelin_stars` row that agrees
with `michelin_stars`. Each new one is in its own guide's edition, and the count
per edition is checked. Every CN Key hotel ends with exactly one current
`michelin_keys` row that agrees. All of these are post-conditions in the file.

## Editions: mainland China is five guides

MICHELIN publishes mainland China as separate city or regional guides at
different times of year. Every restaurant page's JSON-LD carries its edition
(`award.dateAwarded`). `build_research.py` asserts that each one agrees with the
guide below, and each award row takes its own guide's year and announcement
date.

| Guide (MICHELIN's "selection") | Edition | Announced | Live 3/2/1 | Article (`_source/`) |
|---|---|---|---|---|
| Beijing & Tianjin (Tianjin's first) | **2027** | 2026-10-27 | Beijing 2/5/26, Tianjin 0/0/1 | `michelin-guide-beijing-tianjin-2027` |
| Chengdu | **2027** | 2026-09-03 | 1/1/13 | `michelin-stars-chengdu-2027` |
| Guangzhou & Shenzhen (Shenzhen's first) | 2026 | 2026-08-18 | Guangzhou 0/3/17, Shenzhen 0/2/5 | `michelin-stars-guangzhou-shenzhen-2026` |
| Shanghai, Jiangsu & Zhejiang (first regional edition) | 2026 | 2026-04-09 | Shanghai 1/11/38; Hangzhou 0/2/11, Taizhou 0/0/4; Nanjing 0/0/4, Suzhou 0/0/3, Yangzhou 0/0/2 | `michelin-guide-shanghai-jiangsu-zhejiang` |
| Fujian | 2026 | 2025-11-21 | Fuzhou 0/0/3, Xiamen 0/0/3, Quanzhou 0/0/1 | `michelin-guide-fujian-2026` |

- **Announcement dates** come from each article's JSON-LD `datePublished`. In the
  two articles whose text states the ceremony date ("On April 9, 2026";
  "On November 21st"), `datePublished` is that date, while the date printed
  above the headline is a day earlier. The Keys row uses 2026-09-18, the date
  of the 2026 global Key reveal.
- **The articles agree with the listing** wherever they give counts: Beijing 2027
  "Chao Shang Chao (Chaoyang) and Xin Rong Ji (Xinyuan South Road) retain …
  Three MICHELIN Stars", 5 two-stars and 26 one-stars, and Tianjin's single
  one-star, China Banquet; Chengdu 2027 1/1/13; Guangzhou 3/17 and Shenzhen
  2/5. The Shanghai/Jiangsu/Zhejiang article counts 1/14/62 across the region.
  The live listing has 1/13/62: the article's two-star **102 House**
  (Shanghai) is no longer listed. It is not in production, so nothing is added
  (the Spain/Italy precedent for article-only rows).
- **Next:** Hunan's first selection (Changsha, Hengyang, Yiyang) is announced on
  25 November 2026 (QA-294). The other guides' next editions will follow.
- **Source:** the listing `guide.michelin.com/en/cn/restaurants/{3-stars,2-stars,1-star}-michelin`
  ("Chinese Mainland : 4 / 24 / 131"). Its cards also carry Philippines and Bib
  entries, which are filtered out by distinction. All 159 restaurant pages
  were read on 2026-10-29: `_source/michelin_cn_restaurant_pages_20261029.jsonl`.

## Production before (export 2026-10-29)

CN had 3 restaurants, 3 hotels and 3 cities (Beijing, Shanghai, Shenzhen), and no
links. The `countries` row exists, with `{Asia/Shanghai, Asia/Urumqi}`.

- **Xin Rong Ji (Xinyuan South Road)** (3) and **King's Joy** (2) had no
  `michelin_url`. They are matched by coordinates and name, after shifting
  MICHELIN's pin to GCJ-02 (42 m and 10 m; see "Coordinates"). The street
  addresses agree as well. **Fu He Hui** (2) is matched by MICHELIN slug.
- **All three are unchanged.** Their current rows (2026 = 3, 2 and 2) hold
  what MICHELIN's current editions give: Beijing 2026 and 2027 both list Xin
  Rong Ji at 3 and King's Joy at 2, and Shanghai 2026 lists Fu He Hui at 2. Per
  DATA_UPDATE_PROCESS §3 ("Unchanged. No action."), no 2027 row is written for
  the Beijing pair. Their launch label 2026 is the Beijing 2026 edition, so it
  needs no relabel.
- **Hotels** are matched by MICHELIN's numeric hotel id. The Peninsula Shanghai
  and Mandarin Oriental Shenzhen hold 2 Keys with a 2026 row, and agree.
  **Mandarin Oriental Qianmen** (`hotel_704`, a World's 50 Best hotel stored
  with `michelin_keys` NULL) carries 3 Keys on MICHELIN's page. MICHELIN's
  2026 Three-Key article lists it among the new Three-Key hotels, so the file
  sets 3 and adds the 2026 row. The update is NULL-safe (`is not distinct from`).

## Coordinates: GCJ-02 (QA-290), the decision that matters most

Mainland Chinese maps use **GCJ-02**, a legally mandated obfuscation of WGS-84
that shifts points by roughly 300–700 m. `location` is `geography` SRID 4326
(WGS-84), and the app draws its maps on OpenStreetMap tiles (WGS-84:
`lib/features/map/visited_map_screen.dart`), so a GCJ-02 point shows up about
500 m off.

What this pass found:

- **Production's CN rows are GCJ-02** (they came from Google). Each of the 3
  restaurants is 3–42 m from MICHELIN's pin *shifted to GCJ-02*, and 487–550 m
  from the pin itself. The 3 hotels are similar, though less consistent.
- **MICHELIN's restaurant pins are WGS-84.** That is the evidence above, plus
  Jin Sha, 91 m from OpenStreetMap's Four Seasons Hangzhou at West Lake. They are
  stored as printed.
- **MICHELIN's China hotel pins are GCJ-02.** Converted back with the standard
  inverse (`gcj02.py`), 18 of the 21 Key hotels that OpenStreetMap names land
  15–237 m from OSM's point; raw, they are 352–662 m off. The exceptions are a
  resort area, a mall OSM returns for "Raffles Shenzhen", and Hotel Éclat (410 m).
  Results: `_source/osm_nominatim_key_hotels_20261029.json`. **New hotel rows
  take the converted point.** The raw pin is kept in `cn_key_hotels_2026.csv`.
- **Existing rows are not changed** (fill-only). Converting the six existing
  CN points is a separate decision, and so is any later Place ID pass: Google's
  China coordinates must not be copied without conversion.
- Hong Kong, Macau and Taiwan have no offset.

**Wrong pins (QA-291).** Three restaurants inside Key hotels have MICHELIN pins
571 m–2.2 km from the hotel that MICHELIN's own address names, while the
hotel's point is confirmed by OSM. Yi Long Court (The Peninsula), le Comptoir de
Pierre Gagnaire (Capella Shanghai) and Zijin Mansion (Waldorf Astoria Beijing)
take the hotel's point, as in the Gravetye precedent (`COORD_FIX` in
`build_research.py`). **Fu Chun Ju**'s address matches The PuXuan's ("1
Wangfujing Street"), but the two MICHELIN points are 2.2 km apart and neither
can be confirmed. It is neither linked nor given a `property_name`.

## Hotel links and property names

MICHELIN's China restaurant pages carry no "Stay at the hotel" section. Its
hotel pages list only "Restaurants near the hotel", which is proximity, not
containment. The evidence is therefore **MICHELIN's own printed restaurant
address**, e.g. "71F, Four Seasons Hotel, 5 Zhujiang West Road".

- **Link** (`HOSTS` in `build_research.py`, checked again in `build_prepared.py`)
  needs all three:
  - the restaurant's MICHELIN address places it inside a Key hotel;
  - that Key hotel's own MICHELIN page gives the same street number, or, where
    it prints none, the same street address ("Jing Guang Centre, Hujialou");
  - the two points are within 300 m.

  All 15 links are `exact`. Two of them are to existing hotels: Opus 388 and The
  Bay by Chef Fei to Mandarin Oriental Shenzhen, and Yi Long Court to The
  Peninsula Shanghai.
- **`property_name`** (24): the host hotel is not a MICHELIN Key hotel. It is
  written as MICHELIN's address prints it, so it is sometimes generic, e.g.
  "The Ritz-Carlton Hotel" for Jingji in Beijing. Hangzhou House takes
  "Amanfayun": MICHELIN's restaurant address misprints it as "Amandayun", and
  MICHELIN's Amanfayun page has the same 22 Fayun Lane address.

## Key hotels

`guide.michelin.com/en/hotels-stays/china?distinction=all-keys` gives
"China : 54 hotels" (the unfiltered listing has 336). Unlike the UK listing,
this one does filter server-side. Every page's JSON-LD `award` was read, and
all 54 carry a Key: 2/11/41.

- **The 55th hotel (QA-292).** MICHELIN's 2026 global Key article (18 Sep 2026)
  says "Mainland China – 55 Key hotels" but gives no split. The 55th is not
  found. Amanfayun was a nominee for the Local Gateway award announced that
  day, but its page carries no Key now, so it is not added.
- **Towns** are the hotel page's locality. Five districts are written as their
  municipality, per MICHELIN's own `addressRegion`: Tian He → Guangzhou,
  Chaoyang and Dongcheng → Beijing, Pudong and Huangpu → Shanghai. Area
  localities stay, as for GB/Spain: Jiuzhaigou, Shangrila, Lingshui, Deqin,
  Guilin (Yangshuo), and Chengdu for Six Senses at Qingcheng Mountain.
- **Website and phone** were researched per hotel with
  `_source/research_brief_cn_hotels.md`, adapted from the UK brief. Raw results
  are in `cn_key_hotel_contacts_research.csv`.
  - 28 of 51 are confirmed on the hotel's own page, matched on name, city and
    address.
  - IHG and Marriott properties are confirmed on the brands' China mirrors
    (ihg.com.cn, marriott.com.cn). The international URL is in the notes.
  - The other 23 refused automated access (hyatt, fourseasons, bulgarihotels,
    capella, banyantree, sixsenses, peninsula, shangri-la, plus hilton timeouts)
    or have no site of their own (Yanbai Villa, Deqin Meri Poodom). They stay
    NULL (QA-289).
  - Raffles Shenzhen's only number is its reservations line. It is kept and
    labelled, as for the UK.
  - The PuXuan's and Xitan's own sites print a different number from MICHELIN's.
    The hotel's own number is carried (QA-293).
  - 1 Hotel Haitang Bay now trades as "Sunshine Yi Hotel" (QA-293).

## Restaurant phones (QA-289)

A phone is carried only when MICHELIN's number is printed on the venue's own
site:

- **29** were confirmed by the automated check (`check_restaurant_phones.py`,
  national +86 form).
- **11** were confirmed by hand (`_source/cn_restaurant_phone_confirmations.csv`,
  brief `_source/research_brief_cn_restaurant_phones.md`).
- **Held back:** 3 sites print a different number (Vivant, The Hall, BingSheng
  Mansion). 2 are the White Swan Hotel switchboard with an extension (Hongtu
  Hall, Jade River), left out under the Germany/Italy rule. 30 sites could not be
  loaded: bot-blocked brand sites, JavaScript-only Xin Rong Ji pages, and the
  expired dadongdadong.com.
- **No website at all on MICHELIN** for 80 of the 159 restaurants. Their
  numbers are MICHELIN-only, so they are held back.

## How the SQL is built

Generated, not hand-written:

```
python3 build_research.py _source/cn_restaurant_phone_check_20261029.json _source/cn_restaurant_phone_confirmations.csv
python3 build_key_hotels.py
python3 build_prepared.py <export.json> 2659 957 20261023150000_add_cn_2026_star_and_key_cities.sql
```

`export.json` is the JSON cell of `export_cn_query.sql` (run with
`supabase db query --linked -o json -f <abs path>`).

**Codes.** Production's highest are `rest_2658` and `hotel_956`. The US/CA/MX
session left `rest_2659`–`rest_3000`, `hotel_957`–`hotel_1500` and QA-289–299
for China/HK/MO/TW (shared notes, 2026-10-29). No branch claims anything in
those ranges (`git grep` across all remote branches). The file aborts if any
code in its ranges is taken.

**Migration name.** Production's ledger ends at `20261023140000`, and
US/CA/MX took `20261023160000`, so this is `20261023150000`. If US/CA/MX is
applied first, this one sorts before it. Both only insert distinct cities, so
replay order does not matter, but apply with `db push --include-all` in that
case.

## Tested (2026-10-29)

On a scratch PostgreSQL 17 with PostGIS stubbed (geography as text). The scratch
database has the UK session's mirror of production's columns, constraints,
unique and partial indexes and triggers for `countries`, `cities`,
`restaurants`, `hotels`, `hotel_restaurants` and `award_history` (columns
re-checked against production's catalog for this pass), and is seeded with the
real CN export plus the CN hotels' real Key rows.

- **Migration + file:** applies. The result is:
  - CN at 4/24/131 stars and 2/11/41 Keys;
  - 24 cities and 15 links;
  - new award rows of 2026 by 9 Apr 2026 (75), 18 Aug 2026 (27) and
    21 Nov 2025 (7), and of 2027 by 3 Sep 2026 (15) and 27 Oct 2026 (32);
  - Qianmen at 3 with one current Key row.
- **Without the migration:** aborts, nothing applied.
- **Re-run of the file:** aborts. **Re-run of the migration:** no-op.
- **A renamed existing row, or a code in range already taken:** aborts the
  whole file.

It was not run against the real database, and it was not a full migration
replay: PostGIS, RLS and the other tables were not reproduced.

## Hong Kong, Macau, Taiwan (out of this file; next, by the product owner's decision)

These are MICHELIN live counts on 2026-10-29, against production
(`_source/michelin_hk_mo_tw_counts_20261029.json`):

| | Live 3/2/1 | Production 3/2/1 | Edition |
|---|---|---|---|
| Hong Kong (HK) | 7/13/57 | 7/13/1 | Hong Kong & Macau 2026 (19 Mar 2026) |
| Macau (MO) | 2/6/13 | 2/5/0 | Hong Kong & Macau 2026 |
| Taiwan (TW) | 3/9/49 | 3/7/0 | Taiwan 2026 (21 Jul 2026) |

## Not done here

- **Place IDs** (QA-289).
- **The engineering CHANGELOG** (`docs/Plannnig/CHANGELOG.md`) and the
  **Michelin_Database CHANGELOG** are written when the files are applied, as for
  GB/IE.
- **New QA ids:** QA-289–QA-294.
