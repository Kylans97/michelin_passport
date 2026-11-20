# Wairarapa (slug: wairarapa)

Status: recommended, DRAWN from Stats NZ TA 2025 (NZ_TA_048 + NZ_TA_049 + NZ_TA_050).

## Registration
- Wairarapa, NZGI 1012. Registrant The Wairarapa Wine Growers' Association Inc. Filed 27 Jul 2017, accepted 27 Oct 2017, registered 26 Feb 2018 (certificate issued 28 Feb 2018). Renewal due 27 Jul 2032. Register: https://www.iponz.govt.nz/get-ip/geographical-indications/register/wairarapa
- Geodata: https://www.iponz.govt.nz/assets/GIRegister/1851/Wairarapa-GI-boundary.zip (1 polygon; 5,941 km2).

## Boundary
- Examiner: EU OMAR list (2009) "refers to the Wairarapa GI as including the Carterton, Masterton and South Wairarapa Districts".
- Checked: registered polygon = Masterton + Carterton + South Wairarapa districts; 1.3 / 1.1 km2 symmetric difference at full resolution; 5.0 / 5.2 after simplification.
- Dataset: Stats NZ Territorial Authority 2025, codes 048, 049, 050, layer 120963 version 418318, CC BY 4.0.
- Judgement: Wairarapa chosen over Martinborough (NZGI 1011, 286 km2, a custom polygon inside South Wairarapa, not expressible in units) because it is the NZ Winegrowers reporting region and contains Martinborough and Gladstone (both 100% inside, geometry checked).

## Style
- Sources: close to Wellington (nzwine.com; wineanorak); cool and sunny (check sheet "high sunshine hours with relatively cool" temperatures; nzwine.com Martinborough "cool, dry", Gladstone "plenty of sunshine"); day and night swings (check sheet "marked temperature shifts during the day"; nzwine.com Masterton "large diurnal range"); free-draining river terraces (check sheet; nzwine.com); Pinot Noir and Sauvignon Blanc lead (wineanorak "about half Pinot Noir ... most of the rest Sauvignon"; Vineyard Report); Martinborough made its name with Pinot Noir (wineanorak "came to fame from its Pinot Noirs"; NZ Herald "pinot pioneers").
- Grapes 2025 ha: Sauvignon Blanc 531; Pinot Noir 495; Chardonnay 67; Pinot Gris 46; Riesling 17.
- Appellations inside: Martinborough NZGI 1011 (registered 26 Feb 2018); Gladstone NZGI 1014 (accepted 5 Sep 2018, registered 3 Jan 2019).

## Held back
- Red structure scores and pairing. Not used: nzwine.com's Pinot Noir description ("richly flavoured and warm with a savoury undercurrent"), single source.

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
