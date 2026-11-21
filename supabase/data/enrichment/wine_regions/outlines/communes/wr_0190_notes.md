# DOP Islas Canarias: production zone

**Source:** https://canarywine.com/descargas/202208_nuevo_pliego_condiciones_final.pdf

Pliego DOP Islas Canarias published in BOC no. 153, 27 July 2021 (copy hosted by the Consejo Regulador, canarywine.com). Section 4: 'la totalidad del territorio de las Islas Canarias (código NUTS ES70)'. Drawn as every LAU unit with province code 35 or 38 (88). Chosen over the island DOs (Tacoronte-Acentejo, Valle de la Orotava, Ycoden-Daute-Isora, Abona, Valle de Güímar, Lanzarote, La Palma, El Hierro, La Gomera, Gran Canaria) because it is the one DO that stands for 'Canary Islands' as a whole; those DOs overlap it and were not drawn. Whole-territory text, not a list.

## Counts
**88 rows**, 0 partial.

## Held back
The individual island DOs (not drawn this round).

## Method
Names matched to Eurostat GISCO LAU 2024 by name within the stated province only (the pliego gives no INE codes), accent, article and bilingual-name insensitive, using `classics/es/tools/match.py`; spellings that differ from the LAU name were resolved by hand to the sole candidate in the province (aliases in `tools/build.py`). Every name resolved to exactly one LAU unit and every GISCO_ID is unique. Raw text in `raw/`. Partial municipalities are kept and flagged partial = yes when the text names an administrative or cadastral unit (parish, concejo, cadastral polygon); municipalities where the text names only individual villages, places or a pago are held back, because the whole municipality would overstate the area badly. Unlike the classics round, no cadastral share was measured, so a partial row can overstate the area considerably.
