# wr_0022: "Sonoma County"

**Unit delivered:** US_COUNTY_06097, Sonoma County, California. Census cartographic boundary 500k, January 1, 2024 vintage: https://tigerweb.geo.census.gov/arcgis/rest/services/Generalized_ACS2024/State_County/MapServer/11 . **Area 4,111.8 km²** (Census ALAND 4,080.1 km² plus some inland water). Single polygon, valid. Licence: US Census Bureau product, public domain (US federal work).

**This is a recommendation, not a settled choice. Please confirm.**

## What exists
"Sonoma County" is **not an AVA**. It is still a legal US wine appellation: **27 CFR 4.25(a)(1)(iv)** lists "a county" as an American appellation of origin. That requires at least 75% of the fruit from the county and the word "County" on the label. Its legal extent is the county boundary itself. TTB's layer has no "Sonoma County" AVA.

Established AVAs in TTB's layer that list Sonoma as a county (19; North Coast excluded because it spans six counties): Alexander Valley, Bennett Valley, Chalk Hill, Dry Creek Valley, Fort Ross-Seaview, Fountaingrove District, Green Valley of Russian River Valley, Knights Valley, Los Carneros (also in Napa), Moon Mountain District Sonoma County, Northern Sonoma, Petaluma Gap (also in Marin), Pine Mountain-Cloverdale Peak (also in Mendocino), Rockpile, Russian River Valley, Sonoma Coast, Sonoma Mountain, Sonoma Valley, West Sonoma Coast. All are in `wr_0022_alternative_sonoma_avas.geojson`, same property schema.

There is no single umbrella AVA. The two largest, **Northern Sonoma** (9.70, 1,594.8 km²) and **Sonoma Coast** (9.116, 2,086.8 km²), together cover only 3,073.8 km². Sonoma Valley, Los Carneros, Moon Mountain, Bennett Valley, Sonoma Mountain, Fountaingrove, Petaluma Gap and Rockpile all extend outside that pair.

## Options with areas
| Option | Area | Notes |
|---|---|---|
| A. County, cartographic 500k (delivered) | **4,111.8 km²** | Shoreline-clipped and generalised. Same GEOID as TIGER/Line. |
| A′. County, TIGER/Line full (TIGERweb tigerWMS_Current layer 82, 2026 vintage) | 4,574.1 km² | Includes 497 km² of water, including Pacific territorial sea and San Pablo Bay, so on a globe it would paint the sea. Saved as raw/census/county_06097_sonoma.geojson. |
| B. Union of the 19 Sonoma AVAs | 3,899.5 km² | 349.1 km² falls **outside** the county (Petaluma Gap into Marin, Los Carneros into Napa, Pine Mountain into Mendocino). Inside the county the union covers 3,543.5 km², leaving about 570 km² of the county (cartographic) outside any AVA. Not itself an official unit. |
| B′. Northern Sonoma ∪ Sonoma Coast only | 3,073.8 km² | Misses Sonoma Valley, Carneros, Moon Mountain and others. Not an official unit. |

## Which the sources use
- The legal label term "Sonoma County" (27 CFR 4.25) means the county.
- Our own source for the US vineyard list: `supabase/data/enrichment/worlds_50_best_vineyards/worlds_50_best_vineyards_2026.csv`, row vine_0038 (Aperture Cellars). Its note says the 50 Best list region is "Sonoma" and the announcement article says "Sonoma County". Jordan (vine_0027) is labelled "Alexander Valley", a separate AVA inside the county.
- **Recommendation: Option A (county, cartographic).** It is the only official unit whose legal meaning matches the name "Sonoma County". It contains every Sonoma-only AVA, and it is one clean polygon. Option B is not a legal unit, bleeds into three other counties, and would need us to choose a membership list.

## Established / grape statements
- Not applicable to a county appellation. There is no TTB establishment date and no grape or style statement in 27 CFR 4.25.

## Held back
- Nothing from the geometry. The choice between A, A′ and B is left to the product owner.
