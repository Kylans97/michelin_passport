# Cava DOP (multi-region, not a contiguous area): production zone

**Source:** https://www.mapa.gob.es/es/alimentacion/temas/calidad-diferenciada/pliegodecondicionesdopcava_tcm30-564756.pdf

Pliego DOP Cava, last modified by Resolution of 9 January 2026 (BOE 20 January 2026), on MAPA. Section 4 lists 157 términos municipales in Barcelona, Girona, Lleida, Tarragona, Álava, La Rioja, Navarra, Zaragoza, Badajoz and Valencia, grouped into four Zonas. This is the Cava production area, not a place: drawn it is a scatter of municipalities from Girona to Badajoz. Mark it clearly in the UI. Name judgements (sole candidates in each province): Cabrera d'Igualada = Cabrera d'Anoia, Mongat = Montgat, Els Hostelets de Pierola = Els Hostalets de Pierola, Sant Pere de Riudevitlles = Riudebitlles, Mollet de Perelada / Perelada = Peralada spellings, L'Espluga Calva = Calba, Vespella = Vespella de Gaià, Vilaseca de Solcina = Vila-seca (former name), Vilaberd = Vilaverd, Vimbodí = Vimbodí i Poblet, Oyón = Oyón-Oion. Most Penedès municipalities are in both this area and the existing Penedès region, and Penedès already carries a wine-list name 'Cava'.

## Counts
**157 rows**, 0 partial.

## Held back
None. Parajes Calificados (14, all in Catalonia) are listed as appellations, not drawn.

## Method
Names matched to Eurostat GISCO LAU 2024 by name within the stated province only (the pliego gives no INE codes), accent, article and bilingual-name insensitive, using `classics/es/tools/match.py`; spellings that differ from the LAU name were resolved by hand to the sole candidate in the province (aliases in `tools/build.py`). Every name resolved to exactly one LAU unit and every GISCO_ID is unique. Raw text in `raw/`. Partial municipalities are kept and flagged partial = yes when the text names an administrative or cadastral unit (parish, concejo, cadastral polygon); municipalities where the text names only individual villages, places or a pago are held back, because the whole municipality would overstate the area badly. Unlike the classics round, no cadastral share was measured, so a partial row can overstate the area considerably.
