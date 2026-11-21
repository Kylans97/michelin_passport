# Breedekloof (district): ZA_district_breedekloof

## Official hierarchy position
SAWIS Feb 2026: Greater Cape > Western Cape > Breede River Valley (region) > Breedekloof (district) > wards Goudini, Slanghoek.

## Official text
Defining notice not located in this round. Board Notice 122 of 2006 (Worcester amendment, Gazette 29331) refers to "the defined area Breedekloof" as an exclusion from Worcester.

## Boundary dataset
- Layer `Districts20260626` (layer 2) of the ArcGIS FeatureServer "WINE OF ORIGIN SYSTEM 20260626", https://services-eu1.arcgis.com/u4YTgbzxcollBKYL/arcgis/rest/services/WINE_OF_ORIGIN_SYSTEM_20260626/FeatureServer (item d038d5ed1b9e4e54b86be7da14cf97fb, owner heinrich_vinpro, 26 June 2026): boundaries "as demarcated under the Wine of Origin Scheme administered by SAWIS", maintained by VinPro with SAWIS. The same layer the earlier session used.
- Re-fetched 2026-11-21 into `raw/za/`; feature content identical to the 2026-11-20 copy for all six layers.
- **Licence: none stated** (licenseInfo and accessInformation empty). Public item. Must be cleared with SAWIS/VinPro before shipping, as before.
- Status: no gazetted geometry exists; Wine of Origin schedules are written metes and bounds descriptions. This is the scheme administrator's published map, not a legal instrument. Its 2018 predecessor is the map SAWIS embeds on its own Production Areas page (item 77d24f54b9424c69b9a650242d3ceb21).
- The dataset matches SAWIS, *Production areas defined in terms of the Wine of Origin Scheme*, February 2026 (https://www.sawis.co.za/cert/download/Production_areas_-_Eng_&_Afr_-_Feb26.pdf).
- Processing: make_valid, Douglas Peucker 100 m in a local equirectangular metre projection (lat0 -33.8), topology preserved, coordinates rounded to 5 decimals.

## Unit
- unit_id ZA_district_breedekloof: Breedekloof (district), OBJECTID 16, district Breedekloof, region Breede River Valley. Area 1019.7 km2 (attribute 1019.17), after simplification 1020.0 km2; Hausdorff 95 m; 1 part(s); valid True. Difference from the 2018 SAWIS embedded map: 0.0 of area (symmetric difference). Overlap with other units of the same layer: none. Wards of this district inside it (share of each ward): {'Slanghoek': 1.0, 'Goudini': 0.9999}.

## Judgement calls
- Added (optional in the brief). Grape order by SAWIS hectares 2025 (Breedekloof information region, 12,664 ha): Chenin Blanc 2,739, Colombar 1,784, Sauvignon Blanc 1,772, Pinotage 921, Chardonnay 729, Shiraz 680 (read by a research subagent).
- Summary: river valley soils over river stones and sand (WOSA "a bed of river stones", wineanorak "washed out sand and sandstone with pebbles", both checked in raw text; Wineland); high rainfall (wineanorak "more rain than neighbouring regions", checked; Wineland "about 700 mm", re-fetched); major source of Chenin Blanc (Wineland "the home of Chenin Blanc", re-fetched; wineanorak; SAWIS).
- Style rule: every claim in the summary, scores and grape notes has two independent sources (one organisation counts once: Wine Australia covers wineaustralia.com, australianwine.com and its Region Snapshots; WOSA covers all wosa.co.za pages). Quotes were gathered by research subagents (some read raw HTML or PDF text, some through WebFetch's summariser); several key quotes were re-checked by me against raw page text on 2026-11-21. Score mapping: low 1 to 2, medium 3, high 4, full bodied 5; null where fewer than two sources give a level or sources conflict.

## Held back
- Share of national Chenin: conflict (wineanorak one fifth, Wineland 24.3% of grapes, SAWIS area about 17%). Not stated.
- Pinotage descriptors: one low quality source. Cold winters and late harvest: wineanorak only. Pairing: none.
