# Toro DO: production zone

**Source:** Pliego de condiciones DOP "Toro" (PDO-ES-A0886), linked from MAPA (https://www.mapa.gob.es/es/alimentacion/temas/calidad-diferenciada/dop-igp/detalle/vcprd/dop_toro).
PDF: https://www.mapa.gob.es/dam/mapa/contenido/alimentacion/temas/calidad-agroalimentaria/2017-calidad-diferenciada/nuevo_denominaciones/pliegos-de-condiciones/pliego-condiciones-vinos/dops/toro_2025_01_03.pdf . Section 4.2: 12 municipalities in Zamora; in Valladolid San Román de Hornija, Villafranca del Duero "y los pagos de Villaester de Arriba y Villaester de Abajo, del término municipal de Pedrosa del Rey".

## Counts
**14 rows** (Zamora 12, Valladolid 2). Villafranca del Duero -> LAU "Villafranca de Duero" (ES_47204), also in Rueda.

## Held back
- **Pedrosa del Rey (ES_47113)**: only the pagos of Villaester de Arriba and Villaester de Abajo. The pagos are not cadastral polygons, so their share of the 52 km2 municipality could not be measured. Left out.

## Method
Names matched to Eurostat GISCO LAU 2024 by name within the stated province only (the pliego gives no INE codes), accent, article and bilingual-name insensitive; every name resolved to exactly one LAU unit and every GISCO_ID is unique (`tools/match.py`, `tools/build.py`). Raw text in `raw/` (PDF and pypdf extraction). Inclusion rule for partially covered municipalities: kept (partial = yes, with the text's wording) when the covered part is at least about a quarter of the municipality; left out below that or when the share could not be measured. Cadastral shares come from parcel areas in the Catastro INSPIRE WFS (`tools/cad_share.py`, tiles in `raw/cad/`), grouped by polygon of the municipality's own cadastral code; these are measurements, not text.
