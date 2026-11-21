# Eden Valley (Australian GI): AU_GI_eden_valley

## Official determination
- "Eden Valley" is a registered Australian Geographical Indication (region), GI number 48, South Australia; zone: Barossa zone. Register of Protected GIs and Other Terms: https://wineaustralia.com/labelling/register-of-protected-gis-and-other-terms/geographical-indications. Subregion High Eden, entered 28 August 2001.
- Label rule: Wine Australia Regulations 2018 (F2018L00286), s 26(2): with a single Australian GI, at least 850 ml/L of the wine must come from grapes grown in that GI (https://www.legislation.gov.au/F2018L00286/latest/text), as recorded by the earlier session.

## Boundary dataset
- Wine Australia, "Wine Geographical Indications Australia", ArcGIS Online item 2dd4c385f0ed4d109c2e18ae99e819e2 (Wine Australia Open Data Hub). Service https://services6.arcgis.com/s8j6JbJJCqmhNgh7/arcgis/rest/services/Wine_Geographical_Indications_Australia/FeatureServer, layer 1 `Wine_GI_Regions` (layers 0 subregions and 2 zones read for checks).
- Version: layer 1 dataLastEditDate 2026-10-05, the same version the earlier session used (round 7 re-fetched it on 2026-11-21; the item metadata is unchanged).
- Licence: CC BY 4.0. Required attribution, from the item: "Geographical Indications of Australia, © Wine Australia".
- The item says the polygons are an interpretation of the legal textual description and that the text prevails. The legal texts were not re-checked against the polygons.
- Raw: `raw/au/layer{0,1,2}_4326.geojson`, `raw/au/layer*.json`, `raw/au/item.json`, `raw/au/RETRIEVED_UTC.txt` (query `where=1=1&outFields=*&outSR=4326&f=geojson`, source CRS GDA2020, reprojected server side).
- Processing: shapely make_valid, simplify 0.001 deg (about 100 m, topology preserved), coordinates rounded to 5 decimals. Areas on a sinusoidal equal area projection.

## Unit
- One feature, unit_id AU_GI_eden_valley, the whole GI polygon (not partial). GI_NUMBER 48, SA. Dataset area attribute 591 km2; computed from source 591.4 km2; after simplification 591.4 km2; 1 part(s), 70 vertices, valid True. Bounds [138.9376, -34.7755, 139.1938, -34.4075]. Hausdorff distance to source 0.0010 deg (about 100 m).
- Zone layer overlap (share of the region): {'Barossa': 0.9996}. Subregions inside (share of each subregion inside): {'High Eden': 1.0}.
- Nesting: lies inside the Barossa zone (99.96%%) beside the existing Barossa Valley unit; High Eden lies wholly inside it. Not drawn separately.

## Judgement calls
- Grape order by vineyard area, SA Winegrape Crush Survey 2026 (Wine Australia for SAWIA and the Wine Grape Council SA, areas from Vinehealth Australia at 30 April 2026), https://riverlandwine.com.au/content/uploads/2026/08/sa_full_report_2026.pdf (raw copy `raw/au/sa_full_report_2026.pdf`): Shiraz 786 ha, Riesling 521, Cabernet Sauvignon 330, Chardonnay 237, Pinot Noir 54, of 2,244 ha. Same basis as the earlier Barossa Valley entry. By 2026 tonnes Riesling (1,760 t) overtook Shiraz (1,599 t); recorded in Riesling's local note.
- Summary: cooler than the Barossa Valley (Wine Australia, Halliday, Wine Folly, Barossa Australia comparison sheet); hilly (Wine Australia, Jeroboams); rocky, gravelly soils (Wine Australia "ironstone gravels, quartz gravels and rock fragments", Barossa Australia "shallow, rocky soils", Jeroboams "metamorphic gravel over clay"); Riesling best known (Wine Australia, Halliday, Wine Folly).
- Style rule: every claim in the summary, scores and grape notes has two independent sources (one organisation counts once: Wine Australia covers wineaustralia.com, australianwine.com and its Region Snapshots; WOSA covers all wosa.co.za pages). Quotes were gathered by research subagents (some read raw HTML or PDF text, some through WebFetch's summariser); several key quotes were re-checked by me against raw page text on 2026-11-21. Score mapping: low 1 to 2, medium 3, high 4, full bodied 5; null where fewer than two sources give a level or sources conflict.

## Held back
- Red scores: Shiraz "medium to full bodied" and "fine tannins" are Barossa Australia only; Wine Folly "increased acidity" only. Null.
- Pairing: Jeroboams only. "Shallow" soils: one source. Elevation: figures conflict (GI extremes 219 to 632 m against Halliday 380 to 550 m). Pewsey Vale 1847 history: not sourced twice.
