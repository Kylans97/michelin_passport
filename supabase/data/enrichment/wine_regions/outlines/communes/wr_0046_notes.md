# Clare Valley (Australian GI) : AU_GI_clare_valley

## Official determination
- "Clare Valley" is a registered Australian Geographical Indication (region), GI number 65, in South Australia; zone: Mount Lofty Ranges zone. Register of Protected GIs and Other Terms, Wine Australia Act 2013: https://wineaustralia.com/labelling/register-of-protected-gis-and-other-terms/geographical-indications.
- Entered in the Register of Protected Names on 25 March 1999 (Wine Australia GI page: https://www.wineaustralia.com/labelling/geographical-indicators/labelling-gi-clare-valley; saved in `raw/gi_pages/`).
- Label rule: Wine Australia Regulations 2018 (F2018L00286), s 26(2), checked in Compilation No. 4 (F2025C00049, compilation date 1 January 2025; https://www.legislation.gov.au/F2018L00286/latest/text): with one Australian GI and no foreign GI or place name, "at least 850ml/L of the wine must have been obtained from grapes grown in the region or locality in Australia in relation to which the GI is registered". Raw: `raw/wa_regs_F2025C00049.pdf`, `raw/wa_regs_2018.pdf` (as made, same wording).

## Boundary dataset
- Wine Australia, "Wine Geographical Indications Australia", ArcGIS Online item 2dd4c385f0ed4d109c2e18ae99e819e2, published on the Wine Australia Open Data Hub (https://wineaustralia-opendata-wineaustralia.hub.arcgis.com/maps/2dd4c385f0ed4d109c2e18ae99e819e2). Service: https://services6.arcgis.com/s8j6JbJJCqmhNgh7/arcgis/rest/services/Wine_Geographical_Indications_Australia/FeatureServer, layer 1 `Wine_GI_Regions` (layers 0 subregions and 2 zones also read).
- Version: item modified 2026-10-05 (DCAT `modified` 2026-10-05T02:38:10Z; layer 1 dataLastEditDate 2026-10-05; feature `EDIT_DATE` 2026-10-05). This is the current item; the older `Wine_Geographical_Indications_Australia_2022v1` service is labelled "(superseded)" in the hub catalogue and was not used.
- Licence: CC BY 4.0 (https://creativecommons.org/licenses/by/4.0). Required attribution, from the item: "Geographical Indications of Australia, © Wine Australia".
- The item says the polygons are "an interpretation of the legal textual description"; "the textual description prevails". The legal textual descriptions themselves were not re-checked against the polygons.
- Fetched 2026-11-20 with a REST query (`where=1=1&outFields=*&outSR=4326&f=geojson`), source CRS EPSG:7844 (GDA2020), reprojected server side to WGS84. Raw files: `raw/regions_all_4326.geojson`, `raw/subregions_all_4326.geojson`, `raw/zone_tas_4326.geojson`, plus `raw/item.json`, `raw/dcat.json`, `raw/layer*.json`, `raw/attrs*.json`.
- Processing: shapely `buffer(0)`, `simplify(0.001 deg, preserve_topology=True)` (about 100 m), coordinates rounded to 5 decimals. Areas below are on a sinusoidal equal area projection.

## Unit
- One feature, unit_id AU_GI_clare_valley, the whole GI polygon (not partial). Dataset area attribute 680 km2; computed from source 680.3 km2; after simplification 680.1 km2; 1 part(s), 137 vertices, valid. Bounds [138.5031, -34.107, 138.762, -33.706].
- Hausdorff distance source to output: 0.001 deg (about 100 m).

## Judgement calls
- Grape order: Riesling first on 2026 crush (4,662 t; the survey says "Riesling retained its position as the largest variety") and as listed by Wine Australia and Halliday, although Shiraz leads on vineyard area (1,902 ha against 1,072). Source: https://riverlandwine.com.au/content/uploads/2026/08/sa_full_report_2026.pdf.
- red_body null: Shiraz "medium- to full-bodied" is Halliday only; Wine Australia's "full-flavoured" describes flavour, not body.
- Pairing: Halliday's Riesling pairing page lists Clare Rieslings with ceviche with chilli and lime and a red curry of kingfish; Matching Food & Wine names raw and lightly cooked shellfish and Asian food for Clare and Eden Valley Riesling.
- Style rule applied: every claim in summary, body scores, pairing and grape notes has two independent sources. Wine Australia's wineaustralia.com, australianwine.com and its SA Winegrape Crush Survey count as one organisation. Quotes were gathered by research subagents through WebFetch's summariser and were not checked character by character against raw HTML. Wine-Searcher, Britannica, Jancis Robinson, GuildSomm and Decanter could not be fetched (403, paywall or truncated) and are not used.
- Score mapping: low 1 to 2, medium 3, high 4 to 5. Null where fewer than two sources characterise the main red, or where sources conflict.

## Held back
- red_tannin and red_acidity: sourced only for Cabernet Sauvignon, not the main red.
- Limestone soils (Watervale): Wine Australia only, left out of the summary.
- Ageing of Riesling for decades: Wine Australia only.
- Districts (Auburn, Watervale, Sevenhill, Polish Hill River, Clare): unofficial, not shown as appellations.
- Malbec in Cabernet blends: one source; not listed.
