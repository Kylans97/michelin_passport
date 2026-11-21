# walla-walla-valley: Walla Walla Valley AVA (Washington and Oregon)

**Unit:** US_AVA_walla_walla_valley, TTB OBJECTID 68, **27 CFR 9.91**. Source 1,289.1 km², output 1,292.1 km² (0.54%), 1 part, 581 vertices. Province column `WA/OR`.
- Established by T.D. ATF-165 (1984; per the UC Davis record and Wikipedia's citation of 49 FR 4374); the eCFR section as it now reads was set out by T.D. ATF-441 (66 FR 11542, 26 Feb 2001), which realigned it with Columbia Valley's eastern boundary. The CFR text says it is entirely within Columbia Valley.
- Cross-check: UC Davis current version (valid from 2001-04-27) 1,310.4 km²; symmetric difference 30.3 km² (2.4%).
- Sub-AVA: The Rocks District of Milton-Freewater (9.249, 2015), wholly inside by geometry and TTB attribute.

## Style evidence
- Summary: straddles Washington and Oregon, rainfall rising toward the Blue Mountains, loess over flood sediments, cobblestones in The Rocks District (Walla Walla Valley Wine Alliance, about the AVA and terroir pages; Washington State Wine Commission AVA page, which also calls it cooler and wetter than a number of Washington's AVAs; Wikipedia).
- Disagreement noted: Alliance gives rainfall 7 to 22 inches, the Commission 9 to 22. The summary gives no figure.
- Grapes and order: Alliance wine region page: Cabernet Sauvignon 36%, Syrah 18%, Merlot 16%, Cabernet Franc 7%, Malbec 4%; The Rocks District 45% Syrah. Commission: top varieties Cabernet Sauvignon, Merlot, Syrah. Wikipedia lists Cabernet Franc among grapes grown. Malbec held back (Alliance only, plus Wikipedia's unranked list).
- Ratings null: no two sources rate the reds.
- Label note uses the federal 85% rule only. Oregon's own labelling rules for wine naming a cross-border AVA were not checked; held back.
## Dataset (US AVAs except Long Island)
TTB's AVA Map Explorer feature service, `AVAs_Production/FeatureServer/0` (layer `AVA_Polygons_gen2pt5m_WMAS`), https://services7.arcgis.com/ykuAbKu9MbV93nAe/arcgis/rest/services/AVAs_Production/FeatureServer/0. Catalogued on data.gov (https://catalog.data.gov/dataset/ava-map-explorer, publisher TTB, CC0 1.0). Disclaimer on the item: informational only; the 27 CFR part 9 text prevails.
- Version: layer `dataLastEditDate` 1793114489242 = 2026-10-27 15:21 UTC (`raw/ttb/layer.json`). Downloaded 2026-11-21: all 282 `Status='Established'` features in one query (count checked, `raw/ttb/count.json`), reprojected server side with `outSR=4326`.
- CFR check: each section read from eCFR, title 27 up to date as of 2026-11-19, point-in-time 2026-11-13 (`raw/ecfr/`).
- Cross-check: UC Davis AVA project (https://github.com/UCDavisLibrary/ava, CC0, HEAD a00174d, 2026-10-15), current version per AVA (`raw/ucd/`).
- Processing (`tools/build.py`): no editing or tracing. Simplified with a 100 m tolerance in a local equirectangular metric frame, zero-area slivers dropped, made valid, coordinates rounded to 5 decimals (about 1 m). Areas are geodesic on the authalic sphere.
- 85% label rule: 27 CFR 4.25(e)(3), read from eCFR (`raw/ecfr/s4.25.xml`).
