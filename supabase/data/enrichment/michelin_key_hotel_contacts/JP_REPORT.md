# Contact fields — MICHELIN Key hotels, Japan (2026-10-29)

Status: **APPLIED 2026-10-29** (see the Michelin_Database CHANGELOG). This pass uses the same method and
rules as the earlier countries (`ES_REPORT.md`, `IT_REPORT.md`,
`DE_REPORT.md`). Only the differences are written out here.

| File | What it is |
|---|---|
| `prepared_jp_hotel_contacts.sql` | One guarded transaction: 116 `michelin_url`, 97 `website_url`, 93 `phone` |
| `jp_hotels_all.csv` | One row per hotel (118): value, status, source URL, how it was confirmed, notes |
| `_source/jp_michelin_match.txt` | The MICHELIN page matched to each hotel |
| `_source/research_brief_jp.md` | The research rules, with the Japanese phone format and postal-code matching |

## Scope

Read-only production export, 2026-10-29: every `hotels` row with
`country_code = 'JP'` and `michelin_keys` set, 118 rows in all.

Before this pass:

| Field | Already set | Empty |
|---|---|---|
| `phone` | 8 | 110 |
| `website_url` | 7 | 111 |
| `michelin_url` | 2 (Park Hyatt Tokyo, Palace Hotel Tokyo) | 116 |

## Result

| Field | Confirmed (in the SQL) | Unclear | Not found |
|---|---|---|---|
| `michelin_url` | 116 | 0 | 0 |
| `website_url` | 97 | 13 | 1 |
| `phone` | 93 | 12 | 5 |

Japan has the most gaps of the four countries so far. Four causes account
for nearly all of them:

- **The Fufu group's sites are down.** All seven Fufu hotels (Nara,
  Karuizawa, Nikko, Kyu-Karuizawa, Hakone, Kyoto, Kawaguchiko) show a
  "system maintenance" page on every path, and have since about 2026-10-22. I
  re-checked one in the browser on 2026-10-29, and it is still down. This is
  an outage, not bot protection, so the next run should be able to fill them.
- **hyatt.com refused the built-in browser.** That leaves Park Hyatt Niseko,
  Andaz Tokyo, Fuji Speedway Hotel and Park Hyatt Kyoto's website blank.
- **Blocked or unreachable sites.** MUNI KYOTO's site returns 403 even in the
  browser. Oyado The Earth's site refuses connections. For Kofuyuden Beniya,
  no site of the inn's own exists; beniya.co.jp and beniya.jp belong to
  unrelated companies.
- **The hotel's own site prints no phone number.** That is the case for
  Rosewood Miyakojima, Ryokan Onomichi Nishiyama and Satoyama Jujo.
  SIMOSE Art Garden Villa prints only a toll-free 0120 number, which is
  never stored.

**Phone format.** Numbers drop the trunk 0 after +81, and the Japanese hyphen
groups become spaces: printed `03-5224-3333` is stored as `+81 3 5224 3333`,
and `0460-82-2211` as `+81 460 82 2211`. Toll-free 0120 and 0570 numbers are
never stored. Every stored number has 9–10 digits after +81.

## How values were confirmed

### MICHELIN URLs

MICHELIN's Japan listing says "396 hotels" and yields 399 unique pages, all of
which I read. MICHELIN's Japan pages carry 145 Key hotels in all.

Matching was on coordinates, then **postal code**, never name. A Japanese
postcode is precise enough to settle identity. Every accepted match has the
same 7-digit postcode as the stored address. The one exception is Aman Tokyo,
whose stored address has no postcode; its street, the Otemachi Tower, agrees
with MICHELIN's.

**5 nearest-page matches were wrong and were rejected.** In each case the
hotel's own page was missing from the listing:

| Our hotel | Nearest page, rejected |
|---|---|
| Hoshinoya Kyoto | MUNI KYOTO (316 m) |
| Park Hyatt Niseko | Nikko Style Niseko Hanazono (266 m) |
| Araya Totoan | Beniya Mukayu (104 m) |
| Fufu Kyu-Karuizawa | Fufu Karuizawa (2.6 km) |
| Nasu Mukunone | another Nasu hotel (4.5 km) |

I read all five hotels' own pages through MICHELIN's `/h/<id>` links, and all
five postcodes match.

**Other details:**

- **Median distance:** 25 m.
- **Uniqueness:** no existing production row holds any of the 116 MICHELIN
  page ids. I checked by id.
- **Encoded path:** TAYUTA's path contains percent-encoding
  (`Kami%20Amakusa`) and is stored exactly as MICHELIN serves it.

### Websites and phones

Research ran in five parallel batches.

- **Phones re-checked afterwards.** I re-fetched every confirmed phone's
  source page and checked the national number appears on it (full-width
  digits are normalised before comparing): 76 by plain fetch and 17 in the
  built-in browser. All 93 were found.
- **Read in the browser because plain fetches were blocked:**
  - **Marriott:** TIAD (NGOAK), JW Marriott Nara, Suiran, W Osaka (OSAOW).
  - **Four Seasons:** Kyoto, Osaka, Tokyo at Marunouchi, Tokyo at Otemachi.
  - **Others:** Shangri-La Tokyo, Peninsula Tokyo, Six Senses Kyoto,
    InterContinental Osaka (IHG code OSAHA), Banyan Tree Higashiyama, Garrya
    Nijo Castle, Bvlgari Tokyo (phone only) and Ryotei Hanzuiryo. Hanzuiryo's
    access page is rendered by JavaScript.
- **Websites:** every confirmed site matched on name, city and address, using
  the postal code where the site prints one.

### Phone lines for a reviewer to note

- **Hoshinoya Kyoto, +81 75 871 0001.** This is the inn's own local number,
  but the site labels it for night and emergencies (18:00–9:30). The daytime
  line is the Hoshino Resorts reservations number 050-3134-8091, which was
  not stored.
- **Fugaku Gunjo, +81 50 5805 9386.** The operator's central reservations
  line, labelled `group`, and the only number the site prints.
- **Hakone Gora Karaku, +81 460 83 8860.** The property's own booking line, and
  the only number on the site.
- **OSTERIA SINCERITA, +81 238 43 7800.** It shares its address with its
  sister ryokan THE TAKINAMI. Its Japanese access page prints Takinami's
  number; its header and English page print 7800, which was stored.
- **Already set, not touched, but worth a look:**
  - Aman Kyoto's stored phone is its reservations line; the hotel line is
    +81 75 496 1333.
  - Park Hyatt Kyoto's stored phone still has hyphens ("+81 75-531-1234").

## Wrong-record traps hit (all rejected)

- **The 5 wrong nearest-page MICHELIN matches** above.
- **Hijacked domain:** **hanzuiryo.jp now serves credit-card spam.** The real
  site is hanzuiryo-unzen.jp.
- **Domains that belong to someone else:**
  - takinami.jp is a real-estate company in Fukui.
  - enowa.jp is an agriculture-IT company in Toyama.
  - the-earth.jp is a real-estate survey page.
  - tayuta.com is parked.
  - beniya.co.jp is a Kobe clothing firm.
- **Wrong property codes and paths:**
  - **Marriott:** tyorn redirects to the Renaissance Tokyo Hotel Ginza Tobu,
    not the Ritz-Carlton Nikko (tyonz). W Osaka is OSAOW, not OSAWH.
  - **Four Seasons:** /tokyootemachi/ and Banyan Tree's /kyoto-higashiyama
    are 404s.
  - **TRUNK:** trunk-hotel.com/yoyogipark/ lands on the sister CAT STREET
    hotel's 404 page.
- **Sibling properties kept apart:**
  - Four Seasons Marunouchi / Otemachi;
  - Fufu Karuizawa / Kyu-Karuizawa;
  - Bettei Otozure / Otanisanso;
  - Nishimuraya Honkan / Shogetsutei;
  - Gora Karaku / Atami Izusan Karaku;
  - ENOWA / Yufuin Tamanoyu (same postcode);
  - Bellustar Tokyo / Hotel Groove Shinjuku (same tower);
  - Gajoen / Tenku;
  - Azumi Setoda / yubune.
- **Renames:**
  - MUNI KYOTO is now "MUNI KYOTO by Onko Chishin".
  - The Goto retreat is "五島リトリート ray by 温故知新".
  - Shoraiso reopened on 2026-03-01 after its 2021 fire, according to press
    reports.

## Data problems found (logged, not fixed)

- **QA-272 — Key counts differ from MICHELIN's live pages for 5 hotels.**
  - Nasu Mukunone and MUNI KYOTO now show no Key.
  - Ritz-Carlton Nikko, Kanamean Nishitomiya and Aman Tokyo show two Keys;
    production has one.
- **QA-273 — 29 hotels carry a Key on MICHELIN's Japan pages but are not in
  `hotels`.** They include **Asaba (three Keys)**, The Shinmonzen, Capitol
  Hotel Tokyu, Capella Kyoto, Gora Kadan Fuji and Benesse House.
- **QA-274 — Stored pins far from MICHELIN's**, up to 2.7 km (Fufu
  Kyu-Karuizawa) and 1.1 km (Hoshinoya Kyoto), plus Aman Tokyo's missing
  postcode.
- **QA-275 — The contact gaps above.**

## Testing

I ran the SQL on a scratch PostgreSQL 17 database seeded with the 118
exported rows.

- **First run:** commits. The table then holds 101 phones, 104 websites and
  118 MICHELIN URLs. Values that were already set are unchanged; for example,
  Park Hyatt Kyoto keeps its stored phone.
- **Second run:** raises and changes nothing.
- **A website filled after the export** (hotel_573): raises with that code and
  rolls everything back.

The production table's triggers were not tested.
