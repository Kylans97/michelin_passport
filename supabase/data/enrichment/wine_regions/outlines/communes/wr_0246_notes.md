# Añelo (I.G.): anelo

## Official text
INV Resolución N° C.32/2002 (Mendoza, 14 Nov 2002), https://www.argentina.gob.ar/sites/default/files/resolucionnc32-02.pdf, Art. 3 and Anexo I ("Areas geográficas de las I.P. e I.G. de la República Argentina"): row 39 "AÑELO", a departamento I.G. listed under the province NEUQUEN (row 38). Art. 3 recognises the areas of Anexo I as I.G.s. INV register "Indicaciones geográficas y denominaciones de origen reconocidas y protegidas de la República Argentina" (18 Apr 2024 edition, https://www.argentina.gob.ar/sites/default/files/i.g._y_d.o.c._de_la_republica_argentina18_de_abril_2024.pdf; text in `americas/sa/work/ig_list_2024.txt`): "Añelo | I.G. | Neuquén | Resolución INV Nº C.32/2002". INV Resolución C.18/2012 (padrón extension, https://www.argentina.gob.ar/sites/default/files/resolucionc18-2012.pdf, OCR in `americas/sa/work/resolucionc18-2012.ocr.txt`) lists the locality San Patricio del Chañar under Añelo.

## Units used
Departamento Añelo, Neuquén: Añelo (58014). Count: 1. None partial.

## Judgement calls
- Decided by the coordinator (2026-11-21): use the narrower official I.G. Añelo instead of the provincial I.G. Neuquén, which would draw the whole province. INV puts 1,620 of 1,792 ha (90.4%) of Neuquén's vineyard in Añelo (INV provincial report 2023, https://www.argentina.gob.ar/sites/default/files/2018/10/neuquen_2023.pdf).
- Read the I.G. Añelo as the departamento Añelo: C.32/2002 lists it among Neuquén's departamentos and the register column is "Departamento y Provincia". No text spells out the boundary in one sentence (same reading as Cafayate in the earlier round).
- Grape order in style.json comes from the provincial INV 2024 figures; with 90% of the vineyard here they stand for Añelo, but they are not departamento figures.
- Patagonia (interprovincial I.G.) and the provincial I.G. Neuquén are listed as appellations, not drawn.

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

CSV: `anelo.csv` (1 rows).
