# DUTCH EVENT ENRICHMENT — BATCH 2 DEEP VERIFICATION + PRE-APPLY

Continuation of the Dutch Event Enrichment Sprint, drawing exclusively
from candidates already discovered in
`DUTCH_EVENT_ENRICHMENT_SPRINT_AUDIT.md` /
`dutch_event_candidates_2026_2027.json` — no new market discovery was
performed. Nothing in this document was inserted, updated, or staged.

## 1. STATE RECONSTRUCTION

Production re-read fresh: `events` count = **17**, matching the
finalized Batch 1 state exactly. All 8 Dutch Batch 1 Events
(`60271509…`, `12dea83b…`, `bb917cbc…`, `7d9db50e…`, `2a76f968…`,
`b7e5b3f7…`, `226646cf…`, `de0a1aee…`) confirmed present exactly once.
No discrepancy found — proceeded as planned.

**Remaining candidate pool from today's Dutch sprint**: 27 total
candidates − 8 already in Batch 1 = **19 remaining** (5 P1, 10 P2, 4
EXCLUDE from the original sprint's own classification). No candidate
from Batch 1 was reconsidered.

## 2. BATCH 2 CANDIDATE SELECTION

Selected the 5 P1 candidates plus the 7 strongest P2 candidates for
deep verification — 12 total, deliberately not capped to a round
number, and deliberately excluding the 4 original EXCLUDE items
(weak/thin sourcing) and 2 P2 items with known structural concerns
(Oesterparade's MULTI_SESSION_REVIEW flag; the Karels↔Olde Marckt
reciprocal leg's unconfirmed year, redundant with the Olde Marckt leg
already selected):

1. VanOost Sundays | BBQ with Friends
2. Wine & Dine × Pierre Ache Wijnen (Van Oys Maastricht Retreat)
3. Wijnmakersdiner Montanha Vermelha (Kaatje bij de Sluis)
4. Wijnmakerslunch Heidi Schröck & Söhne (De Echoput)
5. Four-Hands Diner: Olde Marckt x Karels
6. Club Leroy bij Parkheuvel
7. Chaîne des Rôtisseurs Gala Dîner op SS Antoinette
8. Jubileumdiner — 5 jaar Restaurant Roemer
9. Friends & Family Zomer BBQ met Marko Karelse ('t Ganzenest)
10. Exclusieve Wijnproeverij — Domaine Paul Pillot ('t Ganzenest)
11. Exclusieve Wijnproeverij — Tenuta San Guido / Sassicaia ('t Ganzenest)
12. "Chardonnay & Spätburgunder" Wine & Food Lunch (Karel 5)

## 3. FRESH VERIFICATION — SIX PARALLEL PASSES

Every candidate was independently re-fetched from live sources this
pass — none of today's earlier sprint findings were trusted without
re-checking. Result: **10 of 12 CONFIRMED_UNCHANGED and READY**, 2
HOLD. Notable corrections/upgrades found:

- **'t Ganzenest triplet — year resolved for all three.** The
  venue's own booking-system API (reached via the "Reserveer" button's
  underlying endpoint, the same technique that resolved Bij Jef's year
  in Batch 1) returns explicit dd-mm-yyyy dates in the venue's own
  ticket text: "Zondag 30 augustus 2026," "Donderdag 24-09-2026,"
  "Donderdag 19-11-2026." Prices also newly confirmed: €130pp (BBQ),
  €450pp/€150 deposit (both wine tastings, shared ticket product).
  Marko Karelse's link to Villa la Ruche (Voorburg), previously
  unconfirmed, is now confirmed via JRE.eu and the restaurant's own
  site.
- **Sassicaia tasting (Nov 19) — a genuine new concern.** Live
  booking-system queries show no bookable slot currently exists for
  this date (empty slot array), unlike the Sept 24 tasting on the same
  shared ticket product, which returns a defined bookable slot. No
  explicit "sold out" or "cancelled" messaging exists anywhere — this
  reads as a slot simply not yet opened 3 months out, but cannot be
  confirmed either way. **This is why this one candidate alone is
  held, not rejected or inserted.**
- **Van Oys Wine & Dine — upgraded from START_KNOWN_END_UNKNOWN to
  FULL_TIME.** The event's own detail box explicitly states "Time:
  18:30 – 22:30," a genuine published range missed in the original
  sprint pass.
- **Olde Marckt x Karels — Michelin status upgraded to A-confidence.**
  Directly confirmed via Michelin's own guide page this pass (1 star,
  awarded Oct 2025), versus B-confidence in the original sprint.
- **De Echoput's recognition status is now genuinely ambiguous** — the
  historic single restaurant was restructured in 2025 into "Grand
  Bistro Echo" and a new fine-dining concept "Wild Atelier" under chef
  Jonathan Zandbergen; sources could not confirm at A-confidence
  whether either currently holds a Michelin star. This doesn't block
  the candidate (De Echoput remains external/uncatalogued either way,
  same as the existing Wildfestival precedent) but no star claim is
  made in its description.
- **Restaurant Roemer — modest recognition upgrade.** Now confirmed
  (C-confidence) to hold a Gault&Millau newcomer-tier listing
  (~12 points/1 Toque) — previously believed to carry zero external
  recognition.
- **VanOost BBQ — one location correction.** Niven Kunz's restaurant
  Triptyque is in Wateringen, not Waalre as the original sprint notes
  stated — this matches Mantelier's own canonical catalogue record
  for Triptyque exactly, so no data-quality issue exists in production,
  only in the prior research note.
- **Karel 5 lunch — source weakness confirmed, not resolved.**
  karelv.nl was reached directly this pass (previously inaccessible)
  and has no agenda page and zero mention of this event anywhere. The
  only source remains the national sommelier guild's own calendar.
  **This is why this candidate is held, not inserted.**
- One end-time value was specifically investigated and discarded: the
  Chaîne Gala's "22:00" appeared in one fetch but could not be
  confirmed as a genuine on-page label rather than a summarization
  artifact — excluded rather than risked.

## 4. DATE/TIME PRECISION

| Candidate | Precision | Start / End |
|---|---|---|
| VanOost BBQ with Friends | DATE_ONLY | no time published |
| Van Oys Wine & Dine × Pierre Ache | **FULL_TIME** | 18:30–22:30 CEST |
| Wijnmakersdiner Montanha Vermelha | DATE_ONLY | no time published |
| Wijnmakerslunch Heidi Schröck | START_KNOWN_END_UNKNOWN | 11:45 reception start; end explicitly "rond 16:00" (approximate) — excluded |
| Olde Marckt x Karels | START_KNOWN_END_UNKNOWN | 13:00 arrival-window start; 15:00 is last-arrival, not meal end — excluded |
| Club Leroy bij Parkheuvel | START_KNOWN_END_UNKNOWN | 13:00 check-in start; no reliable end |
| Chaîne Gala SS Antoinette | START_KNOWN_END_UNKNOWN | 17:00 reception start; "22:00" excluded as unreliable |
| Roemer Jubileumdiner | START_KNOWN_END_UNKNOWN | 18:00 check-in start; no end |
| Ganzenest BBQ Karelse | DATE_ONLY | no time published |
| Ganzenest Paul Pillot | DATE_ONLY | no time published |

No fabricated time anywhere. Every excluded end-time was excluded for
a specific, documented reason (explicit "approximate" wording, an
arrival-window boundary being mistaken for a meal end, or unreliable
sourcing) — never because time was simply missing.

## 5. SESSION MODEL

All 10 READY candidates: **SINGLE_EVENT**. None required session-model
review this pass (the two candidates with known session-model
concerns — Oesterparade, the Karels↔Olde Marckt reciprocal leg — were
deliberately not selected into this batch).

## 6. DUPLICATE CHECK

All 10 candidate titles checked against all 17 live Events by title —
zero matches. Same-date coincidences exist and were individually
confirmed as genuinely distinct real-world events (different venue,
city, and host in every case): 2026-09-13 (Chaîne Gala/Amsterdam vs.
Wildfestival/Apeldoorn vs. Forces of Nature/Slovenia — three unrelated
events sharing a date), 2026-09-24 (Ganzenest Paul Pillot/Rijswijk vs.
Six Hands Dinner/Texel), 2026-10-18 (Echoput wine lunch/Apeldoorn vs.
Game Brunch/Eijsden).

## 7. CANONICAL ENTITY MATCHING

| Entity | Type | Classification | UUID |
|---|---|---|---|
| Van Oys Maastricht Retreat | Hotel | EXACT | `4d09cb3c-7dd0-408e-80ac-02642a6b320b` |
| Kaatje bij de Sluis | Restaurant | EXACT | `a4581a6e-7ec2-48ec-8958-2ec7ded46592` |
| Olde Marckt | Restaurant | EXACT | `8f7cb302-8c83-47ba-bb80-2456689a89ff` |
| Parkheuvel | Restaurant | EXACT | `90d2b4ae-2b39-4bed-beec-31d6008a7ea8` |
| 't Ganzenest | Restaurant | EXACT | `bec64ec6-5f9a-4f73-9bae-a8c61f50fea2` |
| Triptyque | Restaurant | EXACT | `2d37657d-36b6-4f9c-a087-397b22a86d07` |
| Basiliek | Restaurant | EXACT | `8a4d032b-6e9b-4d5c-85ed-68f667f0366b` |
| VanOost | Restaurant | NOT_FOUND (external) | — |
| De Echoput | Hotel | NOT_FOUND (external — confirmed: zero relationship rows exist even for its own existing Wildfestival Event, consistent precedent) | — |
| Restaurant Karels / Villa la Ruche | Restaurant | NOT_FOUND (external participants) | — |
| Chaîne des Rôtisseurs (organizer) / SS Antoinette (venue) | — | NOT_FOUND (neither is a Restaurant/Hotel entity) | — |
| Restaurant Roemer | Restaurant | NOT_FOUND (external) | — |
| Pierre Ache Wijnen / Montanha Vermelha / Domaine Paul Pillot / Heidi Schröck & Söhne | wine producers/merchants | N/A — not Restaurant/Hotel/Chef entities | — |

No catalogue entity was created for any NOT_FOUND or N/A entry.

## 8. HOST / VENUE / PARTICIPANT SEMANTICS

- **Van Oys Maastricht Retreat, Kaatje bij de Sluis, Olde Marckt,
  Parkheuvel, 't Ganzenest (×2)**: HOST+VENUE for their own Event —
  `is_host=true, is_venue=true`.
- **Triptyque, Basiliek** (VanOost BBQ): PARTICIPANT —
  `is_host=false, is_venue=false`. VanOost itself is the organizer but
  is NOT_FOUND, so no relationship row exists for it either;
  `external_host_name` is used instead.
- **De Echoput**: organizer at its own physical venue but NOT_FOUND —
  `external_host_name`/`external_host_url` used, matching Wildfestival's
  existing production precedent exactly.
- **Chaîne des Rôtisseurs**: organizer using a rented venue (the SS
  Antoinette) it does not own — conceptually "organizer using another
  venue" (`is_host=true, is_venue=false` if it were catalogued), but
  since neither the organizer nor the ship is a Restaurant/Hotel
  entity, no relationship row is possible; `external_host_name` used.
- **Restaurant Roemer**: HOST at its own property, NOT_FOUND —
  `external_host_name`/`external_host_url` used.
- Every `is_host=true` relationship proposed below is defensible: each
  belongs to an entity that genuinely organizes and physically holds
  its own Event, with no case of a promoted participant.

## 9. LOCATION

| Candidate | Coordinates | Source |
|---|---|---|
| VanOost BBQ | NULL | VanOost NOT_FOUND — MANUAL_LOCATION_REVIEW |
| Van Oys Wine & Dine | 50.796123, 5.70613 | Van Oys canonical row |
| Kaatje wine dinner | 52.7245, 5.9617 | Kaatje canonical row |
| Echoput wine lunch | NULL | De Echoput NOT_FOUND — MANUAL_LOCATION_REVIEW |
| Olde Marckt x Karels | 51.927491, 6.581685 | Olde Marckt canonical row |
| Parkheuvel | 51.9069, 4.4685 | Parkheuvel canonical row |
| Chaîne Gala | NULL | SS Antoinette NOT_FOUND — MANUAL_LOCATION_REVIEW |
| Roemer | NULL | Restaurant Roemer NOT_FOUND — MANUAL_LOCATION_REVIEW |
| Ganzenest BBQ | 52.038, 4.331 | 't Ganzenest canonical row |
| Ganzenest Paul Pillot | 52.038, 4.331 | 't Ganzenest canonical row |

6 of 10 ship with real, verified coordinates; the other 4 are NULL,
consistent with every prior batch's rule against proxy/guessed
coordinates. **Data-quality note**: Kaatje bij de Sluis's own site
this pass showed "Brouwerstraat 20, 8356 DV Blokzijl" for the
restaurant, while the canonical catalogue address reads "Brouwersgracht
20, 8356 DX Blokzijl" — a minor discrepancy, likely restaurant vs.
attached-hotel wing addressing. The canonical catalogue address and
coordinates are used below, consistent with the location-quality
hierarchy's own top preference for exact canonical data; this is
flagged for future catalogue review, not a blocker.

## 10. ADMISSION + BOOKING

| Candidate | Admission | Price | Ticket |
|---|---|---|---|
| VanOost BBQ | paid | €160pp | GuestPlan widget, live |
| Van Oys Wine & Dine | paid | €110pp | SevenRooms, live |
| Kaatje wine dinner | paid | not published | phone/contact only |
| Echoput wine lunch | paid | €129pp | echoput.nl ticket link, live |
| Olde Marckt x Karels | paid | not published | in-page widget / phone |
| Parkheuvel | paid | €249pp | parkheuvel.nl ticket link, live |
| Chaîne Gala | paid | €135pp (black tie; registration deadline 30 Aug 2026, not yet passed) | chainedesrotisseurs.nl, live |
| Roemer | paid | €75pp | in-page widget |
| Ganzenest BBQ | paid | €130pp | venue booking system, confirmed bookable |
| Ganzenest Paul Pillot | paid | €450pp (€150 deposit) | venue booking system, confirmed bookable ("first available" date) |

No price was inferred for any candidate; all figures above were
explicitly published by the source.

## 11. CHARITY

None of the 10 READY candidates is a charity/fundraising Event —
confirmed absence of any charity/donation language on every official
source this pass, including the two "gala"/"jubileum"-branded
candidates (Chaîne Gala, Roemer Jubileumdiner) — branding alone was
not treated as evidence.

## 12. IMAGERY

Out of scope, per instruction. `image_url = NULL` for all 10 — no
research performed, no Storage touched.

## 13. FINAL CLASSIFICATION

| Candidate | Classification | Reason |
|---|---|---|
| VanOost BBQ with Friends | READY_WITH_EXTERNAL_HOST | All gates clear |
| Van Oys Wine & Dine × Pierre Ache | READY_TO_INSERT | All gates clear; upgraded to FULL_TIME |
| Wijnmakersdiner Montanha Vermelha | READY_TO_INSERT | All gates clear |
| Wijnmakerslunch Heidi Schröck | READY_WITH_EXTERNAL_HOST | All gates clear |
| Olde Marckt x Karels | READY_TO_INSERT | All gates clear; Michelin confidence upgraded |
| Club Leroy bij Parkheuvel | READY_TO_INSERT | All gates clear |
| Chaîne Gala SS Antoinette | READY_WITH_EXTERNAL_HOST | All gates clear; confirmed distinct from same-date Wildfestival |
| Roemer Jubileumdiner | READY_WITH_EXTERNAL_HOST | All gates clear |
| Ganzenest BBQ Karelse | READY_TO_INSERT | Year resolved this pass |
| Ganzenest Paul Pillot | READY_TO_INSERT | Year resolved this pass |
| **Ganzenest Sassicaia** | **HOLD_OTHER** | No bookable slot currently exists in the venue's own reservation system for this date, despite being advertised — cannot distinguish "not yet opened" from "already unavailable." **Unblock path**: re-check the venue's booking system within 4–6 weeks of the 2026-11-19 date, once slots for that window would reasonably be expected to open. |
| **Karel 5 Wine & Food Lunch** | **HOLD_SOURCE** | Only a single non-primary source (the national sommelier guild's own calendar) confirms this event; the host's own site (karelv.nl), now directly and thoroughly reachable, shows zero corroborating mention, no agenda page, and no price/time/ticket information anywhere. **Unblock path**: contact Karel V directly (info@karelv.nl / +31 30 233 75 55) to confirm the event is genuine and obtain a price before reconsidering. |

**0 REJECT** — both held candidates remain genuinely real, plausible
Events; neither was disqualified on quality grounds, only on a
concrete, named, unresolved issue.

## 14. PRODUCTION-READY SUBSET

**CURRENT PRODUCTION EVENTS = 17**
**BATCH 2 CANDIDATES DEEPLY VERIFIED = 12**
**READY NEW EVENTS = 10**
**HELD = 2**
**REJECTED = 0**
**RESULTING TOTAL IF APPROVED = 27**

## 15. EXACT PROPOSED WRITES

### 1. VanOost Sundays: BBQ with Friends
```
event_type: 'dinner'
description: 'VanOost''s late-summer BBQ brings together host chef Floris van Straalen with Niven Kunz of Triptyque (Wateringen) and Yornie van Dijk of Basiliek (Harderwijk) for a shared grill-driven six-course menu.'
start_date/end_date: '2026-08-30' / '2026-08-30'
start_time/end_time: NULL / NULL   start_at/end_at: NULL / NULL
timezone: 'Europe/Amsterdam'
venue_name: 'VanOost'   address: 'Mauritskade 61, 1092 AD Amsterdam'
city: 'Amsterdam'   country_code: 'NL'   latitude/longitude: NULL / NULL
admission_type: 'paid'   admission_note: '€160 per person — 6-course menu, amuses, friandises'
official_url: 'https://www.vanoostrestaurant.com/events-nl'
ticket_url: 'https://widget.guestplan.com/?id=JXvgcNj0bf9032816a33d3a21f990e91b65e2799a0c43fc7&locale=nl'
image_url: NULL   status: 'upcoming'   moderation_status: 'published'   availability_status: 'available'
external_host_name: 'VanOost'   external_host_url: 'https://www.vanoostrestaurant.com'
relationships: event_restaurants ×2 — 2d37657d-36b6-4f9c-a087-397b22a86d07 (Triptyque, is_host=false, is_venue=false); 8a4d032b-6e9b-4d5c-85ed-68f667f0366b (Basiliek, is_host=false, is_venue=false)
```

### 2. Wine & Dine × Pierre Ache Wijnen
```
event_type: 'dinner'
description: 'Van Oys Maastricht Retreat pairs a four-course menu with regional Dutch and Belgian wines selected by Pierre Ache Wijnen, at Maes, Cuisine du Terroir.'
start_date/end_date: '2026-09-15' / '2026-09-15'
start_time/end_time: '18:30:00' / '22:30:00'
start_at/end_at: '2026-09-15T16:30:00Z' / '2026-09-15T20:30:00Z'
timezone: 'Europe/Amsterdam'
venue_name: 'Maes, Cuisine du Terroir (Van Oys Maastricht Retreat)'   address: 'Kasteellaan 1, 6245 SB Eijsden-Margraten'
city: 'Eijsden'   country_code: 'NL'   latitude/longitude: 50.796123 / 5.70613
admission_type: 'paid'   admission_note: '€110 per person — 4-course menu, each course paired with a regional wine'
official_url: 'https://www.vanoys.com/event-calendar/wine-dine-maes-pierre-ache-wijnen/'
ticket_url: 'https://www.sevenrooms.com/events/maescuisineduterroir'
image_url: NULL   status: 'upcoming'   moderation_status: 'published'   availability_status: 'available'
external_host_name/url: NULL / NULL
relationship: event_hotels (hotel_id 4d09cb3c-7dd0-408e-80ac-02642a6b320b, is_host=true, is_venue=true)
```

### 3. Wijnmakersdiner Montanha Vermelha
```
event_type: 'dinner'
description: 'Kaatje bij de Sluis hosts a wine dinner built around the wines of Montanha Vermelha.'
start_date/end_date: '2026-09-18' / '2026-09-18'
start_time/end_time: NULL / NULL   start_at/end_at: NULL / NULL
timezone: 'Europe/Amsterdam'
venue_name: 'Kaatje bij de Sluis'   address: 'Brouwersgracht 20, 8356 DX Blokzijl'
city: 'Blokzijl'   country_code: 'NL'   latitude/longitude: 52.7245 / 5.9617
admission_type: 'paid'   admission_note: NULL
official_url: 'https://www.kaatje.nl'
ticket_url: NULL
image_url: NULL   status: 'upcoming'   moderation_status: 'published'   availability_status: 'available'
external_host_name/url: NULL / NULL
relationship: event_restaurants (restaurant_id a4581a6e-7ec2-48ec-8958-2ec7ded46592, is_host=true, is_venue=true)
```

### 4. Wijnmakerslunch Heidi Schröck & Söhne
```
event_type: 'tasting'
description: 'A seated lunch centered on the wines of Heidi Schröck & Söhne, an Austrian estate from Rust, Burgenland, hosted at De Echoput.'
start_date/end_date: '2026-10-18' / '2026-10-18'
start_time/end_time: '11:45:00' / NULL
start_at/end_at: '2026-10-18T09:45:00Z' / NULL
timezone: 'Europe/Amsterdam'
venue_name: 'Hotel Gastronomique De Echoput'   address: 'Amersfoortseweg 86, 7346 AA Hoog Soeren'
city: 'Apeldoorn'   country_code: 'NL'   latitude/longitude: NULL / NULL
admission_type: 'paid'   admission_note: '€129 per person, all-inclusive — aperitif, wines, table water, coffee/tea with friandises, 4-course menu'
official_url: 'https://echoput.nl/agenda'
ticket_url: 'https://www.echoput.nl/agenda?ft-ticket=2f43e2b2'
image_url: NULL   status: 'upcoming'   moderation_status: 'published'   availability_status: 'available'
external_host_name: 'Hotel Gastronomique De Echoput'   external_host_url: 'https://echoput.nl'
relationship: none
```

### 5. Four-Hands Diner: Olde Marckt x Karels
```
event_type: 'dinner'
description: 'Olde Marckt welcomes Paskal Karels of Restaurant Karels back to its kitchen for a six-course wild-game menu, continuing their season four-hands collaboration.'
start_date/end_date: '2026-11-01' / '2026-11-01'
start_time/end_time: '13:00:00' / NULL
start_at/end_at: '2026-11-01T12:00:00Z' / NULL
timezone: 'Europe/Amsterdam'
venue_name: 'Olde Marckt'   address: 'Markt 10, 7121 CS Aalten'
city: 'Aalten'   country_code: 'NL'   latitude/longitude: 51.927491 / 6.581685
admission_type: 'paid'   admission_note: 'Price not published. Arrival window 13:00–15:00; a 6-course wild-game menu follows.'
official_url: 'https://oldemarckt.nl/agenda'
ticket_url: NULL
image_url: NULL   status: 'upcoming'   moderation_status: 'published'   availability_status: 'available'
external_host_name/url: NULL / NULL
relationship: event_restaurants (restaurant_id 8f7cb302-8c83-47ba-bb80-2456689a89ff, is_host=true, is_venue=true)
```

### 6. Club Leroy bij Parkheuvel
```
event_type: 'experience'
description: 'Restaurant Parkheuvel pairs a four-course menu with a live performance from singer Robert Leroy, hosted by chef Erik van Loo.'
start_date/end_date: '2026-09-20' / '2026-09-20'
start_time/end_time: '13:00:00' / NULL
start_at/end_at: '2026-09-20T11:00:00Z' / NULL
timezone: 'Europe/Amsterdam'
venue_name: 'Restaurant Parkheuvel'   address: 'Heuvellaan 21, 3016 GL Rotterdam'
city: 'Rotterdam'   country_code: 'NL'   latitude/longitude: 51.9069 / 4.4685
admission_type: 'paid'   admission_note: '€249 per person — welcome drink included; wine pairing available in partnership with Hedin Automotive BMW'
official_url: 'https://www.parkheuvel.nl/en/events/'
ticket_url: 'https://www.parkheuvel.nl/en/events/?ft-ticket=ce2e0d48'
image_url: NULL   status: 'upcoming'   moderation_status: 'published'   availability_status: 'available'
external_host_name/url: NULL / NULL
relationship: event_restaurants (restaurant_id 90d2b4ae-2b39-4bed-beec-31d6008a7ea8, is_host=true, is_venue=true)
```

### 7. Chaîne des Rôtisseurs Gala Dîner op SS Antoinette
```
event_type: 'dinner'
description: 'The Dutch chapter of the Chaîne des Rôtisseurs hosts its black-tie gala dinner aboard the SS Antoinette, docked at Amsterdam''s Passenger Terminal.'
start_date/end_date: '2026-09-13' / '2026-09-13'
start_time/end_time: '17:00:00' / NULL
start_at/end_at: '2026-09-13T15:00:00Z' / NULL
timezone: 'Europe/Amsterdam'
venue_name: 'SS Antoinette (Passenger Terminal Amsterdam)'   address: 'Piet Heinkade 27, 1019 BR Amsterdam'
city: 'Amsterdam'   country_code: 'NL'   latitude/longitude: NULL / NULL
admission_type: 'paid'   admission_note: '€135 per person, black tie. Registration deadline 30 August 2026.'
official_url: 'https://chainedesrotisseurs.nl/evenementen'
ticket_url: 'https://chainedesrotisseurs.nl/evenementen'
image_url: NULL   status: 'upcoming'   moderation_status: 'published'   availability_status: 'available'
external_host_name: 'Chaîne des Rôtisseurs, Bailliage Nederland'   external_host_url: 'https://chainedesrotisseurs.nl'
relationship: none
```

### 8. Jubileumdiner — 5 jaar Restaurant Roemer
```
event_type: 'dinner'
description: 'Restaurant Roemer marks its fifth anniversary with a four-course dinner and matching wines.'
start_date/end_date: '2026-10-08' / '2026-10-08'
start_time/end_time: '18:00:00' / NULL
start_at/end_at: '2026-10-08T16:00:00Z' / NULL
timezone: 'Europe/Amsterdam'
venue_name: 'Restaurant Roemer'   address: 'Berlijnplein 2, 3541 CM Utrecht'
city: 'Utrecht'   country_code: 'NL'   latitude/longitude: NULL / NULL
admission_type: 'paid'   admission_note: '€75 per person — 4-course dinner incl. aperitif, matching wines, coffee'
official_url: 'https://www.roemer-utrecht.nl/restaurant-roemer-agenda/'
ticket_url: NULL
image_url: NULL   status: 'upcoming'   moderation_status: 'published'   availability_status: 'available'
external_host_name: 'Restaurant Roemer'   external_host_url: 'https://www.roemer-utrecht.nl'
relationship: none
```

### 9. Friends & Family Zomer BBQ met Marko Karelse
```
event_type: 'dinner'
description: '''t Ganzenest welcomes Marko Karelse of Villa la Ruche (Voorburg) for a summer BBQ collaboration.'
start_date/end_date: '2026-08-30' / '2026-08-30'
start_time/end_time: NULL / NULL   start_at/end_at: NULL / NULL
timezone: 'Europe/Amsterdam'
venue_name: ''t Ganzenest'   address: 'Delftweg 58a, 2289 AL Rijswijk'
city: 'Rijswijk'   country_code: 'NL'   latitude/longitude: 52.038 / 4.331
admission_type: 'paid'   admission_note: '€130 per person'
official_url: 'https://ganzenest.nl/nl/evenementen-agenda'
ticket_url: 'https://ganzenest.nl/nl/evenementen-agenda'
image_url: NULL   status: 'upcoming'   moderation_status: 'published'   availability_status: 'available'
external_host_name/url: NULL / NULL
relationship: event_restaurants (restaurant_id bec64ec6-5f9a-4f73-9bae-a8c61f50fea2, is_host=true, is_venue=true)
```

### 10. Exclusieve Wijnproeverij — Domaine Paul Pillot
```
event_type: 'tasting'
description: '''t Ganzenest hosts an exclusive tasting built around the wines of Domaine Paul Pillot, a family estate in Chassagne-Montrachet, Burgundy.'
start_date/end_date: '2026-09-24' / '2026-09-24'
start_time/end_time: NULL / NULL   start_at/end_at: NULL / NULL
timezone: 'Europe/Amsterdam'
venue_name: ''t Ganzenest'   address: 'Delftweg 58a, 2289 AL Rijswijk'
city: 'Rijswijk'   country_code: 'NL'   latitude/longitude: 52.038 / 4.331
admission_type: 'paid'   admission_note: '€450 per person (€150 deposit at booking)'
official_url: 'https://ganzenest.nl/nl/evenementen-agenda'
ticket_url: 'https://ganzenest.nl/nl/evenementen-agenda'
image_url: NULL   status: 'upcoming'   moderation_status: 'published'   availability_status: 'available'
external_host_name/url: NULL / NULL
relationship: event_restaurants (restaurant_id bec64ec6-5f9a-4f73-9bae-a8c61f50fea2, is_host=true, is_venue=true)
```

## 16. RELATIONSHIP SAFETY MATRIX

| Event | Entity | Role | is_host | is_venue | 8A eligible | 8B eligible |
|---|---|---|---|---|---|---|
| VanOost BBQ | Triptyque | PARTICIPANT | false | false | no | no |
| VanOost BBQ | Basiliek | PARTICIPANT | false | false | no | no |
| Van Oys Wine & Dine | Van Oys Maastricht Retreat | HOST+VENUE | true | true | yes | yes |
| Kaatje wine dinner | Kaatje bij de Sluis | HOST+VENUE | true | true | yes | yes |
| Olde Marckt x Karels | Olde Marckt | HOST+VENUE | true | true | yes | yes |
| Parkheuvel | Parkheuvel | HOST+VENUE | true | true | yes | yes |
| Ganzenest BBQ | 't Ganzenest | HOST+VENUE | true | true | yes | yes |
| Ganzenest Paul Pillot | 't Ganzenest | HOST+VENUE | true | true | yes | yes |
| Echoput wine lunch | (external, no relationship row) | — | — | — | no | no |
| Chaîne Gala | (external, no relationship row) | — | — | — | no | no |
| Roemer | (external, no relationship row) | — | — | — | no | no |

**'t Ganzenest gains two hosted Events in this batch** (BBQ Karelse,
Paul Pillot tasting) — both genuinely organized and held at 't
Ganzenest itself, both correctly `is_host=true`.

## 17. STEP 8A / 8B / 8C SAFETY

**Step 8A**: resulting inventory if approved = 27, still comfortably
below the ~50-concurrently-displayed batching threshold. No batching
work triggered.
**Step 8B**: Van Oys Maastricht Retreat, Kaatje bij de Sluis, Olde
Marckt, Parkheuvel, and 't Ganzenest each gain a genuine `is_host=true`
relationship and will correctly surface their new Event(s) under
Reverse Hosted-Event Discovery. Triptyque and Basiliek gain zero
`is_host=true` rows from this batch and will correctly show nothing
new — no participant surfaces as a host anywhere in this batch.
**Step 8C**: none of the 10 candidates has any `event_confirmed_
attendance` row (they don't exist in production yet); none can appear
in any Passport until genuinely confirmed after insertion.

## 18. TRANSACTION PREVIEW

Not executed — preview only, one atomic transaction for the 10 READY
Events, matching the established CTE/RETURNING pattern from every
prior apply this session:

```sql
BEGIN;

-- Final duplicate re-check (must return 0 rows before proceeding)
SELECT id, name, start_date FROM public.events
WHERE name IN (
  'VanOost Sundays: BBQ with Friends',
  'Wine & Dine × Pierre Ache Wijnen',
  'Wijnmakersdiner Montanha Vermelha',
  'Wijnmakerslunch Heidi Schröck & Söhne',
  'Four-Hands Diner: Olde Marckt x Karels',
  'Club Leroy bij Parkheuvel',
  'Chaîne des Rôtisseurs Gala Dîner op SS Antoinette',
  'Jubileumdiner — 5 jaar Restaurant Roemer',
  'Friends & Family Zomer BBQ met Marko Karelse',
  'Exclusieve Wijnproeverij — Domaine Paul Pillot'
);

WITH e_vanoost_bbq AS (
  INSERT INTO public.events (name, description, event_type, venue_name, address, city,
    country_code, timezone, start_date, end_date, start_time, end_time, start_at, end_at,
    admission_type, admission_note, official_url, ticket_url, image_url, status,
    moderation_status, availability_status, external_host_name, external_host_url)
  VALUES ('VanOost Sundays: BBQ with Friends', '<description>', 'dinner', 'VanOost',
    'Mauritskade 61, 1092 AD Amsterdam', 'Amsterdam', 'NL', 'Europe/Amsterdam',
    '2026-08-30', '2026-08-30', NULL, NULL, NULL, NULL, 'paid',
    '€160 per person — 6-course menu, amuses, friandises',
    'https://www.vanoostrestaurant.com/events-nl',
    'https://widget.guestplan.com/?id=JXvgcNj0bf9032816a33d3a21f990e91b65e2799a0c43fc7&locale=nl',
    NULL, 'upcoming', 'published', 'available', 'VanOost', 'https://www.vanoostrestaurant.com')
  RETURNING id
),
e_wine_dine AS (
  INSERT INTO public.events (name, description, event_type, venue_name, address, city,
    country_code, latitude, longitude, timezone, start_date, end_date, start_time, end_time,
    start_at, end_at, admission_type, admission_note, official_url, ticket_url, image_url,
    status, moderation_status, availability_status)
  VALUES ('Wine & Dine × Pierre Ache Wijnen', '<description>', 'dinner',
    'Maes, Cuisine du Terroir (Van Oys Maastricht Retreat)', 'Kasteellaan 1, 6245 SB Eijsden-Margraten',
    'Eijsden', 'NL', 50.796123, 5.70613, 'Europe/Amsterdam', '2026-09-15', '2026-09-15',
    '18:30:00', '22:30:00', '2026-09-15T16:30:00Z', '2026-09-15T20:30:00Z', 'paid',
    '€110 per person — 4-course menu, each course paired with a regional wine',
    'https://www.vanoys.com/event-calendar/wine-dine-maes-pierre-ache-wijnen/',
    'https://www.sevenrooms.com/events/maescuisineduterroir', NULL, 'upcoming', 'published', 'available')
  RETURNING id
),
e_kaatje AS (
  INSERT INTO public.events (name, description, event_type, venue_name, address, city,
    country_code, latitude, longitude, timezone, start_date, end_date, start_time, end_time,
    start_at, end_at, admission_type, admission_note, official_url, ticket_url, image_url,
    status, moderation_status, availability_status)
  VALUES ('Wijnmakersdiner Montanha Vermelha', '<description>', 'dinner', 'Kaatje bij de Sluis',
    'Brouwersgracht 20, 8356 DX Blokzijl', 'Blokzijl', 'NL', 52.7245, 5.9617, 'Europe/Amsterdam',
    '2026-09-18', '2026-09-18', NULL, NULL, NULL, NULL, 'paid', NULL,
    'https://www.kaatje.nl', NULL, NULL, 'upcoming', 'published', 'available')
  RETURNING id
),
e_echoput AS (
  INSERT INTO public.events (name, description, event_type, venue_name, address, city,
    country_code, timezone, start_date, end_date, start_time, end_time, start_at, end_at,
    admission_type, admission_note, official_url, ticket_url, image_url, status,
    moderation_status, availability_status, external_host_name, external_host_url)
  VALUES ('Wijnmakerslunch Heidi Schröck & Söhne', '<description>', 'tasting',
    'Hotel Gastronomique De Echoput', 'Amersfoortseweg 86, 7346 AA Hoog Soeren', 'Apeldoorn',
    'NL', 'Europe/Amsterdam', '2026-10-18', '2026-10-18', '11:45:00', NULL,
    '2026-10-18T09:45:00Z', NULL, 'paid',
    '€129 per person, all-inclusive — aperitif, wines, table water, coffee/tea with friandises, 4-course menu',
    'https://echoput.nl/agenda', 'https://www.echoput.nl/agenda?ft-ticket=2f43e2b2', NULL,
    'upcoming', 'published', 'available', 'Hotel Gastronomique De Echoput', 'https://echoput.nl')
  RETURNING id
),
e_oldemarckt AS (
  INSERT INTO public.events (name, description, event_type, venue_name, address, city,
    country_code, latitude, longitude, timezone, start_date, end_date, start_time, end_time,
    start_at, end_at, admission_type, admission_note, official_url, ticket_url, image_url,
    status, moderation_status, availability_status)
  VALUES ('Four-Hands Diner: Olde Marckt x Karels', '<description>', 'dinner', 'Olde Marckt',
    'Markt 10, 7121 CS Aalten', 'Aalten', 'NL', 51.927491, 6.581685, 'Europe/Amsterdam',
    '2026-11-01', '2026-11-01', '13:00:00', NULL, '2026-11-01T12:00:00Z', NULL, 'paid',
    'Price not published. Arrival window 13:00–15:00; a 6-course wild-game menu follows.',
    'https://oldemarckt.nl/agenda', NULL, NULL, 'upcoming', 'published', 'available')
  RETURNING id
),
e_parkheuvel AS (
  INSERT INTO public.events (name, description, event_type, venue_name, address, city,
    country_code, latitude, longitude, timezone, start_date, end_date, start_time, end_time,
    start_at, end_at, admission_type, admission_note, official_url, ticket_url, image_url,
    status, moderation_status, availability_status)
  VALUES ('Club Leroy bij Parkheuvel', '<description>', 'experience', 'Restaurant Parkheuvel',
    'Heuvellaan 21, 3016 GL Rotterdam', 'Rotterdam', 'NL', 51.9069, 4.4685, 'Europe/Amsterdam',
    '2026-09-20', '2026-09-20', '13:00:00', NULL, '2026-09-20T11:00:00Z', NULL, 'paid',
    '€249 per person — welcome drink included; wine pairing available in partnership with Hedin Automotive BMW',
    'https://www.parkheuvel.nl/en/events/', 'https://www.parkheuvel.nl/en/events/?ft-ticket=ce2e0d48',
    NULL, 'upcoming', 'published', 'available')
  RETURNING id
),
e_chaine AS (
  INSERT INTO public.events (name, description, event_type, venue_name, address, city,
    country_code, timezone, start_date, end_date, start_time, end_time, start_at, end_at,
    admission_type, admission_note, official_url, ticket_url, image_url, status,
    moderation_status, availability_status, external_host_name, external_host_url)
  VALUES ('Chaîne des Rôtisseurs Gala Dîner op SS Antoinette', '<description>', 'dinner',
    'SS Antoinette (Passenger Terminal Amsterdam)', 'Piet Heinkade 27, 1019 BR Amsterdam',
    'Amsterdam', 'NL', 'Europe/Amsterdam', '2026-09-13', '2026-09-13', '17:00:00', NULL,
    '2026-09-13T15:00:00Z', NULL, 'paid', '€135 per person, black tie. Registration deadline 30 August 2026.',
    'https://chainedesrotisseurs.nl/evenementen', 'https://chainedesrotisseurs.nl/evenementen', NULL,
    'upcoming', 'published', 'available', 'Chaîne des Rôtisseurs, Bailliage Nederland',
    'https://chainedesrotisseurs.nl')
  RETURNING id
),
e_roemer AS (
  INSERT INTO public.events (name, description, event_type, venue_name, address, city,
    country_code, timezone, start_date, end_date, start_time, end_time, start_at, end_at,
    admission_type, admission_note, official_url, ticket_url, image_url, status,
    moderation_status, availability_status, external_host_name, external_host_url)
  VALUES ('Jubileumdiner — 5 jaar Restaurant Roemer', '<description>', 'dinner', 'Restaurant Roemer',
    'Berlijnplein 2, 3541 CM Utrecht', 'Utrecht', 'NL', 'Europe/Amsterdam',
    '2026-10-08', '2026-10-08', '18:00:00', NULL, '2026-10-08T16:00:00Z', NULL, 'paid',
    '€75 per person — 4-course dinner incl. aperitif, matching wines, coffee',
    'https://www.roemer-utrecht.nl/restaurant-roemer-agenda/', NULL, NULL,
    'upcoming', 'published', 'available', 'Restaurant Roemer', 'https://www.roemer-utrecht.nl')
  RETURNING id
),
e_ganzenest_bbq AS (
  INSERT INTO public.events (name, description, event_type, venue_name, address, city,
    country_code, latitude, longitude, timezone, start_date, end_date, start_time, end_time,
    start_at, end_at, admission_type, admission_note, official_url, ticket_url, image_url,
    status, moderation_status, availability_status)
  VALUES ('Friends & Family Zomer BBQ met Marko Karelse', '<description>', 'dinner', '''t Ganzenest',
    'Delftweg 58a, 2289 AL Rijswijk', 'Rijswijk', 'NL', 52.038, 4.331, 'Europe/Amsterdam',
    '2026-08-30', '2026-08-30', NULL, NULL, NULL, NULL, 'paid', '€130 per person',
    'https://ganzenest.nl/nl/evenementen-agenda', 'https://ganzenest.nl/nl/evenementen-agenda',
    NULL, 'upcoming', 'published', 'available')
  RETURNING id
),
e_ganzenest_pillot AS (
  INSERT INTO public.events (name, description, event_type, venue_name, address, city,
    country_code, latitude, longitude, timezone, start_date, end_date, start_time, end_time,
    start_at, end_at, admission_type, admission_note, official_url, ticket_url, image_url,
    status, moderation_status, availability_status)
  VALUES ('Exclusieve Wijnproeverij — Domaine Paul Pillot', '<description>', 'tasting', '''t Ganzenest',
    'Delftweg 58a, 2289 AL Rijswijk', 'Rijswijk', 'NL', 52.038, 4.331, 'Europe/Amsterdam',
    '2026-09-24', '2026-09-24', NULL, NULL, NULL, NULL, 'paid', '€450 per person (€150 deposit at booking)',
    'https://ganzenest.nl/nl/evenementen-agenda', 'https://ganzenest.nl/nl/evenementen-agenda',
    NULL, 'upcoming', 'published', 'available')
  RETURNING id
),
rel_vanoost_triptyque AS (
  INSERT INTO public.event_restaurants (event_id, restaurant_id, is_host, is_venue)
  SELECT id, '2d37657d-36b6-4f9c-a087-397b22a86d07'::uuid, false, false FROM e_vanoost_bbq
  RETURNING event_id
),
rel_vanoost_basiliek AS (
  INSERT INTO public.event_restaurants (event_id, restaurant_id, is_host, is_venue)
  SELECT id, '8a4d032b-6e9b-4d5c-85ed-68f667f0366b'::uuid, false, false FROM e_vanoost_bbq
  RETURNING event_id
),
rel_vanoys_hotel AS (
  INSERT INTO public.event_hotels (event_id, hotel_id, is_host, is_venue)
  SELECT id, '4d09cb3c-7dd0-408e-80ac-02642a6b320b'::uuid, true, true FROM e_wine_dine
  RETURNING event_id
),
rel_kaatje AS (
  INSERT INTO public.event_restaurants (event_id, restaurant_id, is_host, is_venue)
  SELECT id, 'a4581a6e-7ec2-48ec-8958-2ec7ded46592'::uuid, true, true FROM e_kaatje
  RETURNING event_id
),
rel_oldemarckt AS (
  INSERT INTO public.event_restaurants (event_id, restaurant_id, is_host, is_venue)
  SELECT id, '8f7cb302-8c83-47ba-bb80-2456689a89ff'::uuid, true, true FROM e_oldemarckt
  RETURNING event_id
),
rel_parkheuvel AS (
  INSERT INTO public.event_restaurants (event_id, restaurant_id, is_host, is_venue)
  SELECT id, '90d2b4ae-2b39-4bed-beec-31d6008a7ea8'::uuid, true, true FROM e_parkheuvel
  RETURNING event_id
),
rel_ganzenest_bbq AS (
  INSERT INTO public.event_restaurants (event_id, restaurant_id, is_host, is_venue)
  SELECT id, 'bec64ec6-5f9a-4f73-9bae-a8c61f50fea2'::uuid, true, true FROM e_ganzenest_bbq
  RETURNING event_id
),
rel_ganzenest_pillot AS (
  INSERT INTO public.event_restaurants (event_id, restaurant_id, is_host, is_venue)
  SELECT id, 'bec64ec6-5f9a-4f73-9bae-a8c61f50fea2'::uuid, true, true FROM e_ganzenest_pillot
  RETURNING event_id
)
SELECT
  (SELECT id FROM e_vanoost_bbq) AS vanoost_bbq_id, (SELECT id FROM e_wine_dine) AS wine_dine_id,
  (SELECT id FROM e_kaatje) AS kaatje_id, (SELECT id FROM e_echoput) AS echoput_id,
  (SELECT id FROM e_oldemarckt) AS oldemarckt_id, (SELECT id FROM e_parkheuvel) AS parkheuvel_id,
  (SELECT id FROM e_chaine) AS chaine_id, (SELECT id FROM e_roemer) AS roemer_id,
  (SELECT id FROM e_ganzenest_bbq) AS ganzenest_bbq_id, (SELECT id FROM e_ganzenest_pillot) AS ganzenest_pillot_id,
  (SELECT count(*) FROM rel_vanoost_triptyque) + (SELECT count(*) FROM rel_vanoost_basiliek) AS vanoost_rels,
  (SELECT count(*) FROM rel_vanoys_hotel) AS hotel_rels,
  (SELECT count(*) FROM rel_kaatje) + (SELECT count(*) FROM rel_oldemarckt)
    + (SELECT count(*) FROM rel_parkheuvel) + (SELECT count(*) FROM rel_ganzenest_bbq)
    + (SELECT count(*) FROM rel_ganzenest_pillot) AS single_host_rels;

COMMIT;
```

**Expected count deltas**:
```
events               +10   (17 → 27)
event_restaurants     +7   (2 VanOost participants + Kaatje + Olde Marckt + Parkheuvel + 2 Ganzenest)
event_hotels           +1   (Van Oys Wine & Dine)
event_chefs             0
event_confirmed_attendance  0 (unchanged)
```

**Post-apply verification queries** (not run): re-select all 10 new
Events by name, confirm every field matches §15; re-select all 17
pre-existing Events, confirm byte-for-byte unchanged; re-count
`event_restaurants`/`event_hotels`, confirm exact deltas; re-confirm
`is_host`/`is_venue` values for every new relationship row match §16
exactly (especially Triptyque and Basiliek both `false`/`false`); check
for duplicate title/date pairs; re-confirm `event_confirmed_attendance`
unchanged.

## 19. VALIDATION

`dart format --set-exit-if-changed .`: clean (no Dart touched).
`flutter analyze`: no issues. `flutter test`: baseline unchanged (see
accompanying chat report for the exact re-run count). `supabase
migration list --linked`: 39/39 `local == remote`. `supabase db push
--linked --dry-run`: "Remote database is up to date." `git status
--short` / `git diff` / `git diff --cached`: only this new
documentation and dataset file appear untracked — nothing staged.

## DATABASE

Production writes = 0. Schema changes = 0. Migrations = 0. RLS changes
= 0. Storage writes = 0.

## GIT

Nothing staged, committed, or pushed.

## HARD STOP CONFIRMATION

No Event inserted or modified. No relationship row inserted. No
catalogue entity created. No image uploaded/Storage touched. No
migration created. No RLS changed.

## EXACT RECOMMENDATION

Insert exactly 10 Events plus their 8 relationship rows (7
`event_restaurants`, 1 `event_hotels`) when human-approved. Hold
exactly 2 candidates (Ganzenest Sassicaia — booking-system anomaly;
Karel 5 lunch — single-source-only) for the specific, named unblock
paths above — neither is rejected, both remain real candidates for a
future pass once their concrete issue resolves.

DUTCH EVENT ENRICHMENT — BATCH 2 DEEPLY VERIFIED FROM TODAY'S EXISTING
DUTCH RESEARCH, PRODUCTION-READY SUBSET PREPARED, READY FOR HUMAN
APPLY REVIEW
