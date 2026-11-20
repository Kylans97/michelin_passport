# Valle del Maipo (D.O.) — wr_0029

## Official text
Decreto N° 464 (Ministerio de Agricultura, 14 Dec 1994, D.O. 26 May 1995), "Establece zonificación vitícola y fija normas para su utilización". Consolidated text, LeyChile idNorma 13601, version in force since 2026-07-14 ("Última Versión", latest amendment Decreto 4 of 2026, which amended Art. 3 bis and a later article on dealcoholised and late-harvest wine, not Article 1): https://www.bcn.cl/leychile/navegar?idNorma=13601 (JSON saved as `raw/leychile_13601.json`). Article 1 points 3 and 4 were last replaced by Decreto 56 (D.O. 25.05.2018). Cross-checked against SAG's compiled PDF `raw/sag_decreto_464.pdf` (https://www.sag.gob.cl/sites/default/files/decreto_ndeg_464.pdf, undated, older than the LeyChile version: it lacks the Los Lingues/Apalta/Lo Abarca/Licantén areas), which gives the same definitions for these three regions.

Article 1, point 4 A): "Valle del Maipo: Comprende todas las provincias de la Región Administrativa Metropolitana de Santiago y en él se encuentran las siguientes Áreas: a) Santiago, cuyo límite está definido por las comunas de Peñalolén y La Florida. b) Pirque ... m) Lampa ..."

## Units used
All 52 comunas of the Región Metropolitana (provinces Santiago 32, Cordillera 3, Chacabuco 3, Maipo 4, Melipilla 5, Talagante 5). Count: 52. None partial.

## Judgement calls
- "Todas las provincias de la Región Metropolitana" = every comuna of the RM, including dense urban Santiago, San José de Maipo (high Andes) and Curacaví. The 13 named Áreas are sub-areas within the subregion, not its limit.
- Unlike Casablanca, the Valle Central heading says it runs "desde la provincia de Chacabuco"; that is consistent with all RM provinces.

## Grapes / style
No varieties specific to Maipo. The decree's variety list (Art. 3 b) is national (its table was replaced by Decreto 18 of 2024 and is not rendered in the LeyChile text; the older SAG compilation lists it). Art. 5 bis allows the complementary terms "Andes" for the areas Santiago, Pirque, Puente Alto, Buin, and "Entre Cordilleras" for Isla de Maipo, Talagante, Melipilla, Alhué, María Pinto, Colina, Calera de Tango, Til Til, Lampa.

## Held back
None.

## Boundary dataset
- Biblioteca del Congreso Nacional de Chile (BCN), Mapas vectoriales, "División comunal: polígonos de las comunas de Chile", https://www.bcn.cl/obtienearchivo?id=repositorio/10221/10396/5/comunas_final.zip (listed on https://www.bcn.cl/siit/mapas_vectoriales/index_html). Files inside dated 2026-06-17; downloaded 2026-11-20 to `raw/cl_bcn/`.
- 346 comunas; source CRS WGS 84 / Web Mercator (EPSG:3857), converted to EPSG:4326 with the exact spherical-Mercator inverse.
- Unit code: `cod_comuna`, the official Código Único Territorial (CUT), zero-padded to 5 digits in `unit_id` (e.g. CL_COM_05102 Casablanca).
- Version caveat (from BCN's page): the layer is a synthesis of official sources and may reflect editions of 2014, 2017 and December 2018.
- Licence/conditions (BCN): free use, citing the Biblioteca del Congreso Nacional de Chile as the source; the material is referential and not for geodetic-precision work.
- Not used: IDE Chile / INE layers (BCN was reachable, carries the CUT and province names, and is the dataset named in the brief).

## Geometry
- Combined file: `sa_units.geojson` (88 units in total for the six regions, EPSG:4326, properties exactly `unit_id`, `name`, `source`).
- Simplified with Douglas-Peucker at 0.0009 degrees (about 100 m), coordinates snapped to a 1e-5 degree grid (about 1 m). Independent simplification opened thin slivers (up to about 60 m wide) between neighbouring units, so within each region set (Uco, Mendoza, Maipo, Colchagua) every interior hole of the union was given to the neighbour sharing the longest edge with it, and overlaps were removed in unit order (4 passes). Result: no holes in the union for Uco, Cafayate, Maipo, Colchagua and Casablanca when unioned on a 1e-5 grid; Mendoza keeps 2 pinholes of at most about 300 m2. Unioning without a grid can show sub-metre seams; union with `grid_size=1e-5` (or a 1e-6 buffer) when drawing the region outline.
- Area change from simplification is under 2% for every unit (worst: small urban Santiago comunas such as La Granja and La Cisterna) and far smaller for large units.
- Build scripts (not part of the deliverable): `scratchpad/sa_tools/build_sa.py`, `write_csv.py`, `shp.py`.

CSV: `wr_0029.csv` (52 rows).
