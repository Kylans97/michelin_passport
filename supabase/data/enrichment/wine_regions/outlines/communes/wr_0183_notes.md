# Cigales DOP: production zone

**Source:** https://www.mapa.gob.es/dam/mapa/contenido/alimentacion/temas/calidad-agroalimentaria/2017-calidad-diferenciada/nuevo_denominaciones/pliegos-de-condiciones/pliego-condiciones-vinos/dops/cigales_2022_03_25.pdf

Pliego DOP Cigales, MAPA cigales_2022_03_25.pdf. Section 4.2: 11 municipalities in Valladolid and Dueñas (Palencia). 'Corcos del Valle' = LAU Corcos (ES_47055).

## Counts
**12 rows**, 0 partial.

## Held back
Valladolid (ES_47186): only the pago 'El Berrocal'. The city municipality would overstate badly.

## Method
Names matched to Eurostat GISCO LAU 2024 by name within the stated province only (the pliego gives no INE codes), accent, article and bilingual-name insensitive, using `classics/es/tools/match.py`; spellings that differ from the LAU name were resolved by hand to the sole candidate in the province (aliases in `tools/build.py`). Every name resolved to exactly one LAU unit and every GISCO_ID is unique. Raw text in `raw/`. Partial municipalities are kept and flagged partial = yes when the text names an administrative or cadastral unit (parish, concejo, cadastral polygon); municipalities where the text names only individual villages, places or a pago are held back, because the whole municipality would overstate the area badly. Unlike the classics round, no cadastral share was measured, so a partial row can overstate the area considerably.
