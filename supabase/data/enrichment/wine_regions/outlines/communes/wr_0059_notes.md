# Nelson (slug: nelson)

Status: recommended, DRAWN AS AN APPROXIMATION from Stats NZ open layers (see "Approximation drawn"). The earlier fallback point has been removed from nz_points.csv.

## Registration
- Nelson, NZGI 1006. Registrant Nelson Winegrowers Association Inc. Filed 27 Jul 2017, accepted 23 Feb 2018, registered 26 Jun 2018 (certificate issued 26 Jun 2018). Renewal due 27 Jul 2032. Register: https://www.iponz.govt.nz/get-ip/geographical-indications/register/nelson
- Geodata: https://www.iponz.govt.nz/assets/GIRegister/1836/Nelson-GI-boundary.zip (36 polygons, 6 holes; 10,112 km2).

## Boundary
- Examiner: "The boundary is in line with Nelson and Tasman districts" (EU OMAR list 2009: Nelson and Tasman districts).
- Checked: the registered polygon equals the LAND of Nelson City + Tasman District (only 1.6 km2 of the GI falls outside them). The anonymously downloadable Stats NZ TA 2025 and RC 2025 layers are unclipped and include about 5,500 km2 of Tasman Bay and Golden Bay water, so they cannot draw this GI faithfully. The clipped layer (Territorial Authority 2025 Clipped, Datafinder 120962, CC BY 4.0) would, but needs a Datafinder login.
- Judgement: expressible in official units (NZ_TA_051 + NZ_TA_052 clipped), Superseded by the follow-up: drawn as the land part of the two districts, clipped with Stats NZ meshblock land/water codes (see below). An export of layer 120962 with a Datafinder key would still be a useful cross-check.


## Approximation drawn (follow-up, 2026-11-20)
- On the product owner's instruction the IPONZ registered polygon is NOT used for drawing. It is used only in my working, as the yardstick for the differences below. nz_units_iponz_pending.geojson remains a working reference and is not for publication.
- Land clip: LINZ "NZ Coastlines and Islands Polygons (Topo 1:50k)" (layer 51153, CC BY 4.0) could not be fetched without a key (WFS 400, query API 403). The copies on ArcGIS Online are re-hosted by NIWA and Environment Canterbury, not by LINZ, so I did not use them. The Stats NZ clipped layers need a Datafinder login. Instead I clipped with Stats NZ's own land/water coding. From Stats NZ Meshblock 2025 (MB2025_V1_00, CC BY 4.0, Stats NZ ArcGIS Meshblock_2025 FeatureServer), I downloaded every meshblock coded Inlet (22) or Oceanic (23) intersecting 170.5 to 174.8 E, 40.3 to 44.2 S (127 meshblocks) and subtracted their union from the unclipped TA 2025 polygons. Inland water (21) is kept, as the registered polygons include lakes. Stats NZ describes its clipped layers as made "using land water codes", so this is the same method, but I did not reproduce the published clipped layer exactly. No digitising.
- Differences are areas of the full-resolution geometry against the registered polygon (equirectangular km2), then rechecked after simplification to about 100 m.
- Units: Tasman District (TA 051) + Nelson City (TA 052), land part. Features NZ_TA_051_LAND, NZ_TA_052_LAND.
- Against the registered polygon (10,112 km2), full resolution: missing 38.4 km2 (0.38%), extra 14.1 km2 (0.14%). After simplification: missing 47.8 km2 (0.47%), extra 22.8 km2 (0.23%).
- What is missing: mostly water that Stats NZ codes as Inlet but the registered polygon counts as land or includes. The largest piece is 26.6 km2 near 172.56 E, 40.60 S, in Golden Bay (Whanganui Inlet / Farewell Spit area). The rest are slivers along the coast.

## Style
- Sources: sheltered, high sunshine, moderating coastal climate (nzwine.com; check sheet "calmer, more temperate climate", mountains as a barrier to westerlies; NZ Herald "sunniest" contest); Sauvignon Blanc leads (wineanorak "Sauvignon dominates"; Vineyard Report); stony Waimea Plains and clay Moutere Hills as the two areas, the clay giving richer, more textured wines (nzwine.com; check sheet "higher clay content giving good texture and weight").
- Grapes 2025 ha: Sauvignon Blanc 566; Pinot Noir 139; Chardonnay 94; Pinot Gris 92; Riesling 21.
- Appellations: no registered GI inside Nelson.

## Held back
- Exact registered polygon (its reuse terms exclude publication); an approximation is drawn instead. Red structure scores and pairing.
- Not used: nzwine.com's "lighter and fresher" Waimea style (single source).

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
