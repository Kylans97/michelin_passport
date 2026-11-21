# Bierzo DO: production zone

**Source:** Pliego de condiciones DOP "Bierzo" (PDO-ES-A0615), linked from MAPA (https://www.mapa.gob.es/es/alimentacion/temas/calidad-diferenciada/dop-igp/detalle/vcprd/dop_bierzo).
PDF: https://www.mapa.gob.es/dam/mapa/contenido/alimentacion/temas/calidad-agroalimentaria/2017-calidad-diferenciada/nuevo_denominaciones/pliegos-de-condiciones/pliego-condiciones-vinos/dops/bierzo_2021_07_23.pdf . Section 4.1: 31 municipalities, all province of León; section 7 repeats "un total de 31 municipios".

## Counts
**31 rows**, all whole.
Name judgement: "Toral de los Vados-Villadecanes" = LAU "Toral de los Vados" (ES_24206), the only candidate; the municipality is also known as Villadecanes and the pliego joins both names. The count of 31 confirms it is one entry.

## Held back
None. Sub-units (Vino de Villa, Vino de Paraje, Viña Clasificada, Gran Viña Clasificada) are label mentions with lists in the pliego; not mapped.

## Method
Names matched to Eurostat GISCO LAU 2024 by name within the stated province only (the pliego gives no INE codes), accent, article and bilingual-name insensitive; every name resolved to exactly one LAU unit and every GISCO_ID is unique (`tools/match.py`, `tools/build.py`). Raw text in `raw/` (PDF and pypdf extraction). Inclusion rule for partially covered municipalities: kept (partial = yes, with the text's wording) when the covered part is at least about a quarter of the municipality; left out below that or when the share could not be measured. Cadastral shares come from parcel areas in the Catastro INSPIRE WFS (`tools/cad_share.py`, tiles in `raw/cad/`), grouped by polygon of the municipality's own cadastral code; these are measurements, not text.
