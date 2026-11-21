# santa-cruz-mountains: Santa Cruz Mountains AVA

**Unit:** US_AVA_santa_cruz_mountains, TTB OBJECTID 7, **27 CFR 9.31**. Source 1,668.0 km², output 1,661.5 km² (symmetric difference 1.7%, the highest in this set, because the boundary follows the 400 ft and 800 ft contours and is very convoluted), 1 part, 3,095 vertices.
- Established by T.D. ATF-98 (46 FR 59240, 4 Dec 1981); never amended. The CFR boundary follows the 400 ft contour on the ocean side and the 800 ft contour on the bay side (read in `raw/ecfr/s9.31.xml`).
- Cross-check: UC Davis 1,654.0 km²; symmetric difference 19.9 km² (1.2%).
- TTB attribute `Note`: "specifically excluded from the San Francisco Bay AVA and the Central Coast AVA". In TTB's own polygons it nevertheless sits inside both of those outlines. Not relevant to this unit; logged only.
- Sub-AVA: Ben Lomond Mountain (9.118, 1987), wholly inside.

## Style evidence
- Summary: first California appellation defined by its mountain topography, much of it above the fog line, plantings divided evenly among Pinot Noir, Cabernet Sauvignon and Chardonnay (Santa Cruz Mountains Winegrowers Association about page); among the first AVAs defined by mountainous topography, follows the fog line, about 25% each of Pinot Noir, Cabernet Sauvignon, Chardonnay (Wikipedia); cool climate with cool coastal influence, Cabernet, Chardonnay, Pinot Noir and Syrah (Decanter, "Discover Pacific Coast precision in the Santa Cruz Mountains").
- Ratings null. Decanter's tannin and acidity remarks are about Syrah only.
## Dataset (US AVAs except Long Island)
TTB's AVA Map Explorer feature service, `AVAs_Production/FeatureServer/0` (layer `AVA_Polygons_gen2pt5m_WMAS`), https://services7.arcgis.com/ykuAbKu9MbV93nAe/arcgis/rest/services/AVAs_Production/FeatureServer/0. Catalogued on data.gov (https://catalog.data.gov/dataset/ava-map-explorer, publisher TTB, CC0 1.0). Disclaimer on the item: informational only; the 27 CFR part 9 text prevails.
- Version: layer `dataLastEditDate` 1793114489242 = 2026-10-27 15:21 UTC (`raw/ttb/layer.json`). Downloaded 2026-11-21: all 282 `Status='Established'` features in one query (count checked, `raw/ttb/count.json`), reprojected server side with `outSR=4326`.
- CFR check: each section read from eCFR, title 27 up to date as of 2026-11-19, point-in-time 2026-11-13 (`raw/ecfr/`).
- Cross-check: UC Davis AVA project (https://github.com/UCDavisLibrary/ava, CC0, HEAD a00174d, 2026-10-15), current version per AVA (`raw/ucd/`).
- Processing (`tools/build.py`): no editing or tracing. Simplified with a 100 m tolerance in a local equirectangular metric frame, zero-area slivers dropped, made valid, coordinates rounded to 5 decimals (about 1 m). Areas are geodesic on the authalic sphere.
- 85% label rule: 27 CFR 4.25(e)(3), read from eCFR (`raw/ecfr/s4.25.xml`).
