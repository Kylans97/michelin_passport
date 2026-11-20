# North Canterbury (slug: north-canterbury)

Status: recommended, DRAWN AS AN APPROXIMATION from Stats NZ open layers (see "Approximation drawn"). The earlier fallback point has been removed from nz_points.csv.

## Registration
- North Canterbury, NZGI 1016. Registrant North Canterbury Winegrowers' Inc. Filed 27 Jul 2017, accepted 13 Mar 2020, registered 29 Jun 2020 (certificate issued 29 Jun 2020). Renewal due 27 Jul 2032. Register: https://www.iponz.govt.nz/get-ip/geographical-indications/register/north-canterbury
- Geodata: https://www.iponz.govt.nz/assets/GIRegister/1866/North-Canterbury-GI-boundary.zip (1 polygon; 19,144 km2).

## Boundary
- Examiner: the GI's coordinates and the declarant state it is "bounded by the Rakaia River to the South"; the examiner first doubted the southern extent, then accepted it, noting there is no agreed formal definition of North Canterbury. The applicant's evidence (Appendix 1) relies on the North Canterbury Fish and Game region map (south to the Rakaia River; north edge excluding the Conway River).
- Checked against TA 2025: covers Hurunui (96%), Waimakariri, Christchurch City and Selwyn, but differs from their union by about 427 km2 one way and 339 km2 the other. Not expressible in official units.
- Judgement (superseded by the follow-up): now drawn as an approximation from TA 2025 and Meshblock 2025 (see below).
- Recommended over Waipara Valley (NZGI 1010) because it is the reporting region NZ Winegrowers uses and the registrant's focus ("North Canterbury has been identified as the GI in which we will focus our investment", applicant evidence p5). Waipara Valley is listed as an appellation inside it (geometry check: 100% inside).


## Approximation drawn (follow-up, 2026-11-20)
- On the product owner's instruction the IPONZ registered polygon is NOT used for drawing. It is used only in my working, as the yardstick for the differences below. nz_units_iponz_pending.geojson remains a working reference and is not for publication.
- Land clip: LINZ "NZ Coastlines and Islands Polygons (Topo 1:50k)" (layer 51153, CC BY 4.0) could not be fetched without a key (WFS 400, query API 403). The copies on ArcGIS Online are re-hosted by NIWA and Environment Canterbury, not by LINZ, so I did not use them. The Stats NZ clipped layers need a Datafinder login. Instead I clipped with Stats NZ's own land/water coding. From Stats NZ Meshblock 2025 (MB2025_V1_00, CC BY 4.0, Stats NZ ArcGIS Meshblock_2025 FeatureServer), I downloaded every meshblock coded Inlet (22) or Oceanic (23) intersecting 170.5 to 174.8 E, 40.3 to 44.2 S (127 meshblocks) and subtracted their union from the unclipped TA 2025 polygons. Inland water (21) is kept, as the registered polygons include lakes. Stats NZ describes its clipped layers as made "using land water codes", so this is the same method, but I did not reproduce the published clipped layer exactly. No digitising.
- Differences are areas of the full-resolution geometry against the registered polygon (equirectangular km2), then rechecked after simplification to about 100 m.
- Alternatives tried (land-clipped TA 2025 unions vs registered 19,144 km2; total symmetric difference):
  - Hurunui alone 11,135.7 km2 (58.17%); Waimakariri 16,924.3 (88.41%); Christchurch 17,657.7 (92.24%); Selwyn 12,601.4 (65.82%)
  - Hurunui+Waimakariri 8,916.0 (46.57%); Hurunui+Christchurch 9,649.4 (50.40%); Hurunui+Selwyn 4,593.1 (23.99%); Waimakariri+Christchurch 15,438.0 (80.64%); Waimakariri+Selwyn 10,381.7 (54.23%); Christchurch+Selwyn 11,115.0 (58.06%)
  - Hurunui+Waimakariri+Christchurch 7,429.7 (38.81%); Hurunui+Waimakariri+Selwyn 2,373.4 (12.40%); Hurunui+Christchurch+Selwyn 3,106.8 (16.23%); Waimakariri+Christchurch+Selwyn 8,895.2 (46.46%)
  - All four TAs: missing 549.6 (2.87%), extra 337.6 (1.76%), total 887.1 (4.63%). This is the best combination of whole TAs.
  - SA2 2025 units chosen by majority inside the GI: identical to all four TAs (887.1 km2), so SA2s do not help.
  - All four TAs plus Ashburton meshblock 2754200: total 610.3 km2 (3.19%).
  - All four TAs minus the five Hurunui meshblocks of the Marlborough strip: total 562.5 km2 (2.94%).
  - CHOSEN: all four TAs + meshblock 2754200 minus the five Hurunui meshblocks: missing 273.1 km2 (1.43%), extra 12.6 km2 (0.07%), total 285.8 km2 (1.49%). After simplification: missing 279.2 km2 (1.46%), extra 22.4 km2 (0.12%).
- Meshblocks were chosen by a rule, not by hand. Add a meshblock if more than half of it lies outside the four TAs and at least half inside the GI; remove one if more than half lies inside the four TAs and less than half inside the GI. Searched in two boxes around the mismatches: upper Rakaia 170.6 to 171.6 E, 42.9 to 43.6 S, and the Hurunui strip 173.1 to 173.6 E, 42.25 to 42.75 S. Meshblock 2754200 (Ashburton District, confirmed by point query) is 276.8 km2 and lies wholly inside the GI.
- Features: NZ_TA_058_LAND_EXCL_MB (Hurunui land minus MB2025 2311100, 2311200, 2311502, 2310702, 2310800), NZ_TA_059_LAND, NZ_TA_060_LAND, NZ_TA_062_LAND, NZ_MB_2754200.
- What is still missing: about 117 km2 more of the upper Rakaia in Ashburton District, held by meshblocks mostly outside the GI. Also harbour waters on Banks Peninsula (pieces of 51.1 and 44.4 km2 near 172.67 E, 43.63 S and 172.92 E, 43.82 S, Lyttelton and Akaroa harbours), which Stats NZ codes as Inlet but the registered polygon includes.

## Style
- Sources: north and south of Christchurch (applicant evidence; check sheet; nzwine.com Canterbury Plains past Christchurch; wineanorak); river gravels and limestone clays (nzwine.com; check sheet "limestone soils over clay", Canterbury Plains "coarse gravels"; wineanorak Waikari "limestone soils"); Waipara warmer (nzwine.com; NZ Herald); known for Riesling (nzwine.com; NZ Herald); Pinot Noir from clay and limestone (nzwine.com; check sheet).
- Riesling local note: NZ Herald "half of Aotearoa's riesling"; Vineyard Report 254 of 543 ha (47%).
- Grapes 2025 ha: Sauvignon Blanc 503; Pinot Noir 402; Riesling 254; Pinot Gris 222; Chardonnay 95.

## Held back
- Exact registered polygon (its reuse terms exclude publication); an approximation is drawn instead. Red structure scores and pairing.
- Conflict, not used: NZ Herald calls Pinot Noir the "most planted variety"; the 2025 Vineyard Report has Sauvignon Blanc ahead (503 vs 402 ha). The grape list follows the report and the summary makes no "most planted" claim.
- Canterbury GI (NZGI 1017) overlaps and is wider; not listed as an appellation because it is not inside North Canterbury.

## Shared context (all New Zealand regions)

- Register: IPONZ Register of Geographical Indications under the Geographical Indications (Wine and Spirits) Registration Act 2006. Full register export downloaded 2026-11-20 from https://www.iponz.govt.nz/get-ip/geographical-indications/register/downloadExport (saved as raw/export.bin, parsed to raw/register.tsv). Every New Zealand wine GI carries a deemed registration date of 27 July 2017 (stated on each certificate); the dates below are the register's own filing, acceptance and registration dates.
- The register entry carries no written boundary text. The registered boundary is the "Geographical data" file attached to each entry ("Geographical data that define the boundaries of the territory, region or locality to which this geographical indication relates"), an Esri shapefile and Esri JSON in NZGD2000, processed by IPONZ from data supplied by the applicant. Boundary wording below is the IPONZ examiner's characterisation in the published check sheet, where one exists.
- Licence of the IPONZ geodata: Crown copyright. IPONZ's copyright statement grants reuse of site information "excluding the intellectual property registers", and only for personal or in house use; no open licence is stated in the data's metadata. It is therefore NOT used for drawing in nz_units.geojson. The product owner has decided it is not published; nz_units_iponz_pending.geojson is a working reference only (used to measure how far each approximation is from the registered boundary).
- Stats NZ geometry used for drawing: Territorial Authority 2025 (TA2025_V1_00, Datafinder layer 120963, version 418318) and Regional Council 2025 (REGC2025_V1_00, layer 120946, version 418321), both CC BY 4.0, attribution "Stats NZ Tatauranga Aotearoa". Fetched from Stats NZ's own ArcGIS Online FeatureServers (services2.arcgis.com/vKb0s8tBIA3bdocZ, copyrightText "Stats NZ Tatauranga Aotearoa") in NZGD2000 (wkid 4167), full resolution. The clipped variants (layers 120962, 120945) need a Datafinder login to export and were not available to this run.
- NZGD2000 is treated as WGS84 (difference well under 1 m, far below the 100 m simplification). Simplified with Douglas-Peucker, tolerance 0.001 degrees (about 100 m), topology preserved, coordinates rounded to 5 decimals, slivers under 0.05 km2 dropped. All output geometries are valid.
- Every drawn unit set was checked against the registered IPONZ geometry by area of symmetric difference (equirectangular km2 approximation).
- Label rule (label_note): IPONZ, Using geographical indications, https://www.iponz.govt.nz/get-ip/geographical-indications/using-gis/ (at least 85% from grapes harvested in the GI, the rest from grapes harvested in New Zealand; sections 21 to 26 of the Act). The Act's own text on legislation.govt.nz refused automated fetches (403), so the rule rests on the regulator's page alone.
- Grape order: planted area 2025 by region and variety, NZ Winegrowers Vineyard Report 2026 (https://www.nzwine.com/media/5fzng52v/vineyard-report-2026-final.pdf), tables 5.0. Judgement call: its reporting regions are NZ Winegrowers' own, not the GI polygons; they are the best published proxy.
- red_body, red_acidity, red_tannin: null for every region. No region had two independent sources stating a level (nzwine.com gives Marlborough Pinot Noir "mid-weight body" and "fine tannins", but no second independent source said the same).
- pairing: null for every region. None of the sources gives a regional food pairing.
- Style sources and independence: nzwine.com region pages (NZ Winegrowers) count as one source with the Vineyard Report (same site). Independent second sources are Jamie Goode, wineanorak.com (A quick guide to New Zealand wine, 2025, updated 2026), Jo Burzynska in NZ Herald Viva (13 May 2025), and the IPONZ examiner check sheets and applicant evidence (iponz.govt.nz; these summarise the registrant's sworn evidence, a disclosed limitation). VinePair's guide was read but not used: it is sponsored by New Zealand Wine, so not independent of nzwine.com. Wine-Searcher and Te Ara refused automated fetches.
