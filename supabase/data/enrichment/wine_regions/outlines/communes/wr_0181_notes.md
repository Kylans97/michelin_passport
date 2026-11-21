# Bizkaiko Txakolina DOP: production zone

**Source:** https://www.euskadi.eus/contenidos/informacion/dop_txakoli_bizkaia/es_dapa/adjuntos/BIZKAIKO-TXAKOLINAren-pliegoak-20241128-consolidado.pdf

Pliego DOP Bizkaiko Txakolina, consolidated 28-11-2024, Basque Government. Section 4.1: land in 'cualquiera de los términos municipales de Bizkaia' that is found suitable and registered. Drawn as every LAU unit with province code 48 (113). Whole-province text, not a list.

## Counts
**113 rows**, 0 partial.

## Held back
None.

## Method
Names matched to Eurostat GISCO LAU 2024 by name within the stated province only (the pliego gives no INE codes), accent, article and bilingual-name insensitive, using `classics/es/tools/match.py`; spellings that differ from the LAU name were resolved by hand to the sole candidate in the province (aliases in `tools/build.py`). Every name resolved to exactly one LAU unit and every GISCO_ID is unique. Raw text in `raw/`. Partial municipalities are kept and flagged partial = yes when the text names an administrative or cadastral unit (parish, concejo, cadastral polygon); municipalities where the text names only individual villages, places or a pago are held back, because the whole municipality would overstate the area badly. Unlike the classics round, no cadastral share was measured, so a partial row can overstate the area considerably.
