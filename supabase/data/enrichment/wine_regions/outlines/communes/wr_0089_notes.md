# Prosecco (DOC Prosecco)

## Official text
- Disciplinare DOC "Prosecco", last amended DM 22.09.2025 (GU 227, 30.09.2025). Art. 3.1: "la zona che comprende le province di: Belluno, Gorizia, Padova, Pordenone, Treviso, Trieste, Udine, Venezia e Vicenza". Five provinces in Veneto, four in Friuli Venezia Giulia.

Method (all regions): comune names are taken verbatim from Art. 3 of the disciplinare in the MASAF archive (page https://www.masaf.gov.it/flex/cm/pages/ServeBLOB.php/L/IT/IDPagina/4625, archives downloaded 2026-11-20/21, text in `raw/txt/`). Each name is resolved within its named province only, with `it_tools/istat.py` (ISTAT current list, suppressed comuni and variations since 1991), then mapped to GISCO LAU 2024 by ISTAT code (`IT_` + 6 digits). Every name maps to exactly one unit. Build script: `../../it_tools/build_classics.py`; style assembly: `../../it_tools/style_classics.py`. LAU 2024 predates four 2024/25 ISTAT mergers (Sovizzo, Setteville, Santa Caterina d'Este, Uggiate con Ronago); LAU 2024 units are used as they stand.

## Counts
630 rows, every LAU 2024 unit whose ISTAT province prefix is one of the nine: Belluno 61, Gorizia 25, Padova 102, Pordenone 50, Treviso 94, Trieste 6, Udine 134, Venezia 44, Vicenza 114. `partial = no` throughout (whole provinces).

## Judgement calls
- The four FVG provinces were abolished as administrative bodies; ISTAT codes keep the historic prefixes 030, 031, 032, 093, which are used here.
- Sappada moved from Belluno to Udine in 2017; it is inside either way (IT_030189).
- The polygon includes the Dolomites, the lagoon of Venice and big cities; that comes with a whole province definition.
- Conegliano Valdobbiadene Prosecco DOCG and Asolo Prosecco DOCG lie inside (province of Treviso); they are appellations only.

## Style sourcing
Climate and soils left out of the summary: sources differ (VinePair warm and temperate, Wine Folly high rainfall) and soils have one source.

## Held back
- Climate and soil statements (see above).
- Glera's alias "Prosecco" is kept in new_grapes.json as sourced, but it equals this region's name; drop it if search would confuse the two.
