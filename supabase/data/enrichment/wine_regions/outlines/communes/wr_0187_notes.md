# Jumilla DOP: production zone

**Source:** https://mapa.gob.es/ca/alimentacion/temas/calidad-diferenciada/jumilla_2023_03_21_tcm34-656751.pdf

Pliego DOP Jumilla, MAPA version of 21 March 2023. Later amendments (BOE-A-2024-21675, BOE-A-2025-4387) change wine types, grape rules and labelling, not the area (checked in raw/). Section 4: Jumilla (Murcia) and Fuente-Álamo, Albatana, Ontur, Hellín, Tobarra and Montealegre del Castillo (Albacete). 'Fuentealamo' = LAU Fuente-Álamo (ES_02033).

## Counts
**7 rows**, 0 partial.

## Held back
None. Note: the label_note comes from the 2023 text; the 2024 amendment added label mentions, which this text predates.

## Method
Names matched to Eurostat GISCO LAU 2024 by name within the stated province only (the pliego gives no INE codes), accent, article and bilingual-name insensitive, using `classics/es/tools/match.py`; spellings that differ from the LAU name were resolved by hand to the sole candidate in the province (aliases in `tools/build.py`). Every name resolved to exactly one LAU unit and every GISCO_ID is unique. Raw text in `raw/`. Partial municipalities are kept and flagged partial = yes when the text names an administrative or cadastral unit (parish, concejo, cadastral polygon); municipalities where the text names only individual villages, places or a pago are held back, because the whole municipality would overstate the area badly. Unlike the classics round, no cadastral share was measured, so a partial row can overstate the area considerably.
