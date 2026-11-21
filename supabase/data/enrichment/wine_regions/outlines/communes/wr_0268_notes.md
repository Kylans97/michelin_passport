# sierra-foothills: Sierra Foothills AVA

**Unit:** US_AVA_sierra_foothills, TTB OBJECTID 103, **27 CFR 9.120** (T.D. ATF-261, 52 FR 44105, 18 Nov 1987; the 2024 amendment T.D. TTB-196 is the non substantive "Technical Corrections to the TTB Regulations", FR 2024-23662, `raw/fr/fr_2024-11-06.json`). Source 10,719.9 km², output 10,722.6 km² (0.13%), 1 part, 949 vertices, valid. Very large: 8 counties.
- Cross-check: UC Davis (one version, 1987) 10,638.6 km²; symmetric difference 165 km² (1.5%): 123 km² TTB only, 42 km² UC Davis only. Largest piece 44 km² TTB only near 120.87 W 39.31 N, along the Tahoe National Forest boundary (step 19 of the CFR text, drawn on 1:250,000 maps whose forest boundary has since changed). I cannot say which digitisation is right without tracing; TTB used, discrepancy logged.
- Sub-AVAs: TTB `Contains_`: California Shenandoah Valley (9.37), Fiddletown (9.81), Fair Play (9.168), North Yuba (9.106), each 100% inside. El Dorado AVA partially overlaps (74.5% of it inside) and is not listed as a sub-appellation.

## Style evidence
- Summary: Gold Rush plantings, warm days and cool nights, Zinfandel most common (Wikipedia, citing the 1987 final rule; Decanter, Stephen Brook).
- Grapes: Zinfandel (both); Syrah (Wikipedia 560 acres; Decanter "do very well"); Barbera (Decanter, Renwood; Palate Press, Barbera Festival in Amador). Order Syrah before Barbera follows Wikipedia acreage; no current figure found.
- Held back: Cabernet Sauvignon (Wikipedia 600 acres vs Decanter "scarcity of Cabernet"); acidity and tannin (Decanter only, "high tannin levels", "naturally high acidity"); "old Zinfandel in Amador" (Decanter only).

## Dataset (all five US AVAs)
TTB AVA Map Explorer feature service `AVAs_Production/FeatureServer/0` (layer `AVA_Polygons_gen2pt5m_WMAS`), catalogued on data.gov (publisher TTB, CC0 1.0); informational, the 27 CFR part 9 text prevails.
- Version: layer `dataLastEditDate` 2026-10-27 15:21 UTC (`raw/ttb/layer.json`). Downloaded 2026-11-21 (this round): all 282 `Status='Established'` features (count checked, `raw/ttb/count.json`), `outSR=4326`; same OBJECTID/name set as round 4's download.
- CFR check: each section read from eCFR (title 27 up to date as of 2026-11-19, point in time 2026-11-13), `raw/ecfr/`. The TTB `Area` attribute is not in km² (ratio about 1.6 to the geodesic area) and is not used.
- Cross-check: UC Davis AVA project (github.com/UCDavisLibrary/ava, CC0, HEAD a00174d, 2026-10-15), current version, `raw/ucd/`.
- Processing (`na_asia_tools/us_build.py`, from round 4's builder): no editing or tracing; 100 m simplification in a local metric frame, slivers under 0.01 km² dropped, made valid, coordinates rounded to 5 decimals. Areas geodesic on the authalic sphere. Sub-AVA containment checked against the same layer (`na_asia_tools/us_check.py`).
- Label rule: 27 CFR 4.25(e)(3), `raw/ecfr/s4.25.xml`.
