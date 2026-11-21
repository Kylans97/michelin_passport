# Rías Baixas DO: production zone

**Source:** Pliego de condiciones DOP Rías Baixas, "julio 2024", linked from MAPA (https://www.mapa.gob.es/es/alimentacion/temas/calidad-diferenciada/dop-igp/detalle/vcprd/dop_rias-baixas).
PDF: https://www.mapa.gob.es/dam/mapa/contenido/alimentacion/temas/calidad-agroalimentaria/2017-calidad-diferenciada/nuevo_denominaciones/pliegos-de-condiciones/pliego-condiciones-vinos/dops/rias_baixas_2024_09_30.pdf . Section 4 "Delimitación de la zona geográfica": a table of subzone, municipality, parishes ("Todas" or a list).

## Counts
Text: 36 municipality entries over 5 subzones (Tui appears twice). Rows: **28** = 24 whole + 4 partial. Pontevedra 23, A Coruña 5.
- Val do Salnés (12, all parishes), Condado do Tea (Salvaterra de Miño, As Neves, Arbo, Crecente, Salceda de Caselas, Ponteareas, all parishes), O Rosal (O Rosal, Tomiño, A Garda all), Soutomaior (all), Ribeira do Ulla (Vedra all).
- **Tui (ES_36055)** marked not partial: the parishes listed under Condado do Tea (Guillarei, Paramos, Baldráns, Caldelas de Tui) plus those under O Rosal (Pexegueiro, Areas, Malvás, Ribadelouro, Rebordáns, Pazos de Reis, Randufe, Tui) are 12, which is every parish in the gl.wikipedia parish table for Tui. Caveat: the same article says 13 in one place; if 13 is right, one parish is outside.
- Name judgement: "A Garda" (Galician) = LAU "Guarda, A" (ES_36023), the only candidate in Pontevedra.

## Partial (kept, by parish count; parish counts from gl.wikipedia, not an official register)
| Municipality | Listed parishes | Share |
|---|---|---|
| Padrón (ES_15065) | Carcacía, Iria Flavia, Herbón | 3 of 5 |
| Teo (ES_15082) | Oza, Teo, Lampai, Bamonde, Rarís, Vilariño, Reis | 7 of 13 |
| Boqueixón (ES_15012) | Codeso, Pousada, Oural, Ledesma, Donas, Sucira | 6 of 14 |
| A Estrada (ES_36017) | 14 parishes (see CSV) | 14 of 51 (borderline, kept) |

## Left out (only a small part listed; held back)
| Municipality | Listed | Share |
|---|---|---|
| A Cañiza (ES_36009) | Valeixe | 1 of 9 |
| Mos (ES_36033) | Louredo | 1 of 10 |
| Gondomar (ES_36021) | Mañufe, Vilaza | 2 of 10 |
| Touro (ES_15085) | Bendaña | 1 of 19 |
| Silleda (ES_36052) | Cira | 1 of 33 |
| Vila de Cruces (ES_36059) | Camanzo, Gres, Añobre | 3 of 28 |

Parish shares are by count, not area: parish boundaries were not available here. Parish geometry (e.g. IGN/Xunta parroquias) would allow an exact clip.

## Method
Names matched to Eurostat GISCO LAU 2024 by name within the stated province only (the pliego gives no INE codes), accent, article and bilingual-name insensitive; every name resolved to exactly one LAU unit and every GISCO_ID is unique (`tools/match.py`, `tools/build.py`). Raw text in `raw/` (PDF and pypdf extraction). Inclusion rule for partially covered municipalities: kept (partial = yes, with the text's wording) when the covered part is at least about a quarter of the municipality; left out below that or when the share could not be measured. Cadastral shares come from parcel areas in the Catastro INSPIRE WFS (`tools/cad_share.py`, tiles in `raw/cad/`), grouped by polygon of the municipality's own cadastral code; these are measurements, not text.
