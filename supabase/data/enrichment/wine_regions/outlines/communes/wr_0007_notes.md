# wr_0007 — DO Ribera del Duero: production zone municipalities

**Source:** Pliego de condiciones de la DOP «Ribera del Duero» (PDO-ES-A0626), consolidated through revision 5 (modificación normal of 14/09/2022, ITACyL decision 31/03/2023, file PDO-ES-A0626-AM06, in force 31/07/2023). Copy hosted by MAPA:
https://www.mapa.gob.es/es/alimentacion/temas/calidad-diferenciada/ribera_del_duero_2023_07_31_tcm30-210154.pdf
Downloaded 2026-11-20. Zone list is section 4 "Delimitación del área geográfica" (pp. 14–17). The geographic area was last revised in revision 3 (AM04, 2019); AM05 and AM06 did not touch it. A search found no later revision (2024–2026), but the ITACyL / eAmbrosia registers were **not** checked directly. The Consejo Regulador's older "consolidado enero 2018" copy predates the AM04 boundary revision and was not used.

## Counts
- The document defines the zone by **unidades poblacionales** (INE population units) and gives each one's INE province + municipality + unit code: 118 units (Burgos 64, Segovia 5, Soria 25, Valladolid 24) across **82 municipalities** (Burgos 53, Segovia 4, Soria 6, Valladolid 19).
- Matched: **82 of 82** (wr_0007.csv). GISCO_ID = "ES_" + the INE codes printed in the document, each cross-checked against the LAU name (all agree, allowing for article/punctuation differences).
- Held back: **none**.

## Partial
- **Burgo de Osma-Ciudad de Osma (ES_42043)** — definitely partial. Only the entidad local menor Alcubilla del Marqués is in the zone, per the document's legend: "Únicamente pertenece a la zona de producción amparada la entidad local menor que se cita".
- **13 municipalities marked `possible`** — the document lists their head unit plus specific pedanías, and the zone is "los terrenos ubicados en las unidades poblacionales" listed. Gaps in several unit-code sequences suggest some units are not listed (e.g. San Esteban de Gormaz, Aranda de Duero, Pedrosa de Duero, Langa de Duero, Alcubilla de Avellaneda). Whether each list is complete was not verified against the INE Nomenclátor. The 13: Aranda de Duero, Pedrosa de Duero, Peñaranda de Duero, Sotillo de la Ribera, Tórtoles de Esgueva, La Vid y Barrios, Villaverde de Montejo, Alcubilla de Avellaneda, Langa de Duero, San Esteban de Gormaz, Peñafiel, Torre de Peñafiel, Valbuena de Duero. The listed units are in each row's `partial` field.
- The other 68 municipalities have a single listed unit, the document's "Municipios que no tienen pedanías", and are marked `no`.

## Held back
None.
