# Durbanville (ward, Cape Town district): ZA_ward_durbanville

## Official hierarchy position
SAWIS Feb 2026: Greater Cape > Western Cape > Cape Coast > Coastal Region > Cape Town (district) > Durbanville (ward).

## Official text
- Board Notice 55 of 2003 (Gazette 25164) defines production area Durbanville (ward); amended by Board Notice 40 of 2005 (Gazette 27470) and Board Notice 25 of 2007 (Gazette 29716, adds a farm). https://www.gov.za/sites/default/files/gcis_document/201409/25164j0.pdf, .../27470r.pdf, .../29716f.pdf (raw `raw/za/gazette/`, identical to the earlier session's copies). Metes and bounds text; BN 40 of 2005 refers to an earlier BN 87 of 2003 not read here.

## Boundary dataset
- Layer `Wards20260626` (layer 1) of the ArcGIS FeatureServer "WINE OF ORIGIN SYSTEM 20260626", https://services-eu1.arcgis.com/u4YTgbzxcollBKYL/arcgis/rest/services/WINE_OF_ORIGIN_SYSTEM_20260626/FeatureServer (item d038d5ed1b9e4e54b86be7da14cf97fb, owner heinrich_vinpro, 26 June 2026): boundaries "as demarcated under the Wine of Origin Scheme administered by SAWIS", maintained by VinPro with SAWIS. The same layer the earlier session used.
- Re-fetched 2026-11-21 into `raw/za/`; feature content identical to the 2026-11-20 copy for all six layers.
- **Licence: none stated** (licenseInfo and accessInformation empty). Public item. Must be cleared with SAWIS/VinPro before shipping, as before.
- Status: no gazetted geometry exists; Wine of Origin schedules are written metes and bounds descriptions. This is the scheme administrator's published map, not a legal instrument. Its 2018 predecessor is the map SAWIS embeds on its own Production Areas page (item 77d24f54b9424c69b9a650242d3ceb21).
- The dataset matches SAWIS, *Production areas defined in terms of the Wine of Origin Scheme*, February 2026 (https://www.sawis.co.za/cert/download/Production_areas_-_Eng_&_Afr_-_Feb26.pdf).
- Processing: make_valid, Douglas Peucker 100 m in a local equirectangular metre projection (lat0 -33.8), topology preserved, coordinates rounded to 5 decimals.

## Unit
- unit_id ZA_ward_durbanville: Durbanville (ward), OBJECTID 23, district Cape Town, region Coastal Region. Area 86.3 km2 (attribute 8629.83), after simplification 86.5 km2; Hausdorff 99 m; 1 part(s); valid True. Difference from the 2018 SAWIS embedded map: 0.0003 of area (symmetric difference). Overlap with other units of the same layer: none. Share inside its district polygon: 1.0.
- Check: the town centre (my approximate point) falls about 1 km outside the ward polygon; the ward covers the surrounding farmland, not the built up town. Not a defect found in the data.

## Judgement calls
- Grape order: SAWIS gives no ward figure. The SAWIS Cape Town statistical region (Durbanville, Constantia, Philadelphia, Hout Bay) 2025: Sauvignon Blanc 969 ha, Cabernet Sauvignon 349, Merlot 259, Shiraz 245, Chardonnay 190. South African Tourism gives the same order for Durbanville itself (one source). Listed are the grapes WOSA and SA Tourism both name: Sauvignon Blanc, Cabernet Sauvignon, Merlot, Chardonnay.
- Summary: rolling hill slopes, sea breezes, night mists, deep soils (WOSA, checked in raw text; South African Tourism); Sauvignon Blanc signature (WOSA, SA Tourism, Durbanville Wine Valley).
- Style rule: every claim in the summary, scores and grape notes has two independent sources (one organisation counts once: Wine Australia covers wineaustralia.com, australianwine.com and its Region Snapshots; WOSA covers all wosa.co.za pages). Quotes were gathered by research subagents (some read raw HTML or PDF text, some through WebFetch's summariser); several key quotes were re-checked by me against raw page text on 2026-11-21. Score mapping: low 1 to 2, medium 3, high 4, full bodied 5; null where fewer than two sources give a level or sources conflict.

## Held back
- "12 km from the Atlantic": SA Tourism, echoed by a producer; one source. 380 m: WOSA only. Shale derived soils: one source. Pinotage: association only. Red descriptors and pairing: none.
