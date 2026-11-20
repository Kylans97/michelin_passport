# Constantia (ward): drawn

## Official hierarchy position
SAWIS, *Production areas defined in terms of the Wine of Origin Scheme*, February 2026 (https://www.sawis.co.za/cert/download/Production_areas_-_Eng_&_Afr_-_Feb26.pdf): Greater Cape (overarching geographical unit) > Western Cape (geographical unit) > Cape Coast > Coastal Region > Cape Town (district) > Constantia (ward).

## Official text
- Instrument: Board Notice 179 of 2010, Government Gazette 33812, 3 December 2010: https://www.gov.za/sites/default/files/gcis_document/201409/33812179.pdf
- Wine of Origin Scheme: Government Notice R. 1434 of 29 June 1990, made under section 14 of the Liquor Products Act 60 of 1989; areas are defined by the Wine and Spirit Board under section 6 of the Scheme.
- Text: "That portion of land situate within the following boundaries: Start at the point where Rhodes Avenue (M63) joins the Constantia Neck Road (M41) in the vicinity of Constantia Neck; thence north-east along said Rhodes Avenue ..." along Klaassen, Convent, St John, Waterloos, Alphenhill, Constantia (M41), Spaanschemat River, Orpen and Steenberg (M42) roads to Ou Kaapse Weg (M64), then straight lines to Beacon 66 (Steenberg Koppie) and Beacon 5 on Constantia Mountain and along the watershed back to the start. References the 1:50 000 sheets 3418 AB & AD and 3318 CD and the Cape Town street guide. Repeals GN R 1061 of 26 May 1989.
- How the area is defined: Metes and bounds along named streets, beacons and the mountain watershed. It is not built from municipal wards, local municipalities or any current administrative unit, so no Municipal Demarcation Board layer can stand in for it.

## Dataset used
- Layer: `Wards20260626` (layer 1) of the ArcGIS FeatureServer "WINE OF ORIGIN SYSTEM 20260626", https://services-eu1.arcgis.com/u4YTgbzxcollBKYL/arcgis/rest/services/WINE_OF_ORIGIN_SYSTEM_20260626/FeatureServer
  (ArcGIS Online item d038d5ed1b9e4e54b86be7da14cf97fb, owner heinrich_vinpro, created/modified 26 June 2026). Item description: boundaries "as demarcated under the Wine of Origin Scheme administered by SAWIS", "Maintained by VinPro in collaboration with SAWIS", WGS 84.
- Retrieved 2026-11-20 as GeoJSON (outSR 4326); raw copy in `za/raw/vinpro_wo_20260626/`.
- Licence: none stated (licenseInfo and accessInformation empty). Public item. **Licence must be cleared with SAWIS/VinPro before shipping.**
- Date: service 2026-06-26; it matches SAWIS's Feb 2026 list of production areas (all 32 districts and 102 wards present).

## Judgement calls
1. **Is this an "official" boundary?** No gazetted geometry exists: every schedule read is a written description on 1:50 000 sheets. The only machine-readable WO boundaries found are VinPro's. The case for using them: SAWIS's own *Production Areas & Maps* page (https://www.sawis.co.za/cert/productionareas.php) embeds an ArcGIS web map, item 77d24f54b9424c69b9a650242d3ceb21 "WVO stelsel" (Wine of Origin system), owned by the same VinPro author, dated 10 Oct 2018. The 2026 service is its update. For this unit the 2026 polygon differs from the SAWIS-embedded 2018 polygon by 0.07% of its area (symmetric difference), so the SAWIS-published map and the dataset used agree. VinPro is the producers' organisation, not the regulator: treat this as the scheme administrator's published map, not a legal instrument. Flag for the product owner.
2. Not used: CapeFarmMapper / Western Cape DoA services need a token (gis.westerncape.gov.za/server3 returned "Token Required"); WCG portal search for wine/origin found no WO layer. Two older community web maps (patmccarthy681, 2016) ignored. No GADM/OSM used. Nothing digitised.
3. Simplification: Douglas-Peucker 100 m in a local equirectangular metre projection (lat0 -33.8), topology preserved; Hausdorff distance to the source 99 m; area 33.4 km2 before and after (no change beyond 0.5%). Coordinates rounded to 5 decimals.
4. Checks: geometry valid; one polygon; contains the town it is named after; no wards; no overlap with neighbouring districts beyond slivers <0.01% of area.
5. unit_id uses a slug: the dataset has no official code (OBJECTID is a row number, not a code).

## Style content
Sources were gathered with the help of research subagents; the Wine Folly Pinotage and Decanter China Franschhoek quotes were re-fetched and confirmed by me, the rest are quoted as the subagents reported them. Reachability problems: wine-searcher.com, JancisRobinson.com, Wine Enthusiast, ckbk (Oxford Companion) all returned 403. Off-list press used: wineanorak.com (Jamie Goode), winemag.co.za, Vinography, Dr Vino, Vinepair.

Summary: "Cool, ocean influenced slopes of the Table Mountain range above False Bay, on mainly granite soils. Whites lead, above all Sauvignon Blanc, and the valley is home to the historic sweet wine Vin de Constance."
Sources: https://www.wosa.co.za/The-Industry/Winegrowing-Areas/Winelands-of-South-Africa/, https://constantiawineroute.com/serious-about-sauvignon-constantias-golden-thread/, https://winemag.co.za/wine/opinion/greg-sherwood-mw-celebrating-a-resurgent-constantia-wine-route/, https://www.decanter.com/wine-reviews/south-africa/constantia/klein-constantia-vin-de-constance-constantia-2020-73371, https://www.guildsomm.com/public_content/features/articles/b/morgan_harris/posts/south-africa-how-i-learned-to-stop-worrying-and-love-the-bomb

## Held back
- Local note '180 of 420 ha' is Constantia Wine Route only: set to null in style.json.
- Semillon as Sauvignon Blanc's partner: winemag.co.za only. Not listed.
- Muscat de Frontignan as the grape of Vin de Constance: Decanter review page only. Not listed as a grape; the summary names Vin de Constance only (Decanter, winemag.co.za and GuildSomm).
- Reds 'far more variable' (winemag.co.za only); no body/acidity/tannin words. Ratings null.
- Rainfall about 1,000 mm: WOSA only. Not used.
- Pairing: none found.
- Vin de Constance is a producer's wine name, not an official appellation, so it is not in 'appellations'.
