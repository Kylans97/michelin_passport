# Mudgee (Australian GI): AU_GI_mudgee

## Official determination
- "Mudgee" is a registered Australian Geographical Indication (region), GI number 80, New South Wales; zone: Central Ranges zone. Register of Protected GIs and Other Terms: https://wineaustralia.com/labelling/register-of-protected-gis-and-other-terms/geographical-indications. No registered subregions.
- Label rule: Wine Australia Regulations 2018 (F2018L00286), s 26(2): with a single Australian GI, at least 850 ml/L of the wine must come from grapes grown in that GI (https://www.legislation.gov.au/F2018L00286/latest/text), as recorded by the earlier session.

## Boundary dataset
- Wine Australia, "Wine Geographical Indications Australia", ArcGIS Online item 2dd4c385f0ed4d109c2e18ae99e819e2 (Wine Australia Open Data Hub). Service https://services6.arcgis.com/s8j6JbJJCqmhNgh7/arcgis/rest/services/Wine_Geographical_Indications_Australia/FeatureServer, layer 1 `Wine_GI_Regions` (layers 0 subregions and 2 zones read for checks).
- Version: layer 1 dataLastEditDate 2026-10-05, the same version the earlier session used (round 7 re-fetched it on 2026-11-21; the item metadata is unchanged).
- Licence: CC BY 4.0. Required attribution, from the item: "Geographical Indications of Australia, © Wine Australia".
- The item says the polygons are an interpretation of the legal textual description and that the text prevails. The legal texts were not re-checked against the polygons.
- Raw: `raw/au/layer{0,1,2}_4326.geojson`, `raw/au/layer*.json`, `raw/au/item.json`, `raw/au/RETRIEVED_UTC.txt` (query `where=1=1&outFields=*&outSR=4326&f=geojson`, source CRS GDA2020, reprojected server side).
- Processing: shapely make_valid, simplify 0.001 deg (about 100 m, topology preserved), coordinates rounded to 5 decimals. Areas on a sinusoidal equal area projection.

## Unit
- One feature, unit_id AU_GI_mudgee, the whole GI polygon (not partial). GI_NUMBER 80, NSW. Dataset area attribute 9760 km2; computed from source 9769.1 km2; after simplification 9769.2 km2; 1 part(s), 366 vertices, valid True. Bounds [149.1682, -33.1255, 150.3508, -31.8498]. Hausdorff distance to source 0.0010 deg (about 100 m).
- Zone layer overlap (share of the region): {'Central Ranges': 0.824, 'Hunter Valley': 0.0055, 'Northern Slopes': 0.1705}. Subregions inside (share of each subregion inside): none.
- The dataset's zone layer puts 17% of the polygon in the Northern Slopes zone and 0.5% in Hunter Valley; the register places Mudgee in Central Ranges. Treated as a zone layer edge mismatch; the region polygon is used as published.

## Judgement calls
- Grape order by share of 2026 tonnes, Wine Australia Region Snapshot 2025-26: Chardonnay 27%, Shiraz 21%, Pinot Gris/Grigio 19%, Merlot 10%, Cabernet Sauvignon 6%. In 2024 Shiraz led (28%) ahead of Chardonnay (23%); the order moves by year. Plantings are 76% red (Snapshot).
- Summary: 1858 (Mudgee Wine Grape Growers Association, NSW Wine; both checked in raw text); sandy loam over clay (Wine Australia, MWGGA, Halliday; checked); cold winters and frosts, warm dry summers (Wine Australia, Halliday); mostly red (Halliday "predominately red-wine country", MWGGA, Snapshot).
- Shiraz local note "robust": MWGGA and australianwine.com.
- Style rule: every claim in the summary, scores and grape notes has two independent sources (one organisation counts once: Wine Australia covers wineaustralia.com, australianwine.com and its Region Snapshots; WOSA covers all wosa.co.za pages). Quotes were gathered by research subagents (some read raw HTML or PDF text, some through WebFetch's summariser); several key quotes were re-checked by me against raw page text on 2026-11-21. Score mapping: low 1 to 2, medium 3, high 4, full bodied 5; null where fewer than two sources give a level or sources conflict.

## Held back
- Red body, acidity, tannin: no two source levels. "Australia's highest vineyards" (Wine Australia, MWGGA) conflicts with Orange's higher GI; not used. Shiraz with a touch of Viognier: Halliday only. Pairing: none.
