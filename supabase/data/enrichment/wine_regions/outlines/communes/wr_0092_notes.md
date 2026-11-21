# Etna (DOC Etna)

## Official text
- Disciplinare DOC "Etna", last amended DM 19.01.2022 (GU 28, 03.02.2022), corrected DM 14.03.2022. Art. 3.1: "ricade nella provincia di Catania e comprende i terreni di parte dei territori dei comuni di" 20 comuni, then a contour line boundary (about 400 to 1,000 m).

Method (all regions): comune names are taken verbatim from Art. 3 of the disciplinare in the MASAF archive (page https://www.masaf.gov.it/flex/cm/pages/ServeBLOB.php/L/IT/IDPagina/4625, archives downloaded 2026-11-20/21, text in `raw/txt/`). Each name is resolved within its named province only, with `it_tools/istat.py` (ISTAT current list, suppressed comuni and variations since 1991), then mapped to GISCO LAU 2024 by ISTAT code (`IT_` + 6 digits). Every name maps to exactly one unit. Build script: `../../it_tools/build_classics.py`; style assembly: `../../it_tools/style_classics.py`. LAU 2024 predates four 2024/25 ISTAT mergers (Sovizzo, Setteville, Santa Caterina d'Este, Uggiate con Ronago); LAU 2024 units are used as they stand.

## Counts
20 names, 20 rows, all Catania, all `partial = yes` ("parte dei territori").

## Judgement calls
- Abbreviations: S. Maria di Licodia, Aci S. Antonio, S. Venerina, S. Alfio. Short forms Zafferana, Piedimonte, Castiglione = Zafferana Etnea, Piedimonte Etneo, Castiglione di Sicilia (the only comuni of those stems in Catania).
- Every comune reaches up the volcano beyond the zone, and coastal ones (Acireale, Giarre, Mascali) reach down to the sea. None is described as a small part, so all are kept.
- The contrade of Allegato 1 (additional geographic units) are not drawn.

## Style sourcing
Grapes from Art. 2 (Nerello Mascalese 80 percent minimum for Rosso; Carricante 60 percent for Bianco), with Italian Wine Central and VinePair or Wine Scholar Guild. Nerello Cappuccio is not in the app.

## Held back
- Red acidity, pairing (one source each; web search budget ran out, etnadoc.com refused connections).
- Elevation and climate in the summary (one source).
