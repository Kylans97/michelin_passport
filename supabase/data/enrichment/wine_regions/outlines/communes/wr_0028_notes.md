# Cafayate - Valle de Cafayate (I.G.), Salta — wr_0028

## Official texts
- INV Resolución N° C.32/2002, Anexo I row 48: CAFAYATE listed as an I.G. under the province SALTA, alongside the departamentos Cachi, Molinos and San Carlos (and SALTA itself as a province-level I.G., row 46).
- INV Resolución N° C.15/2004 (18 May 2004), https://www.argentina.gob.ar/sites/default/files/resolucionc15-2004.pdf (scan; read by OCR): the request came from "los Productores Vitícolas y Vitivinícolas del Departamento Cafayate"; "los límites del área geográfica definida para la Indicación Geográfica (I.G.) solicitada 'VALLE DE CAFAYATE', son idénticos a los del área geográfica considerada para el reconocimiento de la Indicación Geográfica (I.G.) CAFAYATE"; Art. 1: "Considérase la expresión 'VALLE DE CAFAYATE', como sinónimo de CAFAYATE."
- INV register: "Cafayate - Valle de Cafayate | I.G. | Salta | ... Disposición INV Nº 08/2005, por la cual sólo se autoriza el uso de la expresión Valle de Cafayate, dado que Cafayate es una marca registrada en la Argentina." (Disposición 08/2005 itself not read; quoted from the register.)
- Valles Calchaquíes: INV Resolución C.37/2002 (I.G., no boundary); Resolución C.16/2010 (https://www.argentina.gob.ar/sites/default/files/resolucionc16-2010.pdf, OCR) makes "Valle Calchaquí" a synonym and describes it as "un área interprovincial"; Padrón C.23/1999 footnote "(**) Valles que incluyen localidades de diferentes provincias y que constituyen una misma área vitícola"; INV register: same wording, no departamentos.

## Units used
Departamento Cafayate (66021), Salta. Count: 1. None partial.

## Recommendation (Cafayate vs Valles Calchaquíes) — for the caller to decide
Use the I.G. Cafayate / Valle de Cafayate (label "Valle de Cafayate", the only form INV authorises on labels). It is the only one of the two that an official text ties to an administrative unit (the Cafayate departamento, per C.32/2002 Anexo I and C.15/2004). Valles Calchaquíes is a recognised I.G. but every official text found describes it only as an interprovincial set of valleys "que incluyen localidades de diferentes provincias" with no list of departamentos or localities; drawing it would mean choosing departamentos (Cafayate, San Carlos, Molinos, Cachi, La Poma in Salta; possibly Santa María in Catamarca and Tafí del Valle in Tucumán) ourselves, which is inventing a boundary. Its shape is therefore held back. A third option, the province-level I.G. "Salta" (C.32/2002 row 46), is drawable (all 23 departamentos) but is mostly non-viticultural; not built, available on request (the Salta departamentos are already in the raw download).

## Judgement calls
- Read the I.G. Cafayate as the departamento Cafayate: the C.32 Anexo I lists it among Salta's departamentos, the INV register's column is "Departamento y Provincia", and C.15/2004 names the "Departamento Cafayate" producers as applicants and says the area is identical. No text spells out "departamento Cafayate" as the boundary in one sentence.
- The region record is named "Salta / Cafayate": the drawn area is Cafayate only.

## Grapes / style
None specific to Cafayate in these texts (national I.G. variety list of C.32/2002 applies; Torrontés Riojano is on it but not tied to the area).

## Held back
- Valles Calchaquíes / Valle Calchaquí (I.G., C.37/2002, C.16/2010): no official administrative-unit definition found; not drawn.

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

CSV: `wr_0028.csv` (1 rows).
