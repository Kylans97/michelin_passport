# Rutherglen (Australian GI): AU_GI_rutherglen

## Official determination
- "Rutherglen" is a registered Australian Geographical Indication (region), GI number 49, Victoria; zone: North East Victoria zone. Register of Protected GIs and Other Terms: https://wineaustralia.com/labelling/register-of-protected-gis-and-other-terms/geographical-indications. No registered subregions. Topaque and Apera are registered certification trade marks owned by Wine Australia; Tokay was phased out on 1 September 2020 (https://wineaustralia.com/labelling/additional-labelling-terms, https://wineaustralia.com/news/articles/time-almost-up-for-tokay).
- Label rule: Wine Australia Regulations 2018 (F2018L00286), s 26(2): with a single Australian GI, at least 850 ml/L of the wine must come from grapes grown in that GI (https://www.legislation.gov.au/F2018L00286/latest/text), as recorded by the earlier session.

## Boundary dataset
- Wine Australia, "Wine Geographical Indications Australia", ArcGIS Online item 2dd4c385f0ed4d109c2e18ae99e819e2 (Wine Australia Open Data Hub). Service https://services6.arcgis.com/s8j6JbJJCqmhNgh7/arcgis/rest/services/Wine_Geographical_Indications_Australia/FeatureServer, layer 1 `Wine_GI_Regions` (layers 0 subregions and 2 zones read for checks).
- Version: layer 1 dataLastEditDate 2026-10-05, the same version the earlier session used (round 7 re-fetched it on 2026-11-21; the item metadata is unchanged).
- Licence: CC BY 4.0. Required attribution, from the item: "Geographical Indications of Australia, © Wine Australia".
- The item says the polygons are an interpretation of the legal textual description and that the text prevails. The legal texts were not re-checked against the polygons.
- Raw: `raw/au/layer{0,1,2}_4326.geojson`, `raw/au/layer*.json`, `raw/au/item.json`, `raw/au/RETRIEVED_UTC.txt` (query `where=1=1&outFields=*&outSR=4326&f=geojson`, source CRS GDA2020, reprojected server side).
- Processing: shapely make_valid, simplify 0.001 deg (about 100 m, topology preserved), coordinates rounded to 5 decimals. Areas on a sinusoidal equal area projection.

## Unit
- One feature, unit_id AU_GI_rutherglen, the whole GI polygon (not partial). GI_NUMBER 49, VIC. Dataset area attribute 998 km2; computed from source 998.0 km2; after simplification 998.5 km2; 1 part(s), 335 vertices, valid True. Bounds [146.1752, -36.2633, 146.8218, -35.9582]. Hausdorff distance to source 0.0010 deg (about 100 m).
- Zone layer overlap (share of the region): {'North East Victoria': 1.0}. Subregions inside (share of each subregion inside): none.

## Judgement calls
- Grape order by share of 2026 tonnes, Wine Australia Region Snapshot 2025-26: Shiraz 20%, Durif 15%, Muscat à Petits Grains Rouges 11%, Pinot Noir 8%, Chardonnay 7%. 2026 crush was very small (1,350 t). Muscadelle is outside the top five but named as key (Halliday "durif, shiraz, muscat and topaque"; Wine Australia "fortified wines made from Muscat and Muscadelle"), so it is listed last.
- red_body 4 for Shiraz: Winemakers of Rutherglen "Medium- to full-bodied" (re-fetched https://winemakers.com.au/shiraz-of-rutherglen/), Wine Australia "full flavoured, rich" and "robust". The overlap is high, not full.
- Muscat grape: Winemakers of Rutherglen, Berry Bros & Rudd and Wine Australia's Australian Wine Discovered sheet all name Muscat à Petits Grains Rouges / Rutherglen Brown Muscat. Classification tiers Rutherglen, Classic, Grand, Rare: Winemakers of Rutherglen, BBR, Halliday.
- Topaque is Muscadelle: Winemakers of Rutherglen, Halliday. Topaque is a wine name and trade mark, not a grape synonym; not added as an alias.
- Summary: continental climate (Wine Australia, Winemakers of Rutherglen, BBR); loamy soils (Wine Australia, BBR); fortified Muscat and Topaque plus rich reds (Wine Australia, Halliday).
- Warning from research: the Winemakers of Rutherglen Muscat page carried an unrelated promotional paragraph about a medication, suggesting spam injection. Its Muscat facts agree with BBR, GuildSomm and Wine Australia; re-check the page by eye before citing it publicly.
- Style rule: every claim in the summary, scores and grape notes has two independent sources (one organisation counts once: Wine Australia covers wineaustralia.com, australianwine.com and its Region Snapshots; WOSA covers all wosa.co.za pages). Quotes were gathered by research subagents (some read raw HTML or PDF text, some through WebFetch's summariser); several key quotes were re-checked by me against raw page text on 2026-11-21. Score mapping: low 1 to 2, medium 3, high 4, full bodied 5; null where fewer than two sources give a level or sources conflict.

## Held back
- red_tannin: "medium to high" (Winemakers of Rutherglen) against "supple" (Wine Australia); conflict. red_acidity: one source.
- Average ages for the Muscat tiers: Halliday says there are no hard rules; producer and other figures differ. Not used.
- Pairing: Winemakers of Rutherglen only.
