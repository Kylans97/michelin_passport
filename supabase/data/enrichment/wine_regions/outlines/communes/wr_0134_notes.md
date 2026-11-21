# sta-rita-hills: Sta. Rita Hills AVA

**Unit:** US_AVA_sta_rita_hills, TTB OBJECTID 145, **27 CFR 9.162**. Source 144.6 km², output 144.5 km² (symmetric difference from simplifying 0.27%), 1 part, 48 vertices. The TTB feature is a MultiPolygon whose second part has zero area; it was dropped.
- Established by T.D. ATF-454 (66 FR 29479, 31 May 2001) as "Santa Rita Hills"; renamed by T.D. TTB-37 (2005); boundary expanded on its eastern edge by T.D. TTB-141 (81 FR 56504, 22 Aug 2016). TTB attribute `Note`: originally established as "Santa Rita Hills".
- Cross-check: UC Davis current version (valid from 2016-09-21, includes the 2016 expansion) 144.4 km²; symmetric difference with TTB 0.37 km². So the TTB polygon carries the 2016 boundary.
- Context only: about 95% of it lies inside Santa Ynez Valley (TTB lists it as within Santa Ynez Valley and Central Coast). No sub-AVAs.

## Choice
The brief offered Sta. Rita Hills and Santa Maria Valley, or Santa Ynez Valley. I took the first pair: both are cool, Pinot Noir and Chardonnay AVAs with two independent descriptions each. Santa Ynez Valley was not drawn; it would overlap Sta. Rita Hills.

## Style evidence
- Summary: east to west hills and Pacific fog/wind (staritahills.com about page; Wikipedia); Pinot Noir about 65% and Chardonnay nearly 15% (GuildSomm, Fred Swan, 1 Mar 2017); Pinot largest, Chardonnay next (Wine Folly).
- Syrah third: GuildSomm and Wikipedia list it.
- Ratings left null: no two sources rate the reds' body, acidity or tannin. Retail and producer tasting notes were seen but not used.
## Dataset (US AVAs except Long Island)
TTB's AVA Map Explorer feature service, `AVAs_Production/FeatureServer/0` (layer `AVA_Polygons_gen2pt5m_WMAS`), https://services7.arcgis.com/ykuAbKu9MbV93nAe/arcgis/rest/services/AVAs_Production/FeatureServer/0. Catalogued on data.gov (https://catalog.data.gov/dataset/ava-map-explorer, publisher TTB, CC0 1.0). Disclaimer on the item: informational only; the 27 CFR part 9 text prevails.
- Version: layer `dataLastEditDate` 1793114489242 = 2026-10-27 15:21 UTC (`raw/ttb/layer.json`). Downloaded 2026-11-21: all 282 `Status='Established'` features in one query (count checked, `raw/ttb/count.json`), reprojected server side with `outSR=4326`.
- CFR check: each section read from eCFR, title 27 up to date as of 2026-11-19, point-in-time 2026-11-13 (`raw/ecfr/`).
- Cross-check: UC Davis AVA project (https://github.com/UCDavisLibrary/ava, CC0, HEAD a00174d, 2026-10-15), current version per AVA (`raw/ucd/`).
- Processing (`tools/build.py`): no editing or tracing. Simplified with a 100 m tolerance in a local equirectangular metric frame, zero-area slivers dropped, made valid, coordinates rounded to 5 decimals (about 1 m). Areas are geodesic on the authalic sphere.
- 85% label rule: 27 CFR 4.25(e)(3), read from eCFR (`raw/ecfr/s4.25.xml`).
