# Erloom x Henrique Sá Pessoa — Event Participant Enrichment Report

Status: research complete, event insert **PREPARED — NOT applied to production**. No Michelin restaurant or hotel relationship prepared (none established). Recommendation: **SELECTED — #1 (Top Dutch MVP Event)**.

---

## 1. Event

| Field | Value |
|---|---|
| Name | Erloom x Henrique Sá Pessoa |
| Dates | 25–27 September 2026 |
| City / Country | Hilvarenbeek, Netherlands (NL) |
| Venue | Erloom, a traveling open-air pop-up restaurant on bio-boerderij 't Schop |
| Official URL | https://erloom-restaurant.com/chefs/henrique-sa-pessoa/ |
| Admission | `paid` — EUR 99 (lunch) / EUR 129 (dinner), publicly bookable |

Confirmed via the official Erloom site and cross-validated by Barts Boekje (independent Dutch food-culture editorial). Erloom itself is a genuine, distinctive concept — a rotating weekly guest-chef residency on a working farm, running May–September, each weekend featuring a different chef "from the Netherlands and beyond." No duplicate event exists in production.

## 2. Chef

**Henrique Sá Pessoa** — concept chef of ARCA (art'otel Amsterdam) and chef of **Alma**, Lisbon, which holds **2 Michelin stars**. His restaurant identity was independently confirmed via missethoreca.nl-style Dutch food press and the event's own chef page.

**Michelin recognition of Alma is real but not reflected in the Chasing Stars catalogue** — Portugal coverage in production is limited to a single restaurant (Belcanto), and Alma (Lisbon) is not present. A name-collision trap was specifically checked and ruled out: a *different*, unrelated restaurant also named "Alma" exists in the catalogue in Oisterwijk, Netherlands (1 star) — confirmed via direct query to be a distinct restaurant, not linked here.

**Provenance note (chef-led event, no schema built per the task's instruction):** Sá Pessoa's Amsterdam venture, ARCA (art'otel Amsterdam), also runs its own recurring "Behind the Pass" quarterly guest-chef series — a related but separate event concept, recorded in `candidate_events.csv` as a future-watchlist item (candidate H), not selected here since no confirmed future 2026 date was found.

## 3. Michelin participation

- **Restaurant candidates:** 1 (Henrique Sá Pessoa / Alma).
- **EXACT_MATCH:** 0.
- **Expected MICHELIN AT THIS EVENT preview:** section would not render — no Michelin-starred restaurant currently in the catalogue is linked to this event. This does not disqualify the event per the task's own explicit product direction ("A Michelin-starred restaurant does NOT have to participate for an event to be eligible").

## 4. Hotel relationship

None. Erloom is hosted on a working farm, not a hotel — no `event_hotels` relationship applies.

## 5. Quality score (1–5 scale, unweighted average)

| Dimension | Score |
|---|---|
| Gastronomic significance | 5 |
| Exclusivity | 5 |
| Michelin relevance | 2 |
| Travel-worthiness | 5 |
| Consumer accessibility | 5 |
| Chasing Stars brand fit | 5 |
| Source quality | 5 |
| **Average** | **4.57** |

**Editorial reasoning for selection despite low Michelin-relevance score:** this is the single most distinctive, "worth-travelling-for" concept found in the entire Dutch sweep — a rotating international guest-chef farm residency is exactly the "limited culinary residency" archetype the task's own product direction calls out as exemplary. The curation test ("would someone travel for this? does this beat checking the restaurant's normal reservation page?") is answered clearly yes on both counts — Erloom isn't even a normal restaurant with a normal reservation page; it only exists because of events like this one. The chef's real 2-star pedigree (Alma, Lisbon) adds genuine credibility even though it isn't currently displayable via MICHELIN AT THIS EVENT.

## 5b. Fresh re-verification (Dutch Catalogue Gap Pass)

Re-checked, not blindly reused: dates (25-27 Sep 2026), pricing (€99/€129), chef identity, and Alma's 2-star status all re-confirmed unchanged. The Alma/Alma name-collision check (Lisbon vs. Oisterwijk) was re-verified against production directly (`select ... where name ilike '%alma%'`) and still resolves to two genuinely distinct restaurants. No hotel relationship applies to this event (farm venue) — unaffected by this pass's Okura/Krasnapolsky hotel-eligibility findings, which are specific to those two properties.

## 6. Data quality

- No duplicate participants (1 unique).
- No Michelin star data sourced from the event's own website — Alma's 2-star status was independently corroborated by Dutch food press, and no star count was fabricated or attributed to any catalogue restaurant.
- Name-collision risk (Alma/Alma) explicitly checked and ruled out before concluding NO_MATCH.
- `insert_event.sql` contains a plain insert with zero relationship rows (nothing to link) and zero literal UUIDs.

## 7. APPLIED AND VERIFIED (production apply, 2026-08-16)

- **Production event id:** `d09498ce-df42-4885-98d9-ec26fae5945c`
- **Pre-flight duplicate check:** zero existing rows for this name/date before insert.
- **Post-insert independent re-query:** all fields (name, city, country, dates, venue, URLs, event_type, status, admission) confirmed to exactly match the prepared payload.
- **Relationship counts:** `event_restaurants` = 0, `event_hotels` = 0 — confirmed correct and expected, not incomplete.
- **Runtime verification:** confirmed live via the anon-key PostgREST endpoint (same path the app uses) — the event appears correctly in the full events list, and its `event_restaurants` REST query returns `[]`.
- **Trip-match compatibility:** confirmed via code inspection of `eventMatchesTrip` — `country_code`/`city` are populated in the same shape as 't Preuvenemint's own row; no format issue.
- **applied_at:** 2026-08-16. **verified_at:** 2026-08-16.
