# Beechworth (Australian GI): AU_GI_beechworth

## Official determination
- "Beechworth" is a registered Australian Geographical Indication (region), GI number 81, Victoria; zone: North East Victoria zone. Register of Protected GIs and Other Terms: https://wineaustralia.com/labelling/register-of-protected-gis-and-other-terms/geographical-indications. No registered subregions.
- Label rule: Wine Australia Regulations 2018 (F2018L00286), s 26(2): with a single Australian GI, at least 850 ml/L of the wine must come from grapes grown in that GI (https://www.legislation.gov.au/F2018L00286/latest/text), as recorded by the earlier session.

## Boundary dataset
- Wine Australia, "Wine Geographical Indications Australia", ArcGIS Online item 2dd4c385f0ed4d109c2e18ae99e819e2 (Wine Australia Open Data Hub). Service https://services6.arcgis.com/s8j6JbJJCqmhNgh7/arcgis/rest/services/Wine_Geographical_Indications_Australia/FeatureServer, layer 1 `Wine_GI_Regions` (layers 0 subregions and 2 zones read for checks).
- Version: layer 1 dataLastEditDate 2026-10-05, the same version the earlier session used (round 7 re-fetched it on 2026-11-21; the item metadata is unchanged).
- Licence: CC BY 4.0. Required attribution, from the item: "Geographical Indications of Australia, © Wine Australia".
- The item says the polygons are an interpretation of the legal textual description and that the text prevails. The legal texts were not re-checked against the polygons.
- Raw: `raw/au/layer{0,1,2}_4326.geojson`, `raw/au/layer*.json`, `raw/au/item.json`, `raw/au/RETRIEVED_UTC.txt` (query `where=1=1&outFields=*&outSR=4326&f=geojson`, source CRS GDA2020, reprojected server side).
- Processing: shapely make_valid, simplify 0.001 deg (about 100 m, topology preserved), coordinates rounded to 5 decimals. Areas on a sinusoidal equal area projection.

## Unit
- One feature, unit_id AU_GI_beechworth, the whole GI polygon (not partial). GI_NUMBER 81, VIC. Dataset area attribute 398 km2; computed from source 397.3 km2; after simplification 397.0 km2; 1 part(s), 16 vertices, valid True. Bounds [146.5431, -36.4592, 146.8119, -36.2515]. Hausdorff distance to source 0.0009 deg (about 100 m).
- Zone layer overlap (share of the region): {'North East Victoria': 1.0}. Subregions inside (share of each subregion inside): none.

## Judgement calls
- Added (optional in the brief): two sources for every summary claim. Grape order by share of 2026 tonnes, Wine Australia Region Snapshot 2025-26: Chardonnay 38%, Pinot Noir 15%, Sangiovese 11%, Pinot Gris/Grigio 8%, Shiraz 8%. Very small region (about 126 to 134 ha; sources differ slightly).
- Summary: elevated hillside region with a continental climate (Wine Australia; Halliday "alpine landscape", cooler climate styles); granite in the soils (Wine Australia "sandstone, gravel and granite over clay", Halliday "Devonian granites and granodiorite"; checked in raw text); best known for Chardonnay (Halliday, Wine Australia); Italian varieties (Halliday names nebbiolo, sangiovese, nero d'Avola; checked in raw text; Snapshot shows Sangiovese 11%).
- Style rule: every claim in the summary, scores and grape notes has two independent sources (one organisation counts once: Wine Australia covers wineaustralia.com, australianwine.com and its Region Snapshots; WOSA covers all wosa.co.za pages). Quotes were gathered by research subagents (some read raw HTML or PDF text, some through WebFetch's summariser); several key quotes were re-checked by me against raw page text on 2026-11-21. Score mapping: low 1 to 2, medium 3, high 4, full bodied 5; null where fewer than two sources give a level or sources conflict.

## Held back
- Red descriptors: Wine Australia only. Halliday says the region focuses "almost solely on chardonnay and shiraz", which conflicts with Pinot Noir out-crushing Shiraz in 2026. Pairing: none. Elevation figures conflict.
