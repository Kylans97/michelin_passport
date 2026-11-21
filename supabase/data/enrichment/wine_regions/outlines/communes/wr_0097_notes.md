# Jerez-Xérès-Sherry DO (and Manzanilla-Sanlúcar de Barrameda DO): production zone

**Source:** Pliego de condiciones DOP "Jerez-Xérès-Sherry", consolidated per Orden de 13 de mayo de 2026 (BOJA 95, 20/05/2026), linked from MAPA (https://www.mapa.gob.es/es/alimentacion/temas/calidad-diferenciada/dop-igp/detalle/vcprd/dop_jerez).
PDF: https://www.mapa.gob.es/dam/mapa/contenido/alimentacion/temas/calidad-agroalimentaria/2017-calidad-diferenciada/nuevo_denominaciones/pliegos-de-condiciones/pliego-condiciones-vinos/dops/jerez_2026_08_26.pdf . Section D.1 "Zona Delimitada": the términos municipales of Jerez de la Frontera, El Puerto de Santa María, Sanlúcar de Barrameda, Trebujena, Chipiona, Rota, Puerto Real, Chiclana de la Frontera, Lebrija and San José del Valle, "situados dentro del área delimitada al Este por el meridiano de Greenwich 5° 49´ Oeste y al Norte por el paralelo 36° 58´ Norte".

**Manzanilla-Sanlúcar de Barrameda** (pliego https://www.mapa.gob.es/dam/mapa/contenido/alimentacion/temas/calidad-agroalimentaria/2017-calidad-diferenciada/nuevo_denominaciones/pliegos-de-condiciones/pliego-condiciones-vinos/dops/manzanilla_san_lucar_2026_05_27.pdf, section D.1) has the identical production zone (same ten municipalities, same meridian and parallel); its ageing zone (D.4) is the municipality of Sanlúcar de Barrameda only. No separate CSV: its production polygon would duplicate Jerez's. It is listed as an appellation in style.json; if a polygon is wanted, Sanlúcar de Barrameda is ES_11032.

## Counts
10 municipalities in the text; **9 rows** (Cádiz 8, Sevilla 1).

## Partial (kept)
The box was intersected with each LAU polygon (`tools/jerez_box.py`, planar share in degrees, adequate for a share):
- Jerez de la Frontera (ES_11020): 81.9% inside.
- Lebrija (ES_41053, Sevilla): 69.9% inside.
The other seven are 100% inside.

## Held back
- **San José del Valle (ES_11902)**: only 21.1% of the municipality lies west of 5° 49' W; below the quarter threshold, so left out. Include it (partial) if the threshold is meant to be lower.

## Method
Names matched to Eurostat GISCO LAU 2024 by name within the stated province only (the pliego gives no INE codes), accent, article and bilingual-name insensitive; every name resolved to exactly one LAU unit and every GISCO_ID is unique (`tools/match.py`, `tools/build.py`). Raw text in `raw/` (PDF and pypdf extraction). Inclusion rule for partially covered municipalities: kept (partial = yes, with the text's wording) when the covered part is at least about a quarter of the municipality; left out below that or when the share could not be measured. Cadastral shares come from parcel areas in the Catastro INSPIRE WFS (`tools/cad_share.py`, tiles in `raw/cad/`), grouped by polygon of the municipality's own cadastral code; these are measurements, not text.
