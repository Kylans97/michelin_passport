# anderson-valley: Anderson Valley AVA

**Unit:** US_AVA_anderson_valley, TTB OBJECTID 65, **27 CFR 9.86** (T.D. ATF-139, 48 FR 37370, 18 Aug 1983, never amended). Source 231.9 km², output 231.9 km² (0.14%), 1 part, 31 vertices, valid.
- Cross-check: UC Davis (one version) 234.2 km²; symmetric difference 2.46 km², of which 2.2 km² is one UC Davis only sliver along the south east straight line segment. The CFR boundary is straight lines between benchmarks and hilltops; both are digitisations of the same text, TTB used as the regulator's data.
- Inside Mendocino and North Coast AVAs; partially overlaps Mendocino Ridge (TTB attribute; 21% of Anderson Valley lies inside the Mendocino Ridge outline). No sub-AVAs.

## Style evidence
- Summary: Navarro River opening to the Pacific, fog and sea breezes (North Bay Business Journal 2023; Wine Anorak, Jamie Goode 2023; Decanter, Stephen Brook; Anderson Valley Winegrowers Association).
- Grapes: Pinot Noir 69%, Chardonnay 21% (Wine Anorak); Pinot Noir and Chardonnay dominate, Gewürztraminer and Riesling kept by a handful of wineries (NBBJ); Decanter names Riesling and Gewürztraminer as Navarro's stars.
- red_acidity 4: "preserves high acidity" in Pinot Noir and Chardonnay (AVWA), "fresh, lively acidity" (NBBJ), Pinot "fresher than more heavyweight styles" (Decanter). Body null: Decanter also notes powerful Pinots.
- Held back: Chardonnay "mostly for sparkling" (one ambiguous quote).

## Dataset (all five US AVAs)
TTB AVA Map Explorer feature service `AVAs_Production/FeatureServer/0` (layer `AVA_Polygons_gen2pt5m_WMAS`), catalogued on data.gov (publisher TTB, CC0 1.0); informational, the 27 CFR part 9 text prevails.
- Version: layer `dataLastEditDate` 2026-10-27 15:21 UTC (`raw/ttb/layer.json`). Downloaded 2026-11-21 (this round): all 282 `Status='Established'` features (count checked, `raw/ttb/count.json`), `outSR=4326`; same OBJECTID/name set as round 4's download.
- CFR check: each section read from eCFR (title 27 up to date as of 2026-11-19, point in time 2026-11-13), `raw/ecfr/`. The TTB `Area` attribute is not in km² (ratio about 1.6 to the geodesic area) and is not used.
- Cross-check: UC Davis AVA project (github.com/UCDavisLibrary/ava, CC0, HEAD a00174d, 2026-10-15), current version, `raw/ucd/`.
- Processing (`na_asia_tools/us_build.py`, from round 4's builder): no editing or tracing; 100 m simplification in a local metric frame, slivers under 0.01 km² dropped, made valid, coordinates rounded to 5 decimals. Areas geodesic on the authalic sphere. Sub-AVA containment checked against the same layer (`na_asia_tools/us_check.py`).
- Label rule: 27 CFR 4.25(e)(3), `raw/ecfr/s4.25.xml`.
