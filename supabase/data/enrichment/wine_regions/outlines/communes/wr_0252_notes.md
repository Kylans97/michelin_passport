# Heathcote (Australian GI): AU_GI_heathcote

## Official determination
- "Heathcote" is a registered Australian Geographical Indication (region), GI number 95, Victoria; zone: Central Victoria zone. Register of Protected GIs and Other Terms: https://wineaustralia.com/labelling/register-of-protected-gis-and-other-terms/geographical-indications. Entered 21 August 2002. No registered subregions (Halliday's 'several subregions' are informal).
- Label rule: Wine Australia Regulations 2018 (F2018L00286), s 26(2): with a single Australian GI, at least 850 ml/L of the wine must come from grapes grown in that GI (https://www.legislation.gov.au/F2018L00286/latest/text), as recorded by the earlier session.

## Boundary dataset
- Wine Australia, "Wine Geographical Indications Australia", ArcGIS Online item 2dd4c385f0ed4d109c2e18ae99e819e2 (Wine Australia Open Data Hub). Service https://services6.arcgis.com/s8j6JbJJCqmhNgh7/arcgis/rest/services/Wine_Geographical_Indications_Australia/FeatureServer, layer 1 `Wine_GI_Regions` (layers 0 subregions and 2 zones read for checks).
- Version: layer 1 dataLastEditDate 2026-10-05, the same version the earlier session used (round 7 re-fetched it on 2026-11-21; the item metadata is unchanged).
- Licence: CC BY 4.0. Required attribution, from the item: "Geographical Indications of Australia, © Wine Australia".
- The item says the polygons are an interpretation of the legal textual description and that the text prevails. The legal texts were not re-checked against the polygons.
- Raw: `raw/au/layer{0,1,2}_4326.geojson`, `raw/au/layer*.json`, `raw/au/item.json`, `raw/au/RETRIEVED_UTC.txt` (query `where=1=1&outFields=*&outSR=4326&f=geojson`, source CRS GDA2020, reprojected server side).
- Processing: shapely make_valid, simplify 0.001 deg (about 100 m, topology preserved), coordinates rounded to 5 decimals. Areas on a sinusoidal equal area projection.

## Unit
- One feature, unit_id AU_GI_heathcote, the whole GI polygon (not partial). GI_NUMBER 95, VIC. Dataset area attribute 1913 km2; computed from source 1912.2 km2; after simplification 1912.0 km2; 1 part(s), 196 vertices, valid True. Bounds [144.4184, -37.1185, 144.9478, -36.3715]. Hausdorff distance to source 0.0010 deg (about 100 m).
- Zone layer overlap (share of the region): {'Central Victoria': 1.0}. Subregions inside (share of each subregion inside): none.

## Judgement calls
- Grape order by share of 2026 tonnes, Wine Australia Region Snapshot 2025-26: Shiraz 44%, Chardonnay 17%, Cabernet Sauvignon 8%, Riesling 7%, Grenache 6%. One vintage.
- red_body 4: Halliday "mouth-filling, densely coloured and richly flavoured", Wine Australia "deep, rich and velvety". Neither says "full bodied", so 4 (high), not 5. Flag for review.
- Summary: Cambrian red soils (Halliday, Heathcote Wine Growers Association, Wine Australia); warm summers (Wine Australia "very warm summers", Halliday "warm days"); Mount Camel Range (Wine Australia, HWGA); intensely coloured wines and inky colour (Halliday, Wine Australia, HWGA); Shiraz (all three).
- Style rule: every claim in the summary, scores and grape notes has two independent sources (one organisation counts once: Wine Australia covers wineaustralia.com, australianwine.com and its Region Snapshots; WOSA covers all wosa.co.za pages). Quotes were gathered by research subagents (some read raw HTML or PDF text, some through WebFetch's summariser); several key quotes were re-checked by me against raw page text on 2026-11-21. Score mapping: low 1 to 2, medium 3, high 4, full bodied 5; null where fewer than two sources give a level or sources conflict.

## Held back
- red_tannin: "ripe but fine" and "supple and ripe" describe texture, not a level. red_acidity: HWGA only, no level. Pairing: none. Elevation: figures conflict.
