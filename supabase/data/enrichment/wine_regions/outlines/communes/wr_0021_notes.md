# wr_0021: Napa Valley AVA

**Unit:** US_AVA_napa_valley, TTB OBJECTID 2, **27 CFR 9.23**. **Area 1,620.1 km²**. Single polygon, 5,972 vertices, valid.

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
UC Davis `napa_valley` gives 1,620.0 km². The symmetric difference with TTB is 5.3 km² (0.3%), which is digitisation noise.

## Established
- T.D. ATF-79, 46 FR 9063, published **28 January 1981**. Amended by T.D. ATF-201, 50 FR 12533, 29 March 1985. Both citations are from the eCFR text.
- Effective date: **27 February 1981**, from UC Davis `created`. Not checked against the scanned 1981 Federal Register. TTB's `Established` field gives 1981-01-28, the publication date.
- Context only: it sits within North Coast, and TTB lists 15 established sub-AVAs. Napa Valley partially overlaps Los Carneros and Wild Horse Valley (TTB `Partially_Overlaps`).

## Grape and style statements
- CFR §9.23 text: **none**. It gives only the name, the maps and the boundary: Napa County–Lake County line, Putah Creek and Lake Berryessa shores, then the Solano and Sonoma county lines. The boundary excludes the Lake Berryessa basin, so the AVA is smaller than Napa County.
- Petition summary (T.D. ATF-79 preamble, 1981): **not reviewed**. It exists only in scanned Federal Register issues, so it is held back.

## Judgement calls
None. This is the parent AVA as named.

## Held back
- Any grape or style claim from the 1981 T.D. preamble (not read).
