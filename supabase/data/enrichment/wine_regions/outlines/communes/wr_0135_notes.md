# santa-maria-valley: Santa Maria Valley AVA

**Unit:** US_AVA_santa_maria_valley, TTB OBJECTID 12, **27 CFR 9.28**. Source 479.2 km², output 478.4 km² (0.28% change), 1 part, 36 vertices.
- Established by T.D. ATF-89 (46 FR 39812, 5 Aug 1981); boundary amended by T.D. TTB-88 (75 FR 81849, 29 Dec 2010).
- Cross-check: UC Davis current version (valid from 2011-01-28) 469.5 km²; symmetric difference 10.96 km² (2.3%). Both are separate digitisations of the 2010 text; the TTB one is used as TTB's own. No sub-AVAs. TTB marks it as partly overlapping Central Coast.

## Style evidence
- Summary: funnel shape opening west to the Pacific, fog, afternoon breezes, longer season (Wikipedia; Wine Folly); fog, wind and marine layer keep acidity (GuildSomm).
- Grapes: Pinot Noir and Chardonnay with Syrah (GuildSomm; Wine Folly). No source ranks Pinot Noir against Chardonnay by area; the order follows GuildSomm's wording and is not a measured ranking.
- Ratings null: GuildSomm and Wine Folly describe acidity mainly for Chardonnay; nothing rates the reds twice.
## Dataset (US AVAs except Long Island)
TTB's AVA Map Explorer feature service, `AVAs_Production/FeatureServer/0` (layer `AVA_Polygons_gen2pt5m_WMAS`), https://services7.arcgis.com/ykuAbKu9MbV93nAe/arcgis/rest/services/AVAs_Production/FeatureServer/0. Catalogued on data.gov (https://catalog.data.gov/dataset/ava-map-explorer, publisher TTB, CC0 1.0). Disclaimer on the item: informational only; the 27 CFR part 9 text prevails.
- Version: layer `dataLastEditDate` 1793114489242 = 2026-10-27 15:21 UTC (`raw/ttb/layer.json`). Downloaded 2026-11-21: all 282 `Status='Established'` features in one query (count checked, `raw/ttb/count.json`), reprojected server side with `outSR=4326`.
- CFR check: each section read from eCFR, title 27 up to date as of 2026-11-19, point-in-time 2026-11-13 (`raw/ecfr/`).
- Cross-check: UC Davis AVA project (https://github.com/UCDavisLibrary/ava, CC0, HEAD a00174d, 2026-10-15), current version per AVA (`raw/ucd/`).
- Processing (`tools/build.py`): no editing or tracing. Simplified with a 100 m tolerance in a local equirectangular metric frame, zero-area slivers dropped, made valid, coordinates rounded to 5 decimals (about 1 m). Areas are geodesic on the authalic sphere.
- 85% label rule: 27 CFR 4.25(e)(3), read from eCFR (`raw/ecfr/s4.25.xml`).
