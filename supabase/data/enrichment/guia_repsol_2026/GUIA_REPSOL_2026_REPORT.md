# Guía Repsol 2026 (Spain) — research and staging (2026-11-16)

Status: **2 and 3 Soles APPLIED to production 2026-11-16** with the
product owner's approval (159 rows, verified identical to the CSV; see the
Michelin_Database CHANGELOG). 1 Sol waits for the rest of its fichas (see
"Not finished").
Asked for by the product owner on 2026-11-16 ("ja ik bedoel Repsol").

## The guide

| | |
|---|---|
| Publisher | Repsol S.A. (the energy company), as brand marketing; no fee from restaurants. Expert council and inspectors; published since 1979. |
| Scale | 1, 2 or 3 Soles; plus "Restaurantes Guía Repsol", recommended without a Sol (not staged: it is a recommendation, not a distinction). |
| Coverage | Spain (this file). Portugal has its own 2026 list (gala 2026-04-13, 120 distinguished); not staged. |
| Latest edition | **2026**, gala 2026-02-16, Tarragona. 2027 expected around February 2027 (not verified). |
| Counts | Verified on the official list page 2026-11-16: **46** with 3 Soles, **173** with 2, **589** with 1, **1,605** recommended. Identical to Repsol's own totals. |
| Openness | The full list is open on the web, with a ficha per restaurant: address, coordinates, phone, website and a numeric id in the URL. |
| Terms | The "Condiciones del servicio" have no IP, database or extraction clause; the footer reads "© Repsol S.A.". The Sol logo needs permission: we show "3 Soles" as text only. |
| Access note | The site's bot protection (Akamai) refuses scripts; the list and fichas were read in the browser. After ~250 ficha reads it blocked further requests for more than half an hour. |

Alternatives found for "the Spanish guide": **Macarfi** (a panel of ~2,000
enthusiast "ambassadors", premium paywall, consultancy business — not
recommended) and the Spanish **Michelin**/**50 Best** we already hold.
Repsol is the national reference.

## Source

- List: https://www.guiarepsol.com/es/comer/soles-repsol/ediciones-de-soles/2026/
  (captured 2026-11-16 15:23 UTC) → `_source/official_repsol_2026.csv`, all 2,413 entries with tier.
- Fichas: `https://www.guiarepsol.com/es/fichas/restaurante/<slug>-<id>/`, their
  schema.org data (address, latitude/longitude, phone, website) →
  `_source/repsol_fichas_2026.csv` (249 read).

## Result

| Tier | On the list | In our catalogue, staged | Not in catalogue | Held back | Ficha not yet read |
|---|---|---|---|---|---|
| 3 Soles | 46 | **46** | 0 | 0 | 0 |
| 2 Soles | 173 | **113** | 57 | 2 | 1 |
| 1 Sol | 589 | (8 matched, not staged) | (22) | | 559 |

Per-entry detail: `repsol_2026_matches.csv` (ficha URL, Repsol's address,
phone and website, match basis, note). Restaurants not in the catalogue are
listed, not added: Repsol is not a catalogue-entry reason today.

### How entries were matched

Candidates were searched **by evidence, across the whole Spanish catalogue**
(296 rows), not by name: a catalogue row whose phone or website equals the
ficha's, or whose point is within 150 m of the ficha's coordinates. A
match needs phone or website, plus either the name agreeing, the website
agreeing, or all three kinds. Location alone is never enough in a city
centre. A first, name-led pass missed Akelaŕe (Repsol: Akelarre) — that is
why the evidence-led pass replaced it.

- **Repsol swaps latitude and longitude** on 61 fichas (e.g. Akelarre at
  -2.04, 43.31). Compared swapped back; noted per row.
- **Renamed or differently written, same place** (all on phone/website/
  location): Akelarre/Akelaŕe, Etxebarri/Asador Etxebarri, Casa Solla/Solla,
  Víctor Gutiérrez/Tayta by Víctor Gutiérrez, Castell Peralada/Perelada,
  El Invernadero de Rodrigo de la Calle/El Invernadero, and others in the CSV.
- **DINS Santi Taura**: matched on the address — Repsol gives the catalogue's
  address (Plaça Llorenç Villalonga 4, Palma) but the locality "Lloseta" and
  wrong coordinates.
- **Hotel phones**: San Hô shares the Royal Hideaway Corales number with Il
  Bocconcino; the name decided. **La Gaia** (Ibiza Gran Hotel) shares the
  hotel number with brula: held back.

### Held back (2 Soles)

| Entry | Why |
|---|---|
| La Gaia Ibiza | Only the hotel's phone and 62 m connect it to brula (rest_1624): two restaurants in one hotel. |
| Poemas by Hermanos Padrón | Same name as rest_1775 and 110 m away, but no phone or website match. |

### Notable 2 Soles not in our catalogue

Coure, Xavier Pellicer, Estimar (Madrid and Barcelona), Horcher, Lakasa, La
Tasquita de Enfrente, Rekondo, Mirador de Ulía, Nou Manolín, El Campero,
Bido, Casa Fermín and 45 more — the full 57 are in the CSV. Whether any
should enter is a separate decision.

## What the import does (prepared)

`prepared_guia_repsol_2026_import.sql`, into the shared guide tables (no
migration needed):

- `guides`: `guia_repsol`, measure `tier`, `tier_max` 3, labels
  "1 Sol / 2 Soles / 3 Soles";
- `guide_awards`: 159 rows (46 × 3 Soles, 113 × 2 Soles), edition 2026,
  announced 2026-02-16;
- `guide_venue_links`: 159, keyed on Repsol's numeric ficha id, with evidence;
- `guide_coverage` (ES, 2026, partial): "Shown for the restaurants in our
  catalogue with 3 or 2 Soles: all 46 with three, 113 of 173 with two.
  Restaurants with 1 Sol follow."

The app and site now show a tier in the guide's own words ("Guía Repsol ·
3 Soles"), from `guides.tier_labels`. Never gold.

**Local test** (scratch stack, every migration replayed, the 159 catalogue
rows as fixture): run 1 commits, 46 + 113 rows; run 2 is refused by the
guard; `anon` reads 159 rows from `guide_awards_current`.

## Not finished

- **1 Sol:** 559 fichas still to read once the site lets us back in, at a
  slow pace; then the same matching and a second data file.
- **Béns d'Avall** (2 Soles): its ficha shows "Restaurante no pertenece a
  Guía" and Repsol's list marks it Cerrado; not staged.
- Three entries on the list carry Repsol's "Cerrado" (closed) tag: Ricardo
  Sanz Wellington, O Camiño do Inglés (neither in our catalogue) and Béns
  d'Avall.
- Portugal's Repsol list.
