# Getariako Txakolina DOP: production zone

**Source:** https://www.euskadi.eus/contenidos/informacion/dop_txakoli_getaria/es_dapa/adjuntos/PLIEGO-CR-GT_29-06-2011.pdf

Pliego DOP Getariako Txakolina dated 29-06-2011, the version linked by the Basque Government DO page (page modified 04/02/2026); eAmbrosia shows no later amendment. Section 4 reads only 'Territorio Histórico de Gipuzkoa'. Drawn as every LAU unit with province code 20 (88). This is a whole-province text, not a list of municipios; the vineyards themselves are concentrated on the coast.

## Counts
**88 rows**, 0 partial.

## Held back
None.

## Method
Names matched to Eurostat GISCO LAU 2024 by name within the stated province only (the pliego gives no INE codes), accent, article and bilingual-name insensitive, using `classics/es/tools/match.py`; spellings that differ from the LAU name were resolved by hand to the sole candidate in the province (aliases in `tools/build.py`). Every name resolved to exactly one LAU unit and every GISCO_ID is unique. Raw text in `raw/`. Partial municipalities are kept and flagged partial = yes when the text names an administrative or cadastral unit (parish, concejo, cadastral polygon); municipalities where the text names only individual villages, places or a pago are held back, because the whole municipality would overstate the area badly. Unlike the classics round, no cadastral share was measured, so a partial row can overstate the area considerably.
