# Adelaide Hills (Australian GI) : AU_GI_adelaide_hills

## Official determination
- "Adelaide Hills" is a registered Australian Geographical Indication (region), GI number 53, in South Australia; zone: Mount Lofty Ranges zone. Register of Protected GIs and Other Terms, Wine Australia Act 2013: https://wineaustralia.com/labelling/register-of-protected-gis-and-other-terms/geographical-indications.
- Entered in the Register of Protected Names on 9 February 1998 (Wine Australia GI page: https://www.wineaustralia.com/labelling/geographical-indicators/adelaide-hills; saved in `raw/gi_pages/`).
- Label rule: Wine Australia Regulations 2018 (F2018L00286), s 26(2), checked in Compilation No. 4 (F2025C00049, compilation date 1 January 2025; https://www.legislation.gov.au/F2018L00286/latest/text): with one Australian GI and no foreign GI or place name, "at least 850ml/L of the wine must have been obtained from grapes grown in the region or locality in Australia in relation to which the GI is registered". Raw: `raw/wa_regs_F2025C00049.pdf`, `raw/wa_regs_2018.pdf` (as made, same wording).

## Boundary dataset
- Wine Australia, "Wine Geographical Indications Australia", ArcGIS Online item 2dd4c385f0ed4d109c2e18ae99e819e2, published on the Wine Australia Open Data Hub (https://wineaustralia-opendata-wineaustralia.hub.arcgis.com/maps/2dd4c385f0ed4d109c2e18ae99e819e2). Service: https://services6.arcgis.com/s8j6JbJJCqmhNgh7/arcgis/rest/services/Wine_Geographical_Indications_Australia/FeatureServer, layer 1 `Wine_GI_Regions` (layers 0 subregions and 2 zones also read).
- Version: item modified 2026-10-05 (DCAT `modified` 2026-10-05T02:38:10Z; layer 1 dataLastEditDate 2026-10-05; feature `EDIT_DATE` 2026-10-05). This is the current item; the older `Wine_Geographical_Indications_Australia_2022v1` service is labelled "(superseded)" in the hub catalogue and was not used.
- Licence: CC BY 4.0 (https://creativecommons.org/licenses/by/4.0). Required attribution, from the item: "Geographical Indications of Australia, © Wine Australia".
- The item says the polygons are "an interpretation of the legal textual description"; "the textual description prevails". The legal textual descriptions themselves were not re-checked against the polygons.
- Fetched 2026-11-20 with a REST query (`where=1=1&outFields=*&outSR=4326&f=geojson`), source CRS EPSG:7844 (GDA2020), reprojected server side to WGS84. Raw files: `raw/regions_all_4326.geojson`, `raw/subregions_all_4326.geojson`, `raw/zone_tas_4326.geojson`, plus `raw/item.json`, `raw/dcat.json`, `raw/layer*.json`, `raw/attrs*.json`.
- Processing: shapely `buffer(0)`, `simplify(0.001 deg, preserve_topology=True)` (about 100 m), coordinates rounded to 5 decimals. Areas below are on a sinusoidal equal area projection.

## Unit
- One feature, unit_id AU_GI_adelaide_hills, the whole GI polygon (not partial). Dataset area attribute 1451 km2; computed from source 1451.6 km2; after simplification 1452.0 km2; 1 part(s), 279 vertices, valid. Bounds [138.579, -35.3495, 139.0838, -34.6878].
- Hausdorff distance source to output: 0.00098 deg (about 100 m).

## Judgement calls
- Grape order by vineyard area, SA Winegrape Crush Survey 2024 for the Adelaide Hills (https://vinehealth.com.au/wp-content/uploads/Adelaide-Hills-report-2024.pdf): Sauvignon Blanc 840 ha, Chardonnay 831, Pinot Noir 742, Shiraz 372, Pinot Gris 263. On 2024 crush Chardonnay leads; the two whites are effectively tied.
- Subregions Lenswood (entered 16 October 1998) and Piccadilly Valley (entered 14 April 2000) are official GIs; their polygons lie wholly inside the Adelaide Hills polygon (checked: 100% overlap). Notes from Halliday's article on the subregional GIs and InDaily (2021). Not drawn as separate units.
- Altitude figures differ between sources (Wine Australia 149 to 714 m; the regional association: above 300 m), so no figure is given.
- The register page is at /labelling/geographical-indicators/adelaide-hills (the labelling-gi-adelaide-hills pattern returns 404); the dataset's GI_URL gives the working one.
- Style rule applied: every claim in summary, body scores, pairing and grape notes has two independent sources. Wine Australia's wineaustralia.com, australianwine.com and its SA Winegrape Crush Survey count as one organisation. Quotes were gathered by research subagents through WebFetch's summariser and were not checked character by character against raw HTML. Wine-Searcher, Britannica, Jancis Robinson, GuildSomm and Decanter could not be fetched (403, paywall or truncated) and are not used.
- Score mapping: low 1 to 2, medium 3, high 4 to 5. Null where fewer than two sources characterise the main red, or where sources conflict.

## Held back
- Red body, acidity, tannin: Pinot Noir "medium-bodied ... soft tannins" is Wine Australia only.
- pairing: only variety level (Sauvignon Blanc with goat's cheese or oysters).
- "Benchmark for Sauvignon Blanc in Australia": a superlative with one full source; left out.
- Sparkling as a Piccadilly Valley speciality: one independent source.
