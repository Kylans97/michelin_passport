# Montsant DOP: production zone

**Source:** https://www.mapa.gob.es/dam/mapa/contenido/alimentacion/temas/calidad-agroalimentaria/2017-calidad-diferenciada/nuevo_denominaciones/pliegos-de-condiciones/pliego-condiciones-vinos/dops/montsant_2022_09_14.pdf

Pliego DOP Montsant, version December 2021 (MAPA montsant_2022_09_14.pdf). Section 4 is identical in the INCAVI 'Versión mayo 2026' text (raw/montsant_incavi_2026_05.txt). 12 whole municipalities plus parts of Falset, El Molar, Garcia, Móra la Nova and Tivissa by cadastral polygon and parcel (partial). Falset and El Molar are also partial rows of Priorat: the two drawn areas will overlap there.

## Counts
**17 rows**, 5 partial: Falset, El Molar, Garcia, Móra la Nova, Tivissa.

## Held back
None.

## Method
Names matched to Eurostat GISCO LAU 2024 by name within the stated province only (the pliego gives no INE codes), accent, article and bilingual-name insensitive, using `classics/es/tools/match.py`; spellings that differ from the LAU name were resolved by hand to the sole candidate in the province (aliases in `tools/build.py`). Every name resolved to exactly one LAU unit and every GISCO_ID is unique. Raw text in `raw/`. Partial municipalities are kept and flagged partial = yes when the text names an administrative or cadastral unit (parish, concejo, cadastral polygon); municipalities where the text names only individual villages, places or a pago are held back, because the whole municipality would overstate the area badly. Unlike the classics round, no cadastral share was measured, so a partial row can overstate the area considerably.
