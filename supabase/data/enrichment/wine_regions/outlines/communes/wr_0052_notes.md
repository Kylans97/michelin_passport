# Tasmania (Australian GI) : AU_GI_tasmania

## Official determination
- "Tasmania" is a registered Australian Geographical Indication (state), GI number 33, in Tasmania; zone: State GI (within the South Eastern Australia zone, which covers the whole of NSW, Vic. and Tas.). Register of Protected GIs and Other Terms, Wine Australia Act 2013: https://wineaustralia.com/labelling/register-of-protected-gis-and-other-terms/geographical-indications.
- Entered in the Register of Protected Names on 26 January 1994 (Wine Australia GI page: https://www.wineaustralia.com/labelling/geographical-indicators/labelling-gi-tasmania; saved in `raw/gi_pages/`).
- Label rule: Wine Australia Regulations 2018 (F2018L00286), s 26(2), checked in Compilation No. 4 (F2025C00049, compilation date 1 January 2025; https://www.legislation.gov.au/F2018L00286/latest/text): with one Australian GI and no foreign GI or place name, "at least 850ml/L of the wine must have been obtained from grapes grown in the region or locality in Australia in relation to which the GI is registered". Raw: `raw/wa_regs_F2025C00049.pdf`, `raw/wa_regs_2018.pdf` (as made, same wording).

## Boundary dataset
- Wine Australia, "Wine Geographical Indications Australia", ArcGIS Online item 2dd4c385f0ed4d109c2e18ae99e819e2, published on the Wine Australia Open Data Hub (https://wineaustralia-opendata-wineaustralia.hub.arcgis.com/maps/2dd4c385f0ed4d109c2e18ae99e819e2). Service: https://services6.arcgis.com/s8j6JbJJCqmhNgh7/arcgis/rest/services/Wine_Geographical_Indications_Australia/FeatureServer, layer 1 `Wine_GI_Regions` (layers 0 subregions and 2 zones also read).
- Version: item modified 2026-10-05 (DCAT `modified` 2026-10-05T02:38:10Z; layer 1 dataLastEditDate 2026-10-05; feature `EDIT_DATE` 2026-10-05). This is the current item; the older `Wine_Geographical_Indications_Australia_2022v1` service is labelled "(superseded)" in the hub catalogue and was not used.
- Licence: CC BY 4.0 (https://creativecommons.org/licenses/by/4.0). Required attribution, from the item: "Geographical Indications of Australia, © Wine Australia".
- The item says the polygons are "an interpretation of the legal textual description"; "the textual description prevails". The legal textual descriptions themselves were not re-checked against the polygons.
- Fetched 2026-11-20 with a REST query (`where=1=1&outFields=*&outSR=4326&f=geojson`), source CRS EPSG:7844 (GDA2020), reprojected server side to WGS84. Raw files: `raw/regions_all_4326.geojson`, `raw/subregions_all_4326.geojson`, `raw/zone_tas_4326.geojson`, plus `raw/item.json`, `raw/dcat.json`, `raw/layer*.json`, `raw/attrs*.json`.
- Processing: shapely `buffer(0)`, `simplify(0.001 deg, preserve_topology=True)` (about 100 m), coordinates rounded to 5 decimals. Areas below are on a sinusoidal equal area projection.

## Unit
- One feature, unit_id AU_GI_tasmania, the whole GI polygon (not partial). Dataset area attribute 68582 km2; computed from source 68479.2 km2; after simplification 68467.9 km2; 44 part(s), 8466 vertices, valid. Bounds [143.8333, -43.6583, 148.4819, -39.2071].

## Judgement calls
- Tasmania is a State GI with no regions or subregions. The dataset carries it in both the Regions and the Zone layers; the two polygons are identical (symmetric difference 2e-9 of the area). The Regions layer feature (GI_NUMBER 33) is used.
- Geometry: the source has 5,887 parts (the main island, King Island, the Furneaux Group and many islets). After 100 m simplification, the 44 parts of at least 1 km2 are kept and 5,701 smaller islets (22.8 km2 in all, 0.03% of the area) are dropped. 8,466 vertices remain. Macquarie Island is not in the dataset polygon.
- Grape order: Pinot Noir then Chardonnay (Wine Australia; Halliday: Pinot Noir nearly half and the two together about three quarters of production). Pinot Gris third as listed by Wine Australia; places three to five are not firmly sourced, so Sauvignon Blanc and Riesling are left out.
- red_body 2: Pinot Noir "light to medium-bodied, delicate" (Wine Australia), "delicate palate" (Halliday).
- "Coolest" is sourced to Wine Australia (lowest mean January temperature of Australia's wine regions), Wine Tasmania and Halliday; "most southerly" to Wine Tasmania and the official polygon.
- Style rule applied: every claim in summary, body scores, pairing and grape notes has two independent sources. Wine Australia's wineaustralia.com, australianwine.com and its SA Winegrape Crush Survey count as one organisation. Quotes were gathered by research subagents through WebFetch's summariser and were not checked character by character against raw HTML. Wine-Searcher, Britannica, Jancis Robinson, GuildSomm and Decanter could not be fetched (403, paywall or truncated) and are not used.
- Score mapping: low 1 to 2, medium 3, high 4 to 5. Null where fewer than two sources characterise the main red, or where sources conflict.

## Held back
- red_acidity and red_tannin: The Buyer only.
- pairing: not sourced.
- Meunier in sparkling: Wine Tasmania only.
- The seven growing areas (Tamar Valley, Pipers River, East Coast, Coal River Valley, Derwent Valley, Huon/Southern, North West): informal, not GIs.
- Riesling and Sauvignon Blanc: present but their rank is unverified.
