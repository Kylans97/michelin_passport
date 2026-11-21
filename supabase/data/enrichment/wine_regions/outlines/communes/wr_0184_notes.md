# Somontano DOP: production zone

**Source:** https://www.aragon.es/documents/d/guest/2012_pliego_condiciones_dop_somontano

Pliego DOP Somontano 2012, the current text linked by the Government of Aragón (zone identical to the 2011 MAPA copy). A normal amendment (AM01, 2026) is in progress; its description does not touch section 4. 43 whole términos municipales in Huesca. Name judgements: 'Blecua-Torres' = Blecua y Torres; 'Santa María de Dulces' = Santa María de Dulcis (sole candidate in Huesca; spelling in the pliego differs).

## Counts
**43 rows**, 0 partial.

## Held back
None.

## Method
Names matched to Eurostat GISCO LAU 2024 by name within the stated province only (the pliego gives no INE codes), accent, article and bilingual-name insensitive, using `classics/es/tools/match.py`; spellings that differ from the LAU name were resolved by hand to the sole candidate in the province (aliases in `tools/build.py`). Every name resolved to exactly one LAU unit and every GISCO_ID is unique. Raw text in `raw/`. Partial municipalities are kept and flagged partial = yes when the text names an administrative or cadastral unit (parish, concejo, cadastral polygon); municipalities where the text names only individual villages, places or a pago are held back, because the whole municipality would overstate the area badly. Unlike the classics round, no cadastral share was measured, so a partial row can overstate the area considerably.
