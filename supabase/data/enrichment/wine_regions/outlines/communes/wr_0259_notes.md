# Hemel-en-Aarde (three wards, Walker Bay district): ZA_ward_hemel-en-aarde-valley, ZA_ward_upper-hemel-en-aarde-valley, ZA_ward_hemel-en-aarde-ridge

## Official hierarchy position
SAWIS Feb 2026: Greater Cape > Western Cape > Cape Coast > Cape South Coast > Walker Bay (district) > wards Hemel-en-Aarde Ridge, Hemel-en-Aarde Valley (Hemel-en-Aarde Vallei), Upper Hemel-en-Aarde Valley (Bo Hemel-en-Aarde Vallei). "Hemel-en-Aarde" alone is not a production area.

## Official text
- Board Notice 116 of 2006 (Government Gazette 29319) corrects the English versions of Board Notices 88 and 89 of 2006, which define Upper Hemel-en-Aarde Valley and Hemel-en-Aarde Valley: https://www.gov.za/sites/default/files/gcis_document/201409/29319j0.pdf (raw `raw/za/gazette/29319j0.pdf`). Metes and bounds descriptions.
- Hemel-en-Aarde Ridge: added in 2009 (wineanorak); the earlier session noted an amendment, Board Notice 617 of 2024. Neither notice was read in this round.

## Boundary dataset
- Layer `Wards20260626` (layer 1) of the ArcGIS FeatureServer "WINE OF ORIGIN SYSTEM 20260626", https://services-eu1.arcgis.com/u4YTgbzxcollBKYL/arcgis/rest/services/WINE_OF_ORIGIN_SYSTEM_20260626/FeatureServer (item d038d5ed1b9e4e54b86be7da14cf97fb, owner heinrich_vinpro, 26 June 2026): boundaries "as demarcated under the Wine of Origin Scheme administered by SAWIS", maintained by VinPro with SAWIS. The same layer the earlier session used.
- Re-fetched 2026-11-21 into `raw/za/`; feature content identical to the 2026-11-20 copy for all six layers.
- **Licence: none stated** (licenseInfo and accessInformation empty). Public item. Must be cleared with SAWIS/VinPro before shipping, as before.
- Status: no gazetted geometry exists; Wine of Origin schedules are written metes and bounds descriptions. This is the scheme administrator's published map, not a legal instrument. Its 2018 predecessor is the map SAWIS embeds on its own Production Areas page (item 77d24f54b9424c69b9a650242d3ceb21).
- The dataset matches SAWIS, *Production areas defined in terms of the Wine of Origin Scheme*, February 2026 (https://www.sawis.co.za/cert/download/Production_areas_-_Eng_&_Afr_-_Feb26.pdf).
- Processing: make_valid, Douglas Peucker 100 m in a local equirectangular metre projection (lat0 -33.8), topology preserved, coordinates rounded to 5 decimals.

## Units
- unit_id ZA_ward_hemel-en-aarde-valley: Hemel-en-Aarde Valley (ward), OBJECTID 42, district Walker Bay, region Cape South Coast. Area 16.6 km2 (attribute 1659.01), after simplification 16.5 km2; Hausdorff 48 m; 1 part(s); valid True. Difference from the 2018 SAWIS embedded map: 0.0005 of area (symmetric difference). Overlap with other units of the same layer: none. Share inside its district polygon: 0.9987.
- unit_id ZA_ward_upper-hemel-en-aarde-valley: Upper Hemel-en-Aarde Valley (ward), OBJECTID 43, district Walker Bay, region Cape South Coast. Area 33.1 km2 (attribute 3307.87), after simplification 33.4 km2; Hausdorff 96 m; 1 part(s); valid True. Difference from the 2018 SAWIS embedded map: 0.0206 of area (symmetric difference). Overlap with other units of the same layer: none. Share inside its district polygon: 0.9997.
- unit_id ZA_ward_hemel-en-aarde-ridge: Hemel-en-Aarde Ridge (ward), OBJECTID 53, district Walker Bay, region Cape South Coast. Area 10.3 km2 (attribute 1030.55), after simplification 10.2 km2; Hausdorff 97 m; 1 part(s); valid True. Difference from the 2018 SAWIS embedded map: 0.0446 of area (symmetric difference). Overlap with other units of the same layer: none. Share inside its district polygon: 1.0.
- All three nest inside the existing Walker Bay unit (>=99.87% each), as intended. The Ridge differs from the 2018 map by 4.5%, consistent with a later amendment.

## Judgement calls
- One region of three ward units, slug hemel-en-aarde; CSV has three rows. The region alias "Hemel en Aarde" is the unhyphenated spelling used by wineanorak.
- Grape order follows WOSA ("Chardonnay and Pinot Noir"), as the earlier Walker Bay entry did. No official ward statistic exists; The Wine Society's table (Pinot Noir 124 ha, Chardonnay 116 ha) is one source.
- Summary: ocean breezes (WOSA, wineanorak, The Wine Society, Wesgro); higher rainfall (wineanorak, The Wine Society); clay rich shale near the sea, sandstone and granite inland (wineanorak, The Wine Society); Chardonnay and Pinot Noir (four sources).
- Ward notes: order inland, Valley soils, Upper soils (wineanorak, The Wine Society); Ridge smallest (wineanorak, The Wine Society), highest (The Wine Society, Paul Caputo), coolest (wineanorak, Paul Caputo; Caputo's page is a free preview).
- Pinot Noir "structure": wineanorak and The Wine Society.
- Style rule: every claim in the summary, scores and grape notes has two independent sources (one organisation counts once: Wine Australia covers wineaustralia.com, australianwine.com and its Region Snapshots; WOSA covers all wosa.co.za pages). Quotes were gathered by research subagents (some read raw HTML or PDF text, some through WebFetch's summariser); several key quotes were re-checked by me against raw page text on 2026-11-21. Score mapping: low 1 to 2, medium 3, high 4, full bodied 5; null where fewer than two sources give a level or sources conflict.

## Held back
- Red scores: no two source level for body, acidity or tannin; Hamilton Russell (via wineanorak) calls Pinot low in tannin in general while The Wine Society reports chewier tannins on clay shale. Null.
- Ridge soils "shale dominated", Ridge "largely Pinot Noir", Upper "largest" and "ripens later", elevations: The Wine Society only. Pinotage: WOSA only. Pairing: none. Distances from the sea: unverified.
