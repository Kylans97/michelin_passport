# columbia-valley: Columbia Valley AVA (Washington and Oregon)

**Unit:** US_AVA_columbia_valley, TTB OBJECTID 67, **27 CFR 9.74**. Source 46,613.4 km², output 46,622.9 km² (0.16%), 1 part, 4,907 vertices. Province column `WA/OR`.
- Established by T.D. ATF-190 (49 FR 44897, 13 Nov 1984); amended 1987, 1993, 2001 and by T.D. TTB-136 (81 FR 23161, 20 Apr 2016).
- Cross-check: UC Davis current version (valid from 2016-05-20) 46,624.6 km²; symmetric difference 297 km² (0.6%).
- It wholly contains Walla Walla Valley, which is a separate region in this delivery, so the two features overlap on purpose.

## Sub-AVAs listed
19 established AVAs lie inside it by geometry (≥95% of their area; Lake Chelan 95.5%, the rest 100%), and each is listed as within Columbia Valley by TTB's own `Within` attribute: Yakima Valley; Red Mountain, Rattlesnake Hills, Snipes Mountain, Candy Mountain and Goose Gap (also within Yakima Valley by geometry and TTB attribute); Horse Heaven Hills; Wahluke Slope; Lake Chelan; Naches Heights; Ancient Lakes of Columbia Valley; Walla Walla Valley; The Rocks District of Milton-Freewater; Royal Slope; White Bluffs; The Burn of Columbia Valley; Rocky Reach; Beverly, Washington; Columbia Hills (T.D. TTB-206, 91 FR 53194, 17 Aug 2026). Years in the notes are the year of the first Federal Register rule cited in each eCFR section (Walla Walla Valley's section was rewritten in 2001; its first rule, T.D. ATF-165, was 1984).
- Washington Wine says Yakima Valley has four sub-appellations (Red Mountain, Snipes Mountain, Rattlesnake Hills, Candy Mountain), but TTB's attribute and the geometry also put Goose Gap inside Yakima Valley. I followed TTB; logged as a disagreement, not resolved.
- Wikipedia's count of 18 appellations predates Beverly (2024) and Columbia Hills (2026).

## Style evidence
- Summary: over 99% of Washington's vinifera acreage, rain shadow, loess over flood sediment and basalt (Washington State Wine Commission AVA page and "Grapes, Soil and Sun"); about 99% of acreage, rain shadow, warm days and cool nights keeping acid (Wikipedia).
- Grapes and order: Washington State Wine Commission 2025 Grape Production Report press release (22 Apr 2026): Cabernet Sauvignon 22%, Chardonnay 17%, then Riesling, Syrah, Merlot. That is state level; Columbia Valley holds over 99% of the acreage. The same five are the AVA's "top varieties" on the Commission's AVA page and are listed by Wikipedia.
- Ratings null: the sources speak of ripe fruit and kept acidity for Washington wine in general, not of the reds specifically.
## Dataset (US AVAs except Long Island)
TTB's AVA Map Explorer feature service, `AVAs_Production/FeatureServer/0` (layer `AVA_Polygons_gen2pt5m_WMAS`), https://services7.arcgis.com/ykuAbKu9MbV93nAe/arcgis/rest/services/AVAs_Production/FeatureServer/0. Catalogued on data.gov (https://catalog.data.gov/dataset/ava-map-explorer, publisher TTB, CC0 1.0). Disclaimer on the item: informational only; the 27 CFR part 9 text prevails.
- Version: layer `dataLastEditDate` 1793114489242 = 2026-10-27 15:21 UTC (`raw/ttb/layer.json`). Downloaded 2026-11-21: all 282 `Status='Established'` features in one query (count checked, `raw/ttb/count.json`), reprojected server side with `outSR=4326`.
- CFR check: each section read from eCFR, title 27 up to date as of 2026-11-19, point-in-time 2026-11-13 (`raw/ecfr/`).
- Cross-check: UC Davis AVA project (https://github.com/UCDavisLibrary/ava, CC0, HEAD a00174d, 2026-10-15), current version per AVA (`raw/ucd/`).
- Processing (`tools/build.py`): no editing or tracing. Simplified with a 100 m tolerance in a local equirectangular metric frame, zero-area slivers dropped, made valid, coordinates rounded to 5 decimals (about 1 m). Areas are geodesic on the authalic sphere.
- 85% label rule: 27 CFR 4.25(e)(3), read from eCFR (`raw/ecfr/s4.25.xml`).
