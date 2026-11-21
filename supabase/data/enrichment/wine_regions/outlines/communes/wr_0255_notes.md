# Orange (Australian GI): AU_GI_orange

## Official determination
- "Orange" is a registered Australian Geographical Indication (region), GI number 52, New South Wales; zone: Central Ranges zone. Register of Protected GIs and Other Terms: https://wineaustralia.com/labelling/register-of-protected-gis-and-other-terms/geographical-indications. Entered 31 October 1997. No registered subregions. The GI text: "that contiguous area that is above 600 metre elevation within the City of Orange and the Shires of Cabonne and Blayney" (https://www.wineaustralia.com/labelling/geographical-indicators/labelling-gi-orange; also NSW Wine Industry Association).
- Label rule: Wine Australia Regulations 2018 (F2018L00286), s 26(2): with a single Australian GI, at least 850 ml/L of the wine must come from grapes grown in that GI (https://www.legislation.gov.au/F2018L00286/latest/text), as recorded by the earlier session.

## Boundary dataset
- Wine Australia, "Wine Geographical Indications Australia", ArcGIS Online item 2dd4c385f0ed4d109c2e18ae99e819e2 (Wine Australia Open Data Hub). Service https://services6.arcgis.com/s8j6JbJJCqmhNgh7/arcgis/rest/services/Wine_Geographical_Indications_Australia/FeatureServer, layer 1 `Wine_GI_Regions` (layers 0 subregions and 2 zones read for checks).
- Version: layer 1 dataLastEditDate 2026-10-05, the same version the earlier session used (round 7 re-fetched it on 2026-11-21; the item metadata is unchanged).
- Licence: CC BY 4.0. Required attribution, from the item: "Geographical Indications of Australia, © Wine Australia".
- The item says the polygons are an interpretation of the legal textual description and that the text prevails. The legal texts were not re-checked against the polygons.
- Raw: `raw/au/layer{0,1,2}_4326.geojson`, `raw/au/layer*.json`, `raw/au/item.json`, `raw/au/RETRIEVED_UTC.txt` (query `where=1=1&outFields=*&outSR=4326&f=geojson`, source CRS GDA2020, reprojected server side).
- Processing: shapely make_valid, simplify 0.001 deg (about 100 m, topology preserved), coordinates rounded to 5 decimals. Areas on a sinusoidal equal area projection.

## Unit
- One feature, unit_id AU_GI_orange, the whole GI polygon (not partial). GI_NUMBER 52, NSW. Dataset area attribute 3422 km2; computed from source 3423.6 km2; after simplification 3421.0 km2; 1 part(s), 1685 vertices, valid True. Bounds [148.7932, -33.8124, 149.4221, -32.9648]. Hausdorff distance to source 0.0010 deg (about 100 m).
- Zone layer overlap (share of the region): {'Central Ranges': 1.0}. Subregions inside (share of each subregion inside): none.
- The polygon is the dataset's interpretation of the 600 m contour (1,685 vertices after simplification, one part). Its attribute ALTITUDE_LOW is 376 m, which conflicts with the 600 m legal floor; the text prevails. Simplification at about 100 m slightly smooths the contour edge. Flag for review.

## Judgement calls
- Grape order by share of 2026 tonnes, Wine Australia Region Snapshot 2025-26: Chardonnay 18%, Sauvignon Blanc 18%, Pinot Noir 14%, Pinot Gris/Grigio 13%, Shiraz 10%. The 2026 crush was 38% down. Shiraz is the most widely planted (Wine Australia, Halliday); recorded in its local note and the summary.
- Summary: high altitude (Wine Australia, Halliday, Orange360); Mount Canobolas, an ancient volcano, and basalt soils (Wine Australia, Halliday, Orange360, NSW Wine).
- Style rule: every claim in the summary, scores and grape notes has two independent sources (one organisation counts once: Wine Australia covers wineaustralia.com, australianwine.com and its Region Snapshots; WOSA covers all wosa.co.za pages). Quotes were gathered by research subagents (some read raw HTML or PDF text, some through WebFetch's summariser); several key quotes were re-checked by me against raw page text on 2026-11-21. Score mapping: low 1 to 2, medium 3, high 4, full bodied 5; null where fewer than two sources give a level or sources conflict.

## Held back
- Red scores: Cabernet/Merlot "medium bodied ... fine tannins" appears in Wine Australia and Halliday with near identical wording (shared copy, not independent); Orange360 alone for acidity; Shiraz has no two source descriptor. Null.
- "Cool climate": not phrased so by two sources. "The only Australian GI defined by elevation": not verified. Pairing: none.
