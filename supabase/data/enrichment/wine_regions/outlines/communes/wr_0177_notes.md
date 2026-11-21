# Valdeorras DOP: production zone

**Source:** https://www.mapa.gob.es/dam/mapa/contenido/alimentacion/temas/calidad-agroalimentaria/2017-calidad-diferenciada/nuevo_denominaciones/pliegos-de-condiciones/pliego-condiciones-vinos/dops/valdeorras_2024_12_04.pdf

Pliego de condiciones DOP Valdeorras, version October 2024, in force 04/12/2024, linked from the MAPA DOP page. Section 4: the Ayuntamientos of O Barco de Valdeorras, A Rúa, Vilamartín de Valdeorras, O Bolo, Carballeda de Valdeorras, Larouco, Petín and Rubiá, province of Ourense.

## Counts
**8 rows**, 0 partial.

## Held back
None.

## Method
Names matched to Eurostat GISCO LAU 2024 by name within the stated province only (the pliego gives no INE codes), accent, article and bilingual-name insensitive, using `classics/es/tools/match.py`; spellings that differ from the LAU name were resolved by hand to the sole candidate in the province (aliases in `tools/build.py`). Every name resolved to exactly one LAU unit and every GISCO_ID is unique. Raw text in `raw/`. Partial municipalities are kept and flagged partial = yes when the text names an administrative or cadastral unit (parish, concejo, cadastral polygon); municipalities where the text names only individual villages, places or a pago are held back, because the whole municipality would overstate the area badly. Unlike the classics round, no cadastral share was measured, so a partial row can overstate the area considerably.
