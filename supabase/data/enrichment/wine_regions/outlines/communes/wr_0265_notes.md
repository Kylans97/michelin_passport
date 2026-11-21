# santa-lucia-highlands: Santa Lucia Highlands AVA

**Unit:** US_AVA_santa_lucia_highlands, TTB OBJECTID 124, **27 CFR 9.139**. Source 83.9 km², output 84.0 km² (simplification symmetric difference 1.1%, the strip is narrow), 1 part, 46 vertices, valid.
- Established T.D. ATF-321 (57 FR 20764, 15 May 1992); realigned T.D. TTB-49 (2006); boundary with Arroyo Seco modified T.D. TTB-172 (86 FR 47379, 25 Aug 2021), correction 23 Sep 2021 (Federal Register API, `raw/fr/fr_search_slh.json`).
- Cross-check: UC Davis current version valid from 2021-09-24 (includes the 2021 change), 83.5 km²; symmetric difference with TTB 1.09 km², largest piece 0.4 km². Wholly inside Monterey and Central Coast AVAs. No sub-AVAs.

## Style evidence
- Summary: east facing benchland above the Salinas Valley, fog and afternoon wind from Monterey Bay (SLH Wine Artisans climate page; Wine Industry Advisor 2020; Wikipedia; Decanter, Clive Pursehouse).
- Grapes: Wine Industry Advisor gives Pinot Noir 55%, Chardonnay 35%, rest Syrah, Riesling, Pinot Gris; SLH Wine Artisans: Pinot Noir and Chardonnay dominate, Syrah and Riesling next. Pinot Gris held back (one source).
- red_acidity 4: "vibrant, mouthwatering acidity" (SLH Wine Artisans) and "higher acidity"/"great retention of acidity" (Wine Industry Advisor). Body and tannin null: only winemaker quotes.
- Wikipedia's "about half planted to Pinot noir" not used as a figure (single source, dated).

## Dataset (all five US AVAs)
TTB AVA Map Explorer feature service `AVAs_Production/FeatureServer/0` (layer `AVA_Polygons_gen2pt5m_WMAS`), catalogued on data.gov (publisher TTB, CC0 1.0); informational, the 27 CFR part 9 text prevails.
- Version: layer `dataLastEditDate` 2026-10-27 15:21 UTC (`raw/ttb/layer.json`). Downloaded 2026-11-21 (this round): all 282 `Status='Established'` features (count checked, `raw/ttb/count.json`), `outSR=4326`; same OBJECTID/name set as round 4's download.
- CFR check: each section read from eCFR (title 27 up to date as of 2026-11-19, point in time 2026-11-13), `raw/ecfr/`. The TTB `Area` attribute is not in km² (ratio about 1.6 to the geodesic area) and is not used.
- Cross-check: UC Davis AVA project (github.com/UCDavisLibrary/ava, CC0, HEAD a00174d, 2026-10-15), current version, `raw/ucd/`.
- Processing (`na_asia_tools/us_build.py`, from round 4's builder): no editing or tracing; 100 m simplification in a local metric frame, slivers under 0.01 km² dropped, made valid, coordinates rounded to 5 decimals. Areas geodesic on the authalic sphere. Sub-AVA containment checked against the same layer (`na_asia_tools/us_check.py`).
- Label rule: 27 CFR 4.25(e)(3), `raw/ecfr/s4.25.xml`.
