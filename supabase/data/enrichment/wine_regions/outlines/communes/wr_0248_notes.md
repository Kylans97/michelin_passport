# San Juan (I.G.): san-juan

## Official text
INV Resolución N° C.32/2002 (Mendoza, 14 Nov 2002), https://www.argentina.gob.ar/sites/default/files/resolucionnc32-02.pdf, Art. 3 and Anexo I ("Areas geográficas de las I.P. e I.G. de la República Argentina"): row 51 "SAN JUAN | SAN JUAN", followed by 18 departamento I.G.s and row 68 "VALLE DEL TULUM". INV register "Indicaciones geográficas y denominaciones de origen reconocidas y protegidas de la República Argentina" (18 Apr 2024 edition, https://www.argentina.gob.ar/sites/default/files/i.g._y_d.o.c._de_la_republica_argentina18_de_abril_2024.pdf; text in `americas/sa/work/ig_list_2024.txt`): "San Juan | I.G. | San Juan | Resolución INV Nº C.32/2002".

## Units used
All 19 departamentos of the province of San Juan: Albardón (70007); Angaco (70014); Calingasta (70021); Capital (70028); Caucete (70035); Chimbas (70042); Iglesia (70049); Jáchal (70056); 9 de Julio (70063); Pocito (70070); Rawson (70077); Rivadavia (70084); San Martín (70091); Santa Lucía (70098); Sarmiento (70105); Ullum (70112); Valle Fértil (70119); 25 de Mayo (70126); Zonda (70133). Count: 19. None partial.

## Judgement calls
- Province reading as for Mendoza.
- Valle del Tulum (I.G., C.32/2002 row 68; register "Valle del Tulum | I.G. | San Juan ... Tulum Valley") is HELD BACK: no official text found lists its departamentos or gives a line.
- Valle del Pedernal (I.G., INV Resolución C.21/2007, register "Sarmiento, San Juan") is HELD BACK: the resolution text was not found online (searched argentina.gob.ar, boletinoficial, INV), so its boundary is unknown; drawing departamento Sarmiento would badly overstate a single valley, and a point needs at least the official text to place it.

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

CSV: `san-juan.csv` (19 rows).
