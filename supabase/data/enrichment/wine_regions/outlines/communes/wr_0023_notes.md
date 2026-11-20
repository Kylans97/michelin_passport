# wr_0023: Willamette Valley AVA (parent)

**Unit:** US_AVA_willamette_valley, TTB OBJECTID 6, **27 CFR 9.90**. **Area 13,926.2 km²**. Single polygon, 78,508 vertices, valid. This is a heavy feature: consider simplifying it for display only, and keep this file as the source.

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
- UC Davis `willamette_valley` (post-2016 version) gives 14,003.4 km². The symmetric difference with TTB is 245.9 km² (1.8%). Most of the boundary follows the 1,000 ft contour, so two independent digitisations of the contour line differ more here than elsewhere. Neither is "the" legal line.
- Size check against the Federal Register: T.D. TTB-134 (81 FR 11110, 3 March 2016) states the AVA "covers approximately 5,360 square miles" before an expansion of about 29 square miles. That is about 5,389 sq mi, or about 13,958 km². TTB's polygon is within 0.3% of that.
- TTB lists 11 established sub-AVAs (Chehalem Mountains, Dundee Hills, Eola-Amity Hills, Laurelwood District, Lower Long Tom, McMinnville, Mt. Pisgah Polk County Oregon, Ribbon Ridge, Tualatin Hills, Van Duzer Corridor, Yamhill-Carlton). In the TTB data, 3.5 km² of their union falls outside the parent, which is digitisation slop. The parent is used as instructed.

## Established
- T.D. ATF-162, 48 FR 54221, published **1 December 1983**. The 2016 FR text confirms that date.
- Effective date: **3 January 1984**, from UC Davis `valid_start` of its first version. Not checked against the 1983 FR scan.
- Expanded by T.D. TTB-134, 81 FR 11110/11112, published 3 March 2016, effective **4 April 2016** (federalregister.gov). The expansion added about 29 sq mi in Lane County (King Estate area, Letz Creek map).
- **Discrepancy:** TTB's `Established` attribute gives **1983-01-21**, which matches neither the publication date nor the effective date. It looks like an error in TTB's attribute table. Don't use it.

## Grape and style statements
- CFR §9.90: **none**. Only physical bounds: Columbia River, Coast Range, Calapooya Mountains, Cascades, "approximately 5,200 square miles (3.3 million acres)" (the 1983 figure).
- 2016 expansion T.D. (federalregister.gov/d/2016-04710): **none**. No grape variety is named. It discusses only soils (Bellpine, Jory and others), climate and watersheds. Saved in raw/fr/wv2016.txt.
- 1983 T.D. ATF-162 preamble: **not reviewed** (scan only). Held back.

## Judgement calls
- Used the parent AVA, not the sub-AVAs, per the brief.

## Held back
- Grape or style claims from the 1983 T.D. preamble (not read).
