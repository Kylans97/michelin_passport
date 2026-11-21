# Monterrei DOP: production zone

**Source:** https://www.mapa.gob.es/dam/mapa/contenido/alimentacion/temas/calidad-agroalimentaria/2017-calidad-diferenciada/nuevo_denominaciones/pliegos-de-condiciones/pliego-condiciones-vinos/dops/monterrei_2025_09_12.pdf

Pliego DOP Monterrei, version July 2025, on MAPA (monterrei_2025_09_12.pdf). Section 4: subzonas Valle de Monterrei and Ladera de Monterrei, by parishes, plus the whole ayuntamiento of Vilardevós. Whether a parish list covers the whole municipality was checked against the Galician Wikipedia parish categories (`raw/glwiki_parishes*.json`), used only for this flag; where no category was found the row is kept partial.
Combining both subzonas, Monterrei (11 of 11), Oímbra (7 of 7) and Verín (15 of 15) are complete and drawn whole. Castrelo do Val (5 of 9), Cualedro (4 of 10), Laza (2 of 10) and Riós (count not found) are partial.

## Counts
**8 rows**, 4 partial: Castrelo do Val, Riós, Cualedro, Laza.

## Held back
None.

## Method
Names matched to Eurostat GISCO LAU 2024 by name within the stated province only (the pliego gives no INE codes), accent, article and bilingual-name insensitive, using `classics/es/tools/match.py`; spellings that differ from the LAU name were resolved by hand to the sole candidate in the province (aliases in `tools/build.py`). Every name resolved to exactly one LAU unit and every GISCO_ID is unique. Raw text in `raw/`. Partial municipalities are kept and flagged partial = yes when the text names an administrative or cadastral unit (parish, concejo, cadastral polygon); municipalities where the text names only individual villages, places or a pago are held back, because the whole municipality would overstate the area badly. Unlike the classics round, no cadastral share was measured, so a partial row can overstate the area considerably.
