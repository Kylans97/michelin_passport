# Ribeiro DOP: production zone

**Source:** https://www.mapa.gob.es/dam/mapa/contenido/alimentacion/temas/calidad-agroalimentaria/2017-calidad-diferenciada/nuevo_denominaciones/pliegos-de-condiciones/pliego-condiciones-vinos/dops/ribeiro_2025_12_04.pdf

Pliego DOP Ribeiro, version April 2025, on MAPA (ribeiro_2025_12_04.pdf). Section 4: nine whole ayuntamientos (Ribadavia, Arnoia, Castrelo de Miño, Carballeda de Avia, Leiro, Cenlle, Beade, Punxín, Cortegada), plus parishes of O Carballiño (3) and Boborás (5 of 14), and in Toén the parish of Alongos plus named places (partial).

## Counts
**12 rows**, 3 partial: O Carballiño, Boborás, Toén.

## Held back
Ourense (ES_32054): only the places Santa Cruz de Arrabaldo and Untes. San Amaro (ES_32074): only the village A Touza. Both are named by place, not by parish, so drawing the whole municipality would overstate badly.

## Method
Names matched to Eurostat GISCO LAU 2024 by name within the stated province only (the pliego gives no INE codes), accent, article and bilingual-name insensitive, using `classics/es/tools/match.py`; spellings that differ from the LAU name were resolved by hand to the sole candidate in the province (aliases in `tools/build.py`). Every name resolved to exactly one LAU unit and every GISCO_ID is unique. Raw text in `raw/`. Partial municipalities are kept and flagged partial = yes when the text names an administrative or cadastral unit (parish, concejo, cadastral polygon); municipalities where the text names only individual villages, places or a pago are held back, because the whole municipality would overstate the area badly. Unlike the classics round, no cadastral share was measured, so a partial row can overstate the area considerably.
