# Valpolicella (DOC Valpolicella, with Amarone, Recioto and Ripasso)

## Official text
- Disciplinare DOC "Valpolicella", last amended DM 03.08.2023 (GU 191, 17.08.2023). Art. 3.1:
  "comprende in tutto o in parte i territori dei Comuni di" 19 comuni, then a boundary description.
- Amarone della Valpolicella DOCG, Recioto della Valpolicella DOCG and Valpolicella Ripasso DOC: Art. 3.1
  of each lists the same 19 comuni with the same wording (checked line by line). One polygon covers all four.

Method (all regions): comune names are taken verbatim from Art. 3 of the disciplinare in the MASAF archive (page https://www.masaf.gov.it/flex/cm/pages/ServeBLOB.php/L/IT/IDPagina/4625, archives downloaded 2026-11-20/21, text in `raw/txt/`). Each name is resolved within its named province only, with `it_tools/istat.py` (ISTAT current list, suppressed comuni and variations since 1991), then mapped to GISCO LAU 2024 by ISTAT code (`IT_` + 6 digits). Every name maps to exactly one unit. Build script: `../../it_tools/build_classics.py`; style assembly: `../../it_tools/style_classics.py`. LAU 2024 predates four 2024/25 ISTAT mergers (Sovizzo, Setteville, Santa Caterina d'Este, Uggiate con Ronago); LAU 2024 units are used as they stand.

## Counts
19 names, 19 rows, all in the province of Verona. All 19 are `partial = yes` because the text says "in tutto o in parte" for the whole list and does not say which comuni are whole.

## Judgement calls
- Abbreviations and short forms: S. Ambrogio = Sant'Ambrogio di Valpolicella (the same Art. 3 spells it so), S. Pietro in Cariano, S. Martino Buon Albergo, S. Mauro di Saline = San; Marano = Marano di Valpolicella and Mezzane = Mezzane di Sotto (the only comuni of those stems in Verona; Soave Art. 3 lists Mezzane di Sotto). Negrar = Negrar di Valpolicella (ISTAT rename).
- Verona, Pescantina and Dolcè are only partly inside: the boundary follows Quinzano, Avesa, the Torricelle and Montorio inside Verona, the SS 12 and the Brenner railway in Pescantina, and the Adige near Ceraino in Dolcè. None is described as a small part, so all are kept and marked partial. Verona is the comune most likely to over-draw the zone (city and plain to the south); drop it if the map must stay tight.
- Classico (five comuni) and Valpantena are recorded in style.json as appellations only; they are not separate polygons.

## Style sourcing
Ratings are for standard Valpolicella, not Amarone (Wine Folly, VinePair). Grapes: only Corvina is listed, since Corvinone, Rondinella and Molinara are not in the app and are not in new_grapes.json (Rondinella lacked two sources for a profile); the blend rule naming them is in Corvina's local_note, from Art. 2.

## Held back
- Lake Garda's moderating effect (one source only).
- Rondinella as a grape profile (single source for tastes, body, acidity).
