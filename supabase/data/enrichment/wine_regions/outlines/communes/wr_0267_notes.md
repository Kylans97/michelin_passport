# lodi: Lodi AVA

**Unit:** US_AVA_lodi, TTB OBJECTID 86, **27 CFR 9.107** (T.D. ATF-223, 1986; expanded T.D. ATF-482, 67 FR 56484, 4 Sep 2002). Source 2,183.9 km², output 2,182.4 km² (0.18%), 1 part, 102 vertices, valid.
- Cross-check: UC Davis current version valid from 2002-11-04, 2,187.4 km²; symmetric difference 8.0 km² (0.4%), largest piece 4.8 km².
- Sub-AVAs: TTB `Contains_` lists 7 (Alta Mesa 9.195, Borden Ranch 9.196, Clements Hills 9.197, Cosumnes River 9.198, Jahant 9.199, Mokelumne River 9.200, Sloughhouse 9.201, all T.D. TTB-47, 2006). Geometric check: each lies 100% inside the Lodi polygon. Not drawn separately.

## Style evidence
- Summary: Delta breezes (GuildSomm, Lodi feature); Zinfandel the defining and most planted grape (Wine Folly; GuildSomm); most old vine acreage in the country (Lodi Winegrape Commission; Wine Folly).
- Grapes: Zinfandel then Cabernet Sauvignon ("catching up fast", GuildSomm; named by Wine Folly). The ranking could not be checked against current NASS district acreage: the 2025 California Grape Acreage Report URLs returned 404 on 2026-11-21. GuildSomm's figures are from 2013, so the order is a near-miss to recheck.
- Held back: Merlot, Petite Sirah (GuildSomm only); Chardonnay and Pinot Gris (Wine Folly only, "dominate" plantings, contradicting the order above); Cinsault world's oldest vineyard (Wine Folly only).
- Mokelumne River note: sandy soils, oldest vines (Wine Folly; GuildSomm). Other sub-AVA notes kept to the bare TTB fact.
- Ratings null: no two sources rate Lodi reds.

## Dataset (all five US AVAs)
TTB AVA Map Explorer feature service `AVAs_Production/FeatureServer/0` (layer `AVA_Polygons_gen2pt5m_WMAS`), catalogued on data.gov (publisher TTB, CC0 1.0); informational, the 27 CFR part 9 text prevails.
- Version: layer `dataLastEditDate` 2026-10-27 15:21 UTC (`raw/ttb/layer.json`). Downloaded 2026-11-21 (this round): all 282 `Status='Established'` features (count checked, `raw/ttb/count.json`), `outSR=4326`; same OBJECTID/name set as round 4's download.
- CFR check: each section read from eCFR (title 27 up to date as of 2026-11-19, point in time 2026-11-13), `raw/ecfr/`. The TTB `Area` attribute is not in km² (ratio about 1.6 to the geodesic area) and is not used.
- Cross-check: UC Davis AVA project (github.com/UCDavisLibrary/ava, CC0, HEAD a00174d, 2026-10-15), current version, `raw/ucd/`.
- Processing (`na_asia_tools/us_build.py`, from round 4's builder): no editing or tracing; 100 m simplification in a local metric frame, slivers under 0.01 km² dropped, made valid, coordinates rounded to 5 decimals. Areas geodesic on the authalic sphere. Sub-AVA containment checked against the same layer (`na_asia_tools/us_check.py`).
- Label rule: 27 CFR 4.25(e)(3), `raw/ecfr/s4.25.xml`.
