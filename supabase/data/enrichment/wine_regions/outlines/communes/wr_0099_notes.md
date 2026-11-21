# Rueda DO: production zone

**Source:** Pliego de condiciones DOP "Rueda" (PDO-ES-A0889), linked from MAPA (https://www.mapa.gob.es/es/alimentacion/temas/calidad-diferenciada/dop-igp/detalle/vcprd/dop_rueda).
PDF: https://www.mapa.gob.es/dam/mapa/contenido/alimentacion/temas/calidad-agroalimentaria/2017-calidad-diferenciada/nuevo_denominaciones/pliegos-de-condiciones/pliego-condiciones-vinos/dops/rueda_2025_06_12.pdf . Section 4.1, by province.

## Counts
Text: 53 Valladolid + 4 Ávila + 17 Segovia = 74 names. **66 rows** (Valladolid 50, Ávila 3, Segovia 13).

## Name judgements (single candidate in the province, recorded)
Carpio del Campo -> Carpio (ES_47035; no source found that uses "Carpio del Campo" as a municipal name, Carpio is the only Valladolid candidate: flag for review); Castrejón -> Castrejón de Trabancos; Hornillos -> Hornillos de Eresma; Sieteiglesias de Trabancos -> Siete Iglesias de Trabancos; Villafranca del Duero -> Villafranca de Duero; Villanueva del Duero -> Villanueva de Duero; Fuentes de Santa Cruz -> Fuente de Santa Cruz; Fuente Olmedo -> Fuente-Olmedo; Órbita -> Orbita.
Villafranca de Duero (ES_47204) is also in Toro; both pliegos list it.

## Partial (kept)
- **Órbita (ES_05174)**: "Órbita (polígonos catastrales 1, 2, 4 y 5)". Measured 56.6% of cadastral area (polygon 5 exists only as a consolidated-area polygon B5 in today's cadastre).

## Held back
| Entry | Reason |
|---|---|
| Gomeznarro, Rodilana (Valladolid) | Not municipalities; secondary sources describe both as pedanías of Medina del Campo (ES_47085, already included). Union unaffected. |
| Torrecilla del Valle (Valladolid) | Not a municipality; secondary sources place it in Rueda (already included). |
| Bernuy de Coca, Moraleja de Coca, Montuenga (Segovia) | Not municipalities; secondary sources place them in Santiuste de San Juan Bautista, Nava de la Asunción and Codorniz respectively, all already included. |
| Palacios de Goda (ES_05178) | Partial: "polígonos catastrales 14, 17, 18, 19 y 22" = 20.5% of cadastral area; below the quarter threshold. |
| Coca (ES_40057) | Partial: "polígono 7, correspondiente a la pedanía de Villagonzalo de Coca". Today's cadastre has no polygon 7 in Coca (renumbered or consolidated), so the share could not be measured; one pedanía of a 98 km2 municipality. Left out. |

## Method
Names matched to Eurostat GISCO LAU 2024 by name within the stated province only (the pliego gives no INE codes), accent, article and bilingual-name insensitive; every name resolved to exactly one LAU unit and every GISCO_ID is unique (`tools/match.py`, `tools/build.py`). Raw text in `raw/` (PDF and pypdf extraction). Inclusion rule for partially covered municipalities: kept (partial = yes, with the text's wording) when the covered part is at least about a quarter of the municipality; left out below that or when the share could not be measured. Cadastral shares come from parcel areas in the Catastro INSPIRE WFS (`tools/cad_share.py`, tiles in `raw/cad/`), grouped by polygon of the municipality's own cadastral code; these are measurements, not text.
