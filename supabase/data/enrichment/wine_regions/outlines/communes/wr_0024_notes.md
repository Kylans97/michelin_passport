# wr_0024: Paso Robles AVA (parent)

**Unit:** US_AVA_paso_robles, TTB OBJECTID 64, **27 CFR 9.84**. **Area 2,491.0 km²** (about 615,500 acres). Single polygon, 179 vertices, valid. The boundary is mostly township and range lines and straight segments, hence so few vertices.

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
UC Davis `paso_robles` (post-2009 version) gives 2,472.0 km². The symmetric difference is 24.3 km² (1.0%). It lies inside San Luis Obispo County: 0.07 km² falls outside the Census county polygon, which is noise.

## Parent or sub-AVAs: decision
- Since T.D. TTB-125 (79 FR 60954, published 9 October 2014, effective 10 November 2014) there are **11 sub-AVAs**: Adelaida District, Creston District, El Pomar District, Paso Robles Estrella District, Paso Robles Geneseo District, Paso Robles Highlands District, Paso Robles Willow Creek District, San Juan Creek, San Miguel District, Santa Margarita Ranch, Templeton Gap District. All are in the TTB layer.
- Their union covers **1,478.0 km², about 59% of the parent**, with 0.0 km² outside it. The 2014 rule says they "would not alter the current boundary or size of the Paso Robles AVA". Some of the parent is deliberately left in no sub-AVA (urban land, government land, little viticulture).
- The 2014 rule also cites California's conjunctive-labelling law, under which a sub-AVA label must also carry "Paso Robles". The parent is therefore the unit every Paso Robles wine is labelled under.
- **Recommendation: the parent AVA, which is what is delivered.** The union of the sub-AVAs would leave 41% of the legal area as gaps and is not itself an official unit.

## Established
- T.D. ATF-148, 48 FR 45241 (the 2009 T.D. cites 48 FR 45239), published **4 October 1983**. Effective **3 November 1983** per UC Davis `created`/`valid_start`; not checked against the 1983 scan. TTB `Established` = 1983-10-04 (publication).
- Expanded by T.D. ATF-377, 61 FR 29953, published 13 June 1996 (+52,618 acres to the west).
- Expanded by T.D. TTB-72, 74 FR 3425/3429, published 21 January 2009, effective 20 February 2009 (+2,635 acres, Santa Margarita Valley in the south). Source: federalregister.gov/d/E9-994.

## Grape and style statements
- CFR §9.84: **none**.
- 2009 T.D. preamble (summarising the original 1983 rule): the AVA had about 5,000 acres of vineyards in 1983. It describes a drier, warmer summer than regions to the west and south because the Santa Lucia Mountains block marine air; day–night swings of 40–50 °F; 10–25 in of rain; 600–1,000 ft elevations; well-drained alluvial terrace soils. **No grape variety or wine style is named.** The petition says only that vineyards on both sides of the line "grow the same varietals".
- 2014 sub-AVA rule: no grape variety is named (checked by text search).

## Judgement calls
- Parent rather than sub-AVAs, as above.

## Held back
- Grape or style claims from the original 1983 T.D. ATF-148 preamble itself (scan only; I used the 2009 summary of it).
