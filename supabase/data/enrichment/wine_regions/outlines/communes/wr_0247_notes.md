# General Roca (I.G.): general-roca

## Official text
INV Resolución N° C.32/2002 (Mendoza, 14 Nov 2002), https://www.argentina.gob.ar/sites/default/files/resolucionnc32-02.pdf, Art. 3 and Anexo I ("Areas geográficas de las I.P. e I.G. de la República Argentina"): row 42 "GENERAL ROCA", a departamento I.G. listed under the province RIO NEGRO (row 41). INV register "Indicaciones geográficas y denominaciones de origen reconocidas y protegidas de la República Argentina" (18 Apr 2024 edition, https://www.argentina.gob.ar/sites/default/files/i.g._y_d.o.c._de_la_republica_argentina18_de_abril_2024.pdf; text in `americas/sa/work/ig_list_2024.txt`): "General Roca | I.G. | Río Negro | Resolución INV Nº C.32/2002". The padrón C.23/1999 (OCR) lists the localities Allen, Cipolletti, Ingeniero Huergo and Villa Regina under GENERAL ROCA.

## Units used
Departamento General Roca, Río Negro: General Roca (62042). Count: 1. None partial.

## Judgement calls
- Decided by the coordinator (2026-11-21): use the narrower official I.G. General Roca instead of the provincial I.G. Río Negro. INV puts 1,082.5 of 1,549.2 ha (70%) of Río Negro's vineyard in General Roca (INV provincial report, https://www.argentina.gob.ar/sites/default/files/2018/10/rio_negro_2023.pdf).
- Departamento reading as for Añelo. The departamento runs north to the Río Colorado, well beyond the irrigated valley.
- "Alto Valle" is NOT used as an alias: the I.G. Alto Valle de Río Negro (C.37/2002) has no official boundary, and the one source that links the names (Wines of Argentina: vineyards "in Alto Valle de Río Negro in places such as General Roca, Fernández Oro, Mainqué") places General Roca inside the Alto Valle rather than equating them. Listed as an appellation only.
- Grape order in style.json comes from the provincial INV 2024 figures (70% of the vineyard is here); not departamento figures.

## Grapes / style
See `style.json` (sources per field) and the research logs in `work/` (style_cl_north_log.md, style_cl_south_log.md, style_ar_br_log.md).

## Boundary dataset
- Instituto Geográfico Nacional (IGN), WFS layer `ign:departamento` ("División político administrativa de segundo orden"), https://wms.ign.gob.ar/geoserver/ows, requested 2026-11-21 as GeoJSON in EPSG:4326 with `CQL_FILTER=in1 LIKE '58%' OR in1 LIKE '62%' OR in1 LIKE '70%'` (Neuquén, Río Negro, San Juan; 48 departamentos). Saved: `raw/ar_ign/departamento_nqn_rn_sj.geojson`.
- Unit code: `in1` (5-digit departamento code). `fdc` records the provincial source (Neuquén: Dirección Provincial de Catastro e Información Territorial; Río Negro: IDE Río Negro; San Juan: Dirección de Catastro).
- Version: the service publishes no edition date; the download date is the version recorded.
- Licence: the WFS AccessConstraints (checked by the earlier session, `americas/sa/raw/ar_ign/wfs_caps.xml`) allow free search, copying, reprocessing, reuse and redistribution under Article 2 of Ley 27.275.

## Geometry
- Combined file: `sa_units.geojson` (91 units for the eleven regions, EPSG:4326, properties exactly `unit_id`, `name`, `source`).
- Douglas-Peucker at 0.0009 degrees (about 100 m), coordinates snapped to a 1e-5 degree grid. Slivers opened between neighbours by independent simplification were filled within each region's unit set (interior holes of the union given to the neighbour with the longest shared edge, overlaps removed in unit order, 5 passes). Union for this region: 1 part(s), 0 interior hole(s).
- Area change from simplification is under 1.2% for every unit (worst: the Altos de Pinto Bandeira polygon, then the small urban San Juan departamentos Santa Lucía, Capital and Chimbas).
- Union with `grid_size=1e-5` (or a 1e-6 buffer) when drawing the region outline.
- Build scripts (not part of the deliverable): `scratchpad/sa7_tools/build.py`, `write_out.py`, `write_notes.py`.

CSV: `general-roca.csv` (1 rows).
