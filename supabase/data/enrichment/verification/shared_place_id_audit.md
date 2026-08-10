# Shared Google Place ID Audit

Full audit of every restaurant/hotel pair in the production catalogue that shares a `google_place_id` — not just the two cases already flagged (Château Neercanne, ABaC). Computed directly from `supabase/data/restaurants_master.csv` and `supabase/data/hotels_master.csv` (read-only) using the Haversine formula. Full row-level data in `shared_place_id_audit.csv`.

## Headline finding

**10 shared Place IDs exist — matching `DATABASE_ARCHITECTURE.md` §8's documented count exactly.** Of those 10, **3 (30%) have a materially wrong coordinate on the restaurant side**, not 2:

| Pair | Distance | Status |
|---|---|---|
| **Central Park**, Voorburg (`rest_0021`/`hotel_02`) | **2,002.9 m** | New finding — not previously flagged |
| **Château Neercanne**, Maastricht (`rest_0022`/`hotel_13`) | 1,787.5 m | Already flagged, reaffirmed |
| **ABaC**, Barcelona (`rest_0002`/`hotel_537`) | 459.8 m | Already flagged, reaffirmed |

The other 7 pairs (Kanamean Nishitomiya, Da Vittorio–St. Moritz/Carlton Hotel, Terra The Magic Place, Atrio, La Brezza/Tschuggen Grand Hotel, Söl'ring Hof, 7132 Silver/7132 Hotel) have **identical coordinates to the decimal** — clean.

## Is this isolated or systematic?

**Systematic, not isolated — but scoped to one specific pattern.** All three broken pairs share the same signature:

1. The restaurant row and hotel row store the **same or a near-identical address string** (confirmed for Central Park — both rows read `"Oosteinde 14, 2271 EH Voorburg"` verbatim; confirmed for Château Neercanne and ABaC by their own operator sites — genuinely one building housing both).
2. In every case checked against an independent source, **the hotel-side coordinate is the one that's correct** and the restaurant-side coordinate is the outlier:
   - Château Neercanne: hotel's stored value (50.818737, 5.667403) matches Wikipedia (50.8188833, 5.6679306) almost exactly.
   - Central Park: hotel's stored value (52.069951, 4.369563) matches the independently-sourced postcode-centroid for `2271` (52.072, 4.369) closely; the restaurant's stored value (52.059, 4.3463) does not.
   - ABaC: not independently geocode-confirmed this session, but the same shared-building, same-address situation applies.

This strongly suggests the original import pipeline's restaurant-side geocoding pass drifted for a subset of properties where a restaurant and hotel occupy the same building — plausibly because the restaurant's Place ID or address string was resolved through a slightly different lookup path than the hotel's. It is **not** universal (7 of 10 are exact), so this is not "every shared Place ID is broken" — it's "roughly a third of them are, and there's a plausible common cause."

## Recommendation

- **Château Neercanne** — apply the fix already proposed in `p0_corrections.csv` (MA-069): align `rest_0022` to `hotel_13`'s coordinates. High confidence.
- **Central Park** — new fix proposed here: align `rest_0021` to `hotel_02`'s coordinates. Medium-high confidence (postcode-level, not exact-address, corroboration).
- **ABaC** — flagged but **not resolved**. The same-building pattern strongly suggests the hotel's coordinate is again the correct one, but this session could not independently geocode-confirm it. Left `unresolved` rather than guessed, per the no-fabrication rule.
- **The other 7** — no action. Confirmed clean.
- **Process recommendation**: when the master catalogue is next rebuilt or re-imported, add a regression check for exactly this — any restaurant/hotel pair sharing a `google_place_id` whose coordinates differ by more than ~50m should fail CI, the same way the existing bounding-box check does. Two of three known cases self-corrected by trusting the hotel-side value; that heuristic could seed the fix but should not be applied blindly to the third (ABaC) without a real geocode.

Nothing in this audit has been applied to `supabase/data/*.csv`. See `p0_corrections.csv` for the Central Park and ABaC rows added as a result of this pass.
