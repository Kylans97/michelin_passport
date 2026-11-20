# Gisborne (slug: gisborne)

Status: recommended (added on evidence; not in the expected list), DRAWN from Stats NZ TA 2025 (NZ_TA_028).

## Why it is in
- Planted area 2025 (Vineyard Report 2026): Marlborough 32,042 ha, Hawke's Bay 4,615, Central Otago 2,099, North Canterbury 1,539, Gisborne 1,325, Wairarapa 1,189, Nelson 970. Gisborne is fifth, ahead of Wairarapa and Nelson, so the evidence supports it. Seven regions are recommended rather than six.

## Registration
- Gisborne, NZGI 1008. Filed 27 Jul 2017, accepted 26 Oct 2017, registered 26 Feb 2018. Renewal due 27 Jul 2032. Register: https://www.iponz.govt.nz/get-ip/geographical-indications/register/gisborne
- Geodata: https://www.iponz.govt.nz/assets/GIRegister/1842/Gisborne-GI-boundary.zip (4 polygons; 8,368 km2).

## Boundary
- Examiner: "the area included within the geographical indication boundaries is considered to be the greater Gisborne area. See district council jurisdiction map".
- Checked: registered polygon = Gisborne District (TA 028; land area 8,385 km2 = total area, so the unclipped layer stops at the coast). 2.0 / 1.5 km2 symmetric difference at full resolution; 6.0 / 7.0 after simplification.
- Dataset: Stats NZ Territorial Authority 2025, code 028, layer 120963 version 418318, CC BY 4.0.

## Style
- Sources: sunniest and warmest (nzwine.com "some of the highest sunshine and temperatures"; check sheet "warm, sunny climate", "high sunshine hours"); soils vary by subregion (nzwine.com subregion soils; check sheet "Different sub-regions contain different soil"); best known for Chardonnay with rich, generous fruit (nzwine.com "rich, lush palates bursting with fruit"; check sheet "generously fruited Chardonnay"; NZ Herald); with Sauvignon Blanc and Pinot Gris (nzwine.com; wineanorak).
- Grapes 2025 ha: Sauvignon Blanc 543; Chardonnay 451; Pinot Gris 241; Pinot Noir 27.

## Held back
- Conflict, recorded: nzwine.com calls Chardonnay "the dominant variety" and NZ Herald says half the vineyards are Chardonnay, but the 2025 Vineyard Report has Sauvignon Blanc ahead (543 vs 451 ha). Grapes follow the report; the summary says "best known for", which three sources support.
- Red structure scores and pairing. No registered GI inside Gisborne.

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
