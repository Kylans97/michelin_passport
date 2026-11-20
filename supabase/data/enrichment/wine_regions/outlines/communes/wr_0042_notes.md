# Elgin (district): drawn

## Official hierarchy position
SAWIS, *Production areas defined in terms of the Wine of Origin Scheme*, February 2026 (https://www.sawis.co.za/cert/download/Production_areas_-_Eng_&_Afr_-_Feb26.pdf): Greater Cape (overarching geographical unit) > Western Cape (geographical unit) > Cape Coast > Cape South Coast > Elgin (district).

## Official text
- Instrument: Board Notice 189 of 2011, Government Gazette 34767, 25 November 2011: https://www.gov.za/sites/default/files/gcis_document/201409/34767bn189.pdf
- Wine of Origin Scheme: Government Notice R. 1434 of 29 June 1990, made under section 14 of the Liquor Products Act 60 of 1989; areas are defined by the Wine and Spirit Board under section 6 of the Scheme.
- Text: "... amends the definition of the area known as Elgin (ward) to Elgin (district) with the same definition as set out in Government Notice No. R. 1031 of 11 May 1990." The 1990 schedule itself (GN R. 1031) was NOT located online.
- How the area is defined: Unknown: the 1990 schedule was not located. It is not built from municipal wards, local municipalities or any current administrative unit, so no Municipal Demarcation Board layer can stand in for it.

## Dataset used
- Layer: `Districts20260626` (layer 2) of the ArcGIS FeatureServer "WINE OF ORIGIN SYSTEM 20260626", https://services-eu1.arcgis.com/u4YTgbzxcollBKYL/arcgis/rest/services/WINE_OF_ORIGIN_SYSTEM_20260626/FeatureServer
  (ArcGIS Online item d038d5ed1b9e4e54b86be7da14cf97fb, owner heinrich_vinpro, created/modified 26 June 2026). Item description: boundaries "as demarcated under the Wine of Origin Scheme administered by SAWIS", "Maintained by VinPro in collaboration with SAWIS", WGS 84.
- Retrieved 2026-11-20 as GeoJSON (outSR 4326); raw copy in `za/raw/vinpro_wo_20260626/`.
- Licence: none stated (licenseInfo and accessInformation empty). Public item. **Licence must be cleared with SAWIS/VinPro before shipping.**
- Date: service 2026-06-26; it matches SAWIS's Feb 2026 list of production areas (all 32 districts and 102 wards present).

## Judgement calls
1. **Is this an "official" boundary?** No gazetted geometry exists: every schedule read is a written description on 1:50 000 sheets. The only machine-readable WO boundaries found are VinPro's. The case for using them: SAWIS's own *Production Areas & Maps* page (https://www.sawis.co.za/cert/productionareas.php) embeds an ArcGIS web map, item 77d24f54b9424c69b9a650242d3ceb21 "WVO stelsel" (Wine of Origin system), owned by the same VinPro author, dated 10 Oct 2018. The 2026 service is its update. For this unit the 2026 polygon differs from the SAWIS-embedded 2018 polygon by 0.09% of its area (symmetric difference), so the SAWIS-published map and the dataset used agree. VinPro is the producers' organisation, not the regulator: treat this as the scheme administrator's published map, not a legal instrument. Flag for the product owner.
2. Not used: CapeFarmMapper / Western Cape DoA services need a token (gis.westerncape.gov.za/server3 returned "Token Required"); WCG portal search for wine/origin found no WO layer. Two older community web maps (patmccarthy681, 2016) ignored. No GADM/OSM used. Nothing digitised.
3. Simplification: Douglas-Peucker 100 m in a local equirectangular metre projection (lat0 -33.8), topology preserved; Hausdorff distance to the source 92 m; area 451.6 km2 before and after (no change beyond 0.5%). Coordinates rounded to 5 decimals.
4. Checks: geometry valid; one polygon; contains the town it is named after; no wards; no overlap with neighbouring districts beyond slivers <0.01% of area.
5. unit_id uses a slug: the dataset has no official code (OBJECTID is a row number, not a code).

## Style content
Sources were gathered with the help of research subagents; the Wine Folly Pinotage and Decanter China Franschhoek quotes were re-fetched and confirmed by me, the rest are quoted as the subagents reported them. Reachability problems: wine-searcher.com, JancisRobinson.com, Wine Enthusiast, ckbk (Oxford Companion) all returned 403. Off-list press used: wineanorak.com (Jamie Goode), winemag.co.za, Vinography, Dr Vino, Vinepair.

Summary: "A high, cool district between about 250 and 500 m in the Hottentots Holland mountains, once mainly apple country. Sauvignon Blanc is the most planted grape, then Chardonnay and Pinot Noir, with some Syrah."
Sources: https://www.wosa.co.za/The-Industry/Winegrowing-Areas/Winelands-of-South-Africa/, https://winemag.co.za/?p=41754, https://www.winesofelgin.co.za/our-story/

## Held back
- CONFLICT on second grape: winemag.co.za gives Chardonnay 15% ahead of Pinot Noir 14.5%; Wines of Elgin gives Chardonnay 18% and Pinot Noir 17% but lists Pinot first; WOSA names Chardonnay first. Both sources put Chardonnay slightly ahead by share, so that order is used; the summary does not rank them strongly.
- Riesling: WOSA only. Not listed.
- Soils (Table Mountain sandstone and Bokkeveld shale): Wines of Elgin only beyond WOSA's 'sandstone' mountains. Left out.
- 'Coolest wine-growing area in South Africa' (winemag.co.za and Wines of Elgin) is a superlative; deliberately softened to 'cool'.
- Reds 'higher acidities ... a particular elegance': winemag.co.za only. Ratings null.
- Pairing: none found.
