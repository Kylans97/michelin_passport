# Altos de Pinto Bandeira (DO): altos-de-pinto-bandeira

## Official text
INPI, "Lista das Denominações de Origem reconhecidas" (at 20 Oct 2026, https://www.gov.br/inpi/pt-br/servicos/indicacoes-geograficas/arquivos/status-pedidos/LISTADASDENOMINAESDEORIGEMRECONHECIDAS.At20Outubro2026.pdf; text in `scratchpad/round4/br_mx/txt/inpi_do_list.txt`): BR412021000003-4, Associação dos Produtores de Vinho de Pinto Bandeira, "Altos de Pinto Bandeira", BR/RS, Espumante natural, Denominação de Origem, 29/11/2022. Delimitation: "A área delimitada ... possui 65Km2 de área contínua, sendo 76,6% localizada no município de Pinto Bandeira, 19,0% no município de Farroupilha e 4,4% no município de Bento Gonçalves", with extreme coordinates N 29°01'22" S 51°28'02" W; E 29°06'46" S 51°23'09" W; S 29°10'32" S 51°26'38" W; W 29°02'07" S 51°30'35" W.

## Units used
One polygon, the Embrapa DO limit: Altos de Pinto Bandeira (BR_do_BR412021000003-4). Count: 1. None partial.

## Judgement calls
- The line is a continuous area crossing three municipalities in part, so municipal units would overstate it; the Embrapa polygon of the delimitation is used instead.
- Check against INPI: polygon area 64.98 km2 (layer attribute "Área" 64,982,611.87 m2) against INPI's 65 km2; polygon bounds N -29.0228, E -51.3859, S -29.1756, W -51.5099 against INPI extremes -29.0228, -51.3858, -29.1756, -51.5097 (all within about 30 m).
- Licence caveat: the Embrapa GeoInfo metadata gives licence "not_specified" (restriction code "license", no text). Used as the official delimitation geometry of a public body, with attribution; flag for the product owner before publishing, as in round 4 (Vale dos Vinhedos).
- The older Indicação de Procedência Pinto Bandeira (2010) is not drawn.

## Grapes / style
See `style.json` (sources per field) and the research logs in `work/` (style_cl_north_log.md, style_cl_south_log.md, style_ar_br_log.md).

## Boundary dataset
- Embrapa Uva e Vinho, GeoInfo dataset 11728, "Denominação de Origem Altos de Pinto Bandeira - vetor limite" (geonode:doapb_limite_4326), https://geoinfo.dados.embrapa.br/catalogue/#/dataset/11728, published 2025-12-11, last updated 2026-05-27, EPSG:4326, point of contact Rosemary Hoff (Embrapa); project "Estruturação, qualificação e consolidação de Indicações Geográficas brasileiras de vinhos".
- WFS GetFeature (https://geoinfo.dados.embrapa.br/geoserver/ows) retrieved 2026-11-21 to `raw/br_embrapa/doapb_limite_4326.geojson`, metadata to `raw/br_embrapa/meta_11728.json`. Geometry identical to the copy fetched in round 4.
- Licence: "not_specified" in the layer metadata (see above).

## Geometry
- Combined file: `sa_units.geojson` (91 units for the eleven regions, EPSG:4326, properties exactly `unit_id`, `name`, `source`).
- Douglas-Peucker at 0.0009 degrees (about 100 m), coordinates snapped to a 1e-5 degree grid. Slivers opened between neighbours by independent simplification were filled within each region's unit set (interior holes of the union given to the neighbour with the longest shared edge, overlaps removed in unit order, 5 passes). Union for this region: 1 part(s), 0 interior hole(s).
- Area change from simplification is under 1.2% for every unit (worst: the Altos de Pinto Bandeira polygon, then the small urban San Juan departamentos Santa Lucía, Capital and Chimbas).
- Union with `grid_size=1e-5` (or a 1e-6 buffer) when drawing the region outline.
- Build scripts (not part of the deliverable): `scratchpad/sa7_tools/build.py`, `write_out.py`, `write_notes.py`.

CSV: `altos-de-pinto-bandeira.csv` (1 rows).
