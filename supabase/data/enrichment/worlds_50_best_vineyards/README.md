# The World's 50 Best Vineyards 2026 — staging data

Unreviewed staging data. Nothing here has been imported into Supabase or
any master CSV. Researched 2026-11-20.

## Files

| File | What it is |
|---|---|
| `worlds_50_best_vineyards_2026.csv` | Ranks 1–50, identity from the official list, location checked on each estate's own website |
| `worlds_50_best_vineyards_2026_51_100.csv` | Ranks 51–100 as printed on the same official list page. **Unverified**: no estate pages or estate sites opened. `country_name` is blank because the list page prints no country. |

## Source and edition

- `https://www.worldsbestvineyards.com/` now answers **301 → `https://www.the50.com/vineyards/`**, and
  `/the-list/1-50` redirects to the50.com, where the old path 404s. The official list lives at
  **https://www.the50.com/vineyards/best-in-the-world/list/1-50**, which also prints 51–100. the50.com is
  the organiser's own domain (the old domain redirects there), not a press source.
- **Edition: 2026.** The list index page is titled "The 50 Best Vineyards 2026". The awards on the list page
  are labelled 2026. Schloss Johannisberg is "The World's Best Vineyard 2026".
- **Announced 18 November 2026, from Santiago, Chile.** This comes from the organiser's own article
  https://www.the50.com/stories/News/the-50-best-vineyards-2026-the-1-50-list.html (byline date 18/11/2026,
  `article:published_time` 2026-11-18): "announced on 18 November from Santiago, Chile". The list pages
  themselves print no date.
- Estate pages: `https://www.the50.com/vineyards/best-in-the-world/the-list/...`. There is one per estate for
  ranks 1–50. Each page's "Contact" block links the estate's website. All 50 have one.

## Method

1. Rank, name and region come from the list page exactly as printed. The list page and estate pages print
   **no country**. Country therefore comes from the organiser's own announcement article, whose per-entry
   links carry the country (`/discovery/Establishments/<Country>/...` or `country=`). For rank 17 the article
   gives only "Western Australia", so the country comes from the estate's contact page.
2. `website_url` is the link the 50 Best estate page gives. The only cleanup was removing Google `srsltid`
   tracking parameters (Shafer, Craggy Range). Redirects such as yquem.fr → www.yquem.fr are noted per row.
3. Location comes from the estate's own site only: its contact, visit or legal pages and its own map links.
   Most pages were fetched directly. Pages that block scripts (Durigutti, Chapoutier, Pape Clément's map data,
   Kefraya, Cloudy Bay, Riccitelli, El Enemigo, Ceretto's 403) were read in a real browser.
4. Coordinates were accepted only when the estate itself publishes them:
   - a Google Maps **pin** in the estate's own link (`!3d/!4d`, a directions destination `!1d/!2d`, or an
     explicit `place/lat,lng`);
   - JSON-LD `GeoCoordinates`;
   - a site map-widget pin;
   - coordinates printed as text.
   Short links were resolved by following the redirect. **Not accepted:** Google embed viewport centres,
   `@lat,lng` viewports without a pin, and address-search links. These leave lat/lng blank, and the note gives
   the centre value. Nothing was geocoded.
5. Name was never the only match. Every website was reached through the 50 Best page's own link, and the
   site's location agrees with the listed region.
6. Pages behind age gates were **not passed**. Clicking "I am of age" or "accept terms" is a declaration made
   on the user's behalf.
7. `vineyard_code` follows rank order: vine_0001 is rank 1.

## Counts (ranks 1–50)

| verification_status | count |
|---|---|
| verified | 22 |
| partial | 22 |
| held_back | 6 |

## Held-back and partial items

**Held back (6)**
1. vine_0015 Bodegas Salentein: the site shows only an age gate. No location was read.
2. vine_0021 Bodegas Tio Pepe: the site shows only an age gate. No location was read.
3. vine_0028 Almaviva: the age gate says that entering "accept[s] terms and conditions". No location was read.
4. vine_0048 Santa Rita: the site shows only an age gate. No location was read.
5. vine_0033 El Enemigo: the site prints no address, no town, and does not even say "Mendoza". The region
   rests on the 50 Best pages alone.
6. vine_0047 Champagne Philipponnat: the estate's own site disagrees on the street number. The contact page
   says 13 rue du Pont; the JSON-LD says 3 rue du Pont. The coordinates come from that JSON-LD.

**Partial: no coordinates on the estate site, address present (9)**
vine_0002 Ysios, vine_0004 Ruinart (no postcode), vine_0011 Taittinger (company address), vine_0025 Muga,
vine_0029 William Chris, vine_0034 Shafer, vine_0036 Chapoutier, vine_0037 Bollinger, vine_0045 Seppeltsfield.

**Partial: only an embed centre or viewport, not a pin, address present (6)**
vine_0005 Creation, vine_0026 Perelada, vine_0035 Viña Cobos, vine_0038 Aperture (viewport),
vine_0041 Leeuwin, vine_0050 Colomé.

**Partial: the estate's own coordinates conflict (2)**
- vine_0003 Montes: two pins about 430 m apart.
- vine_0017 Vasse Felix: the map marker and the directions pin are about 1.4 km apart.

**Partial: the site publishes no street address (5)**
- vine_0006 Clos Apalta: no municipality, but it has a pin.
- vine_0018 Kefraya: nothing beyond "West Bekaa Valley".
- vine_0030 Szepsy: a holding page with e-mail only.
- vine_0031 Cloudy Bay: the visit page has no address.
- vine_0032 Riccitelli: locality only, "Las Compuertas, Luján de Cuyo".

**Logged near-misses on verified rows (no action needed)**
- vine_0007 Klein Constantia prints only a PO Box. The street comes from its directions, and its two own pins
  are about 45 m apart.
- vine_0046 Tokara has no street address. The directions and printed coordinates are used.
- vine_0043 Delaire gives decimal coordinates plus a front-gate GPS reading about 60 m apart.
- vine_0022 Ceretto: the exact 50 Best link `www.ceretto.com/it` returns 403, while `ceretto.com` works.
- Name and region variants between the list page, estate page titles and the announcement article are noted
  per row. Examples: Gusbourne/"Gusborne", Casas del Bosque/"Viña Casas del Bosque", Vivanco/"Bodegas Vivanco",
  Tio/Tío Pepe, D'Yquem/d'Yquem, Hemel-en-Aarde/"Walker Bay", Empordà/"Catalonia", Alt Penedès/"Penedés",
  Sauternes/"Bordeaux". The list page values are kept.

## Proposed QA log entries

```
QA-520,Access,Medium,worlds_50_best_vineyards_2026,vine_0015;vine_0021;vine_0028;vine_0048,"Estate website shows only an age-verification gate (Almaviva's also asks you to accept terms and conditions); every page returns the gate, so no address, city or coordinates could be read",Human opens each site past the gate, or decides an agent may answer age gates; then fill location from the estate's contact page,Open
QA-521,Data conflict,Medium,worlds_50_best_vineyards_2026,vine_0047,"Philipponnat's own site gives two street numbers: contact page 13 rue du Pont (Mareuil-sur-Ay, 51160 Ay-Champagne) vs JSON-LD 3 rue du Pont; coordinates 49.04485,4.04071 come from the JSON-LD record",Confirm the correct number with the estate or its visit-booking page before import,Open
QA-522,Identity,Low,worlds_50_best_vineyards_2026,vine_0033,"El Enemigo's site names its vineyard areas but never prints an address, a town or even 'Mendoza'; region rests on the 50 Best pages alone",Keep held back until the estate publishes a location or a human confirms it,Open
QA-523,Data conflict,Low,worlds_50_best_vineyards_2026,vine_0003;vine_0017,"Estate's own coordinates disagree: Montes contact-page pin -34.6160556,-71.2738611 vs experiences-page pin -34.6121301,-71.2738775 (~430 m); Vasse Felix contact-page map marker -33.818734,115.062442 vs directions pin -33.8237492,115.0479993 (~1.4 km)",Human picks the cellar-door pin for each; leave lat/lng blank until then,Open
QA-524,Missing data,Low,worlds_50_best_vineyards_2026,vine_0005;vine_0026;vine_0035;vine_0038;vine_0041;vine_0050,"Estate site's only map is an embed viewport centre or a viewport without a pin; centre values logged in the note but not used as coordinates",Accept a source for coordinates (e.g. ask the estate) or leave blank; do not promote embed centres to coordinates without a decision,Open
QA-525,Missing data,Low,worlds_50_best_vineyards_2026,vine_0002;vine_0004;vine_0011;vine_0025;vine_0029;vine_0034;vine_0036;vine_0037;vine_0045,"Estate site gives an address but no coordinates or only a text-search map link; lat/lng blank. Ruinart prints no postcode; Taittinger's is the company address (place Saint-Nicaise, Reims Cedex)",Leave blank or obtain coordinates from a later, decided source,Open
QA-526,Missing data,Low,worlds_50_best_vineyards_2026,vine_0006;vine_0018;vine_0030;vine_0031;vine_0032,"Estate site publishes no street address (Kefraya, Szepsy, Cloudy Bay give none at all; Riccitelli only 'Las Compuertas, Luján de Cuyo'; Clos Apalta gives 'Apalta KM 5' but no municipality)",Ask the estates or accept city-level location; do not fill from aggregators,Open
QA-527,Source,Low,worlds_50_best_vineyards_2026,all,"worldsbestvineyards.com now 301-redirects to the50.com/vineyards; the list and estate pages print no country, so country was taken from the organiser's own 18/11/2026 announcement article; rank 17's article entry gives only 'Western Australia' (country from estate site)",Record the50.com as the source domain; recheck the list URL each edition,Open
QA-528,Naming,Low,worlds_50_best_vineyards_2026,vine_0009;vine_0012;vine_0013;vine_0021;vine_0024;vine_0044,"Name variants between the list page and the 50 Best estate page titles: Château D'Yquem/d’Yquem, Pago De/de Carraovejas, Casas del Bosque/Viña Casas del Bosque, Bodegas Tio/Tío Pepe, Gusbourne/'Gusborne' (typo on 50 Best), Vivanco/Bodegas Vivanco; list-page form kept",Decide the display name per estate; never match on name,Open
QA-529,Near-miss,Low,worlds_50_best_vineyards_2026,vine_0007;vine_0022;vine_0043;vine_0046,"Verified rows with logged caveats: Klein Constantia prints a PO Box only (street from its directions; own pins 45 m apart); Ceretto's 50 Best link www.ceretto.com/it returns 403 while ceretto.com works; Delaire's decimal coordinates vs front-gate GPS ~60 m apart; Tokara has no street address (directions + printed coordinates used)",None required; review notes when importing,Open
```
