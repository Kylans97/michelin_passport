# monticello: Monticello AVA (Virginia)

**Unit:** US_AVA_monticello, TTB OBJECTID 243, **27 CFR 9.48** (T.D. ATF-164, 1984; ATF-249 and ATF-255, 1987; expanded into Fluvanna County by T.D. TTB-154, 83 FR 64274, 14 Dec 2018). Source 3,788.0 km², output 3,788.9 km² (0.29%), 1 part, 574 vertices, valid.
- Cross-check: UC Davis current version valid from 2019-01-14 (includes 2018 expansion) 3,792.9 km²; symmetric difference 60 km² (1.6%), in many small pieces; largest 11.3 km² TTB only near 78.73 W 38.19 N (Greene County line / Shenandoah National Park boundary, steps 5 to 6). Logged, TTB used. No sub-AVAs; touches Shenandoah Valley AVA only at the edge.

## Style evidence
- Summary: eastern slopes of the Blue Ridge, cool air through mountain gaps lengthening the season, Jefferson and Mazzei in the 1770s (Wikipedia; Wine Folly Virginia guide).
- Grapes: Cabernet Franc, Chardonnay, Viognier named as most notable by both. Viognier also in WTOP's report of the 2023 Wine Enthusiast award. Order is the order both sources list; no acreage for the AVA found.
- Held back: Petit Manseng and Petit Verdot (named only in lists of many grapes, WTOP and a tourism release); Virginia wide statistics (Wine Folly: Cabernet Franc 14% of Virginia's harvest) not applied to the AVA.

## Dataset (all five US AVAs)
TTB AVA Map Explorer feature service `AVAs_Production/FeatureServer/0` (layer `AVA_Polygons_gen2pt5m_WMAS`), catalogued on data.gov (publisher TTB, CC0 1.0); informational, the 27 CFR part 9 text prevails.
- Version: layer `dataLastEditDate` 2026-10-27 15:21 UTC (`raw/ttb/layer.json`). Downloaded 2026-11-21 (this round): all 282 `Status='Established'` features (count checked, `raw/ttb/count.json`), `outSR=4326`; same OBJECTID/name set as round 4's download.
- CFR check: each section read from eCFR (title 27 up to date as of 2026-11-19, point in time 2026-11-13), `raw/ecfr/`. The TTB `Area` attribute is not in km² (ratio about 1.6 to the geodesic area) and is not used.
- Cross-check: UC Davis AVA project (github.com/UCDavisLibrary/ava, CC0, HEAD a00174d, 2026-10-15), current version, `raw/ucd/`.
- Processing (`na_asia_tools/us_build.py`, from round 4's builder): no editing or tracing; 100 m simplification in a local metric frame, slivers under 0.01 km² dropped, made valid, coordinates rounded to 5 decimals. Areas geodesic on the authalic sphere. Sub-AVA containment checked against the same layer (`na_asia_tools/us_check.py`).
- Label rule: 27 CFR 4.25(e)(3), `raw/ecfr/s4.25.xml`.
