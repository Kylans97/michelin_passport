# long-island: Long Island AVA (New York)

**Unit:** US_AVA_long_island, **27 CFR 9.170**: "made up of the counties of Nassau and Suffolk, New York, including all off shore islands in those counties", about 1,170 sq mi (3,030 km²). Established by T.D. ATF-453 (66 FR 26791, 15 May 2001); never amended.

## Why the geometry is not TTB's polygon
TTB's feature (OBJECTID 154) is 7,311.6 km²: it follows the county lines out into the water (Census total area of the two counties incl. water is 7,321 km²). The CFR's own stated size, 3,030 km², matches the counties' land (Census ALAND 2,359.3 + 737.0 = 3,096 km²), and the UC Davis digitisation is 3,142.7 km². Since the AVA is defined as the two counties, I used the official shoreline-clipped county outlines instead:
- US Census Bureau cartographic boundary counties, 1:500,000, January 1, 2024 vintage, via TIGERweb `Generalized_ACS2024/State_County/MapServer/11`, GEOID 36059 (Nassau) and 36103 (Suffolk); public domain US government work. Downloaded 2026-11-21 (`raw/census/cb_ny_36059_36103.geojson`), dissolved, simplified as above.
- Output 3,789.3 km², 4 parts (main island plus offshore islands), 476 vertices. It is about 690 km² more than the Census land area, so the generalised 500k outline must include some inshore water; not investigated further. It is 21% larger than the UC Davis outline and about half the TTB one; judgement call, flag if TTB's own polygon is wanted instead.
- Data quirk logged: TTB's attributes have Long Island's `Within` as "North Fork of Long Island, The Hamptons Long Island", i.e. reversed. Geometry and CFR show the two are sub-AVAs of Long Island.
- Sub-AVAs: North Fork of Long Island (9.113, 1986) and The Hamptons, Long Island (9.101, 1985), both wholly inside.

## Why Long Island and not Virginia
"Virginia" is a state, not an AVA; its AVAs (Monticello, Middleburg Virginia, Virginia's Eastern Shore, Virginia Peninsula and others) are each small and none stands for the state. Long Island is one AVA, has an official definition, a clean official geometry, a regional body (Long Island Wine Country) and a state body (New York Wine & Grape Foundation) with acreage by grape, plus independent guides. So Long Island was chosen; Virginia held back.

## Style evidence
- Summary: Nassau and Suffolk, water moderating temperature, sandy glacial soils (Wikipedia, which draws on the TTB final rule); cool maritime climate, wines "restrained, intense in aroma, and crisp" (Long Island Wine Country trade page); Atlantic influence (NYWGF one sheet); maritime climate, sandy soils, Bordeaux grapes flagship (Wine Folly New York guide).
- Grapes and order: NYWGF one sheet acreage: Merlot 658 acres, Chardonnay 440, Cabernet Franc 215, Cabernet Sauvignon 143, Pinot Noir 87, Sauvignon Blanc 82. Long Island Wine Country FAQ lists the same grapes.
- red_acidity 4: Wine Folly says the Bordeaux reds have "high levels of refreshing acidity"; Long Island Wine Country calls the wines crisp. Body and tannin null: Wine Folly says lighter bodies, but NYWGF describes Cabernet Sauvignon as highly tannic and full bodied and Cabernet Franc as light in tannin, so no single rating is supported.
- Label note: federal 85% rule (27 CFR 4.25(e)(3)); Long Island Wine Country states the same 85% for the Long Island AVA.
