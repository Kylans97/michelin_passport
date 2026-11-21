# Valle del Biobío (D.O.): valle-del-bio-bio

## Official text
Decreto N° 464 (Ministerio de Agricultura, 14 Dec 1994), "Establece zonificación vitícola y fija normas para su utilización". Consolidated text, LeyChile idNorma 13601, https://www.bcn.cl/leychile/navegar?idNorma=13601, version in force since 2026-07-14 (latest amendment Decreto 4 of 2026, which changed Art. 3 bis, not Article 1). Article 1 points 2 to 5 as quoted below; points 3, 4 and 5 were last replaced by Decreto 56 (D.O. 25.05.2018). Text read from the copy saved on 2026-11-20 (`scratchpad/americas/sa/raw/leychile_13601.json`, extracted to `americas/sa/work/leychile_13601.txt`); a second copy fetched in this round is in `raw/cl_leychile/`.

Article 1, point 5 B): "Valle del Biobío: Comprende las comunas de Yumbel, Nacimiento, Mulchén, Negrete y Laja de la provincia de Biobío de la VIII Región Administrativa del Biobío, y en él se encuentran las siguientes áreas: a) Yumbel, cuyo límite está definido por la comuna del mismo nombre y la comuna de Laja. b) Mulchén, cuyo límite está definido por la comuna del mismo nombre y las comunas de Nacimiento y Negrete." 

## Units used
The 5 comunas named: Laja (08304); Mulchén (08305); Nacimiento (08306); Negrete (08307); Yumbel (08313). Count: 5. None partial.

## Judgement calls
- Listed comunas only; the Áreas use the same five. Other Biobío province comunas named in Art. 3 bis for Secano Interior (Los Ángeles, San Rosendo, etc.) are not in this subregion and are not drawn.

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
- Douglas-Peucker at 0.0009 degrees (about 100 m), coordinates snapped to a 1e-5 degree grid. Slivers opened between neighbours by independent simplification were filled within each region's unit set (interior holes of the union given to the neighbour with the longest shared edge, overlaps removed in unit order, 5 passes). Union for this region: 1 part(s), 0 interior hole(s).
- Area change from simplification is under 1.2% for every unit (worst: the Altos de Pinto Bandeira polygon, then the small urban San Juan departamentos Santa Lucía, Capital and Chimbas).
- Union with `grid_size=1e-5` (or a 1e-6 buffer) when drawing the region outline.
- Build scripts (not part of the deliverable): `scratchpad/sa7_tools/build.py`, `write_out.py`, `write_notes.py`.

CSV: `valle-del-bio-bio.csv` (5 rows).
