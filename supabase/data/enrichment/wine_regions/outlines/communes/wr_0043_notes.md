# Walker Bay (district): drawn

## Official hierarchy position
SAWIS, *Production areas defined in terms of the Wine of Origin Scheme*, February 2026 (https://www.sawis.co.za/cert/download/Production_areas_-_Eng_&_Afr_-_Feb26.pdf): Greater Cape (overarching geographical unit) > Western Cape (geographical unit) > Cape Coast > Cape South Coast > Walker Bay (district).

## Official text
- Instrument: Board Notice 59 of 2004, Government Gazette 26374, 28 May 2004: https://www.gov.za/sites/default/files/gcis_document/201409/26374h0.pdf
- Wine of Origin Scheme: Government Notice R. 1434 of 29 June 1990, made under section 14 of the Liquor Products Act 60 of 1989; areas are defined by the Wine and Spirit Board under section 6 of the Scheme.
- Text: "... amends the definition of the area known as Walker Bay (ward) to Walker Bay (district) with the same definition as set out in Board Notice 12 of 30 January 2004." Board Notice 12 of 2004 (the schedule) was NOT located online. Ward notices inside it (Hemel-en-Aarde Valley, Upper Hemel-en-Aarde Valley: Board Notices 88/89 of 2006 with correction 116 of 2006; Hemel-en-Aarde Ridge amendment 617 of 2024) are metes and bounds descriptions.
- How the area is defined: Unknown for the district schedule (not located); the ward schedules are metes and bounds. It is not built from municipal wards, local municipalities or any current administrative unit, so no Municipal Demarcation Board layer can stand in for it.

## Dataset used
- Layer: `Districts20260626` (layer 2) of the ArcGIS FeatureServer "WINE OF ORIGIN SYSTEM 20260626", https://services-eu1.arcgis.com/u4YTgbzxcollBKYL/arcgis/rest/services/WINE_OF_ORIGIN_SYSTEM_20260626/FeatureServer
  (ArcGIS Online item d038d5ed1b9e4e54b86be7da14cf97fb, owner heinrich_vinpro, created/modified 26 June 2026). Item description: boundaries "as demarcated under the Wine of Origin Scheme administered by SAWIS", "Maintained by VinPro in collaboration with SAWIS", WGS 84.
- Retrieved 2026-11-20 as GeoJSON (outSR 4326); raw copy in `za/raw/vinpro_wo_20260626/`.
- Licence: none stated (licenseInfo and accessInformation empty). Public item. **Licence must be cleared with SAWIS/VinPro before shipping.**
- Date: service 2026-06-26; it matches SAWIS's Feb 2026 list of production areas (all 32 districts and 102 wards present).

## Judgement calls
1. **Is this an "official" boundary?** No gazetted geometry exists: every schedule read is a written description on 1:50 000 sheets. The only machine-readable WO boundaries found are VinPro's. The case for using them: SAWIS's own *Production Areas & Maps* page (https://www.sawis.co.za/cert/productionareas.php) embeds an ArcGIS web map, item 77d24f54b9424c69b9a650242d3ceb21 "WVO stelsel" (Wine of Origin system), owned by the same VinPro author, dated 10 Oct 2018. The 2026 service is its update. For this unit the 2026 polygon differs from the SAWIS-embedded 2018 polygon by 0.40% of its area (symmetric difference), so the SAWIS-published map and the dataset used agree. VinPro is the producers' organisation, not the regulator: treat this as the scheme administrator's published map, not a legal instrument. Flag for the product owner.
2. Not used: CapeFarmMapper / Western Cape DoA services need a token (gis.westerncape.gov.za/server3 returned "Token Required"); WCG portal search for wine/origin found no WO layer. Two older community web maps (patmccarthy681, 2016) ignored. No GADM/OSM used. Nothing digitised.
3. Simplification: Douglas-Peucker 100 m in a local equirectangular metre projection (lat0 -33.8), topology preserved; Hausdorff distance to the source 98 m; area 840.2 km2 before and after (no change beyond 0.5%). Coordinates rounded to 5 decimals.
4. Checks: geometry valid; one polygon; contains the town it is named after; all wards listed by SAWIS for this district lie inside it (>=98.9% of each ward area); no overlap with neighbouring districts beyond slivers <0.01% of area.
5. unit_id uses a slug: the dataset has no official code (OBJECTID is a row number, not a code).

## Style content
Sources were gathered with the help of research subagents; the Wine Folly Pinotage and Decanter China Franschhoek quotes were re-fetched and confirmed by me, the rest are quoted as the subagents reported them. Reachability problems: wine-searcher.com, JancisRobinson.com, Wine Enthusiast, ckbk (Oxford Companion) all returned 403. Off-list press used: wineanorak.com (Jamie Goode), winemag.co.za, Vinography, Dr Vino, Vinepair.

Summary: "A cool coastal district around Hermanus, cooled by winds off the cold ocean, on largely shale soils. Chardonnay and Pinot Noir from the Hemel-en-Aarde valleys lead."
Sources: https://www.wosa.co.za/The-Industry/Winegrowing-Areas/Winelands-of-South-Africa/, https://wineanorak.com/southafrica/hemelenaarde1intro.htm, https://www.guildsomm.com/public_content/features/articles/b/morgan_harris/posts/south-africa-how-i-learned-to-stop-worrying-and-love-the-bomb

## Held back
- Soils: CONFLICT. WOSA ('weathered shales') and wineanorak ('clay-rich Bokkeveld shales') vs GuildSomm ('clay-limestone complexes'); the Upper Valley is sandstone and decomposed granite (wineanorak). Summary says 'largely shale', the two-source reading; flag for review.
- Which grape the area does best: CONFLICT (GuildSomm and a JancisRobinson headline favour Chardonnay; wineanorak 'a particular talent for Pinot Noir'). Order Chardonnay, Pinot Noir follows WOSA and GuildSomm.
- Pinot Noir 'without much tannin' (wineanorak) and freshness (GuildSomm) are one source each. Ratings null.
- Pinotage, Sauvignon Blanc, Merlot, Shiraz: WOSA only. Not listed.
- Pairing: generic Pinot Noir pairing only (Wine Folly). Not used.
