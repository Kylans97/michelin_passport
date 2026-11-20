# Mendoza (I.G.) — wr_0026

## Official text
- INV Resolución N° C.32/2002 (Mendoza, 14 Nov 2002), https://www.argentina.gob.ar/sites/default/files/resolucionnc32-02.pdf. Art. 3: "Reconócense incluidos en la categoría a que alude el Artículo 4° de la Ley N° 25.163 'Indicación Geográfica' (I.G.), a los productos originarios de las áreas geográficas que se detallan en el Anexo I". Anexo I row 21: MENDOZA appears in both the "Indicación Procedencia" and the "Indicación Geográfica" column, at province level, followed by the departamentos (General Alvear ... Tupungato) as separate IGs.
- INV register "Indicaciones geográficas y denominaciones de origen reconocidas y protegidas de la República Argentina" (argentina.gob.ar; current file last-modified 2022-04-11, and the 18 Apr 2024 edition): "Mendoza | I.G. | Mendoza | Resolución INV Nº C.32/2002".
- Padrón básico, Resolución C.23/1999 (scanned; read by OCR), lists MENDOZA as the province heading with its departamentos and localities underneath.

## Units used
All 18 departamentos of the province of Mendoza (the I.G. is named and listed at province level; no text narrows it to wine departamentos): Capital, General Alvear, Godoy Cruz, Guaymallén, Junín, La Paz, Las Heras, Lavalle, Luján de Cuyo, Maipú, Malargüe, Rivadavia, San Carlos, San Martín, San Rafael, Santa Rosa, Tunuyán, Tupungato. Count: 18. None partial.

## Judgement calls
- Read "Mendoza" in C.32 Anexo I as the whole province: it is the province row (the same name in the I.P. column, which Art. 1 defines as "vinos de mesa elaborados en las provincias de ... Mendoza"), and each departamento has its own separate I.G. row. The INV text never lists departamentos for the I.G. Mendoza explicitly; the province reading is the only one the text supports. It includes Malargüe and the non-viticultural east and south.
- Drawn as the 18 departamentos rather than one province polygon, to share units with Uco (wr_0027).

## Grapes / style
C.32/2002 Art. 4 gives a national list of varieties allowed for any I.G. wine (reds incl. Malbec, Merlot, Cabernet Sauvignon, Syrah, Pinot Negro, Bonarda, Tempranillo...; whites incl. Chardonnay, Torrontés Riojano, Sauvignon...), extended by later resolutions, plus a minimum of 130 kg grapes per 100 L. Nothing specific to Mendoza.

## Held back
None.

## Boundary dataset
- Instituto Geográfico Nacional (IGN), WFS layer `ign:departamento` ("División político administrativa de segundo orden"), https://wms.ign.gob.ar/geoserver/ows, requested 2026-11-20 as GeoJSON in EPSG:4326 with `CQL_FILTER=in1 LIKE '50%' OR in1 LIKE '66%'` (Mendoza and Salta). Saved: `raw/ar_ign/departamento_mendoza_salta.geojson`.
- Unit code: `in1` (INDEC-style 5-digit departamento code, e.g. 50119 Tunuyán); `fdc` records the provincial source (Oficina Provincial de Mendoza; Dirección General de Inmuebles de Salta).
- Version: the service publishes no edition date for the layer; the date of download is the version recorded.
- Licence: the WFS AccessConstraints state the data may be freely searched, copied, reprocessed, reused and redistributed under Article 2 of Ley 27.275 (access to public information).

## Geometry
- Combined file: `sa_units.geojson` (88 units in total for the six regions, EPSG:4326, properties exactly `unit_id`, `name`, `source`).
- Simplified with Douglas-Peucker at 0.0009 degrees (about 100 m), coordinates snapped to a 1e-5 degree grid (about 1 m). Independent simplification opened thin slivers (up to about 60 m wide) between neighbouring units, so within each region set (Uco, Mendoza, Maipo, Colchagua) every interior hole of the union was given to the neighbour sharing the longest edge with it, and overlaps were removed in unit order (4 passes). Result: no holes in the union for Uco, Cafayate, Maipo, Colchagua and Casablanca when unioned on a 1e-5 grid; Mendoza keeps 2 pinholes of at most about 300 m2. Unioning without a grid can show sub-metre seams; union with `grid_size=1e-5` (or a 1e-6 buffer) when drawing the region outline.
- Area change from simplification is under 2% for every unit (worst: small urban Santiago comunas such as La Granja and La Cisterna) and far smaller for large units.
- Build scripts (not part of the deliverable): `scratchpad/sa_tools/build_sa.py`, `write_csv.py`, `shp.py`.

CSV: `wr_0026.csv` (18 rows).
