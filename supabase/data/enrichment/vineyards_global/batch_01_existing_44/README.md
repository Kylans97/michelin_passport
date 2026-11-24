# Batch 1: region and village for the 44 estates on production

Prepared 2026-11-24. **Part A APPLIED to production 2026-11-24** (product owner: "Yes, apply part A"); 40 regions set, verified after. Part B (24 villages) APPLIED the same day after migration 20261101740000 and the village table. QA-540..543 are in qa_issues.csv. Was: waiting for the product
owner's review.

## Files

| File | What it is |
|---|---|
| `vineyards_LIVE_20261124.csv` | Read-only export of `public.vineyards` on 2026-11-24 (44 rows) |
| `wine_regions_LIVE_20261124.csv` | Read-only export of `public.wine_regions` on 2026-11-24 (275 rows) |
| `assign_regions.py` | One written decision per estate, then checks it (see below) |
| `estate_regions_batch01.csv` | The result, one row per estate, for review |
| `prepared_batch01_part_a_regions.sql` | Sets `wine_region_id` for 40 estates. Needs no migration |
| `prepared_batch01_part_b_villages.sql` | Sets the village for 24 estates. Applied 2026-11-24, after the migration |

## Method

The region is never found by matching names. For each estate the region
printed on The World's 50 Best Vineyards list (kept in `vineyards.region`)
and the estate's own address on production were read, and the atlas region
was chosen by hand and written into `assign_regions.py` with the reason.
The village is the unit in that region's official commune list
(`wine_regions/outlines/communes/wr_NNNN.csv`) that holds the address's
municipality, looked up by its id inside the right province.

The script then checks every decision and holds back any row that fails:
the region exists and is in the estate's country; the village id is in
that region's list; where production has the estate's own pin, the pin is
inside the region's outline, and outside Europe also inside the village
unit's own polygon. All 44 pass. A dry run against production (select
only) found all 40 estates and all 40 regions, every region published and
in the same country, every `wine_region_id` still empty.

A village is set only where the region's list has two or more units. In a
one-unit region (Napa Valley, Stellenbosch, Margaret River, Casablanca,
Constantia, Maldonado, Hawke's Bay, Barossa Valley, Sonoma County) the
region is its own village.

## Result

| Status | Count | Meaning |
|---|---|---|
| ready | 24 | region and village |
| region_only | 16 | region; village not set (one-unit region, or no address) |
| no_region | 4 | the atlas has no region for this estate yet |

**What was not checked.** In Europe the village rests on the address only:
the municipality boundaries (GISCO LAU 2024) are not on disk, and
downloading them was not done in this session, so no pin was tested
against a European village polygon. Eighteen of the 40 placed estates have no pin on
production, so for them nothing was checked by geometry at all.

## Proposed QA log entries

```
QA-540,Scope gap,Medium,vineyards wine_region_id,vine_0024;vine_0026;vine_0029;vine_0050,"No atlas region for four 50 Best estates: Gusbourne (list 'Kent'; England has only Sussex, wr_0132), Perelada (list 'Empordà'), William Chris (list 'Texas Hill Country'), Colomé (Molinos, Salta: wr_0028 Cafayate is departamento Cafayate only; IG Valles Calchaquíes is held back in the atlas). None placed in a neighbouring region",Add the regions to the atlas from their official texts, then place these four,Open
QA-541,Missing data,Low,vineyards commune,vine_0005;vine_0018;vine_0030;vine_0031,"Region set but village held: Creation (Hemel-en-Aarde has three wards; address 'Hemel-en-Aarde Road, Hermanus' does not say which, no pin); Kefraya (wr_0115 has no commune list, no address); Szepsy (site publishes no address); Cloudy Bay (no address on production)",Fill from the estate's own address or Wine of Origin statement in a later batch; never from memory,Open
QA-542,Near-miss,Low,vineyards wine_region_id,vine_0009;vine_0027;vine_0038;vine_0049,"Region chosen by definition, not by name: 'Sauternes' placed in Bordeaux (wr_0002 is defined to include AOC Sauternes); 'Alexander Valley' and 'Sonoma' placed in Sonoma County (wr_0022, the county both addresses are in); Gramona's Sant Sadurní d'Anoia is in both Penedès (wr_0098) and Cava (wr_0189), placed in Penedès because the list names Alt Penedès",Confirm on review; one region per estate by design,Open
QA-543,Unverified,Low,vineyards commune,24 estates (batch 1 ready rows),"European villages rest on the estate's address only: GISCO LAU 2024 polygons are not on disk, so no pin was checked against a European municipality. Region outlines were checked where a pin exists. Peñafiel (vine_0012) is marked possible-partial in the Ribera del Duero list",Run the pin-in-commune check when the outline script next downloads LAU 2024,Open
```
