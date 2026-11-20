# wr_0006 — DOCa Rioja: production zone municipalities

**Source:** Pliego de condiciones de la Denominación de Origen Protegida (Denominación de Origen Calificada) "Rioja" — MAPA, version "en vigor" linked from https://www.mapa.gob.es/es/alimentacion/temas/calidad-diferenciada/dop-igp/htm/dop_rioja
PDF: https://www.mapa.gob.es/dam/mapa/contenido/alimentacion/temas/calidad-agroalimentaria/2017-calidad-diferenciada/nuevo_denominaciones/htm/pliego-de-condiciones-doca-rioja.pdf
**Document date:** header "Última modificación: Resolución de 7 de octubre de 2026 de la DGA, BOE de 19 de octubre de 2026". Downloaded 2026-11-20. Zone list is section 4 "Delimitación de la zona geográfica" (pp. 10–12).

## Counts
- Document: 144 named entries (Rioja Alta 76 La Rioja; Rioja Oriental 42 La Rioja + 8 Navarra; Rioja Alavesa 18 Álava) — this matches the document's own statement in section 7 (144 términos municipales: 118 La Rioja, 18 Álava, 8 Navarra). Plus one Burgos enclave ("Provincia de Burgos (Miranda de Ebro) El Ternero (enclave)") not counted in the 144.
- Matched: **141 rows** in wr_0006.csv = 140 of the 144 entries + Miranda de Ebro (El Ternero enclave). 117 La Rioja, 15 Álava, 8 Navarra, 1 Burgos. Every GISCO_ID unique.
- Held back: 4 of the 144 entries, plus Lodosa (see below).

Not all 144 entries are municipalities: several are villages inside a municipality. The geographic union is unaffected where the parent municipality is already matched, but the parents were not confirmed from the official text, so these are held back rather than mapped.

## Partial
- **Miranda de Ebro (ES_09219)** — only the El Ternero enclave is in the zone. Drawing the whole LAU polygon greatly overstates it; consider excluding or replacing with the enclave geometry.
- **Santa Engracia del Jubera (ES_26135)** — document: "Santa Engracia de Jubera (Zona Norte)".
- **Ocón (ES_26108)** — document: "Ocón (La Villa)"; La Villa is a locality of Ocón. "Molinos de Ocón" is listed too (held back below).

## Name matches that needed judgement (all within the correct province, single candidate)
Canillas → Canillas de Río Tuerto; Albelda → Albelda de Iregua; Bergasilla → Bergasillas Bajera; Lagunilla de Jubera → Lagunilla del Jubera; Leza del Río Leza → Leza de Río Leza; Santa Engracia de Jubera → Santa Engracia del Jubera; Elvillar de Álava → Elvillar / Bilar; Cripán → Kripan; Oyón → Oyón-Oion. Article/bilingual/accent-only differences (El Redal → Redal, El; Cellórigo → Cellorigo; Baños de Ebro → Baños de Ebro / Mañueta, etc.) were matched automatically.

## Held back
| Entry | Province | Reason |
|---|---|---|
| Molinos de Ocón | La Rioja | No LAU municipality of this name; reads as a locality of Ocón (ES_26108, already included as partial). Parent not confirmed from the official text. |
| Barriobusto | Álava | No LAU municipality; believed to be a concejo of Oyón-Oion (ES_01043, already matched). Not confirmed from the official text. |
| Labraza | Álava | Same — believed to be in Oyón-Oion (ES_01043). Not confirmed. |
| Salinillas de Buradón | Álava | No LAU municipality; believed to be in Labastida / Bastida (ES_01028, already matched). Not confirmed. |
| Lodosa | Navarra | Not in the zone list. The pliego only lets right-bank Lodosa vineyards registered by 29 April 1991 keep their registration while they last — a grandfather clause, not a zone inclusion. |

## Method caveat
The PDF table is extracted row-wise across five columns, with some names wrapped over two lines (e.g. "Baños de Río / Tobía", "Aguilar del Río / Alhama", "Aldeanueva de / Ebro", "Cervera del Río / Alhama"). The list was transcribed by hand from that text and checked against the document's own totals (76 + 42 = 118 La Rioja, 18 Álava, 8 Navarra). It was not checked against a rendered page image.
