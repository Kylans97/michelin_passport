# Cederberg (ward, no district): ZA_ward_cederberg

## Official hierarchy position
SAWIS Feb 2026: Greater Cape > Western Cape (geographical unit), with no overarching region, region, subregion or district: Cederberg (ward). The dataset attributes District and Region are "None", matching.

## Official text
Defining notice not located in this round.

## Boundary dataset
- Layer `Wards20260626` (layer 1) of the ArcGIS FeatureServer "WINE OF ORIGIN SYSTEM 20260626", https://services-eu1.arcgis.com/u4YTgbzxcollBKYL/arcgis/rest/services/WINE_OF_ORIGIN_SYSTEM_20260626/FeatureServer (item d038d5ed1b9e4e54b86be7da14cf97fb, owner heinrich_vinpro, 26 June 2026): boundaries "as demarcated under the Wine of Origin Scheme administered by SAWIS", maintained by VinPro with SAWIS. The same layer the earlier session used.
- Re-fetched 2026-11-21 into `raw/za/`; feature content identical to the 2026-11-20 copy for all six layers.
- **Licence: none stated** (licenseInfo and accessInformation empty). Public item. Must be cleared with SAWIS/VinPro before shipping, as before.
- Status: no gazetted geometry exists; Wine of Origin schedules are written metes and bounds descriptions. This is the scheme administrator's published map, not a legal instrument. Its 2018 predecessor is the map SAWIS embeds on its own Production Areas page (item 77d24f54b9424c69b9a650242d3ceb21).
- The dataset matches SAWIS, *Production areas defined in terms of the Wine of Origin Scheme*, February 2026 (https://www.sawis.co.za/cert/download/Production_areas_-_Eng_&_Afr_-_Feb26.pdf).
- Processing: make_valid, Douglas Peucker 100 m in a local equirectangular metre projection (lat0 -33.8), topology preserved, coordinates rounded to 5 decimals.

## Unit
- unit_id ZA_ward_cederberg: Cederberg (ward), OBJECTID 12, district None, region None. Area 144.5 km2 (attribute 14437.04), after simplification 144.5 km2; Hausdorff 71 m; 1 part(s); valid True. Difference from the 2018 SAWIS embedded map: 0.0001 of area (symmetric difference). Overlap with other units of the same layer: none.

## Judgement calls
- Summary: remote and among the highest vineyards (WOSA, checked in raw text; Cederberg Wines; Decanter; The Buyer), about 1,000 m (Cederberg Wines 950 to 1,100 m; Decanter; The Buyer "over 1000 metres"); frost (Decanter, The Buyer).
- Grapes: Shiraz, Cabernet Sauvignon and Chenin Blanc are named by both WOSA and The Buyer. No statistic; order not established.
- Caveat: the ward is essentially one main producer (Cederberg Wines), so press sources describe the same estate.
- Style rule: every claim in the summary, scores and grape notes has two independent sources (one organisation counts once: Wine Australia covers wineaustralia.com, australianwine.com and its Region Snapshots; WOSA covers all wosa.co.za pages). Quotes were gathered by research subagents (some read raw HTML or PDF text, some through WebFetch's summariser); several key quotes were re-checked by me against raw page text on 2026-11-21. Score mapping: low 1 to 2, medium 3, high 4, full bodied 5; null where fewer than two sources give a level or sources conflict.

## Held back
- Sauvignon Blanc: WOSA only as a key wine. Snow, the 22°C day night swing and soils: one source each. Red descriptors and pairing: none.
