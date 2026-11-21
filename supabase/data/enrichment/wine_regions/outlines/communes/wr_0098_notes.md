# Penedès DO: production zone

**Source:** Pliego de condiciones DOP Penedès ("Versión noviembre 2024", PDO-ES-A1551), linked from MAPA (https://www.mapa.gob.es/es/alimentacion/temas/calidad-diferenciada/dop-igp/detalle/vcprd/dop_penedes).
PDF: https://www.mapa.gob.es/dam/mapa/contenido/alimentacion/temas/calidad-agroalimentaria/2017-calidad-diferenciada/nuevo_denominaciones/pliegos-de-condiciones/pliego-condiciones-vinos/dops/penedes_2026_02_20.pdf . Section 4.1: municipalities marked (1) Barcelona or (2) Tarragona.

## Counts
61 municipalities, **61 rows**, all whole (Barcelona 47, Tarragona 14).
Name judgement: "Cabrera d'Igualada" = LAU "Cabrera d'Anoia" (ES_08028): the municipality was renamed from Cabrera d'Igualada to Cabrera d'Anoia in 2007 (DOGC 4814, cited by en.wikipedia; Gran Enciclopèdia Catalana lists Cabrera d'Igualada as a former name). The pliego keeps the old name. "Montmell" = "Montmell, El".

## Held back
None.

## Sub-units (4.2, no geometry here)
Ten unidades geográficas menores (Alts d'Ancosa, Conca del Foix, Costers de l'Anoia, Costers de Lavernó, Costers del Montmell, Marina del Garraf, Massís del Garraf, Muntanyes d'Ordal, Turons de Vilafrana [sic], Vall Bitlles-Anoia), parcel lists on INCAVI. Cava is a separate, multi-region DO and is not a region here.

## Method
Names matched to Eurostat GISCO LAU 2024 by name within the stated province only (the pliego gives no INE codes), accent, article and bilingual-name insensitive; every name resolved to exactly one LAU unit and every GISCO_ID is unique (`tools/match.py`, `tools/build.py`). Raw text in `raw/` (PDF and pypdf extraction). Inclusion rule for partially covered municipalities: kept (partial = yes, with the text's wording) when the covered part is at least about a quarter of the municipality; left out below that or when the share could not be measured. Cadastral shares come from parcel areas in the Catastro INSPIRE WFS (`tools/cad_share.py`, tiles in `raw/cad/`), grouped by polygon of the municipality's own cadastral code; these are measurements, not text.
