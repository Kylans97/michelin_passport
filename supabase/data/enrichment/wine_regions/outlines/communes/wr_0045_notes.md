# McLaren Vale (Australian GI) : AU_GI_mclaren_vale

## Official determination
- "McLaren Vale" is a registered Australian Geographical Indication (region), GI number 51, in South Australia; zone: Fleurieu zone. Register of Protected GIs and Other Terms, Wine Australia Act 2013: https://wineaustralia.com/labelling/register-of-protected-gis-and-other-terms/geographical-indications.
- Entered in the Register of Protected Names on 2 September 1997 (Wine Australia GI page: https://www.wineaustralia.com/labelling/geographical-indicators/labelling-gi-mclaren-vale; saved in `raw/gi_pages/`).
- Label rule: Wine Australia Regulations 2018 (F2018L00286), s 26(2), checked in Compilation No. 4 (F2025C00049, compilation date 1 January 2025; https://www.legislation.gov.au/F2018L00286/latest/text): with one Australian GI and no foreign GI or place name, "at least 850ml/L of the wine must have been obtained from grapes grown in the region or locality in Australia in relation to which the GI is registered". Raw: `raw/wa_regs_F2025C00049.pdf`, `raw/wa_regs_2018.pdf` (as made, same wording).

## Boundary dataset
- Wine Australia, "Wine Geographical Indications Australia", ArcGIS Online item 2dd4c385f0ed4d109c2e18ae99e819e2, published on the Wine Australia Open Data Hub (https://wineaustralia-opendata-wineaustralia.hub.arcgis.com/maps/2dd4c385f0ed4d109c2e18ae99e819e2). Service: https://services6.arcgis.com/s8j6JbJJCqmhNgh7/arcgis/rest/services/Wine_Geographical_Indications_Australia/FeatureServer, layer 1 `Wine_GI_Regions` (layers 0 subregions and 2 zones also read).
- Version: item modified 2026-10-05 (DCAT `modified` 2026-10-05T02:38:10Z; layer 1 dataLastEditDate 2026-10-05; feature `EDIT_DATE` 2026-10-05). This is the current item; the older `Wine_Geographical_Indications_Australia_2022v1` service is labelled "(superseded)" in the hub catalogue and was not used.
- Licence: CC BY 4.0 (https://creativecommons.org/licenses/by/4.0). Required attribution, from the item: "Geographical Indications of Australia, © Wine Australia".
- The item says the polygons are "an interpretation of the legal textual description"; "the textual description prevails". The legal textual descriptions themselves were not re-checked against the polygons.
- Fetched 2026-11-20 with a REST query (`where=1=1&outFields=*&outSR=4326&f=geojson`), source CRS EPSG:7844 (GDA2020), reprojected server side to WGS84. Raw files: `raw/regions_all_4326.geojson`, `raw/subregions_all_4326.geojson`, `raw/zone_tas_4326.geojson`, plus `raw/item.json`, `raw/dcat.json`, `raw/layer*.json`, `raw/attrs*.json`.
- Processing: shapely `buffer(0)`, `simplify(0.001 deg, preserve_topology=True)` (about 100 m), coordinates rounded to 5 decimals. Areas below are on a sinusoidal equal area projection.

## Unit
- One feature, unit_id AU_GI_mclaren_vale, the whole GI polygon (not partial). Dataset area attribute 433 km2; computed from source 432.8 km2; after simplification 433.0 km2; 1 part(s), 185 vertices, valid. Bounds [138.4415, -35.3488, 138.6907, -35.0487].
- Hausdorff distance source to output: 0.00097 deg (about 100 m).

## Judgement calls
- The dataset spells the GI "Mclaren Vale"; the register page spells it "McLaren Vale", used as the name.
- Grape order by area, SA Winegrape Crush Survey 2026 (https://riverlandwine.com.au/content/uploads/2026/08/sa_full_report_2026.pdf), matching the McLaren Vale Grape Wine & Tourism Association's key varieties page: Shiraz 4,002 ha (55.5%), Cabernet Sauvignon 1,254, Grenache 544, Chardonnay 231, Merlot 152 to 166.
- red_body 4: Wine Australia "medium to full-bodied", Halliday "typically full-bodied".
- "On the coast south of Adelaide" is read from the official polygon, not from a style source.
- Style rule applied: every claim in summary, body scores, pairing and grape notes has two independent sources. Wine Australia's wineaustralia.com, australianwine.com and its SA Winegrape Crush Survey count as one organisation. Quotes were gathered by research subagents through WebFetch's summariser and were not checked character by character against raw HTML. Wine-Searcher, Britannica, Jancis Robinson, GuildSomm and Decanter could not be fetched (403, paywall or truncated) and are not used.
- Score mapping: low 1 to 2, medium 3, high 4 to 5. Null where fewer than two sources characterise the main red, or where sources conflict.

## Held back
- red_tannin: Shiraz tannin not sourced; Cabernet tannin conflicts ("ripe, soft" against "firm but approachable").
- red_acidity: not sourced.
- pairing: one region specific source only.
- Fiano (81 ha): promoted by the regional association as a future icon white, one source; not added and not in new_grapes.
- The association's Districts are unofficial, not shown as appellations.
