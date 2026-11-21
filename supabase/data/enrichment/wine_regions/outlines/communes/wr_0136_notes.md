# russian-river-valley: Russian River Valley AVA

**Unit:** US_AVA_russian_river_valley, TTB OBJECTID 48, **27 CFR 9.66**. Source 675.0 km², output 675.2 km² (0.38%), 1 part (a zero-area second part in the TTB MultiPolygon was dropped), 127 vertices.
- Established by T.D. ATF-159 (48 FR 48813, 21 Oct 1983); amended 1987, 2003, 2005, 2011, and by T.D. TTB-196 (89 FR 87936, 6 Nov 2024).
- Near-miss checked: the 2024 amendment is FR doc 2024-23662, "Technical Corrections to the TTB Regulations". Its table changes only a typo in 9.66(c)(29) ("Vally" to "Valley"), so it does not move the boundary (`raw/fr/2024-23662.txt`, line 790).
- Cross-check: UC Davis current version (valid from 2011-12-16) 691.3 km²; symmetric difference 17.0 km² (2.5%). Not investigated further; both digitise the same 2011 text. TTB's own polygon used.
- Sub-AVAs (wholly inside, by geometry and TTB attributes): Chalk Hill (9.52, 1983) and Green Valley of Russian River Valley (9.57, 1983). RRV partly overlaps Alexander Valley and Sonoma Coast (TTB attribute).

## Style evidence
- Summary: 10 miles from the Pacific, fog, diurnal swing preserving acidity, over 70% Chardonnay and Pinot Noir (Russian River Valley Winegrowers, climate and varietals pages); fog, 35 to 40 °F swing, higher acidity (Wikipedia).
- Grapes: Chardonnay about 42%, Pinot Noir about 29% (RRV Winegrowers; Wikipedia quotes the same body, so Sonoma County Winegrowers, 19 Oct 2022, is the independent second source for both grapes being central). Zinfandel: RRV Winegrowers and Sonoma County Winegrowers (old vines on the Santa Rosa Plain).
- Ratings null: Sonoma County Winegrowers calls one neighbourhood's Pinot "moderate acidity" while Wikipedia says higher acidity overall; sources disagree, so nothing is rated.
## Dataset (US AVAs except Long Island)
TTB's AVA Map Explorer feature service, `AVAs_Production/FeatureServer/0` (layer `AVA_Polygons_gen2pt5m_WMAS`), https://services7.arcgis.com/ykuAbKu9MbV93nAe/arcgis/rest/services/AVAs_Production/FeatureServer/0. Catalogued on data.gov (https://catalog.data.gov/dataset/ava-map-explorer, publisher TTB, CC0 1.0). Disclaimer on the item: informational only; the 27 CFR part 9 text prevails.
- Version: layer `dataLastEditDate` 1793114489242 = 2026-10-27 15:21 UTC (`raw/ttb/layer.json`). Downloaded 2026-11-21: all 282 `Status='Established'` features in one query (count checked, `raw/ttb/count.json`), reprojected server side with `outSR=4326`.
- CFR check: each section read from eCFR, title 27 up to date as of 2026-11-19, point-in-time 2026-11-13 (`raw/ecfr/`).
- Cross-check: UC Davis AVA project (https://github.com/UCDavisLibrary/ava, CC0, HEAD a00174d, 2026-10-15), current version per AVA (`raw/ucd/`).
- Processing (`tools/build.py`): no editing or tracing. Simplified with a 100 m tolerance in a local equirectangular metric frame, zero-area slivers dropped, made valid, coordinates rounded to 5 decimals (about 1 m). Areas are geodesic on the authalic sphere.
- 85% label rule: 27 CFR 4.25(e)(3), read from eCFR (`raw/ecfr/s4.25.xml`).
