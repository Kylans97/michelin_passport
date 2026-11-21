# Canberra District (Australian GI): AU_GI_canberra_district

## Official determination
- "Canberra District" is a registered Australian Geographical Indication (region), GI number 55, partly New South Wales and partly the Australian Capital Territory (dataset STATE attribute: NSW); zone: Southern New South Wales zone. Register of Protected GIs and Other Terms: https://wineaustralia.com/labelling/register-of-protected-gis-and-other-terms/geographical-indications. Entered 9 February 1998. No registered subregions (the association's three subregions are informal).
- Label rule: Wine Australia Regulations 2018 (F2018L00286), s 26(2): with a single Australian GI, at least 850 ml/L of the wine must come from grapes grown in that GI (https://www.legislation.gov.au/F2018L00286/latest/text), as recorded by the earlier session.

## Boundary dataset
- Wine Australia, "Wine Geographical Indications Australia", ArcGIS Online item 2dd4c385f0ed4d109c2e18ae99e819e2 (Wine Australia Open Data Hub). Service https://services6.arcgis.com/s8j6JbJJCqmhNgh7/arcgis/rest/services/Wine_Geographical_Indications_Australia/FeatureServer, layer 1 `Wine_GI_Regions` (layers 0 subregions and 2 zones read for checks).
- Version: layer 1 dataLastEditDate 2026-10-05, the same version the earlier session used (round 7 re-fetched it on 2026-11-21; the item metadata is unchanged).
- Licence: CC BY 4.0. Required attribution, from the item: "Geographical Indications of Australia, © Wine Australia".
- The item says the polygons are an interpretation of the legal textual description and that the text prevails. The legal texts were not re-checked against the polygons.
- Raw: `raw/au/layer{0,1,2}_4326.geojson`, `raw/au/layer*.json`, `raw/au/item.json`, `raw/au/RETRIEVED_UTC.txt` (query `where=1=1&outFields=*&outSR=4326&f=geojson`, source CRS GDA2020, reprojected server side).
- Processing: shapely make_valid, simplify 0.001 deg (about 100 m, topology preserved), coordinates rounded to 5 decimals. Areas on a sinusoidal equal area projection.

## Unit
- One feature, unit_id AU_GI_canberra_district, the whole GI polygon (not partial). GI_NUMBER 55, NSW. Dataset area attribute 8607 km2; computed from source 8591.1 km2; after simplification 8590.8 km2; 1 part(s), 416 vertices, valid True. Bounds [148.5223, -35.5844, 149.5351, -34.409]. Hausdorff distance to source 0.0010 deg (about 100 m).
- Zone layer overlap (share of the region): {'Southern New South Wales': 1.0}. Subregions inside (share of each subregion inside): none.
- The CSV province gives both New South Wales and the Australian Capital Territory, per the GI text.

## Judgement calls
- Added (optional in the brief). No official per variety statistic found (no Region Snapshot for this GI). Grapes are those two sources name as key: Shiraz and Riesling (Wine Australia "The main varieties grown in the region are Shiraz, Riesling, and Cabernet Sauvignon", checked in raw text; Decanter; NSW Wine, checked; CDWIA). Viognier is listed for the Shiraz Viognier style (CDWIA "Shiraz, Shiraz Viognier and Riesling"; NSW Wine "Shiraz and Shiraz Viogner blends", checked). The order is by these sources, not by a statistic.
- Summary: partly NSW, partly ACT (GI text; Decanter); strongly continental climate (Wine Australia "extreme Continental", CDWIA, Decanter).
- Style rule: every claim in the summary, scores and grape notes has two independent sources (one organisation counts once: Wine Australia covers wineaustralia.com, australianwine.com and its Region Snapshots; WOSA covers all wosa.co.za pages). Quotes were gathered by research subagents (some read raw HTML or PDF text, some through WebFetch's summariser); several key quotes were re-checked by me against raw page text on 2026-11-21. Score mapping: low 1 to 2, medium 3, high 4, full bodied 5; null where fewer than two sources give a level or sources conflict.

## Held back
- Cabernet Sauvignon: Wine Australia only as a main variety.
- Shiraz "medium bodied": Decanter only. "Fine tannins": two publications both quoting the same producer. "Natural acidity": no level. Null.
- Vineyard elevation 500 to 850 m: Decanter plus a Halliday panel that may not be region specific. Pairing: none. Viognier co-fermentation share: unverified.
