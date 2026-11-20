# Swartland (district): drawn

## Official hierarchy position
SAWIS, *Production areas defined in terms of the Wine of Origin Scheme*, February 2026 (https://www.sawis.co.za/cert/download/Production_areas_-_Eng_&_Afr_-_Feb26.pdf): Greater Cape (overarching geographical unit) > Western Cape (geographical unit) > Cape Coast > Coastal Region > Swartland (district).

## Official text
- Instrument: not located (see below)
- Wine of Origin Scheme: Government Notice R. 1434 of 29 June 1990, made under section 14 of the Liquor Products Act 60 of 1989; areas are defined by the Wine and Spirit Board under section 6 of the Scheme.
- Text: Current schedule NOT located online. Amended through the Wellington process (Board Notice 12 of 2011, Gazette 33982) and the Darling extension (Board Notice 121 of 2017, Gazette 40945, which redefines Darling; the 2017 application states that the boundaries of Swartland (district) are amended by that extension). SAWIS (Feb 2026) lists eight wards, one of them (St Helena Bay) in the Cape West Coast subregion.
- How the area is defined: Unknown for the current text (schedule not located); neighbouring Darling and Cape Town schedules are metes and bounds along farms, roads and rivers. It is not built from municipal wards, local municipalities or any current administrative unit, so no Municipal Demarcation Board layer can stand in for it.

## Dataset used
- Layer: `Districts20260626` (layer 2) of the ArcGIS FeatureServer "WINE OF ORIGIN SYSTEM 20260626", https://services-eu1.arcgis.com/u4YTgbzxcollBKYL/arcgis/rest/services/WINE_OF_ORIGIN_SYSTEM_20260626/FeatureServer
  (ArcGIS Online item d038d5ed1b9e4e54b86be7da14cf97fb, owner heinrich_vinpro, created/modified 26 June 2026). Item description: boundaries "as demarcated under the Wine of Origin Scheme administered by SAWIS", "Maintained by VinPro in collaboration with SAWIS", WGS 84.
- Retrieved 2026-11-20 as GeoJSON (outSR 4326); raw copy in `za/raw/vinpro_wo_20260626/`.
- Licence: none stated (licenseInfo and accessInformation empty). Public item. **Licence must be cleared with SAWIS/VinPro before shipping.**
- Date: service 2026-06-26; it matches SAWIS's Feb 2026 list of production areas (all 32 districts and 102 wards present).

## Judgement calls
1. **Is this an "official" boundary?** No gazetted geometry exists: every schedule read is a written description on 1:50 000 sheets. The only machine-readable WO boundaries found are VinPro's. The case for using them: SAWIS's own *Production Areas & Maps* page (https://www.sawis.co.za/cert/productionareas.php) embeds an ArcGIS web map, item 77d24f54b9424c69b9a650242d3ceb21 "WVO stelsel" (Wine of Origin system), owned by the same VinPro author, dated 10 Oct 2018. The 2026 service is its update. For this unit the 2026 polygon differs from the SAWIS-embedded 2018 polygon by 0.02% of its area (symmetric difference), so the SAWIS-published map and the dataset used agree. VinPro is the producers' organisation, not the regulator: treat this as the scheme administrator's published map, not a legal instrument. Flag for the product owner.
2. Not used: CapeFarmMapper / Western Cape DoA services need a token (gis.westerncape.gov.za/server3 returned "Token Required"); WCG portal search for wine/origin found no WO layer. Two older community web maps (patmccarthy681, 2016) ignored. No GADM/OSM used. Nothing digitised.
3. Simplification: Douglas-Peucker 100 m in a local equirectangular metre projection (lat0 -33.8), topology preserved; Hausdorff distance to the source 100 m; area 9900.1 km2 before and after (no change beyond 0.5%). Coordinates rounded to 5 decimals.
4. Checks: geometry valid; one polygon; contains the town it is named after; all wards listed by SAWIS for this district lie inside it (>=98.9% of each ward area); no overlap with neighbouring districts beyond slivers <0.01% of area.
5. unit_id uses a slug: the dataset has no official code (OBJECTID is a row number, not a code).

## Style content
Sources were gathered with the help of research subagents; the Wine Folly Pinotage and Decanter China Franschhoek quotes were re-fetched and confirmed by me, the rest are quoted as the subagents reported them. Reachability problems: wine-searcher.com, JancisRobinson.com, Wine Enthusiast, ckbk (Oxford Companion) all returned 403. Off-list press used: wineanorak.com (Jamie Goode), winemag.co.za, Vinography, Dr Vino, Vinepair.

Summary: "A large, warm and dry district north of Cape Town, with many old bush vines farmed without irrigation. Syrah and Cinsault stand out among the reds, with Chenin Blanc for whites."
Sources: https://www.winespectator.com/articles/abcs-of-south-africa-42847, https://wineanorak.com/?p=7884, https://www.vinography.com/2024/06/tasting-the-swartland-revolution

## Held back
- Body: CONFLICT. WOSA: 'robust, full-bodied red wines'; Vinography and wineanorak describe moderate alcohol, natural acidity and smooth tannins (a style shift). Ratings null.
- 'Fresher' Swartland Revolution style: clearly stated only by Vinography (the 25% new oak cap is in Vinography and Dr Vino 2012). Left out of the summary.
- Grenache and Mourvèdre: Vinography plus producer examples only. Not listed.
- Pinotage: WOSA only. Not listed.
- Old vine Chenin Blanc as a district-wide claim: wineanorak cites one Mullineux wine; Decanter Sadie page seen only as a snippet. The grape is listed (WOSA and wineanorak both name it), and the local note says only 'Old bush vines', which rests on wineanorak and Vinography for the district's bush vines generally.
- Rainfall (100 mm vs 200 to 500 mm) conflicting and unverified. Not used.
- Grape order: no SAWIS variety table reached; by-variety hectares (Chenin 2,332 ha, Syrah 1,871 ha) seen only in an unidentified snippet. Order is not a planting ranking.
- Pairing: none found.
- Geometry: the district polygon includes St Helena Bay ward on the coast (about 940 km2), which makes the district reach west to 17.85 E. That is the official list, not an error.
