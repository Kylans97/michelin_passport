# Robertson (district): ZA_district_robertson

## Official hierarchy position
SAWIS Feb 2026: Greater Cape > Western Cape > Breede River Valley (region) > Robertson (district) > 14 wards: Agterkliphoogte, Ashton, Boesmansrivier, Bonnievale, Eilandia, Goedemoed, Goree, Goudmyn, Hoopsrivier, Klaasvoogds, Le Chasseur, McGregor, Vinkrivier, Zandrivier.

## Official text
Defining notice not located in this round.

## Boundary dataset
- Layer `Districts20260626` (layer 2) of the ArcGIS FeatureServer "WINE OF ORIGIN SYSTEM 20260626", https://services-eu1.arcgis.com/u4YTgbzxcollBKYL/arcgis/rest/services/WINE_OF_ORIGIN_SYSTEM_20260626/FeatureServer (item d038d5ed1b9e4e54b86be7da14cf97fb, owner heinrich_vinpro, 26 June 2026): boundaries "as demarcated under the Wine of Origin Scheme administered by SAWIS", maintained by VinPro with SAWIS. The same layer the earlier session used.
- Re-fetched 2026-11-21 into `raw/za/`; feature content identical to the 2026-11-20 copy for all six layers.
- **Licence: none stated** (licenseInfo and accessInformation empty). Public item. Must be cleared with SAWIS/VinPro before shipping, as before.
- Status: no gazetted geometry exists; Wine of Origin schedules are written metes and bounds descriptions. This is the scheme administrator's published map, not a legal instrument. Its 2018 predecessor is the map SAWIS embeds on its own Production Areas page (item 77d24f54b9424c69b9a650242d3ceb21).
- The dataset matches SAWIS, *Production areas defined in terms of the Wine of Origin Scheme*, February 2026 (https://www.sawis.co.za/cert/download/Production_areas_-_Eng_&_Afr_-_Feb26.pdf).
- Processing: make_valid, Douglas Peucker 100 m in a local equirectangular metre projection (lat0 -33.8), topology preserved, coordinates rounded to 5 decimals.

## Unit
- unit_id ZA_district_robertson: Robertson (district), OBJECTID 5, district Robertson, region Breede River Valley. Area 2088.1 km2 (attribute 2086.36), after simplification 2088.8 km2; Hausdorff 98 m; 1 part(s); valid True. Difference from the 2018 SAWIS embedded map: 0.0132 of area (symmetric difference). Overlap with other units of the same layer: none. Wards of this district inside it (share of each ward): {'Hoopsrivier': 1.0, 'Eilandia': 0.9999, 'Klaasvoogds': 1.0, 'Le Chasseur': 1.0, 'Agterkliphoogte': 1.0, 'Bonnievale': 1.0, 'McGregor': 1.0, 'Boesmansrivier': 1.0, 'Goudmyn': 1.0, 'Ashton': 0.9999, 'Vinkrivier': 1.0, 'Goedemoed': 1.0, 'Goree': 1.0, 'Zandrivier': 1.0}.

## Judgement calls
- Grape order by SAWIS hectares per region and cultivar, 2025 (Robertson information region, 13,010 ha), https://sawis.co.za/info/download/VERSPREIDING_VAN_WYNDRUIF_HEKTAAR_PER_WYNDISTRIK_EN_KULTIVAR_2015-2025_eng.xlsx: Sauvignon Blanc 1,853, Colombar 1,826, Chardonnay 1,746, Chenin Blanc 1,570, Cabernet Sauvignon 1,230, Pinotage 894, Shiraz 859. SAWIS information regions align with but are not identical to WO districts; the statistics book gives 13,067 ha. Read by a research subagent; I did not open the spreadsheet myself.
- Summary: lime rich soils (WOSA, checked; Decanter; The Buyer; Robertson Wine Valley); Breede River irrigation and low rainfall (WOSA, Decanter); south easterly winds (WOSA, Decanter, near identical wording, flagged); Chardonnay and Cap Classique (WOSA, Decanter, The Buyer).
- Chardonnay local note (Cap Classique): WOSA Cape Chatter, The Buyer, Robertson Wine Valley.
- Style rule: every claim in the summary, scores and grape notes has two independent sources (one organisation counts once: Wine Australia covers wineaustralia.com, australianwine.com and its Region Snapshots; WOSA covers all wosa.co.za pages). Quotes were gathered by research subagents (some read raw HTML or PDF text, some through WebFetch's summariser); several key quotes were re-checked by me against raw page text on 2026-11-21. Score mapping: low 1 to 2, medium 3, high 4, full bodied 5; null where fewer than two sources give a level or sources conflict.

## Held back
- Shiraz style: Decanter "Rhône style, peppery" against Wine Folly "richly intense"; conflict, no scores. Fortified Muscadel heritage: WOSA and a producer entry; left out. Under 300 mm rain and Indian Ocean 70 km: WOSA only. Pairing: none.
