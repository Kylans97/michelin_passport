# Valle de Uco (I.G.) — wr_0027

## Official text
- INV Resolución N° C.37/2002 (Mendoza, 16 Dec 2002), https://www.argentina.gob.ar/sites/default/files/resolucionnc37-02.pdf. Art. 1: "Reconócense incluidos en la categoría a que alude el Artículo 4° de la Ley N° 25.163 'Indicaciones Geográficas' (I.G.), en idénticas condiciones a las establecidas en la Resolución N° C.32/2002, a los productos originarios de las siguientes áreas geográficas: − Valle de Uco ..." The resolution itself gives no boundary.
- Padrón básico, Resolución C.23/1999 (OCR), row 180 "VALLE DE UCO(*)", with the footnote "(*) Localidades comunes a departamentos colindantes que constituyen una misma área vitícola" (no departamentos named).
- The boundary comes from the INV register (both the 2022 file and the 18 Apr 2024 edition): "Valle de Uco | I.G. | Zona interjurisdiccional integrada por los Departamentos de San Carlos, Tunuyán y Tupungato de la Provincia de Mendoza | Resolución INV Nº C.37/2002. Uco Valley".

## Units used
Departamentos San Carlos (50091), Tunuyán (50119), Tupungato (50126), Mendoza. Count: 3. None partial. This confirms the expected three.

## Judgement calls
- The three-departamento definition is INV's own published wording in its register, not the text of C.37/2002 itself; C.23/1999 only says it is "localities common to neighbouring departamentos". Used the register as the INV's authoritative statement of the area; recorded here so it can be re-checked if a resolution with a narrower area turns up.
- Smaller I.G.s inside (Tupungato/Valle de Tupungato, Tunuyán, San Carlos, Los Chacayes, Paraje Altamira, La Consulta, Vista Flores, San Pablo, Pampa El Cepillo) are not part of this task.

## Grapes / style
None specific; C.37/2002 applies the conditions of C.32/2002 (national variety list, 130 kg/100 L).

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

CSV: `wr_0027.csv` (3 rows).
