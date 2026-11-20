# Stellenbosch (district): drawn

## Official hierarchy position
SAWIS, *Production areas defined in terms of the Wine of Origin Scheme*, February 2026 (https://www.sawis.co.za/cert/download/Production_areas_-_Eng_&_Afr_-_Feb26.pdf): Greater Cape (overarching geographical unit) > Western Cape (geographical unit) > Cape Coast > Coastal Region > Stellenbosch (district).

## Official text
- Instrument: Board Notice 37 of 2004, Government Gazette 26164, 26 March 2004: https://www.gov.za/sites/default/files/gcis_document/201409/26164l0.pdf
- Wine of Origin Scheme: Government Notice R. 1434 of 29 June 1990, made under section 14 of the Liquor Products Act 60 of 1989; areas are defined by the Wine and Spirit Board under section 6 of the Scheme.
- Text: "That area situate in the former Divisional Council Area of Stellenbosch including the under-mentioned farms situate in the Administrative District of Paarl: ..." followed by a list of named farm portions (Weltevreden 744, Lievland 1311, Kleinjoostenberg 730, Joostenbergs Vlakte 727, farm 729 ...) "as well as that farms situate south of a boundary drawn, on the topographic map of South Africa 1:50 000, sheet 3318 DD Stellenbosch (fourth edition)" from the Dwars River along farms 1211, 1331 and 1200 to Simonsberg Forest Reserve. Repeals Board Notice 55 of 31 May 2002.
- How the area is defined: A former Divisional Council area (a pre-1990s administrative unit with no current official GIS layer) plus named farm portions and a short map line on a 1:50 000 sheet. It is not built from municipal wards, local municipalities or any current administrative unit, so no Municipal Demarcation Board layer can stand in for it.

## Dataset used
- Layer: `Districts20260626` (layer 2) of the ArcGIS FeatureServer "WINE OF ORIGIN SYSTEM 20260626", https://services-eu1.arcgis.com/u4YTgbzxcollBKYL/arcgis/rest/services/WINE_OF_ORIGIN_SYSTEM_20260626/FeatureServer
  (ArcGIS Online item d038d5ed1b9e4e54b86be7da14cf97fb, owner heinrich_vinpro, created/modified 26 June 2026). Item description: boundaries "as demarcated under the Wine of Origin Scheme administered by SAWIS", "Maintained by VinPro in collaboration with SAWIS", WGS 84.
- Retrieved 2026-11-20 as GeoJSON (outSR 4326); raw copy in `za/raw/vinpro_wo_20260626/`.
- Licence: none stated (licenseInfo and accessInformation empty). Public item. **Licence must be cleared with SAWIS/VinPro before shipping.**
- Date: service 2026-06-26; it matches SAWIS's Feb 2026 list of production areas (all 32 districts and 102 wards present).

## Judgement calls
1. **Is this an "official" boundary?** No gazetted geometry exists: every schedule read is a written description on 1:50 000 sheets. The only machine-readable WO boundaries found are VinPro's. The case for using them: SAWIS's own *Production Areas & Maps* page (https://www.sawis.co.za/cert/productionareas.php) embeds an ArcGIS web map, item 77d24f54b9424c69b9a650242d3ceb21 "WVO stelsel" (Wine of Origin system), owned by the same VinPro author, dated 10 Oct 2018. The 2026 service is its update. For this unit the 2026 polygon differs from the SAWIS-embedded 2018 polygon by 0.02% of its area (symmetric difference), so the SAWIS-published map and the dataset used agree. VinPro is the producers' organisation, not the regulator: treat this as the scheme administrator's published map, not a legal instrument. Flag for the product owner.
2. Not used: CapeFarmMapper / Western Cape DoA services need a token (gis.westerncape.gov.za/server3 returned "Token Required"); WCG portal search for wine/origin found no WO layer. Two older community web maps (patmccarthy681, 2016) ignored. No GADM/OSM used. Nothing digitised.
3. Simplification: Douglas-Peucker 100 m in a local equirectangular metre projection (lat0 -33.8), topology preserved; Hausdorff distance to the source 99 m; area 822.4 km2 before and after (no change beyond 0.5%). Coordinates rounded to 5 decimals.
4. Checks: geometry valid; one polygon; contains the town it is named after; all wards listed by SAWIS for this district lie inside it (>=98.9% of each ward area); no overlap with neighbouring districts beyond slivers <0.01% of area.
5. unit_id uses a slug: the dataset has no official code (OBJECTID is a row number, not a code).

## Style content
Sources were gathered with the help of research subagents; the Wine Folly Pinotage and Decanter China Franschhoek quotes were re-fetched and confirmed by me, the rest are quoted as the subagents reported them. Reachability problems: wine-searcher.com, JancisRobinson.com, Wine Enthusiast, ckbk (Oxford Companion) all returned 403. Off-list press used: wineanorak.com (Jamie Goode), winemag.co.za, Vinography, Dr Vino, Vinepair.

Summary: "Mountain slopes and valleys with deep, well drained soils from granite, shale and sandstone. Known for blended reds and Cabernet Sauvignon, while Syrah and Chenin Blanc also do well."
Sources: https://www.wosa.co.za/The-Industry/Winegrowing-Areas/Winelands-of-South-Africa/, https://www.guildsomm.com/public_content/features/mw-perspectives/b/mw-perspectives/posts/cabernet-in-stellenbosch, https://winefolly.com/deep-dive/wines-south-africas-stellenbosch-district/, https://www.winespectator.com/articles/abcs-of-south-africa-42847

## Held back
- Climate: GuildSomm ('long, warm conditions permit late ripening') is the only reachable source; the False Bay cooling claim was seen only in a search snippet of a JancisRobinson.com page (403). Left out of the summary.
- Red body/tannin: Wine Folly speaks of 'massive tannins' only for Simonsberg reds; GuildSomm speaks of 'elegance, latent power'. No two sources give a district-wide level: all three ratings null.
- Chardonnay and Merlot: one source each (Wine Spectator 2010; Wine Folly). Not listed.
- Grape order: no district-by-variety SAWIS planting table was reachable; the order follows how the sources lead (Cabernet first in both GuildSomm and Wine Spectator), not hectares.
- Planted area 14,933 ha (SAWIS 2021 via winemag.co.za) is a SAWIS statistical 'region' that also includes Cape Town wards; not the WO district. Not used.
- Pairing: no reputable source states a regional pairing.
