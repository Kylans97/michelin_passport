# Valle del Maule (D.O.): valle-del-maule

## Official text
Decreto N° 464 (Ministerio de Agricultura, 14 Dec 1994), "Establece zonificación vitícola y fija normas para su utilización". Consolidated text, LeyChile idNorma 13601, https://www.bcn.cl/leychile/navegar?idNorma=13601, version in force since 2026-07-14 (latest amendment Decreto 4 of 2026, which changed Art. 3 bis, not Article 1). Article 1 points 2 to 5 as quoted below; points 3, 4 and 5 were last replaced by Decreto 56 (D.O. 25.05.2018). Text read from the copy saved on 2026-11-20 (`scratchpad/americas/sa/raw/leychile_13601.json`, extracted to `americas/sa/work/leychile_13601.txt`); a second copy fetched in this round is in `raw/cl_leychile/`.

Article 1, point 4 D): "Valle del Maule: Comprende la provincia de Talca, con excepción de la comuna de Río Claro, la provincia de Linares y la comuna de Cauquenes de la provincia del mismo nombre de la VII Región Administrativa del Maule y en él se encuentran las siguientes Zonas: Valle del Claro, Valle del Loncomilla y Valle del Tutuvén." Zona Valle del Claro: comunas Talca, San Clemente, Pencahue, Maule, Pelarco, San Rafael, Empedrado, Curepto; Valle del Loncomilla: San Javier, Villa Alegre, Retiro, Parral, Linares, Yerbas Buenas, Colbún, Longaví; Valle del Tutuvén: Cauquenes. 

## Units used
Province Talca without Río Claro (9), province Linares (8), comuna Cauquenes (1): Talca (07101); Constitución (07102); Curepto (07103); Empedrado (07104); Maule (07105); Pelarco (07106); Pencahue (07107); San Clemente (07109); San Rafael (07110); Cauquenes (07201); Linares (07401); Colbún (07402); Longaví (07403); Parral (07404); Retiro (07405); San Javier (07406); Villa Alegre (07407); Yerbas Buenas (07408). Count: 18. None partial.

## Judgement calls
- Constitución (Talca province) is inside the subregion by the province wording, although no Zona names it. Río Claro (7108) is excluded as the text says; it belongs to Valle de Curicó. Chanco and Pelluhue (Cauquenes province) are excluded.

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
- Douglas-Peucker at 0.0009 degrees (about 100 m), coordinates snapped to a 1e-5 degree grid. Slivers opened between neighbours by independent simplification were filled within each region's unit set (interior holes of the union given to the neighbour with the longest shared edge, overlaps removed in unit order, 5 passes). Union for this region: 1 part(s), 4 interior hole(s). Each remaining hole is a pinhole under about 500 m2 where three units meet (or a gap inside one unit), not a real gap.
- Area change from simplification is under 1.2% for every unit (worst: the Altos de Pinto Bandeira polygon, then the small urban San Juan departamentos Santa Lucía, Capital and Chimbas).
- Union with `grid_size=1e-5` (or a 1e-6 buffer) when drawing the region outline.
- Build scripts (not part of the deliverable): `scratchpad/sa7_tools/build.py`, `write_out.py`, `write_notes.py`.

CSV: `valle-del-maule.csv` (18 rows).
