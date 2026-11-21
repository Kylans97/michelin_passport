# Campo de Borja DOP: production zone

**Source:** https://www.aragon.es/documents/d/guest/202412_pliego_condiciones_dop_campo_borja_vigente

Pliego approved by Orden AGA/1497/2024 (BOA 11/12/2024), linked as 'vigente' by the Government of Aragón; zone text identical to the MAPA 2023 copy. 16 whole municipalities plus Mallén (cadastral polygons 4 to 11) and Fréscano (polygons 1 to 14 and 19), partial. 'Alberite' = Alberite de San Juan.

## Counts
**18 rows**, 2 partial: Mallén, Fréscano.

## Held back
None.

## Method
Names matched to Eurostat GISCO LAU 2024 by name within the stated province only (the pliego gives no INE codes), accent, article and bilingual-name insensitive, using `classics/es/tools/match.py`; spellings that differ from the LAU name were resolved by hand to the sole candidate in the province (aliases in `tools/build.py`). Every name resolved to exactly one LAU unit and every GISCO_ID is unique. Raw text in `raw/`. Partial municipalities are kept and flagged partial = yes when the text names an administrative or cadastral unit (parish, concejo, cadastral polygon); municipalities where the text names only individual villages, places or a pago are held back, because the whole municipality would overstate the area badly. Unlike the classics round, no cadastral share was measured, so a partial row can overstate the area considerably.
