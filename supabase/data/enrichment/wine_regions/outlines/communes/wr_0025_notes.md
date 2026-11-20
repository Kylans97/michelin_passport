# wr_0025: Finger Lakes AVA

**Unit:** US_AVA_finger_lakes, TTB OBJECTID 10, **27 CFR 9.34**. **Area 8,944.9 km²**. Single polygon, 2,278 vertices, valid.

## Dataset (shared by all five regions)
**Used:** TTB's own AVA Map Explorer data — ArcGIS Online item `a1c35b4a3dd2426f911d918aebd8add1` ("AVAs_Production", owner `karen.thornton_ATTB`), feature service
https://services7.arcgis.com/ykuAbKu9MbV93nAe/arcgis/rest/services/AVAs_Production/FeatureServer/0 (layer name `AVA_Polygons_gen2pt5m_WMAS`, stored in Web Mercator 3857; requested with `outSR=4326`, so reprojected to WGS84 by the ArcGIS server). The `gen2pt5m` in the layer name suggests generalisation at 2.5 m; that reading comes from the name only and is not documented.
- Public page: https://www.ttb.gov/regulated-commodities/beverage-alcohol/wine/ava-map-explorer. Catalogue entry: https://catalog.data.gov/dataset/ava-map-explorer (publisher TTB, licence CC0 1.0).
- Item licence text: "There is no fee for downloading the shapefiles and no restrictions on their use." Item and layer disclaimer: the outlines are informational only, and the codified 27 CFR part 9 description takes precedence if the two disagree.
- Version: the layer `dataLastEditDate` is 1793114489242, which is 2026-10-27 UTC. Downloaded 2026-11-20, with all 282 `Status='Established'` features in one query (count checked).
- Raw: `raw/ttb/all_4326.geojson`, `raw/ttb/item.json`, `raw/ttb/layer.json`, `raw/ttb/attrs_all.json` (all 330 rows, including Historic and Pending).

**Why TTB and not UC Davis:** TTB publishes polygons itself. The UC Davis page (https://datalab.ucdavis.edu/digitizing-american-viticultural-areas/) and repo (https://github.com/UCDavisLibrary/ava, CC0, HEAD a00174d, 2026-10-15) don't say TTB uses or endorses that set, and neither TTB page mentions UC Davis. The two sets are separate digitisations of the same CFR text. I kept the UC Davis current-version polygons as a cross-check (`raw/ucd/`). Both are informational. The legal boundary is the CFR text.

**CFR check:** I read each section from eCFR (https://www.ecfr.gov/api/versioner/v1/full/2026-11-13/title-27.xml?part=9&section=…, title 27 up to date as of 2026-11-18; `raw/ecfr/`). The amendment citations match the UC Davis `cfr_revision_history` for the version used, so neither dataset is missing a later boundary amendment.

**Area:** geodesic area of the WGS84 polygon on the authalic sphere, computed by me. The same method gives 4,574.1 km² for the full TIGER Sonoma County polygon against Census ALAND+AWATER of 4,577.4 km². The TTB `Area` attribute was not used: its ratio to the real area varies (×1.30 to ×1.71), so its unit is unknown.

**Coordinates** are rounded to 6 decimals (about 0.1 m). No simplification, tracing or editing.

## Cross-check
UC Davis `finger_lakes` gives 8,952.5 km². The symmetric difference is 33.3 km² (0.4%). The boundary follows roads, the canal and power lines on 1:250,000 maps, so this level of difference is expected. TTB lists 2 sub-AVAs, Cayuga Lake and Seneca Lake. The parent is used.

## Established
- T.D. ATF-113, 47 FR 38518, published **1 September 1982**. Amended by T.D. ATF-249, 52 FR 5956, 27 February 1987.
- Effective date: **not established**. UC Davis `created` and TTB `Established` both give 1982-09-01, which is the publication date. Held back.

## Grape and style statements
- CFR §9.34: **none**. It gives only the maps and the boundary, a 17-step road, canal and rail description.
- 1982 T.D. preamble: **not reviewed** (scan only). Held back.

## Judgement calls
None. Note that the AVA's own landmarks are mid-20th-century (Conrail lines, NY-17 alignment). The digitisers' interpretation of those landmarks is the main source of uncertainty.

## Held back
- Effective date. Grape or style claims from the 1982 T.D. preamble.
