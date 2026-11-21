# Valle de San Antonio (D.O.), with Zona Valle de Leyda: valle-de-san-antonio

## Official text
Decreto N° 464 (Ministerio de Agricultura, 14 Dec 1994), "Establece zonificación vitícola y fija normas para su utilización". Consolidated text, LeyChile idNorma 13601, https://www.bcn.cl/leychile/navegar?idNorma=13601, version in force since 2026-07-14 (latest amendment Decreto 4 of 2026, which changed Art. 3 bis, not Article 1). Article 1 points 2 to 5 as quoted below; points 3, 4 and 5 were last replaced by Decreto 56 (D.O. 25.05.2018). Text read from the copy saved on 2026-11-20 (`scratchpad/americas/sa/raw/leychile_13601.json`, extracted to `americas/sa/work/leychile_13601.txt`); a second copy fetched in this round is in `raw/cl_leychile/`.

Article 1, point 3 C): "Valle de San Antonio, comprende a la provincia de igual nombre y en él se encuentran la Zona Valle de Leyda, el Área de Lo Abarca, cuyo límite es la localidad rural del mismo nombre en la comuna de Cartagena, y las Áreas de Cartagena y Algarrobo ... Valle de Leyda, cuyo límite está definido por las comunas de San Antonio y Santo Domingo y en él se encuentran las siguientes Áreas: a) San Juan, cuyo límite está definido por la comuna de San Antonio. b) Santo Domingo ..." 

## Units used
All 6 comunas of the province of San Antonio: San Antonio (05601); Algarrobo (05602); Cartagena (05603); El Quisco (05604); El Tabo (05605); Santo Domingo (05606). Count: 6. None partial.

## Judgement calls
- The subregion is the whole province (including El Quisco and El Tabo, not named as Áreas).
- Zona Valle de Leyda = comunas San Antonio (CL_COM_05601) and Santo Domingo (CL_COM_05606), both whole and both already in `sa_units.geojson`; it can be drawn as a sub-area from those two units if wanted. Not given its own CSV, since the brief asked for San Antonio with Leyda.
- Lo Abarca (a rural locality) is not drawn: no official locality boundary was sourced.
- The union has 4 parts: mainland plus tiny coastal islets.

## Grapes / style
See `style.json` (sources per field) and the research logs in `work/` (style_cl_north_log.md, style_cl_south_log.md, style_ar_br_log.md).

## Boundary dataset
- Biblioteca del Congreso Nacional de Chile (BCN), Mapas vectoriales, "División comunal: polígonos de las comunas de Chile", https://www.bcn.cl/obtienearchivo?id=repositorio/10221/10396/5/comunas_final.zip (listed on https://www.bcn.cl/siit/mapas_vectoriales/index_html). Files inside dated 2026-06-17; the copy downloaded 2026-11-20 by the earlier session (`scratchpad/americas/sa/raw/cl_bcn/`) was reused, not downloaded again.
- Source CRS WGS 84 / Web Mercator (EPSG:3857), converted to EPSG:4326 with the exact spherical-Mercator inverse.
- Unit code: `cod_comuna`, the official Código Único Territorial (CUT), zero-padded to 5 digits in `unit_id`.
- BCN spellings kept in `lau_name` (e.g. Paihuano for the decree's Paiguano, Ranquil for Ránquil, Los Angeles). BCN still labels the province of comunas 161xx with its pre-2018 name "Ñuble"; the official name since Ley 21.033 is Diguillín, used in the `province` column.
- Version caveat (BCN): a synthesis of official sources that may reflect editions of 2014, 2017 and December 2018.
- Licence/conditions (BCN): free use, citing the Biblioteca del Congreso Nacional de Chile as the source; referential, not for geodetic-precision work.

## Geometry
- Combined file: `sa_units.geojson` (91 units for the eleven regions, EPSG:4326, properties exactly `unit_id`, `name`, `source`).
- Douglas-Peucker at 0.0009 degrees (about 100 m), coordinates snapped to a 1e-5 degree grid. Slivers opened between neighbours by independent simplification were filled within each region's unit set (interior holes of the union given to the neighbour with the longest shared edge, overlaps removed in unit order, 5 passes). Union for this region: 4 part(s), 0 interior hole(s). Extra parts are small coastal islets that belong to the official comunas.
- Area change from simplification is under 1.2% for every unit (worst: the Altos de Pinto Bandeira polygon, then the small urban San Juan departamentos Santa Lucía, Capital and Chimbas).
- Union with `grid_size=1e-5` (or a 1e-6 buffer) when drawing the region outline.
- Build scripts (not part of the deliverable): `scratchpad/sa7_tools/build.py`, `write_out.py`, `write_notes.py`.

CSV: `valle-de-san-antonio.csv` (6 rows).
