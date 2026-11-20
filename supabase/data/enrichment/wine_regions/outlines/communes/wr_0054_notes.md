# Hawke's Bay (slug: hawkes-bay)

Status: recommended, DRAWN from Stats NZ RC 2025 Hawke's Bay Region, land part (NZ_RC_06).

## Registration
- Hawke's Bay / Hawkes Bay, NZGI 1005 (both spellings registered). Registrant Hawke's Bay Winegrowers Association Inc. Filed 27 Jul 2017, accepted 2 Nov 2017, registered 26 Feb 2018 (certificate issued 28 Feb 2018). Renewal due 27 Jul 2032. Register: https://www.iponz.govt.nz/get-ip/geographical-indications/register/hawkes-bay
- Geodata: https://www.iponz.govt.nz/assets/GIRegister/1833/Hawkes-Bay-GI-boundary.zip (5 polygons; 14,185 km2).

## Boundary
- No examiner check sheet is published for this entry; the register gives no text. The applicant evidence (p2) describes the GI as "situated on the central Eastern Coast of the North Island".
- Checked: the registered polygon = Hawke's Bay Region land: all of Napier, Hastings, Wairoa and Central Hawke's Bay districts plus the Hawke's Bay Region parts of Taupo (784 km2) and Rangitikei (612 km2) districts. Hawke's Bay Region land area 14,139 km2 (Stats NZ) vs 14,185 km2.
- Judgement call (derivation): the unclipped RC 2025 polygon includes the 12 nautical mile sea. I intersected Regional Council 2025 code 06 with the union of the TA 2025 polygons it touches (codes 021, 028, 029, 030, 031, 032, 038, 041), whose unclipped edges follow the coast here (their LAND and total areas match). This is a set operation on two official layers, not digitising. Result vs registered polygon: 0.9 / 1.1 km2 symmetric difference at full resolution; 8.5 / 11.0 km2 after simplification.
- Dataset: Stats NZ Regional Council 2025 (layer 120946 version 418321) and Territorial Authority 2025 (layer 120963 version 418318), CC BY 4.0.

## Style
- Sources: east coast (applicant evidence p2; wineanorak); temperate, maritime (applicant evidence "essentially temperate and maritime"; nzwine.com "temperate climate"); free-draining alluvial plains and gravels, Gimblett Gravels (nzwine.com; applicant evidence; wineanorak "800 hectare patch of free draining gravelly soils"; NZ Herald "stony Gimblett Gravels"); strengths Chardonnay, Bordeaux-style blends, Syrah (nzwine.com; wineanorak; NZ Herald); Syrah aromatic and elegant (nzwine.com "perfumed, elegant"; NZ Herald "fresh, aromatic and elegant").
- Grapes 2025 ha: Sauvignon Blanc 1,209; Chardonnay 1,014; Merlot 757; Pinot Gris 677; Syrah 306; Pinot Noir 195; Cabernet Sauvignon 166.
- Appellation inside: Central Hawke's Bay / Central Hawkes Bay, NZGI 1020 (accepted 3 Sep 2018, registered 28 Jan 2019), geometry 100% inside.

## Held back
- Red structure scores and pairing. Gimblett Gravels, Bridge Pa Triangle etc. are not registered GIs (the applicant evidence names them as smaller units it "does not seek registration" for), so not listed as appellations.
- Not used: "Chardonnay leads the whites" (Sauvignon Blanc has more area in 2025).

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
