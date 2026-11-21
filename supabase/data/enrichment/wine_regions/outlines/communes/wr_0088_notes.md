# Soave (DOC Soave)

## Official text
- Disciplinare DOC "Soave", last amended by Reg. esecuzione (UE) 2021/2023 of 12.11.2021. Art. 3.1 A: "comprende in tutto o in parte il territorio dei comuni di" 13 comuni "in provincia di Verona", then a boundary.
- Soave Superiore DOCG lists the same comuni less San Bonifacio; Recioto di Soave DOCG has its own text. Neither is drawn separately.

Method (all regions): comune names are taken verbatim from Art. 3 of the disciplinare in the MASAF archive (page https://www.masaf.gov.it/flex/cm/pages/ServeBLOB.php/L/IT/IDPagina/4625, archives downloaded 2026-11-20/21, text in `raw/txt/`). Each name is resolved within its named province only, with `it_tools/istat.py` (ISTAT current list, suppressed comuni and variations since 1991), then mapped to GISCO LAU 2024 by ISTAT code (`IT_` + 6 digits). Every name maps to exactly one unit. Build script: `../../it_tools/build_classics.py`; style assembly: `../../it_tools/style_classics.py`. LAU 2024 predates four 2024/25 ISTAT mergers (Sovizzo, Setteville, Santa Caterina d'Este, Uggiate con Ronago); LAU 2024 units are used as they stand.

## Counts
13 names, 13 rows, all Verona, all `partial = yes` ("in tutto o in parte", no comune said to be whole).

## Judgement calls
- Mezzane di Sotto, San Martino Buon Albergo, Lavagno, Illasi, Colognola ai Colli and Cazzano di Tramigna are also in the Valpolicella list: the two polygons overlap.
- San Bonifacio: only the part delimited by the SS 11, the road to San Lorenzo and the A4 motorway is in. Kept as partial; it is not described as small.
- Classico (part of Soave and Monteforte d'Alpone, DM 23.10.1931) and Colli Scaligeri are appellations only.

## Style sourcing
Grapes: Garganega, Chardonnay. Trebbiano di Soave is not in the app; it is named in Garganega's local_note from Art. 2.

## Held back
- Trebbiano di Soave as a grape (not in the app, not profiled).
