# nova-scotia: Nova Scotia, CA_PR_12

## Official basis
- Nova Scotia Wine Standards Regulations, N.S. Reg. 170/2010 under the Agriculture and Marketing Act, consolidated to N.S. Reg. 358/2015 (`raw/ns/amwinestds.htm`); the Registry's regulations-by-act list (`raw/ns/regsbyact.htm`, 2026-11-21) shows no later amendment. s.16 to 17: "Nova Scotia Wine" (the Nova Scotia Geographical Indicator) needs at least 85% grapes grown in the Province; s.18: "Wines of Nova Scotia" needs 100%. The area is the Province as a whole, so the unit is the province.
- Tidal Bay is an industry standard set by the wineries' association (WANS, now Wine Growers Nova Scotia) in 2011/2012, not in the regulation (no match for "Tidal" in it). It is therefore not listed under appellations; it appears in the summary and pairing only.

## Boundary
- Statistics Canada, 2021 Census cartographic boundary file, provinces (lpr_000b21s_e), PRUID 12, through the StatCan ArcGIS REST service `geo.statcan.gc.ca/geo_wa/rest/services/2021/Cartographic_boundary_files/MapServer/0`, `outSR=4326` (`raw/statcan/pr12_4326.geojson`). Licence: Open Government Licence - Canada (service metadata, `raw/statcan/cbf_service.json`). 2021 is the current cartographic edition used; provincial boundaries are unchanged.
- Processing (`na_asia_tools/build_ns.py`): 3,453 source polygons (all valid), parts under 4 km² dropped (3,429 parts, 198.1 km²), each kept part simplified at 100 m in a local metric frame, snapped 1e-5°, unioned and made valid. Output 23 parts, 55,085.4 km² (source 55,277 km²; StatCan LANDAREA 52,825 km² excludes inland water), 14,620 vertices, valid. Sable Island (about 30 km², far offshore) is part of the province and kept; drop it at display time if wanted.
- Near-miss: the round 4 builder's coordinate lambda multiplies tuples when shapely passes whole coordinate arrays; on small AVAs this fails into shapely's per-point fallback and gives correct output, but on Nova Scotia's 187,820-vertex mainland it exhausted memory. Replaced here by a vectorised `shapely.transform`. US and Japanese outputs were rechecked (areas and validity) and are unaffected.

## Style evidence
- Summary: vineyards near the sea (Wines of Nova Scotia: never more than 20 km from the Atlantic; Decanter, Michaela Morris: surrounded by water, Bay of Fundy moderation); crisp whites and traditional method sparkling (Decanter; Wikipedia; Circle of Wine Writers; Tourism Nova Scotia).
- Grapes: L'Acadie Blanc 30% of production (Decanter), most widely planted (Wikipedia), signature hybrid (CWW); Chardonnay third overall and most planted vinifera (Decanter), "some success" (Wikipedia).
- Pairing: Tidal Bay with seafood (Wines of Nova Scotia; Tourism Nova Scotia).
- Held back: New York Muscat (second most planted) and Maréchal Foch (fourth), Decanter only for ranking and not in the app; Seyval Blanc, Vidal, Geisenheim 318 (Tidal Bay blend grapes, no planting figures).
