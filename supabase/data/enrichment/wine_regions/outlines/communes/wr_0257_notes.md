# Great Southern (Australian GI): AU_GI_great_southern

## Official determination
- "Great Southern" is a registered Australian Geographical Indication (region), GI number 40, Western Australia; zone: South West Australia zone. Register of Protected GIs and Other Terms: https://wineaustralia.com/labelling/register-of-protected-gis-and-other-terms/geographical-indications. Entered 30 October 1996. Registered subregions: Albany, Denmark, Frankland River, Mount Barker, Porongurup (GI register; Wines of Western Australia; Halliday).
- Label rule: Wine Australia Regulations 2018 (F2018L00286), s 26(2): with a single Australian GI, at least 850 ml/L of the wine must come from grapes grown in that GI (https://www.legislation.gov.au/F2018L00286/latest/text), as recorded by the earlier session.

## Boundary dataset
- Wine Australia, "Wine Geographical Indications Australia", ArcGIS Online item 2dd4c385f0ed4d109c2e18ae99e819e2 (Wine Australia Open Data Hub). Service https://services6.arcgis.com/s8j6JbJJCqmhNgh7/arcgis/rest/services/Wine_Geographical_Indications_Australia/FeatureServer, layer 1 `Wine_GI_Regions` (layers 0 subregions and 2 zones read for checks).
- Version: layer 1 dataLastEditDate 2026-10-05, the same version the earlier session used (round 7 re-fetched it on 2026-11-21; the item metadata is unchanged).
- Licence: CC BY 4.0. Required attribution, from the item: "Geographical Indications of Australia, © Wine Australia".
- The item says the polygons are an interpretation of the legal textual description and that the text prevails. The legal texts were not re-checked against the polygons.
- Raw: `raw/au/layer{0,1,2}_4326.geojson`, `raw/au/layer*.json`, `raw/au/item.json`, `raw/au/RETRIEVED_UTC.txt` (query `where=1=1&outFields=*&outSR=4326&f=geojson`, source CRS GDA2020, reprojected server side).
- Processing: shapely make_valid, simplify 0.001 deg (about 100 m, topology preserved), coordinates rounded to 5 decimals. Areas on a sinusoidal equal area projection.

## Unit
- One feature, unit_id AU_GI_great_southern, the whole GI polygon (not partial). GI_NUMBER 40, WA. Dataset area attribute 17131 km2; computed from source 17134.4 km2; after simplification 17151.8 km2; 1 part(s), 681 vertices, valid True. Bounds [116.5717, -35.1345, 118.9147, -34.1321]. Hausdorff distance to source 0.0010 deg (about 100 m).
- Zone layer overlap (share of the region): {'Central Western Australia': 0.0397, 'South West Australia': 0.8614, 'West Australian South East Coastal': 0.0988}. Subregions inside (share of each subregion inside): {'Porongurup': 1.0, 'Mount Barker': 1.0, 'Frankland River': 1.0, 'Denmark': 1.0, 'Albany': 1.0}.
- All five subregions lie wholly inside the polygon and are not drawn separately. The zone layer puts 14% of the polygon outside the South West Australia zone polygon; treated as a zone layer edge mismatch.
- Simplification grew the area by 0.1% (17 km2 of 17,134); within tolerance.

## Judgement calls
- Grape order by share of 2026 tonnes, Wine Australia Region Snapshot 2025-26: Shiraz 27%, Cabernet Sauvignon 24%, Chardonnay 14%, Riesling 9%, Semillon 7%.
- Summary: maritime near the coast, continental inland (Wine Australia, Wines of Western Australia, Halliday); five subregions (three sources); Riesling most recognised (Wine Australia "Riesling vies with Cabernet Sauvignon", WineWA "Riesling and Shiraz the most recognised").
- Riesling local note "ages well, ten years or more": WineWA, Wine Australia, Halliday.
- Style rule: every claim in the summary, scores and grape notes has two independent sources (one organisation counts once: Wine Australia covers wineaustralia.com, australianwine.com and its Region Snapshots; WOSA covers all wosa.co.za pages). Quotes were gathered by research subagents (some read raw HTML or PDF text, some through WebFetch's summariser); several key quotes were re-checked by me against raw page text on 2026-11-21. Score mapping: low 1 to 2, medium 3, high 4, full bodied 5; null where fewer than two sources give a level or sources conflict.

## Held back
- Shiraz body and tannin: WineWA only; Halliday on Mount Barker reds conflicts ("plenty of tannin"). Acidity unsourced.
- Riesling "citrus with herbs": Wine Australia and WineWA share copy; not independent.
- Pairing: Riesling with Albany rock oysters rests on one wine review and one producer anecdote. Not used.
- "Australia's largest wine region" and "coolest in WA": WineWA only. Elevation figures conflict.
