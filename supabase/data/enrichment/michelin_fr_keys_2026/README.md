# France: MICHELIN Key hotels 2026 (research 2026-10-30)

Status: **APPLIED 2026-10-30** (ledger 114/114; see the Michelin_Database CHANGELOG). Generated from production's read-only export of
2026-10-29 23:01 UTC, re-checked unchanged on 2026-10-30. To apply, in order:

1. `supabase/migrations/20261023190000_add_fr_key_hotel_cities.sql` (43 French towns),
   with `supabase db push --linked`. It sorts after the unapplied migrations other
   branches hold (150000 CN, 160000 US/CA/MX, 170000 HK/MO/TW, 180000 CH/AT/Nordics),
   so push those first or use `--include-all` knowingly.
2. `prepared_fr_key_hotels.sql` (one transaction; aborts on any check),
   with `supabase db query --linked -f <absolute path>`.
3. `prepared_mc_key_hotels.sql` (Monaco; independent of 1 and 2, see Monaco below),
   the same way.

Review `match_report.csv` and the open questions below first.

| After applying | France (FR) |
|---|---|
| Key hotels (3/2/1) | **25/38/157 = 220**, exactly the French Key pages on guide.michelin.com |
| Key hotels added | 211 (`hotel_2001`–`hotel_2211`): 19 three-Key, 36 two-Key, 156 one-Key |
| … with website / phone | 211 / 209 |
| … with a Google Place ID | **0** (QA-350) |
| Existing Key hotels matched | 9 of 9, by MICHELIN hotel id; all keep their Key (no change) |
| Existing rows filled (fill-only) | Le Bristol Paris phone |
| Current 2026 Key rows added | 219 (211 new + 8 existing that had none; the Ritz already had one) |
| Hotel links (5 before) | **83**: 78 new (66 `exact`, 12 `campus`) + the 5 existing, which MICHELIN confirms |
| Restaurants changed | none (no stars, names, points or `property_name` touched) |
| Carlton Cannes (hotel_793) | untouched: World's 50 Best, no Key on MICHELIN |

Every French Key hotel ends with exactly one current `michelin_keys` row equal to
`michelin_keys`; the French hotel count, link count and Key tiers are
post-conditions in the file.

## Source (guide.michelin.com, read 2026-10-30 in the built-in browser)

- **Edition:** MICHELIN's 2026 Key selection, launched **18 September 2026**
  ("Clefs MICHELIN 2026 : découvrez la liste complète des hôtels récompensés en
  France", `/fr/fr/article/travel/hotels-france-michelin-clefs-liste-complete`).
  Every Key row gets `guide_year 2026`, `announced_on 2026-09-18`. The file
  aborts if production's current Key rows are not all 2026.
  Saved: `_source/michelin_article_keys_fr_2026.json` (text, every hotel link
  with its tier heading and the town printed before it).
- **The article's totals are not its list (QA-351).** It states 26/39/155 = 220
  but links 26/39/158 = 223, three of them Monaco hotels (Hôtel de Paris 3,
  Métropole 2, Hermitage 1). Counted from the hotel pages instead.
- **Hotel pages decide.** The France hotel listing (`/en/hotels-stays/france`,
  850 hotels, 18 pages, `_source/michelin_fr_hotel_listing_20261030.json`) only
  filters Keys client-side; its cards' `data-distinction` gave 25/38/158. The
  union of the article's 223 links and the listing's Key cards (224 pages) was
  read one by one (`_source/michelin_fr_key_hotel_pages_20261030.json`):
  - `addressCountry FRA`: **25/38/157 = 220**, every one agreeing with its
    article heading and its listing card. 220 is also the count the listing
    shows under its Keys filter.
  - 3 Monaco (MC, not this file; see Monaco below), 1 The Little Nell, Aspen
    (USA), which the France listing carries by mistake.
- Address, coordinates, MICHELIN phone and the canonical `michelin_url` are the
  page's JSON-LD. Names are the page's `h1`, as for the UK (some print without
  accents, e.g. "Le Kaila", "Chateau de la Resle").

## Production before (export 2026-10-29)

- 10 FR hotels: 9 Key hotels + Carlton Cannes (World's 50 Best, Keys NULL);
  653 FR restaurants (30/80/542, complete); 5 hotel links; 411 FR cities.
- **The 9 Key hotels** were matched by MICHELIN's numeric hotel id in their
  stored `michelin_url`; stored points are 3–82 m from MICHELIN's pins, and
  every stored Key equals MICHELIN's. Only the Ritz had a Key row in
  `award_history` (the August World's 50 Best import gap, PE_REPORT finding 1);
  the file adds the other 8, guarded by NOT EXISTS.
- Eight of them store a non-canonical MICHELIN URL (`/is/en/…`, `/hu/en/…`,
  `/sg/en/…`, `/us/en/…`, `/h/<id>`). Left as is (fill-only; QA-356).

## Website and phone

Researched per hotel with `_source/research_brief_fr_hotels.md` (the UK brief
with French brands, traps and number format), in four parallel batches
(`_research/batch*_out.csv`, merged into `fr_key_hotel_contacts_research.csv`):
the hotel's **own** site (the property page for brands), confirmed on
name + town + address; the hotel's own number as printed there, as
`+33 X XX XX XX XX`. MICHELIN's number is a cross-check only. Carried only
when `confirmed`; `group` lines are held back.

- **11 brand sites blocked automated fetches** (Four Seasons ×3, Peninsula,
  Dorchester, Bvlgari, Shangri-La, Hilton/LXR, Oetker ×2, Negresco) and Le
  Bristol's missing phone: all confirmed in the built-in browser, address and
  number on the page (`_source/browser_checks_20261030.csv`). Oetker's
  oetkercollection.com now redirects to oetkerhotels.com.
- **Missing (QA-354):** Château Lafaurie-Peyraguey (site prints no phone);
  Château Richeux (only the Maisons de Bricourt group line).
- **Site number differs from MICHELIN's (QA-354):** 10, listed there; the site's
  number is stored. Two are labelled reservations and are the hotel's only
  published line (Maison Barrière Vendôme, Le Royal Monceau).
- Traps caught by the research (wrong-business domains, sister properties,
  parked domains, renames) are in each row's `notes`.

## Hotel links

Only MICHELIN's restaurant page **"Stay at the hotel"** for a French Key hotel,
identified by MICHELIN's hotel id (the French 2026 star article has no "Inside
the … Key" wording). `exact` when MICHELIN's restaurant pin is within 100 m of
the hotel's pin, else `campus`; over 1 km it would be held.

- Distances use **MICHELIN's own restaurant pins** (`../michelin_fr_stars_2026/michelin_fr_pages.csv`,
  read 2026-10-28). Four production restaurant points are 0.76–3.1 km from
  them (Anne, La Table d'Olivier Nasti, L'Oustau de Baumanière, La Palmeraie);
  logged, not changed (QA-352).
- **Coverage:** MICHELIN rate-limits the crawl, so pages were read for the 255
  live restaurants whose production point is within 1 km of a French Key hotel
  pin (plus 19 read first in listing order): 274 pages
  (`_source/michelin_fr_restaurant_stay_20261030.json`). 379 restaurants
  further away were not read; 4 within 1 km are no longer in MICHELIN's live
  listing (QA-356).
- **Cheval Blanc Courchevel (QA-352, resolved).** MICHELIN's hotel pin is
  13.3 km from Courchevel 1850. MICHELIN's Le 1947 pin (same address, "Le Jardin
  Alpin") is 19 m from OpenStreetMap's Cheval Blanc (way 206365327), so the
  hotel row takes the restaurant pin (`COORD_FIX`) and Le 1947 is linked `exact`.
- **Non-Key hosts:** 14 restaurants' "Stay at the hotel" is a hotel without a
  Key (Assiette Champenoise, Maison Lameloise, La Côte Saint-Jacques, …).
  Production holds no `property_name` for any French restaurant, and none was
  written (QA-355). No linked restaurant carries a `property_name`, so nothing
  needs clearing; the file aborts if one appears before apply.

## Towns (QA-353, closed)

Each hotel goes in the commune it actually stands in; new towns are added
where needed (product owner, 2026-10-30). MICHELIN's hotel pages often name a
neighbouring, better-known town (Biarritz for Eugénie-les-Bains, Aix for Le
Tholonet), so every new hotel's pin was looked up against the official commune
boundaries (geo.api.gouv.fr, `_source/commune_check_20261030.json`), and the
generator refuses to build if a hotel's town disagrees with its pin's commune
without a recorded reason. In order:

1. **`TOWN_FIX` (11):** MICHELIN names another commune; the pin's commune is
   confirmed by the address on the hotel's own site, which is stored: Brindos
   → Anglet, Château de Berne → Flayosc, Château de Maubreuil → Carquefou,
   Château du Palanquey → Sainte-Colombe, Domaine de Biar → Lavérune, Domaine
   des Andéols → Saint-Saturnin-lès-Apt, Domaine de Verchant →
   Castelnau-le-Lez, Cala Rossa → Lecci, Sainte Victoire → Vauvenargues, Les
   Lodges Sainte-Victoire → Le Tholonet, Les Regalia → Zonza.
2. **The linked restaurant's town (10):** e.g. Les Prés d'Eugénie →
   Eugénie-les-Bains, Les Sources de Cheverny → Cheverny (the page says
   "Centre-Val de Loire"), Royal Champagne → Champillon.
3. **The Key article's town, when it is the pin's commune (3):** Villa La
   Coste → Le Puy-Sainte-Réparade, Château de la Treyne → Lacave, Le Prieuré →
   Villeneuve-lès-Avignon.
4. **Otherwise the hotel page's locality**, in production's spelling when it
   is the same name (accent-, case-, space-, hyphen- and St/Saint-insensitive),
   or the article's spelling for a new town ("Menerbes" → "Ménerbes"). A
   locality inside a commune stays when production already uses it for
   restaurants (Val Thorens, Pyla-sur-Mer, Méribel, Uriage-les-Bains).

`ADDRESS_FIX` (10): where (2) or (3) moved a hotel but MICHELIN's address
still names the other town, the hotel's own site's address is stored (e.g.
"334 Rue René Vielle, 40320 Eugénie-les-Bains", not "…40320 Biarritz").

`TOWN_KEEP` (3): the pin falls in a neighbouring commune but MICHELIN and the
hotel's site agree on the town: COMO Le Montrachet (Puligny-Montrachet),
Domaine de Primard (Guainville), Cheval Blanc St-Tropez (pin outside every
commune polygon). 43 new towns in all.

## Open questions for review

1. **`property_name` for the 14 non-Key hosts (QA-355)** — fill or leave.
2. **Restaurant points off (QA-352)** — four corrections, not prepared.

## Monaco (QA-357)

MICHELIN's French Key article includes Monaco's three Keys. Production
(read 2026-10-30, `_source/production_mc_export_20261030.json`) holds Hôtel de
Paris (3) and Hotel Metropole (2), each with a correct current 2026 Key row,
but **not Hermitage Monte-Carlo (1 Key, new in 2026)**; neither existing row
has a `michelin_url`, and Metropole has no phone or website.
`prepared_mc_key_hotels.sql` (hand-written, guarded, one transaction):

- adds Hermitage Monte-Carlo as `hotel_2212` (Monte Carlo; Square
  Beaumarchais; MICHELIN pin; website and +377 98 06 40 00 read on
  montecarlosbm.com's Hermitage page) with its 2026 Key row;
- fills `michelin_url` on both existing hotels, and Metropole's phone
  (+377 93 15 15 15) and website (metropole.com), both read on its own site;
- links L'Abysse Monte-Carlo to Hermitage (`campus`: MICHELIN's "Stay at the
  hotel"; its pin, 1 square Beaumarchais, 213 m from the hotel's). MICHELIN's
  pages confirm the three existing Monaco links (Le Louis XV and Le Grill →
  Hôtel de Paris, Les Ambassadeurs → Metropole); Pavyllon, Robuchon, Elsa and
  Rampoldi show no hotel, and Blue Bay's is the non-Key Monte Carlo Bay.

Post-conditions: Monaco 1/1/1 Keys, one matching Key row each, every Monaco
hotel with a `michelin_url`, 4 Monaco links.

## How the files are built

```
python3 build_fr_key_hotels.py 2001 20261023190000_add_fr_key_hotel_cities.sql
```

Reads only the committed `_source/` files, `fr_key_hotel_contacts_research.csv`
and `../michelin_fr_stars_2026/michelin_fr_pages.csv`; writes
`fr_key_hotels_2026.csv`, `match_report.csv`, `prepared_fr_key_hotels.sql` and
the migration. `export_fr_query.sql` produced the export
(`supabase --workdir <main checkout> db query --linked -o json -f <abs path>`).

**Codes and ids.** Production's highest hotel code is `hotel_956`. Claimed by
parallel work (shared notes and `git grep` across all remote branches,
2026-10-30): CN/HK/MO/TW `hotel_957`–`hotel_1029`, US/CA/MX `hotel_1501`–`hotel_1981`,
CH/AT/Nordics `hotel_2501`–`hotel_2700`. These files use `hotel_2001`–`hotel_2212`
(claimed up to `hotel_2400`) and aborts if any is taken. Migration
`20261023190000` (180000 is CH/AT/Nordics'). QA ids QA-350–QA-357 (QA-300–309
US/CA/MX, QA-360+ CH/AT/Nordics).

## Tested (2026-10-30)

On a scratch PostgreSQL 17 with PostGIS stubbed (geography as text), mirroring
production's columns, constraints, unique and partial indexes and the
`updated_at` triggers of `countries`, `cities`, `hotels`, `restaurants`,
`hotel_restaurants` and `award_history` (read from production's catalog),
seeded with the real export and production's one French Key row:

- **Migration + file:** applies; FR 25/38/157 + Carlton, 221 FR hotels, 220
  current French Key rows, 83 French links (69 exact, 14 campus), 454 FR
  cities, the corrected towns and addresses, Le Bristol's phone filled.
- **Re-run of the file:** aborts. **Re-run of the migration:** no-op.
- **Without the migration:** aborts, nothing applied.
- **Renamed existing hotel / a code in range taken / a `property_name` on a
  linked restaurant / a non-2026 current Key row:** each aborts the whole file.
- **Monaco file** (seeded with the Monaco export as well): applies after the
  French files and on its own; Monaco 1/1/1, 4 links, all three URLs set,
  Metropole's phone and website filled. Re-run aborts; a changed Key on an
  existing Monaco hotel aborts.

Not run against the real database, and not a full migration replay (PostGIS,
RLS and the other tables were not reproduced).

## Not done here

- Place IDs (QA-350).
- The engineering CHANGELOG and the Michelin_Database CHANGELOG are written when
  the files are applied, as for the UK and Germany.
