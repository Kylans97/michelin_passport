# P0 Data Quality — Investigation Report

**Status: research only.** Nothing in this report or in `p0_corrections.csv` has been applied to `supabase/data/*.csv`, to any migration, or to any database. Every line below is a proposal for human review, per `supabase/data/enrichment/PROVENANCE_SCHEMA.md`.

**Method.** Every item was checked against WebSearch/WebFetch results, preferring (in order): the venue's own official site, its parent hotel group/operator, reputable press, and established travel-industry aggregators. `guide.michelin.com` returned HTTP 403 on every direct `WebFetch` attempt made during this investigation (Villa Feltrinelli, the Italy stars-ceremony article, Sofitel Frankfurt, Verve by Sven, Lai Ching Heen, La Paix), confirming the project's own note that MICHELIN's site blocks automated fetching. All findings involving MICHELIN's own position are therefore sourced from search-result snippets and secondary aggregators, not a direct read of the MICHELIN page, and are marked `medium` or `low` confidence accordingly, per `PROVENANCE_SCHEMA.md`. No coordinate or Google Place ID was invented anywhere in this file or in `p0_corrections.csv` — every geodata gap is left `unresolved` with `proposed_value = "unable to verify"`.

Full per-field detail, sources, and status are in `p0_corrections.csv` (68 rows). This report explains the reasoning and groups findings by outcome.

---

## Summary of outcomes

| Outcome | Count (rows in CSV) |
|---|---|
| `proposed` (ready for human review) | 29 |
| `rejected` (investigated, no change needed) | 9 |
| `unresolved` (could not verify — flagged, not guessed) | 30 |

Of the 17 MA numbers investigated (covering all 19 tracked QA/MA items across Groups A–D, several MA numbers bundling multiple sub-venues):

- **Fully or mostly resolved at high/medium confidence:** MA-045, MA-046 (partially), MA-051, MA-064, MA-067, MA-068, MA-069, MA-070, MA-071 (address only), MA-062 (Jean-Georges piece) — 9 items with at least one high/medium-confidence, actionable finding.
- **Partially resolved (address found, geodata not):** MA-054, MA-055, MA-056 (Kyo Seika only), MA-057, MA-060, MA-066 — 6 items with a name/address lead but no verifiable coordinates or Place ID.
- **Left unresolved or newly complicated:** MA-048 (identity of the Place IDs themselves could not be confirmed for 6 of 9 properties — see below), MA-056 (Kenya — address is now stale, venue relocated).

---

## Group A — the 4 critical value conflicts

### MA-067 / QA-176 — Villa Feltrinelli star count: **no change** (high-medium confidence)
Two independent secondary sources that each publish the complete Italy 2026 two-star roster (archieinteriors.com, universofood.net) both list Villa Feltrinelli under **two** stars, not three. The 28-Jul-2026 MICHELIN card capture was very likely misread. As a consequence, **MA-051's "Italy becomes 16 three-star" hypothesis does not hold** — both sources independently list exactly 15 three-star restaurants for Italy 2026, and Villa Feltrinelli is not one of them.

### MA-051 / QA-090 — the "38th Italian two-star": bigger than one missing name
This is the most consequential finding in Group A. Cross-referencing the current `restaurants_master.csv` (37 Italian two-star rows) against two independent, mutually-consistent 2026 rosters (archieinteriors.com and universofood.net, 38 names each) shows:

- **Two restaurants are genuinely missing**, not one: **Torre del Saracino** (Vico Equense, chef Gennaro Esposito — confirmed 2★ on its own official site, `torredelsaracino.it`) and **Il Piccolo Principe** (Viareggio, inside Grand Hotel Principe di Piemonte — 2★ since 2014 per multiple sources).
- **One existing row is misclassified**: `rest_0394` **Tre Olivi** (Paestum) is stored as 2 stars, but every 2026-dated source found (universofood.net explicitly, plus press coverage of a 2025 chef change) shows it now holds **1 star**. The "confirmed two-star" reference in the project's own QA-090 note traces to an earlier (2022) article, predating the demotion.
- Net effect: 37 (current) − 1 (Tre Olivi correction) + 2 (new rows) = **38**, reconciling the roster exactly.

Addresses for the two missing restaurants are proposed at medium confidence; coordinates and Place IDs could not be verified for either and are left unresolved.

### MA-068 / QA-177 — Sofitel Frankfurt Opera address: **no change** (high confidence)
The premise — that "Opernplatz 16" and "Hochstraße 44" are ~400 m apart — is wrong. The hotel occupies a **triangular block with three street frontages** (Opernplatz, Hochstraße, and Wallanlagen park); its own operator page (`all.accor.com/hotel/8159`) lists both addresses together for the same building, and its own contact page (`sofitel-frankfurt.com/contact-us`) states Hochstraße 44 as the current, sole point of access. This is one building with dual postal addressing, not a location conflict. No change proposed to address, coordinates, or Place ID.

### MA-069 / QA-178 — Château Neercanne: address confirmed correct, but a **real coordinate bug found**
The stored address ("Von Dopfflaan 10") is confirmed correct by the property's own operator site and by Wikipedia — MICHELIN's alleged "Von Dopffplein" does not check out. However, in the course of checking this, an independent bug surfaced: **`rest_0022` and `hotel_13` share the identical `google_place_id`** (already "Ratified" by the project as one legitimate shared record per `venues_to_check.csv` row W023) **but store coordinates roughly 1.7 km apart.** Wikipedia's independently sourced coordinates (50.8188833°N, 5.6679306°E) match `hotel_13`'s stored value almost exactly, meaning `rest_0022`'s coordinates are the ones that are wrong. Proposed fix: update `rest_0022` latitude/longitude to match `hotel_13`.

### MA-070 / QA-179 — Flores Raras address: **no change** (high confidence)
The restaurant's own official site (`floresraras.com`) and its parent group's press release both give "8, Correos St, 1st floor" — matching the currently stored house number 8, not the "43" MA-070 attributes to the MICHELIN card. No change proposed; optionally the floor designator "1º" could be appended.

---

## Group B — 10 Place ID / identity issues

### MA-048 — the "9 hotels returning a restaurant/facility" pattern
This turned out to be three different situations, not one:

1. **Confirmed shared-record pattern** (Terra – The Magic Place `hotel_460`, Atrio `hotel_480`): each shares an *identical* `google_place_id` and identical coordinates with its sibling restaurant row already in the catalogue (`rest_0419`, `rest_0350`). This is strong internal evidence supporting MA-048's suspicion, but this workspace has no Google Places API access to confirm the listing's `type` field, so the Place ID field itself is left `unresolved` rather than "fixed" — there is no verified alternate ID to propose.
2. **New coordinate-mismatch bug** (ABaC `hotel_537` / `rest_0002`): same shared Place ID, but **different** coordinates (~460 m apart) — the same bug pattern as Château Neercanne above, flagged but not resolved (no independent source with precise coordinates was found).
3. **Already resolved, contradicts MA-048's own framing** (Villa Feltrinelli, hotel side): no `hotel_master` row exists for "Grand Hotel a Villa Feltrinelli" at all — and per the project's **own** `QA-095` and `venues_to_check.csv` (row W019, "Resolved - non-Key property"), none should exist, because the hotel does not hold a MICHELIN Key. `rest_0403` already stores `property_name` correctly as contextual metadata. **No action needed** — MA-048 should not have listed this as an open Place ID question.
4. **Evidence against the suspicion** (Rote Wand `hotel_136`): the sibling restaurant (`rest_0271`) already has a distinct Place ID and a different building number, and the link between them is already `"Approved - Exact"` in `venues_to_check.csv` (row W066). No internal evidence supports a problem here.
5. **Genuinely unverifiable without Places API** (Seesteg Norderney, Widmann's Löwen, L'Ovella Negra, Quadrille): addresses confirmed correct against each property's own site, but none has a separately-catalogued sibling restaurant to cross-check against, so the Place-ID-type question is left open.
6. **A factual correction to MA-048 itself**: the note speculates "Quadrille (Spain — likely Atrio-adjacent)." This is wrong — `hotel_315` Quadrille is a real, unrelated Relais & Châteaux property in **Gdynia, Poland**, confirmed via `relaischateaux.com` and its own site `quadrille.pl`, with no connection to Atrio or Spain whatsoever.

### MA-046 / QA-112 — Hong Kong
- **L'Atelier de Joël Robuchon** (`rest_0452`): the stored address currently splices "Shop 401" (which The Landmark's own tenant directory attributes to the *separate* sibling concept, Le Jardin de Joël Robuchon) together with "415." Proposed correction: "Shops 403-410, 4/F, The Landmark" per `landmark.hk`'s own page for L'Atelier. The Place ID itself remains unverified.
- **Lai Ching Heen** (`rest_0451`): **not actually a merged-identity problem.** The South China Morning Post confirms this is one restaurant whose name has changed twice in step with the hotel's own rebranding (Regent → InterContinental "Yan Toh Heen" → Regent "Lai Ching Heen" again). No change proposed.

### MA-045 / QA-109 — Macau: **wrong resort entirely** (high confidence)
MA-045's premise — that The Huaiyang Garden is "a different restaurant at the same [Grand Lisboa Palace] resort" as Palace Garden — is incorrect. Four independent sources (Sands Resorts Macao's own press release, OpenRice, The Londoner Macao's own site, Trip.com) confirm **The Huaiyang Garden is at The Londoner Macao**, a completely different Cotai resort. The two restaurants only share superficial name/cuisine similarity ("Garden"), which likely explains the original search-engine confusion. Address proposed at high confidence; coordinates/Place ID unresolved.

### MA-054 / QA-144 — Japan hotels
All three (Atami Izusan Karaku, Kinugawa Keisui, Benesse House) are confirmed still absent from `hotels_master.csv`. Addresses were found for Atami Izusan Karaku (medium confidence) and Benesse House (medium confidence, neighborhood-level precision); no verifiable street address for Kinugawa Keisui was found at all. Key counts (1, 1, 2 respectively) are already established in the project's own `venues_to_check.csv`. No coordinates/Place IDs verified for any of the three.

### MA-055 / MA-056 / MA-057 — Kyoto/Tokyo restaurants
- **Ogata** (Kyoto): address confirmed at medium confidence, clearly distinct from the wrongly-returned "Youshoku Ogata."
- **Kyo Seika** (Kyoto): address confirmed at medium confidence. **New finding:** the restaurant is reported temporarily closed, expected to reopen in September — worth flagging for import timing.
- **Kenya** (Kyoto): **new finding — the venue has relocated.** Tabelog's own listing is explicitly marked "[Relocated]" as of early 2026; the address in MA-056/`venues_to_check.csv` is now stale. A new listing exists near Takaragaike, but its exact street address could not be read (the page returned HTTP 403). Left fully unresolved rather than importing a known-outdated address.
- **Sassa** (Tokyo): address confirmed at medium confidence in the Hiroo district, consistent with MA-057's note that the wrongly-returned "Sasaya Asakusa" is in a different district.
- **Hyakuyaku by Tokuyamazushi** (Tokyo): address confirmed at high confidence in Ginza, Tokyo — directly refuting the claim that the only findable record was 350 km away in Shiga prefecture. A genuine Tokyo branch exists with its own address.

### MA-060 / QA-177(US) — Masa, New York
Confirmed address (10 Columbus Circle, 4th floor) and confirmed 2-star status (demoted from 3 in Nov 2025, per the project's own note). However, **Masa and Bar Masa share the same building and floor**, so address alone cannot disambiguate their Google Place IDs — the Place ID field is left unresolved rather than guessing which of the two listings is which.

### MA-062 / QA-180 — property names
- Cristal Room and L'Atelier de Joël Robuchon (Hong Kong): cross-referenced only — already correctly resolved per the project's own 28-Jul-2026 update (`located_in_hotel=false`, `property_name` blank), confirmed against current `restaurants_master.csv`.
- **Jean-Georges** (New York): resolved at high confidence. Wikipedia confirms Jean-Georges has occupied the ground floor of the **Trump International Hotel and Tower** at 1 Central Park West since 1997. Since that hotel does not appear to hold a MICHELIN Key, per the project's own hotel-scope rule this should be stored as `property_name` contextual metadata only — no new `hotels_master` row or link — exactly like the other 31 restaurants already handled this way.

---

## Group C — 3 confirmed-missing venues

### MA-071 — Widder Hotel & The Dolder Grand, Zurich
Both addresses confirmed (Widdergasse 6, 8001 Zürich; Kurhausstrasse 65, 8032 Zürich). Key counts (2 and 2) were already established in the project's own `venues_to_check.csv`. **Widder Hotel's address is character-for-character identical to `rest_0264` Widder Restaurant's already-stored address**, supporting the proposed `hotel_restaurant_links` row — but its coordinates/Place ID are *not* assumed to be identical to the restaurant's without independent confirmation (see the ABaC and Château Neercanne findings above, where identical addresses did **not** guarantee identical coordinates). Coordinates and Place IDs for both hotels are left unresolved.

### MA-066 — Verve by Sven, Bad Ragaz
Two sources conflict on the house number: one gives "Bernhard-Simonstrasse 14" (matching the address already verified and imported for sibling resort restaurants Memories and IGNIV), the other gives "Bernhard-Simon-Strasse 2." Rather than pick one, this is left **unresolved** with both candidates documented and a lean toward "14" explained — per the guardrail against guessing when evidence conflicts. Also worth noting: Memories and IGNIV, despite sharing one street address, have two *different* coordinate pairs and Place IDs ~150 m apart — so even a confirmed address for Verve by Sven would not be enough to safely infer its coordinates from a sibling.

---

## Group D — La Paix

### MA-064 / QA-054 — resolved with a concrete date (high confidence)
This is the single most actionable finding in the whole investigation. La Paix's own official site (`lapaix.eu`) states directly: **"La Paix déménage à partir du 15 septembre 2026. Adresse : Corinthia Hotel Astoria – Brussels, Rue Royale 103, 1000 Bruxelles."** Independent Belgian press (La Libre, L'Echo, Brussels Times) corroborates a move "effective September 15, 2026." As of this research (2026-08-07):

- La Paix is **currently open** and taking reservations at its original Anderlecht address, **Rue Ropsy-Chaudron 49, 1070 Bruxelles** — confirmed by the restaurant's own site, resolving the address half of MA-064/QA-054 at high confidence.
- It has **not yet moved.** The move is roughly five weeks away from today.
- This also explains the apparent contradiction between the "TEMPORARILY CLOSED" MICHELIN card (captured 28 Jul 2026) and the restaurant's own site, which frames itself as open through the transition — these are consistent with a scheduled future closure/move, not a current closure.
- The currently quarantined coordinates (50.851154, 4.365088) are confirmed to essentially duplicate `hotel_153` Corinthia's own stored coordinates (50.851163, 4.365092) — corroborating the project's existing theory that the quarantined row holds the *future* Corinthia location, not today's Anderlecht one.

**Recommended import path:** import `rest_0158` now at its current, open, Anderlecht identity (address corrected to Rue Ropsy-Chaudron 49), not the future Corinthia identity. Coordinates and a Place ID for the Anderlecht address could not be verified via WebSearch/WebFetch and are left unresolved — do not import any coordinate/Place ID for this row until confirmed directly in Google Maps. **Do not create the `hotel_153` link yet** — revisit after 15 September 2026, and when that day comes, get a *fresh* Place ID for the restaurant's own listing at the Corinthia rather than reusing the hotel's Place ID for the restaurant tenant.

---

## New issues found that were not among the original 19

1. **`rest_0022` / `hotel_13` (Château Neercanne) coordinate mismatch** — ~1.7 km apart despite an identical, already-"Ratified" shared Place ID. High confidence fix proposed (align to `hotel_13`'s Wikipedia-confirmed value).
2. **`rest_0002` / `hotel_537` (ABaC) coordinate mismatch** — ~460 m apart despite an identical shared Place ID. Same bug family as #1; not resolved, flagged for a fresh lookup.
3. **Tre Olivi (`rest_0394`) is stored as 2★ but appears to be 1★ in the 2026 guide** — the "confirmed two-star" source cited in QA-090 appears to predate a subsequent demotion/chef change.
4. **Two Italian two-star restaurants are missing outright** (Torre del Saracino, Il Piccolo Principe) — MA-051 undercounted the gap as one name when it is at least two names plus one misclassification.
5. **MA-048's characterization of "Quadrille" as a Spanish, Atrio-adjacent property is wrong** — it is an unrelated Gdynia, Poland property.
6. **MA-045's characterization of The Huaiyang Garden as being at the same resort as Palace Garden is wrong** — they are at entirely different Macau resorts (The Londoner Macao vs. Grand Lisboa Palace).
7. **MA-048's inclusion of "Villa Feltrinelli (hotel side)" is moot** — the project's own QA-095/`venues_to_check.csv` already closed this as a non-Key property that correctly has no hotel row.
8. **Kenya (Kyoto) has relocated** since MA-056 was written; its documented address is now stale.
9. **Kyo Seika (Kyoto) is reported temporarily closed**, expected to reopen in September — relevant to import timing, similar to the La Paix situation.
10. **La Paix's move has a confirmed hard date** (15 September 2026) not previously captured in the project's notes.

---

## What remains genuinely unresolved (and why)

The largest single limitation across this investigation is the **lack of Google Places API access** in this research environment. WebSearch and WebFetch can confirm names, addresses, and (via search-result snippets and official sites) award tiers, but cannot return a Google Place's `place_id` or its `types` classification, and Google Maps itself blocks automated fetching behind a consent wall. Every row in `p0_corrections.csv` needing a coordinate or Place ID that could not be independently corroborated from a non-Google source is marked `status=unresolved`, `proposed_value="unable to verify"` — nothing was guessed. A human reviewer with Google Maps/Places access should treat the `unresolved` rows as a punch list: 30 of the 68 rows in the corrections file need exactly that kind of manual lookup, concentrated in: all new-venue coordinate/Place-ID fields (Groups B and C), the MA-048 Place-ID-type question for 6 of 9 hotels, Kenya's new address, and Verve by Sven's exact house number.
