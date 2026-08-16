# Wildfestival 2026 — Event Participant Enrichment Report

Status: research complete, event insert **PREPARED — NOT applied to production**. No Michelin restaurant or hotel relationship prepared (none established). Recommendation: **SELECTED — #2 (public gastronomic festival portfolio slot)**.

---

## 1. Event

| Field | Value |
|---|---|
| Name | Wildfestival |
| Edition | 3rd |
| Dates | 13 September 2026, 13:00–17:00 |
| City / Country | Apeldoorn, Veluwe, Netherlands (NL) |
| Venue | Hotel Gastronomique De Echoput |
| Official URL | https://www.echoput.nl/agenda |
| Ticket URL | Eventbrite (see `event_payload.json`) |
| Admission | `paid` — EUR 114, previous editions sold out |

Confirmed via the official Echoput agenda page and cross-validated by four independent sources (Apeldoorn Direct, Stedendriehoek, Strrn, De RestaurantKrant), all describing the same 2026, 3rd-edition event. Recurrence evidence is strong: distinct 1st/2nd/3rd-edition press coverage exists for this series. No duplicate event exists in production.

## 2. Chefs

**Peter Paul van den Breemen** (De Echoput, host) and **Jonathan Zandbergen** (Wild Atelier, co-presenting) — both confirmed via the official festival page.

## 3. Michelin participation

- **Restaurant candidates:** 2.
- **EXACT_MATCH:** 0 — neither De Echoput nor Wild Atelier exists in the production restaurant catalogue, confirmed via direct query (not merely a failed search).
- **Expected MICHELIN AT THIS EVENT preview:** section would not render.

Both restaurants are real, well-regarded Veluwe establishments and are recorded as catalogue-expansion candidates — not created here.

## 4. Hotel relationship

De Echoput is not in the production hotel catalogue either (confirmed via direct query) — no `event_hotels` relationship can be prepared. Recorded as a catalogue gap.

## 5. Quality score (1–5 scale, unweighted average)

| Dimension | Score |
|---|---|
| Gastronomic significance | 4 |
| Exclusivity | 3 |
| Michelin relevance | 1 |
| Travel-worthiness | 4 |
| Consumer accessibility | 5 |
| Chasing Stars brand fit | 4 |
| Source quality | 5 |
| **Average** | **3.71** |

**Editorial reasoning for selection:** despite the weakest Michelin-relevance score of the three selected events, Wildfestival is the clearest "public gastronomic festival" portfolio fit — recurring, well-documented, genuinely seasonal/regional (game season opening), and sells out, evidencing real consumer demand. It's the closest Dutch analogue to 't Preuvenemint's own proven model (a curated public festival, not a private dinner) and fills a portfolio slot none of the other candidates cover.

## 5b. Fresh re-verification (Dutch Catalogue Gap Pass)

Re-checked, not blindly reused: date (13 Sep 2026), price (€114), 3rd-edition framing, and both chefs' restaurant affiliations all re-confirmed unchanged. De Echoput was re-checked as a potential hotel candidate too (it operates as "Hotel Gastronomique De Echoput") — confirmed absent from the hotel catalogue as well as the restaurant catalogue, and in any case would need to independently satisfy the Michelin Key/W50B union rule to qualify as a hotel, which no evidence found in this pass supports.

## 6. Data quality

- No duplicate participants (2 unique).
- No Michelin star data fabricated or sourced from the event's own website.
- `insert_event.sql` contains a plain insert with zero relationship rows and zero literal UUIDs.

## 7. APPLIED AND VERIFIED (production apply, 2026-08-16)

- **Production event id:** `eaad5729-e88c-47fa-b842-0343f6f794a2`
- **Pre-flight duplicate check:** zero existing rows for this name/date before insert.
- **Post-insert independent re-query:** all fields confirmed to exactly match the prepared payload.
- **Relationship counts:** `event_restaurants` = 0, `event_hotels` = 0 — confirmed correct and expected.
- **Runtime verification:** confirmed live via the anon-key PostgREST endpoint — event appears correctly in the full events list, `event_restaurants` REST query returns `[]`.
- **Trip-match compatibility:** confirmed via code inspection — same `country_code`/`city` shape as 't Preuvenemint.
- **applied_at:** 2026-08-16. **verified_at:** 2026-08-16.
