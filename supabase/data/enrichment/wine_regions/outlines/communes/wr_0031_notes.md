# Valle de Casablanca (D.O.) — wr_0031

## Official text
Decreto N° 464 (Ministerio de Agricultura, 14 Dec 1994, D.O. 26 May 1995), "Establece zonificación vitícola y fija normas para su utilización". Consolidated text, LeyChile idNorma 13601, version in force since 2026-07-14 ("Última Versión", latest amendment Decreto 4 of 2026, which amended Art. 3 bis and a later article on dealcoholised and late-harvest wine, not Article 1): https://www.bcn.cl/leychile/navegar?idNorma=13601 (JSON saved as `raw/leychile_13601.json`). Article 1 points 3 and 4 were last replaced by Decreto 56 (D.O. 25.05.2018). Cross-checked against SAG's compiled PDF `raw/sag_decreto_464.pdf` (https://www.sag.gob.cl/sites/default/files/decreto_ndeg_464.pdf, undated, older than the LeyChile version: it lacks the Los Lingues/Apalta/Lo Abarca/Licantén areas), which gives the same definitions for these three regions.

Article 1, point 3: "REGIÓN VITÍCOLA DE ACONCAGUA: Comprende a la V Región Administrativa de Valparaíso, que corresponde para estos efectos a las siguientes Subregiones: Valle del Aconcagua, Valle de Casablanca, Valle de San Antonio ..." and "B) Valle de Casablanca, cuyo límite se extiende a la comuna del mismo nombre." Art. 5 bis repeats: "la Subregión Valle de Casablanca, cuyo límite está definido por la comuna del mismo nombre".

## Units used
Comuna Casablanca (CUT 05102), provincia Valparaíso, Región de Valparaíso. Count: 1. None partial.

## Judgement calls
- Casablanca is a Subregión of the Región Vitícola de Aconcagua, a sibling of Valle del Aconcagua, not a Zona within it as the brief said.
- The comuna polygon has 2 parts: mainland plus a coastal islet under 0.01 km2 from the source; kept.

## Grapes / style
None specific to varieties. Art. 5 bis: wines from the subregion may carry the complementary term "Costa" if at least 85% by volume comes from it and it was declared to SAG.

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

CSV: `wr_0031.csv` (1 rows).
