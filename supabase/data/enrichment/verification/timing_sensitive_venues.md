# Timing-sensitive venues — current state (7 Aug 2026) vs. known future change

Three venues where the catalogue must not be updated to a state that hasn't happened yet. For each: what's true today, what's scheduled, and exactly what should be imported now vs. queued.

---

## La Paix (`rest_0158`)

| | |
|---|---|
| **Current state, 7 Aug 2026** | **Open**, operating at its original address, Rue Ropsy-Chaudron 49, 1070 Bruxelles (Anderlecht). Still holds 2 MICHELIN stars. |
| **Known future change** | Moving to Corinthia Grand Hotel Astoria Brussels (`hotel_153`), confirmed by the restaurant's own site (`lapaix.eu`): *"La Paix déménage à partir du 15 septembre 2026. Adresse : Corinthia Hotel Astoria – Brussels."* Corroborated by Belgian press (La Libre, L'Echo, Brussels Times). |
| **Import now** | The restaurant at its **current** Anderlecht identity: open, 2 stars, address Rue Ropsy-Chaudron 49 (coordinates/Place ID for this specific address remain unverified in this session — see `p0_corrections.csv` MA-064, still `unresolved`). Do **not** import the currently-quarantined row's stored address/coordinates/Place ID (Rue Royale 103) — those belong to the future Corinthia location, not today's. |
| **Queue for later** | The `hotel_restaurants` link to `hotel_153`, and the post-move address/coordinates/Place ID. Explicitly do not create either before 15 Sept 2026 — the move hasn't happened. |

This was already the P0 pass's finding (MA-064); reaffirmed here, not re-litigated.

---

## Kyo Seika (Kyoto)

| | |
|---|---|
| **Current state, 7 Aug 2026** | Not in the catalogue (MA-056 — original lookup returned an unrelated ramen house). This pass's P0 research found an address for the correct venue at medium confidence, **and** found it is currently reported **temporarily closed**. |
| **Known future change** | Reopening reported for "September" — **year not stated in the source found**, presumed 2026 but not confirmed. |
| **Import now** | Do not import as `status = open`. If imported at all before the reopening is confirmed, it should carry `status = temporarily_closed` with a `status_note`, mirroring the treatment already established for La Paix. |
| **Queue for later** | Confirm the reopening date (and year) before flipping to `open`. This is a new, smaller version of the same problem as La Paix — flagged here rather than left implicit. |

---

## Kenya (Kyoto)

| | |
|---|---|
| **Current state, 7 Aug 2026** | Not in the catalogue (MA-056 — original lookup returned a student cafeteria). Confirmed via WebSearch: **1 MICHELIN star** in the current 2026 guide (guide.michelin.com listing, via search snippet), restaurant phone number recovered. |
| **Known future change** | None found — the "relocation" flagged in the prior pass (§P0 report, new finding #8: "Kenya has relocated since MA-056 was written") describes something that has **already happened**, not a scheduled future change. This is a currency problem (the address on file for the wrong-lookup venue is stale), not a timing problem in the sense of the other two. |
| **Import now** | Star count (1) is confirmed and safe to use once the restaurant is added. **Address and coordinates are still not independently verified in this session** — guide.michelin.com's full address field was not retrievable via WebSearch (only the phone number surfaced). Do not import without a verified address. |
| **Queue for later** | A dedicated address/Place ID lookup, ideally with direct Google Maps/Places access this environment doesn't have. |

---

## Summary table

| Venue | Import now as | Do not do |
|---|---|---|
| La Paix | Open, current Anderlecht address (coords/Place ID still unresolved) | Do not use the quarantined row's Corinthia-address values; do not create the `hotel_153` link |
| Kyo Seika | If imported: `temporarily_closed` with a note | Do not mark `open`; do not assume the reopening year |
| Kenya | Not enough verified data to import yet (star count only) | Do not import without a verified address |
