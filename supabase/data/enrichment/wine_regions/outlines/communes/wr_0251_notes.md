# Mornington Peninsula (Australian GI): AU_GI_mornington_peninsula

## Official determination
- "Mornington Peninsula" is a registered Australian Geographical Indication (region), GI number 42, Victoria; zone: Port Phillip zone. Register of Protected GIs and Other Terms: https://wineaustralia.com/labelling/register-of-protected-gis-and-other-terms/geographical-indications. No registered subregions.
- Label rule: Wine Australia Regulations 2018 (F2018L00286), s 26(2): with a single Australian GI, at least 850 ml/L of the wine must come from grapes grown in that GI (https://www.legislation.gov.au/F2018L00286/latest/text), as recorded by the earlier session.

## Boundary dataset
- Wine Australia, "Wine Geographical Indications Australia", ArcGIS Online item 2dd4c385f0ed4d109c2e18ae99e819e2 (Wine Australia Open Data Hub). Service https://services6.arcgis.com/s8j6JbJJCqmhNgh7/arcgis/rest/services/Wine_Geographical_Indications_Australia/FeatureServer, layer 1 `Wine_GI_Regions` (layers 0 subregions and 2 zones read for checks).
- Version: layer 1 dataLastEditDate 2026-10-05, the same version the earlier session used (round 7 re-fetched it on 2026-11-21; the item metadata is unchanged).
- Licence: CC BY 4.0. Required attribution, from the item: "Geographical Indications of Australia, © Wine Australia".
- The item says the polygons are an interpretation of the legal textual description and that the text prevails. The legal texts were not re-checked against the polygons.
- Raw: `raw/au/layer{0,1,2}_4326.geojson`, `raw/au/layer*.json`, `raw/au/item.json`, `raw/au/RETRIEVED_UTC.txt` (query `where=1=1&outFields=*&outSR=4326&f=geojson`, source CRS GDA2020, reprojected server side).
- Processing: shapely make_valid, simplify 0.001 deg (about 100 m, topology preserved), coordinates rounded to 5 decimals. Areas on a sinusoidal equal area projection.

## Unit
- One feature, unit_id AU_GI_mornington_peninsula, the whole GI polygon (not partial). GI_NUMBER 42, VIC. Dataset area attribute 723 km2; computed from source 722.7 km2; after simplification 724.5 km2; 1 part(s), 263 vertices, valid True. Bounds [144.6516, -38.4993, 145.2627, -38.1624]. Hausdorff distance to source 0.0010 deg (about 100 m).
- Zone layer overlap (share of the region): {'Port Phillip': 0.9998}. Subregions inside (share of each subregion inside): none.

## Judgement calls
- Grape order by share of 2026 tonnes crushed, Wine Australia Region Snapshot 2025-26 (National Vintage Survey 2026): Pinot Noir 47%, Chardonnay 26%, Pinot Gris/Grigio 13%, Shiraz 7%. A single vintage; agrees with Mornington Peninsula Vignerons ("Pinot Noir is the dominant variety, comprising half of total plantings").
- red_acidity 4: Wine Australia "vibrant acidity", Mornington Peninsula Vignerons "high natural acidity".
- Summary: cool maritime climate (Wine Australia, Halliday, MPV); sandy, red volcanic and yellow/brown over clay soils (Wine Australia, Halliday).
- Style rule: every claim in the summary, scores and grape notes has two independent sources (one organisation counts once: Wine Australia covers wineaustralia.com, australianwine.com and its Region Snapshots; WOSA covers all wosa.co.za pages). Quotes were gathered by research subagents (some read raw HTML or PDF text, some through WebFetch's summariser); several key quotes were re-checked by me against raw page text on 2026-11-21. Score mapping: low 1 to 2, medium 3, high 4, full bodied 5; null where fewer than two sources give a level or sources conflict.

## Held back
- red_body: "light to medium bodied" is Wine Australia only. red_tannin: "soft" (Wine Australia) and "fine" (MPV), but MPV also says warmer sites are more tannic; null.
- "No vineyard further than 7 km from the ocean": Wine Australia only. Vineyard area figures conflict (976 against about 1,100 ha). Pairing: none found.
