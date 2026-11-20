# Central Otago (slug: central-otago)

Status: recommended, DRAWN from Stats NZ TA 2025 (NZ_TA_069 + NZ_TA_070).

## Registration
- Central Otago, NZGI 1007. Registrant Central Otago Winegrowers Association Inc. Filed 27 Jul 2017, accepted 10 Jul 2018, registered 29 Oct 2018 (certificate issued 29 Oct 2018; the certificate text says entered on the register 27 Jul 2017, a wording difference from the register's 29 Oct 2018, both recorded here). Renewal due 27 Jul 2032. Register: https://www.iponz.govt.nz/get-ip/geographical-indications/register/central-otago
- Geodata: https://www.iponz.govt.nz/assets/GIRegister/1839/Central-Otago-GI-boundary.zip (1 polygon; 19,317 km2).

## Boundary
- Examiner: in line with the Central Otago District boundary; the EU OMAR list (2009) includes both Central Otago and Queenstown Lakes districts.
- Checked: registered polygon = Central Otago District + Queenstown-Lakes District. Full resolution: 2.3 km2 / 1.8 km2 symmetric difference out of 19,317 km2; after simplification 9.5 / 9.0 km2. Both TAs are landlocked, so the unclipped TA layer is the right one (it includes Lakes Wakatipu, Wanaka, Hawea and Dunstan, as the registered polygon does).
- Dataset: Stats NZ Territorial Authority 2025, codes 069 and 070, layer 120963 version 418318, CC BY 4.0.

## Style
- Sources: far south, inland (nzwine.com "southernmost"; wineanorak); dry, hot summer days, cold nights (nzwine.com; check sheet "very cold winters and hot summers", "very low rainfall"; NZ Herald "dry climate"; wineanorak "cool and arid"); stony, free-draining soils (nzwine.com "stony soils"; check sheet "free-draining gravels, silts and sands"); Pinot Noir about four fifths (NZ Herald 80%; check sheet 77%; Vineyard Report 1,694 of 2,099 ha); intense, lush fruit (nzwine.com "true intensity", "lush fruit"; check sheet "very good fruit intensity"; NZ Herald "plush fruit").
- Grapes 2025 ha: Pinot Noir 1,694; Pinot Gris 166; Chardonnay 114; Sauvignon Blanc 50; Riesling 46.
- Appellation inside: Bannockburn, NZGI 1028 (filed 6 Aug 2021, registered 1 Feb 2022, renewed to 6 Aug 2036), geometry 100% inside Central Otago.

## Held back
- Red structure scores and pairing. Subregions Gibbston, Bendigo, Wanaka, Alexandra, Cromwell: named by nzwine.com but not registered GIs, so not listed.

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
