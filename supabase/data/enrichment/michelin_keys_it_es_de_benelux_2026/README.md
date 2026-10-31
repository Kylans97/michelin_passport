# Italy, Spain, Germany, Belgium, the Netherlands, Luxembourg: MICHELIN Key hotels 2026 (research 2026-10-31)

Status: **PREPARED, NOT APPLIED.** Generated from production's read-only export of
2026-10-31 12:42 UTC (`export_keys_query.sql`, saved as
`_source/production_export_20261031.json`). To apply, in order:

1. `supabase/migrations/20261031150000_add_it_es_de_benelux_key_hotel_cities.sql`
   (27 new towns), with `supabase db push --linked`.
2. `prepared_keys_it_es_de_benelux_2026.sql` (one transaction; aborts on any
   check), with `supabase db query --linked -f <absolute path>`.

Review `match_report.csv` and the decisions below first.

| After applying | IT | ES | DE | BE | NL | LU |
|---|---|---|---|---|---|---|
| MICHELIN 2026 Keys (3/2/1) | 17/49/158 = 224 | 5/17/100 = 122 | 6/37/87 = 130 | 0/4/14 = 18 | 1/5/12 = 18 | 0/1/1 = 2 |
| Production before | 12/37/106 = 155 | 4/10/95 = 109 (+1 W50B, no Key) | 6/31/89 = 126 | 0/2/13 = 15 | 1/5/11 = 17 | 0/0/1 = 1 |
| Production after | 17/49/158 | 5/17/100 | 6/37/87 | 0/4/14 | 1/5/12 | 0/1/1 |
| Key lost in 2026, hotel kept with `michelin_keys` NULL (QA-387) | 1 | 5 | 12 | — | — | — |
| Key hotels added (`hotel_2701`–`hotel_2809`) | 70 | 18 | 16 | 3 | 1 | 1 |
| Key changes, launch row relabelled 2025 (QA-383) | 6 | 2 | 8 | 1 | — | — |
| Key import errors corrected in place (QA-384) | 10 | 5 | — | — | — | — |
| Existing hotels given their missing 2026 row (QA-390) | 5 | — | — | — | — | — |
| Stored Key verified against the 2026 page, left as is | 133 | 97 | 106 | 14 | 17 | 1 |
| New towns (migration) | 19 | 4 | 4 | — | — | — |

Every Key hotel the file touches or adds ends with exactly one current
`michelin_keys` row equal to `michelin_keys`, and each country's Key tiers
are post-conditions in the file: after applying, every country's Key hotels
equal MICHELIN's 2026 list exactly. **No restaurant, hotel link,
`property_name`, website, phone or Place ID is written.**

## Keys lost in 2026 (QA-387, decided 2026-10-31)

18 stored Key hotels have a live MICHELIN page with no award in 2026; each
held exactly its stored Key in MICHELIN's 2025 article. IT: Aethos
Monterosa. ES: Only YOU Hotel Atocha, Ohla Eixample, The Principal Madrid,
Little Beach House Barcelona, Yurbban Passage. DE: Hotel de Rome (2 Keys),
Schloss Eberstein, AMERON Neuschwanstein, Kloster Hornbach, Villa
Mittermeier, Hanusel Hof, Strandhotel Fischland, DAS.HOCHGRAT,
Staudacherhof, Haubers Naturresort, Gewandhaus Dresden, Spa & Resort
Bachmair Weissach.

The product owner decided that a hotel that loses its Key **stays**, as a
restaurant that loses its stars does: a member who stayed there keeps that
record. Guides show only the current list; search finds the hotel. So the
file relabels each launch row 2025 and closes it, writes a current 2026 row
with NULL (`announced_on` 2026-09-18) and sets `michelin_keys` NULL. Links
(Schloss Eberstein and Villa Mittermeier have one each) are untouched. This
revises hotel-scope rule 1 in `CLAUDE.md`; the same wording in
`docs/Architecture/Michelin_Database/DATABASE_ARCHITECTURE.md` is not
changed here (that folder is edited only when asked).

The app already behaves this way: the Michelin Hotels guide queries
`michelin_keys is not null`, while Explore's search includes hotels without
a Key, and visits keep `keys_at_visit`.

## Decisions waiting for you

- **QA-384 — 15 launch Keys match no MICHELIN edition.** For these,
  MICHELIN's 2024 article, its 2025 article and the live 2026 page agree with
  each other and not with production (e.g. Hassler Roma and Le Sirenuse
  stored 2, MICHELIN 1 in 2024, 2025 and 2026; Borgo San Felice stored 1,
  MICHELIN 2 throughout; Torre del Marqués stored 2, MICHELIN 3). They are
  corrected in place to the 2026 Key, as La Brezza Arosa was for stars
  (QA-361). To keep any of them out, add its code to `decisions.json` with
  `"outcome": "hold"` and regenerate.
- **QA-391 — Spain's and the Benelux's 2025 lists come from archived
  MICHELIN pages.** MICHELIN republished both articles with the 2026
  selection on 18 September 2026; the 2025 versions were read from the
  Internet Archive's raw captures of those same guide.michelin.com pages.
  They decide the edition of 3 ES/BE Key changes and of the 5 Spanish import
  errors, nothing else. If an archived page is not acceptable evidence, hold
  those 8 rows.
- **QA-386 — towns.** Two hotel towns were resolved to production's own row
  (below); the rest keep MICHELIN's locality, including the island and area
  names production already uses for Spain and Italy and some South Tyrol
  frazioni and German names. Listed for a naming rule, not changed.

## Sources (guide.michelin.com, read 2026-10-31 with curl)

Pacing 2.5 s per request, 3 minutes back-off on HTTP 202: MICHELIN did not
throttle once in about 600 requests.

- **Totals:** MICHELIN's 2026 global Key article ("The 2026 MICHELIN Key
  Hotels", 18 Sep 2026, `_source/michelin_article_keys_global_2026.txt`):
  Italy 224, Spain 122, Germany 130, Netherlands 18, Belgium 18,
  Luxembourg 2.
- **Listings:** `/en/hotels-stays/<country>`, every page
  (`_source/michelin_hotel_listing_20261031.json`, 2,019 cards). Keys are not
  filtered server-side; each card's `data-distinction` was read. Key cards per
  country equal the article's totals and the coverage-gaps world list
  (`michelin_key_hotels_live_20261031.csv`, 514 = 514, same tiers) exactly.
  Every listing also carries **The Little Nell** (Aspen, US) as a Key card
  (QA-389); not counted.
- **Hotel pages:** all 514 Key hotel pages plus the 19 stored hotels that are
  not Key cards (`_source/michelin_hotel_pages_20261031.json`). The JSON-LD
  `award` decides the Key and agrees with the card on all 514; name is the
  `h1`; address, pin, MICHELIN phone (lead only) and canonical URL are the
  JSON-LD. Hotel pages print no `dateAwarded`.
- **Earlier editions** (`_source/michelin_article_*.json`, every hotel link
  with the heading above it and the text just before it):

  | Edition | Article | Tiers read |
  |---|---|---|
  | IT 2025 | "All the Key Hotels in Italy: The Full 2025 Selection" (8 Oct 2025) | 13/47/127 |
  | DE 2025 | "All the Key Hotels in Germany: The Full 2025 Selection" (8 Oct 2025) | 6/36/88 (id 7589 dropped, QA-389) |
  | ES 2025 | "Todos los hoteles de España con Llave MICHELIN" (8 Oct 2025), archived 28 Nov 2025 | 6/13/91 |
  | BE/NL/LU 2025 | "Alle MICHELIN Sleutels in de Benelux" (9 Oct 2025), archived 13 Oct 2025 | 1/7/25, its own stated totals |
  | IT 2024, ES 2024 | "The First MICHELIN Key Hotels" (May / Apr 2024) | cross-check only |
  | ES 2026, Benelux 2026 | the same two articles as republished 18 Sep 2026 | cross-check only |

  Only tier-list entries count (a "Town: hotel" line under a "The One/Two/
  Three Key Hotels" heading, or its Spanish and Dutch equivalents); body-text
  mentions and photo captions do not.

## Production before (export 2026-10-31)

424 hotels in the six countries, all `open`, all with a `michelin_url`
(one non-canonical: Six Senses Ibiza, World's 50 Best, no Key). Every current
Key row is labelled 2026 with `announced_on` NULL (the launch convention);
hotel_17 also has a 2025 row. Six Italian hotels have no Key row at all
(QA-390).

## Matching

**Identity is MICHELIN's numeric hotel id**, read from the stored
`michelin_url`; never a name. All 424 stored hotels carry one, and none is
shared. A new hotel within 150 m of a stored hotel is held as a possible
duplicate **unless** that stored hotel is itself matched to a different 2026
Key id: nine new hotels have such neighbours (Hotel de la Ville 16 m from
Hassler Roma at the Spanish Steps, Airelles Palladio 106 m from Cipriani on
the Giudecca, …), all distinct MICHELIN entries. None was held.

**Key changes (QA-383, the QA-217 rule).** When MICHELIN's 2026 Key differs
from the stored one, the stored value is compared with the hotel's entry in
MICHELIN's own 2025 country article, by id:

- equal (17 hotels): the launch row holds the 2025 Key. It is relabelled
  2025 and closed, value unchanged, and a 2026 row is written
  (`announced_on` 2026-09-18). Borgo Santandrea had no Key row; a non-current
  2025 row with the stored value is written instead.
- different (15 hotels, QA-384): the launch value belongs to no edition; the
  2026 row is corrected in place.
- no 2025 entry: held. None occurred.

Every Key change, per hotel, with the article line that proves it:
`match_report.csv` (`KEY CHANGE …`, `KEY IMPORT ERROR …`).

| Country | Up | Down |
|---|---|---|
| IT | Collegio alla Querce 2→3, Splendido Portofino 2→3, Borgo Santandrea 2→3, Splendido Mare 1→2, Villa d'Este 1→2 | J.K. Place Roma 2→1 |
| ES | Cap Vermell Grand Hotel 1→2, Esperit Roca 1→2 | — |
| DE | Chiemgauhof 1→2, Der Birkenhof 1→2, Hotel PURS 1→2, Hüttenhof 1→2, Steigenberger Icon Europäischer Hof 1→2 | Esplanade Saarbrücken 2→1, Hotel Ketschauer Hof 2→1, Seezeitlodge 2→1 |
| BE | Corinthia Grand Hotel Astoria 1→2 | — |
| NL, LU | — | — |

**Stored points off (QA-388):** seven matched hotels are 626 m–4.5 km from
MICHELIN's pin (Castel Monastero 4,529 m, La Torre del Visco 3,137 m, …).
Reported, not changed.

## New hotels and towns

109 hotels, `hotel_2701`–`hotel_2809`, website/phone/Place ID NULL
(QA-385). Towns are the page's `addressLocality`, in production's spelling
when production already holds the same name (accent-, case-, space-, hyphen-
and apostrophe-insensitive). Two by decision (`decisions.json`):

- The Florentin by Althoff Collection: "Frankfurt" → **Frankfurt am Main**,
  where production files Frankfurt's two Key hotels. Production also has a
  second row, "Frankfurt on the Main", holding ten restaurants — one city,
  two rows; logged in QA-386, not merged here.
- Weissenhaus Private Nature Luxury Resort: "Weissenhaus" → **Wangels**,
  the row production's Courtier restaurant at the same address (Parkallee 1,
  23758) uses.

The 27 new towns are in the migration; region and `postal_municipality`
NULL like the existing rows; idempotent (`on conflict … do nothing`).

## How the files are built

```
python3 fetch_michelin.py listing _source/michelin_hotel_listing_20261031.json
python3 fetch_michelin.py pages <urls.txt> _source/michelin_hotel_pages_20261031.json
python3 fetch_articles.py _source <edition> <article url> ...
python3 build_keys.py 2701 20261031150000_add_it_es_de_benelux_key_hotel_cities.sql
```

`urls.txt` (`_source/hotel_page_urls_20261031.txt`) is every Key card of the six listings plus every stored hotel's
`michelin_url` that is not one. `build_keys.py` reads only the committed
`_source/` files and `decisions.json`, and writes `<cc>_key_hotels.csv`,
`match_report.csv`, the prepared SQL and the migration. Re-running it
reproduces them byte for byte.

**Codes and ids.** Production's highest hotel code is `hotel_2614`; none in
`hotel_2701`–`hotel_2900` is taken (export). Claimed in the shared session
notes: `hotel_2701`–`hotel_2900` (2809 used), migration `20261031150000`
(the highest existing is `20261031140000`), QA-383–QA-395 (383–391 used).
The shared `qa-ids.md` still said "next free QA-377"; the Gault&Millau
Benelux session had already used QA-377–QA-382.

## Tested (2026-10-31)

On a scratch PostgreSQL 17 (port 58931) with PostGIS stubbed (geography as
text), mirroring production's columns, checks, unique and partial indexes and
the `updated_at` trigger of `cities`, `hotels` and `award_history` (read
from production's catalog), seeded with the real export:

- **Without the migration:** aborts at the first Italian hotel city; nothing
  applied.
- **Migration + file:** applies; every country equals MICHELIN 2026
  exactly; 0 Key hotels without exactly one matching current row; 36
  non-current 2025 rows (17 changes + 18 lost Keys + hotel_17's), 131 new
  2026 rows (109 + 17 + 5) and 18 current 2026 NULL rows.
- **Re-run of the file:** aborts. **Re-run of the migration:** no-op.
- **A renamed or re-keyed existing hotel / a code in the range already taken /
  a current Key row not labelled 2026:** each aborts the whole file.

Not run against the real database, and not a full migration replay (PostGIS,
RLS and the other tables were not reproduced).

## Not done here

- The open questions above, and the DATABASE_ARCHITECTURE.md wording for QA-387.
- Website, phone and Place ID of the new hotels (QA-385).
- Hotel links for the new hotels: no restaurant page was read, so no "Stay at
  the hotel" link and no `property_name` were derived.
- The engineering CHANGELOG (`docs/Plannnig/CHANGELOG.md`) and the
  Michelin_Database CHANGELOG are written when the files are applied, as for
  France and CH/AT/Nordics.
