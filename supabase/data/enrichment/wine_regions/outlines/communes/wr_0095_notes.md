# Priorat (DOQ / DOCa): production zone

**Source used:** Pliego de condiciones DOP (DOCa) "Priorat", "Versión abril 2026", published by INCAVI (Generalitat de Catalunya) as the text approved by Resolución de 6 de octubre de 2026 (BOE-A-2026-21943).
PDF: https://incavi.gencat.cat/content/dam/incavi/home/normativa/plecs-de-condicions-de-les-do-catalanes/do-priorat/PRIORAT_DOQ_ETIQUETATGE_canvis_juny_2026_061026.pdf
**Cross-check:** MAPA's linked text (`https://www.mapa.gob.es/dam/mapa/contenido/alimentacion/temas/calidad-agroalimentaria/2017-calidad-diferenciada/nuevo_denominaciones/pliegos-de-condiciones/pliego-condiciones-vinos/dops/priorat_2022_09_06.pdf`, "Versión Noviembre 2021"). Section 4.1 is word-for-word identical in both (compared programmatically).
Section 4.1 "Zona de producción de la uva".

## Counts
11 rows: 9 whole municipalities (Bellmunt del Priorat, Gratallops, El Lloar, La Morera de Montsant "y su agregado Escaladei", Poboleda, Porrera, Torroja del Priorat, La Vilella Alta, La Vilella Baixa) + 2 partial. All Tarragona.

## Partial (kept)
- **Falset (ES_43055)**: "la parte norte del municipio de Falset comprendida por los polígonos números 1, 4, 5, 6, 7, 21 y 25 enteros" plus long parcel lists in polygons 2, 3, 19, 20, 22 and 24. The whole polygons alone are 42.7% of Falset's cadastral area; the true share is higher.
- **El Molar (ES_43085)**: "la parte este del municipio del Molar comprendida por los polígonos nº. 5, 6 y 7 enteros" plus parcels in polygons 4, 8, 9, 10. Whole polygons alone are 26.1%; true share higher (polygon 8 alone is 11.7% and most of its parcels are listed).
Both carry Vila units of their own (Masos de Falset, Solanes del Molar).

## Held back
None.

## Sub-units (section 4.2, not geometry)
12 "vila" units for the label mention "vino de vila de ...": Bellmunt, Escaladei, Gratallops, El Lloar, La Morera, Poboleda, Porrera, Torroja, La Vilella Alta, La Vilella Baixa, Masos de Falset, Solanes del Molar. Also Paraje units and Viña Clasificada / Gran Viña Clasificada (defined by reference to the Consejo's register).

## Method
Names matched to Eurostat GISCO LAU 2024 by name within the stated province only (the pliego gives no INE codes), accent, article and bilingual-name insensitive; every name resolved to exactly one LAU unit and every GISCO_ID is unique (`tools/match.py`, `tools/build.py`). Raw text in `raw/` (PDF and pypdf extraction). Inclusion rule for partially covered municipalities: kept (partial = yes, with the text's wording) when the covered part is at least about a quarter of the municipality; left out below that or when the share could not be measured. Cadastral shares come from parcel areas in the Catastro INSPIRE WFS (`tools/cad_share.py`, tiles in `raw/cad/`), grouped by polygon of the municipality's own cadastral code; these are measurements, not text.
