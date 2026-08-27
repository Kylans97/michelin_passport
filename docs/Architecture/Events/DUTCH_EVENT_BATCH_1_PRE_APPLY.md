# DUTCH EVENT ENRICHMENT — BATCH 1 DEEP VERIFICATION + PRE-APPLY

Deep, freshly re-verified production pre-apply for the 8 Dutch Event
candidates recommended by the Dutch Event Enrichment Sprint. Nothing in
this document was inserted, updated, or staged — this is a pre-apply
report only.

## 1. THE EXACT 8

| Event | Date | City | Host | Why selected |
|---|---|---|---|---|
| 4 Hands Dinner: Bas van Kranen x Sebastian Frank | 2026-11-09 | Amsterdam | Restaurant Flore | Same host as the live production pilot, internationally lauded guest (Horváth, Berlin, 2★+Green Star) |
| VanOost 4 Hands Lunch — Sören Herzig | 2026-09-06 | Amsterdam | VanOost | International Michelin guest (Vienna) flown in for a reciprocal exchange |
| Game Brunch | 2026-10-18 | Eijsden | Van Oys Maastricht Retreat | Clean FULL_TIME candidate, seasonal, chef-curated |
| Dîner Dansant (Christmas Eve Gala) | 2026-12-24 | Eijsden | Van Oys Maastricht Retreat | Genuine FULL_TIME with a real cross-midnight end time |
| Chefs & Sommeliers Party | 2026-08-31 | Kruiningen | Inter Scaldes | Highest-impact candidate: 8-chef, multi-Michelin-star collaboration |
| Winemakers Lunch — South Africa | 2026-09-12 | Schoorl | Merlet | Two named international winemakers at a milestone-year kitchen |
| Six Hands Dinner: 3 chefs, 3 continents | 2026-09-24 | Texel (Den Hoorn) | Bij Jef | Strongest destination story in the pool |
| Four Hands: Merlet x Joann | 2026-11-22 | Schoorl | Merlet | Both sides EXACT catalogue matches, second consecutive year — editorially durable |

No substitutions were made from the remaining 10 shortlisted-but-not-
selected candidates.

## 2. FRESH PRODUCTION DUPLICATE CHECK

Re-read live, not assumed: `events` count = **9**, unchanged since the
Dutch sprint and the European Batch 1 apply. Checked all 8 candidates
against every existing Event's title, date, venue, city, official_url,
ticket_url, and host — **zero duplicates found** (`NEW` for all 8). No
existing Event describes the same real-world occurrence under a
different title.

## 3. FRESH SOURCE VERIFICATION

Every candidate was independently re-researched this pass — the Dutch
sprint dataset was treated as a hypothesis to check, not evidence.
Result: **all 8 are CONFIRMED_UNCHANGED**, still upcoming, not
cancelled, not concluded. Verification surfaced real corrections,
folded into the final rows below:

- **Bij Jef (Six Hands Dinner)**: the sprint's biggest open question —
  an inferred, not printed, year — is now resolved. The venue's own
  site (both the CMS payload and the visible specials-overview card)
  states "24 september **2026**" explicitly. YEAR_CONFIRMED.
- **VanOost x Sören Herzig**: inclusions corrected — water, coffee and
  tea are included, not a wine/beverage pairing (the reciprocal Vienna
  leg does include wine pairing; this Amsterdam leg does not).
- **Chefs & Sommeliers Party**: two corrections — wine and champagne
  are included in the €325 price (not an optional add-on), and the
  courtesy car is a separate complimentary ≤15km shuttle, not a
  wine-pairing option. Lineup detail enriched: Sidney Schutte is
  affiliated with three restaurants (Molina, Cocina de Autor, Rust
  Wat), and the Suis team includes Soumia Chouaf and Jurgen Houben
  alongside Ralf Berendsen.
- **Winemakers Lunch (Merlet)**: address discrepancy resolved — a
  third-party Yelp listing showed "Duinweg 13"; Merlet's own contact
  page confirms **Duinweg 15**, treated as authoritative.
- **Dîner Dansant**: chef spelling corrected to "Stijn Antens" (no
  accent, per the official site). The event's live URL slug has
  changed to `/event-calendar/diner-dansant/` (no longer has the
  `-24-12` suffix from the original sprint pass). **The page's own
  "Reserve your table" button currently misroutes to an unrelated
  event** (`thegrandsundaybrunchlatabledudimanche` on SevenRooms) —
  flagged as a live site bug, not a reason to hold; `availability_
  status` is set to `unknown` and the ticket URL is not propagated
  since it demonstrably does not point to the correct booking flow.
- **Flore x Sebastian Frank**: confirmed genuinely distinct from the
  already-live "Bas van Kranen x Sang Hoon Degeimbre" pilot — Flore's
  own 4-Hands series page lists four separate dinners (Jun 22 — David
  Žefran, already past; Aug 17 — John Chantarasak, already past; Oct
  19 — Sang Hoon Degeimbre, the live pilot; Nov 9 — Sebastian Frank,
  this candidate). No overlap risk.
- **Merlet x Joann**: no material change; date/time/guest confirmed
  identical.

None of the 8 required inventing a fact to fill a gap — every
correction above replaced an uncertain or slightly-off prior value with
a freshly sourced, more precise one.

## 4. DATE/TIME PRECISION

| Event | Precision | Start / End |
|---|---|---|
| Flore x Sebastian Frank | DATE_ONLY | no time published |
| VanOost x Sören Herzig | DATE_ONLY | no time published (confirmed: only water/coffee/tea, no time on page) |
| Game Brunch | FULL_TIME | 12:00–15:00 CEST |
| Dîner Dansant | FULL_TIME | 19:00 (Dec 24) – 00:00 (Dec 25) CET |
| Chefs & Sommeliers Party | FULL_TIME | 18:00 (Aug 31) – 00:00 (Sep 1) CEST |
| Winemakers Lunch (Merlet) | DATE_ONLY | no time published |
| Six Hands Dinner (Bij Jef) | DATE_ONLY | no time published |
| Merlet x Joann | START_KNOWN_END_UNKNOWN | 12:30 CET, no end time |

No fabricated time anywhere — every DATE_ONLY classification was
independently reconfirmed this pass to genuinely have no published
time, not merely inherited from the sprint.

## 5. EVENT IDENTITY / SESSION MODEL

All 8 confirmed **SINGLE_EVENT**. Two were specifically checked for
hidden multi-session structure and cleared: **Game Brunch** is a
one-off named special within Van Oys's broader "Special Brunches"
program (distinct from the venue's own separately-priced recurring
Sunday brunch and other named specials — Sinterklaas Brunch, Christmas
Brunch, New Year's Brunch — each its own single date, not a series to
flatten). **VanOost x Sören Herzig** is narratively framed by the
venue as one half of a reciprocal two-city exchange (a return lunch at
Herzig in Vienna, Sept 22, different price, wine pairing included), but
the two are genuinely separate, independently bookable events with no
combined ticket — the Amsterdam leg alone is proposed; the Vienna leg
is out of NL scope and not proposed.

## 6. CANONICAL ENTITY MATCHING

Freshly queried against `restaurants_full`/`hotels_full`:

| Entity | Type | Classification | UUID |
|---|---|---|---|
| Flore | Restaurant | EXACT | `d656c75f-9354-4f57-b133-b5ce03b913a7` |
| Van Oys Maastricht Retreat | Hotel | EXACT | `4d09cb3c-7dd0-408e-80ac-02642a6b320b` |
| Inter Scaldes | Restaurant | EXACT | `2ea838af-6205-4e76-8528-fc85d196f450` |
| Merlet | Restaurant | EXACT | `0f7aefc0-6384-468e-832f-2423d6fcb2ed` |
| Joann | Restaurant | EXACT | `6cd400f4-5fad-477a-8fc5-9b9adfb18789` |
| Bij Jef | Restaurant | EXACT | `d2725c06-f3cf-43bc-b884-957c9e6762da` |
| Zarzo | Restaurant | EXACT | `3aa741e9-ad38-463c-a358-fa0ee8a2d698` |
| Parkheuvel | Restaurant | EXACT | `90d2b4ae-2b39-4bed-beec-31d6008a7ea8` |
| Zilte (Antwerp, BE) | Restaurant | EXACT | `fef9e0e6-5bd8-4bc5-8a0e-0ddfcedc1807` |
| VanOost | Restaurant | NOT_FOUND | — |
| Suis, Bontom Chocolaterie, Molina, Cocina de Autor, Rust Wat | — | NOT_FOUND | — |
| Sebastian Frank / Horváth (Berlin), Sören Herzig (Vienna), Shinichiro Takagi / Zeniya (Japan), Peter Tempelhoff / Fyn (Cape Town) | — | NOT_FOUND (foreign, out of catalogue scope) | — |

Zilte's presence surprised this pass — it is already catalogued
(Belgium), the same way L'air du temps already supports the Bas van
Kranen pilot. No Restaurant, Hotel, or Private Chef row was created for
any NOT_FOUND entity.

## 7. HOST / VENUE / PARTICIPANT SEMANTICS

Applied per-entity, not assumed from "a chef is cooking there":

- **Flore**, **Van Oys Maastricht Retreat** (both Events), **Inter
  Scaldes**, **Merlet** (both Events), **Bij Jef**: each is HOST+VENUE
  for its own Event — genuinely organizes and physically holds it.
- **Bij Jef, Zarzo, Parkheuvel, Zilte** (all four, for Chefs &
  Sommeliers Party only): PARTICIPANT — Inter Scaldes's own copy
  states it "is exclusively reserved for our Chefs & Sommeliers,"
  i.e. Inter Scaldes hosts, everyone else is a visiting guest. None of
  these four gets `is_host=true` for this Event, even though Bij Jef
  is separately the genuine host of its own Six Hands Dinner.
- **Joann** (for Merlet x Joann only): PARTICIPANT — the dinner
  happens at Merlet's address; Joann's own chef is the visiting guest.
- **VanOost**: no relationship row is possible (NOT_FOUND) — recorded
  via `external_host_name`/`external_host_url` instead.

No participant was promoted into a host anywhere in this batch.

## 8. LOCATION QUALITY

| Event | Coordinates | Source |
|---|---|---|
| Flore x Sebastian Frank | 52.3638, 4.8906 | Flore's own canonical catalogue row |
| VanOost x Sören Herzig | NULL | VanOost NOT_FOUND — MANUAL_LOCATION_REVIEW, no proxy used |
| Game Brunch | 50.796123, 5.70613 | Van Oys's own canonical catalogue row |
| Dîner Dansant | 50.796123, 5.70613 | Van Oys's own canonical catalogue row |
| Chefs & Sommeliers Party | 51.4532, 4.0258 | Inter Scaldes's own canonical catalogue row |
| Winemakers Lunch (Merlet) | 52.6996668, 4.6942853 | Merlet's own canonical catalogue row |
| Merlet x Joann | 52.6996668, 4.6942853 | Merlet's own canonical catalogue row |
| Six Hands Dinner (Bij Jef) | 53.0247743, 4.7498821 | Bij Jef's own canonical catalogue row |

7 of 8 ship with real, verified, non-guessed coordinates. Only VanOost
is NULL — per the location-quality hierarchy, no city-centre or
geocoded proxy was substituted; this alone is not a HOLD reason.

## 9. ADMISSION + BOOKING

| Event | Admission | Price | Availability |
|---|---|---|---|
| Flore x Sebastian Frank | paid | not published | available (no sold-out marker; live seat count in the JS-rendered SevenRooms widget could not be independently confirmed) |
| VanOost x Sören Herzig | paid | €210pp (aperitif, 6-course, amuses/friandises, water/coffee/tea — non-alcoholic) | available |
| Game Brunch | paid | €150 adult / €45 (4–11) / €75 (12–17) / free (0–3) | available |
| Dîner Dansant | paid | €245pp | **unknown** — official booking CTA currently misrouted to an unrelated event; not a hold reason, but flagged for a human click-through before go-live |
| Chefs & Sommeliers Party | paid | €325pp (wine/champagne included; complimentary ≤15km courtesy car separately) | available |
| Winemakers Lunch (Merlet) | paid | €175pp | available |
| Merlet x Joann | paid | not published | available |
| Six Hands Dinner (Bij Jef) | paid | €225pp | available (no online booking exists at all — phone/email only) |

No candidate is sold out or cancelled. None is proposed for insertion
in an already-concluded state.

## 10. CHARITY

None of the 8 is a charity/fundraising Event — confirmed absence of
any charity/donation language on every official source this pass. The
permanent rule (charity Events never pay for placement, never held to
a different quality bar) has no live decision to make here.

## 11. IMAGERY

All 8: `image_url = NULL`, classification **UNKNOWN** — imagery-rights
research remains out of scope for this pass, consistent with every
prior batch. Not treated as a hold reason for any candidate.

## 12. DESCRIPTIONS

- **Flore x Sebastian Frank**: "Restaurant Flore's ongoing 4-Hands
  Dinner Series welcomes Sebastian Frank, chef-patron of Horváth in
  Berlin, for a one-night collaboration between two vegetable-forward
  kitchens."
- **VanOost x Sören Herzig**: "VanOost hosts Sören Herzig of Restaurant
  Herzig in Vienna for a four-hands lunch — the Amsterdam leg of a
  reciprocal exchange between the two kitchens."
- **Game Brunch**: "Van Oys Maastricht Retreat opens game season with
  a hunting-horn welcome and a chef Stijn Antens-led brunch built
  around autumnal, game-inspired dishes at its Sainte Cécile
  Ballroom."
- **Dîner Dansant**: "Van Oys Maastricht Retreat closes the year with
  a Christmas Eve Dîner Dansant — a champagne aperitif, four-course
  dinner from chef Stijn Antens, and live music and dancing from Gary
  Gielen & Friends at the Sainte Cécile Ballroom."
- **Chefs & Sommeliers Party**: "Inter Scaldes opens its own hotel
  exclusively to seven visiting kitchens for one night, gathering
  chefs from Bij Jef, Zilte, Zarzo, Parkheuvel, Suis, Bontom
  Chocolaterie and Sidney Schutte's restaurants for a collaborative
  walking dinner with wines and champagnes chosen by their
  sommeliers."
- **Winemakers Lunch — South Africa**: "Restaurant Merlet pairs its
  own kitchen with two South African producers, Newton Johnson of the
  Hemel-en-Aarde Valley and Grangehurst of Stellenbosch, for a
  wine-focused lunch built around their vineyards."
- **Merlet x Joann**: "Restaurant Merlet welcomes Emiel Kwekkeboom of
  Restaurant Joann in Enschede for a second consecutive year of
  four-hands collaboration, pairing two Michelin-starred kitchens for
  one dinner."
- **Six Hands Dinner**: "Bij Jef's kitchen on Texel joins Shinichiro
  Takagi of Zeniya in Kanazawa and Peter Tempelhoff of Fyn in Cape
  Town for a single six-course menu spanning three continents in one
  evening."

No description overstates Michelin recognition or copies source
marketing language.

## 13. FINAL CLASSIFICATION

All 8 are **READY**. This is a genuinely clean batch — nothing was
held or rejected.

| Event | Classification | Reason |
|---|---|---|
| Flore x Sebastian Frank | READY_TO_INSERT | All gates clear |
| VanOost x Sören Herzig | READY_WITH_EXTERNAL_HOST | VanOost NOT_FOUND — external host |
| Game Brunch | READY_TO_INSERT | All gates clear |
| Dîner Dansant | READY_TO_INSERT | Broken booking CTA noted but not a hold reason; date/venue/price fully confirmed |
| Chefs & Sommeliers Party | READY_TO_INSERT | All gates clear |
| Winemakers Lunch (Merlet) | READY_TO_INSERT | All gates clear |
| Merlet x Joann | READY_TO_INSERT | All gates clear |
| Six Hands Dinner (Bij Jef) | READY_TO_INSERT | Year uncertainty resolved this pass |

## 14. PRODUCTION-READY TABLE

| Event | Date | Precision | City | Venue | Host | Canonical host | Participants | Admission | Coords | Confidence | Image | Status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Flore x Sebastian Frank | 2026-11-09 | DATE_ONLY | Amsterdam | Restaurant Flore | Flore | EXACT | Sebastian Frank (Horváth) | paid | real | A | UNKNOWN | READY |
| VanOost x Sören Herzig | 2026-09-06 | DATE_ONLY | Amsterdam | VanOost | VanOost | NOT_FOUND | Sören Herzig (Herzig) | paid €210 | NULL | A | UNKNOWN | READY_EXTERNAL |
| Game Brunch | 2026-10-18 | FULL_TIME | Eijsden | Van Oys Maastricht Retreat | Van Oys | EXACT | Stijn Antens | paid €150 | real | A | UNKNOWN | READY |
| Dîner Dansant | 2026-12-24 | FULL_TIME | Eijsden | Van Oys Maastricht Retreat | Van Oys | EXACT | Stijn Antens | paid €245 | real | A | UNKNOWN | READY |
| Chefs & Sommeliers Party | 2026-08-31 | FULL_TIME | Kruiningen | Inter Scaldes | Inter Scaldes | EXACT | Bij Jef, Zarzo, Parkheuvel, Zilte + others | paid €325 | real | A | UNKNOWN | READY |
| Winemakers Lunch | 2026-09-12 | DATE_ONLY | Schoorl | Merlet | Merlet | EXACT | Newton Johnson, Grangehurst | paid €175 | real | A | UNKNOWN | READY |
| Merlet x Joann | 2026-11-22 | START_KNOWN_END_UNKNOWN | Schoorl | Merlet | Merlet | EXACT | Joann (Emiel Kwekkeboom) | paid | real | A | UNKNOWN | READY |
| Six Hands Dinner | 2026-09-24 | DATE_ONLY | Texel | Bij Jef | Bij Jef | EXACT | Zeniya, Fyn | paid €225 | real | A | UNKNOWN | READY |

**CURRENT PRODUCTION EVENTS = 9**
**DUTCH CANDIDATES REVIEWED = 8**
**READY NEW EVENTS = 8**
**HELD/REJECTED = 0**
**RESULTING TOTAL IF APPROVED = 17**

## 15. EXACT PROPOSED WRITES

### 1. 4 Hands Dinner: Bas van Kranen x Sebastian Frank
```
name: '4 Hands Dinner: Bas van Kranen x Sebastian Frank'
event_type: 'dinner'
description: (§12)
start_date/end_date: '2026-11-09' / '2026-11-09'
start_time/end_time: NULL / NULL
start_at/end_at: NULL / NULL
timezone: 'Europe/Amsterdam'
venue_name: 'Restaurant Flore (De L''Europe Amsterdam)'
address: 'Nieuwe Doelenstraat 2-14, 1012 CP Amsterdam'
city: 'Amsterdam'  country_code: 'NL'
latitude/longitude: 52.3638 / 4.8906
admission_type: 'paid'  admission_note: NULL
official_url: 'https://restaurantflore.com/4-hands-dinner-series/'
ticket_url: 'https://www.sevenrooms.com/explore/restaurantflore/reservations/create/search?date=2026-11-09&lang=en&tracking=flore-website'
image_url: NULL  status: 'upcoming'  moderation_status: 'published'  availability_status: 'available'
external_host_name/url: NULL / NULL
relationship: event_restaurants (restaurant_id d656c75f-9354-4f57-b133-b5ce03b913a7, is_host=true, is_venue=true)
```

### 2. VanOost Sundays | 4 Hands Lunch — Sören Herzig
```
name: 'VanOost Sundays: 4 Hands Lunch — Sören Herzig'
event_type: 'dinner'
description: (§12)
start_date/end_date: '2026-09-06' / '2026-09-06'
start_time/end_time: NULL / NULL
start_at/end_at: NULL / NULL
timezone: 'Europe/Amsterdam'
venue_name: 'VanOost'
address: 'Mauritskade 61, 1092 AD Amsterdam'
city: 'Amsterdam'  country_code: 'NL'
latitude/longitude: NULL / NULL
admission_type: 'paid'  admission_note: '€210 per person — aperitif, 6-course menu, amuses and friandises, water, coffee and tea'
official_url: 'https://www.vanoostrestaurant.com/events-nl'
ticket_url: 'https://widget.guestplan.com/?id=LqaNhjf0bf9032816a33d3a21f990e91b65e2799a0c43fc7&locale=nl'
image_url: NULL  status: 'upcoming'  moderation_status: 'published'  availability_status: 'available'
external_host_name: 'VanOost'  external_host_url: 'https://www.vanoostrestaurant.com'
relationship: none
```

### 3. Game Brunch
```
name: 'Game Brunch'
event_type: 'experience'
description: (§12)
start_date/end_date: '2026-10-18' / '2026-10-18'
start_time/end_time: '12:00:00' / '15:00:00'
start_at/end_at: '2026-10-18T10:00:00Z' / '2026-10-18T13:00:00Z'
timezone: 'Europe/Amsterdam'
venue_name: 'Sainte Cécile Ballroom (Van Oys Maastricht Retreat)'
address: 'Kasteellaan 1, 6245 SB Eijsden-Margraten'
city: 'Eijsden'  country_code: 'NL'
latitude/longitude: 50.796123 / 5.70613
admission_type: 'paid'  admission_note: '€150 adult; children 4–11 €45, 12–17 €75, 0–3 free'
official_url: 'https://www.vanoys.com/event-calendar/game-brunch/'
ticket_url: 'https://sevn.ly/xu9m3Tuz'
image_url: NULL  status: 'upcoming'  moderation_status: 'published'  availability_status: 'available'
external_host_name/url: NULL / NULL
relationship: event_hotels (hotel_id 4d09cb3c-7dd0-408e-80ac-02642a6b320b, is_host=true, is_venue=true)
```

### 4. Dîner Dansant (Christmas Eve Gala)
```
name: 'Dîner Dansant'
event_type: 'dinner'
description: (§12)
start_date/end_date: '2026-12-24' / '2026-12-25'
start_time/end_time: '19:00:00' / '00:00:00'
start_at/end_at: '2026-12-24T18:00:00Z' / '2026-12-24T23:00:00Z'
timezone: 'Europe/Amsterdam'
venue_name: 'Sainte Cécile Ballroom (Van Oys Maastricht Retreat)'
address: 'Kasteellaan 1, 6245 SB Eijsden-Margraten'
city: 'Eijsden'  country_code: 'NL'
latitude/longitude: 50.796123 / 5.70613
admission_type: 'paid'  admission_note: '€245 per person — champagne aperitif, 4-course dinner, wines, live music and dancing'
official_url: 'https://www.vanoys.com/event-calendar/diner-dansant/'
ticket_url: 'https://www.vanoys.com/event-calendar/diner-dansant/' (site's own booking CTA is currently misrouted — re-check before go-live)
image_url: NULL  status: 'upcoming'  moderation_status: 'published'  availability_status: 'unknown'
external_host_name/url: NULL / NULL
relationship: event_hotels (hotel_id 4d09cb3c-7dd0-408e-80ac-02642a6b320b, is_host=true, is_venue=true)
```

### 5. Chefs & Sommeliers Party
```
name: 'Chefs & Sommeliers Party'
event_type: 'dinner'
description: (§12)
start_date/end_date: '2026-08-31' / '2026-09-01'
start_time/end_time: '18:00:00' / '00:00:00'
start_at/end_at: '2026-08-31T16:00:00Z' / '2026-08-31T22:00:00Z'
timezone: 'Europe/Amsterdam'
venue_name: 'Pillows Luxury Boutique Hotel Inter Scaldes'
address: 'Zandweg 2, 4416 NA Kruiningen'
city: 'Kruiningen'  country_code: 'NL'
latitude/longitude: 51.4532 / 4.0258
admission_type: 'paid'  admission_note: '€325 per person — wines and champagnes selected by participating sommeliers included; complimentary courtesy car ≤15km separately available'
official_url: 'https://www.interscaldes.nl/eng/chefs-sommelier-party'
ticket_url: 'https://widget.guestplan.com/?id=FSDmZop002604654aa9c689c0c18ff0d0bcbec2a41bacda1&locale=nl'
image_url: NULL  status: 'upcoming'  moderation_status: 'published'  availability_status: 'available'
external_host_name/url: NULL / NULL
relationships: event_restaurants ×5 —
  2ea838af-6205-4e76-8528-fc85d196f450 (Inter Scaldes, is_host=true, is_venue=true)
  d2725c06-f3cf-43bc-b884-957c9e6762da (Bij Jef, is_host=false, is_venue=false)
  3aa741e9-ad38-463c-a358-fa0ee8a2d698 (Zarzo, is_host=false, is_venue=false)
  90d2b4ae-2b39-4bed-beec-31d6008a7ea8 (Parkheuvel, is_host=false, is_venue=false)
  fef9e0e6-5bd8-4bc5-8a0e-0ddfcedc1807 (Zilte, is_host=false, is_venue=false)
```

### 6. Winemakers Lunch — South Africa
```
name: 'Winemakers Lunch — South Africa'
event_type: 'tasting'
description: (§12)
start_date/end_date: '2026-09-12' / '2026-09-12'
start_time/end_time: NULL / NULL
start_at/end_at: NULL / NULL
timezone: 'Europe/Amsterdam'
venue_name: 'Restaurant Merlet'
address: 'Duinweg 15, 1871 AC Schoorl'
city: 'Schoorl'  country_code: 'NL'
latitude/longitude: 52.6996668 / 4.6942853
admission_type: 'paid'  admission_note: '€175 per person — 4-course lunch, champagne aperitif, 9 selected wines'
official_url: 'https://merlet.nl/evenementenagenda/12-september-winemakers-lunch'
ticket_url: 'https://widget.guestplan.com/?id=HRTig9K0f8333294b4ca22b74d69ce4a79685bd0ea87222f&locale=nl'
image_url: NULL  status: 'upcoming'  moderation_status: 'published'  availability_status: 'available'
external_host_name/url: NULL / NULL
relationship: event_restaurants (restaurant_id 0f7aefc0-6384-468e-832f-2423d6fcb2ed, is_host=true, is_venue=true)
```

### 7. Four Hands Dinner: Merlet x Restaurant Joann
```
name: 'Four Hands Dinner: Merlet x Restaurant Joann'
event_type: 'dinner'
description: (§12)
start_date/end_date: '2026-11-22' / '2026-11-22'
start_time/end_time: '12:30:00' / NULL
start_at/end_at: '2026-11-22T11:30:00Z' / NULL
timezone: 'Europe/Amsterdam'
venue_name: 'Restaurant Merlet'
address: 'Duinweg 15, 1871 AC Schoorl'
city: 'Schoorl'  country_code: 'NL'
latitude/longitude: 52.6996668 / 4.6942853
admission_type: 'paid'  admission_note: NULL
official_url: 'https://merlet.nl/evenementenagenda/22-november-four-hands-dinner-merlet-x-restaurant-joann'
ticket_url: 'https://merlet.nl/evenementenagenda/22-november-four-hands-dinner-merlet-x-restaurant-joann' (exact GuestPlan widget URL to be captured at actual apply time)
image_url: NULL  status: 'upcoming'  moderation_status: 'published'  availability_status: 'available'
external_host_name/url: NULL / NULL
relationships: event_restaurants ×2 —
  0f7aefc0-6384-468e-832f-2423d6fcb2ed (Merlet, is_host=true, is_venue=true)
  6cd400f4-5fad-477a-8fc5-9b9adfb18789 (Joann, is_host=false, is_venue=false)
```

### 8. Six Hands Dinner: Drie chefs, drie continenten, één avond
```
name: 'Six Hands Dinner: Drie chefs, drie continenten, één avond'
event_type: 'dinner'
description: (§12)
start_date/end_date: '2026-09-24' / '2026-09-24'
start_time/end_time: NULL / NULL
start_at/end_at: NULL / NULL
timezone: 'Europe/Amsterdam'
venue_name: 'Bij Jef'
address: 'Herenstraat 34, 1797 AJ Den Hoorn, Texel'
city: 'Den Hoorn'  country_code: 'NL'
latitude/longitude: 53.0247743 / 4.7498821
admission_type: 'paid'  admission_note: '€225 per person, 6-course menu. Booking by phone (+31 222 31 96 23) or email (info@bijjef.nl) only — no online ticket link exists.'
official_url: 'https://bijjef.nl/nl/specials/drie-chefs-drie-continenten-een-avond'
ticket_url: NULL
image_url: NULL  status: 'upcoming'  moderation_status: 'published'  availability_status: 'available'
external_host_name/url: NULL / NULL
relationship: event_restaurants (restaurant_id d2725c06-f3cf-43bc-b884-957c9e6762da, is_host=true, is_venue=true)
```

## 16. RELATIONSHIP SAFETY MATRIX

| Event | Entity | Type | Role | is_host | is_venue | 8A eligible | 8B eligible |
|---|---|---|---|---|---|---|---|
| Flore x Sebastian Frank | Flore | Restaurant | HOST+VENUE | true | true | yes | yes |
| Game Brunch | Van Oys Maastricht Retreat | Hotel | HOST+VENUE | true | true | yes | yes |
| Dîner Dansant | Van Oys Maastricht Retreat | Hotel | HOST+VENUE | true | true | yes | yes |
| Chefs & Sommeliers Party | Inter Scaldes | Restaurant | HOST+VENUE | true | true | yes | yes |
| Chefs & Sommeliers Party | Bij Jef | Restaurant | PARTICIPANT | false | false | no | no |
| Chefs & Sommeliers Party | Zarzo | Restaurant | PARTICIPANT | false | false | no | no |
| Chefs & Sommeliers Party | Parkheuvel | Restaurant | PARTICIPANT | false | false | no | no |
| Chefs & Sommeliers Party | Zilte | Restaurant | PARTICIPANT | false | false | no | no |
| Winemakers Lunch | Merlet | Restaurant | HOST+VENUE | true | true | yes | yes |
| Merlet x Joann | Merlet | Restaurant | HOST+VENUE | true | true | yes | yes |
| Merlet x Joann | Joann | Restaurant | PARTICIPANT | false | false | no | no |
| Six Hands Dinner | Bij Jef | Restaurant | HOST+VENUE | true | true | yes | yes |
| VanOost x Sören Herzig | (no relationship row — external host) | — | — | — | — | no | no |

Note that **Bij Jef appears twice with two different roles**: HOST for
its own Six Hands Dinner, PARTICIPANT for Inter Scaldes's Chefs &
Sommeliers Party. This is exactly the kind of case the semantic model
exists to get right — the same restaurant is correctly `is_host=true`
on one Event and `is_host=false` on another, based purely on who
actually organizes each specific Event.

## 17. STEP 8C PASSPORT SAFETY

Re-confirmed: `event_confirmed_attendance` remains the sole Passport
eligibility gate. Inserting any of these 8 Events, or any of their 10
relationship rows (5 for Chefs & Sommeliers Party, 2 each for Game
Brunch/Dîner Dansant relationship... correction: 1 each for those two,
2 for Merlet x Joann, 1 each for Flore/Winemakers Lunch/Six Hands),
cannot place any of them into any user's Passport — there is no code
path from `events`, `event_restaurants`, or `event_hotels` into
Passport. No production attendance fixture was created or proposed.

## 18. AT THIS EVENT

Based on existing, unmodified product behavior (culinary participants
attached via relationship rows render under "AT THIS EVENT" on Event
Detail, regardless of host/participant role):

- **Flore x Sebastian Frank**: Flore.
- **Game Brunch / Dîner Dansant**: Van Oys Maastricht Retreat.
- **Chefs & Sommeliers Party**: Inter Scaldes, Bij Jef, Zarzo,
  Parkheuvel, Zilte — five canonical entities, the richest "AT THIS
  EVENT" section this app will have shown for a Netherlands Event.
- **Winemakers Lunch**: Merlet.
- **Merlet x Joann**: Merlet, Joann.
- **Six Hands Dinner**: Bij Jef.
- **VanOost x Sören Herzig**: nothing renders — no canonical
  relationship exists (external host only), matching the existing
  Marchal/Douro to Table precedent from the European batch.

No UI change is proposed or required.

## 19. SCALE

If the full 8-Event subset is approved: **9 → 17** total upcoming
Events. Comfortably below the ~50-concurrently-displayed threshold
already identified for Step 8A popularity-RPC batching. No batching
concern, no batching work triggered.

## 20. TRANSACTION PREVIEW

Not executed — preview only, one atomic transaction, matching the
established pattern from every prior apply this session:

```sql
BEGIN;

-- Final duplicate re-check (must return 0 rows before proceeding)
SELECT id, name, start_date FROM public.events
WHERE name IN (
  '4 Hands Dinner: Bas van Kranen x Sebastian Frank',
  'VanOost Sundays: 4 Hands Lunch — Sören Herzig',
  'Game Brunch',
  'Dîner Dansant',
  'Chefs & Sommeliers Party',
  'Winemakers Lunch — South Africa',
  'Four Hands Dinner: Merlet x Restaurant Joann',
  'Six Hands Dinner: Drie chefs, drie continenten, één avond'
);

WITH e_flore AS (
  INSERT INTO public.events (name, description, event_type, venue_name, address, city,
    country_code, latitude, longitude, timezone, start_date, end_date, start_time, end_time,
    start_at, end_at, admission_type, admission_note, official_url, ticket_url, image_url,
    status, moderation_status, availability_status)
  VALUES ('4 Hands Dinner: Bas van Kranen x Sebastian Frank', '<description>', 'dinner',
    'Restaurant Flore (De L''Europe Amsterdam)', 'Nieuwe Doelenstraat 2-14, 1012 CP Amsterdam',
    'Amsterdam', 'NL', 52.3638, 4.8906, 'Europe/Amsterdam', '2026-11-09', '2026-11-09', NULL, NULL,
    NULL, NULL, 'paid', NULL, 'https://restaurantflore.com/4-hands-dinner-series/',
    'https://www.sevenrooms.com/explore/restaurantflore/reservations/create/search?date=2026-11-09&lang=en&tracking=flore-website',
    NULL, 'upcoming', 'published', 'available') RETURNING id
),
e_vanoost AS (
  INSERT INTO public.events (name, description, event_type, venue_name, address, city,
    country_code, timezone, start_date, end_date, start_time, end_time, start_at, end_at,
    admission_type, admission_note, official_url, ticket_url, image_url, status,
    moderation_status, availability_status, external_host_name, external_host_url)
  VALUES ('VanOost Sundays: 4 Hands Lunch — Sören Herzig', '<description>', 'dinner', 'VanOost',
    'Mauritskade 61, 1092 AD Amsterdam', 'Amsterdam', 'NL', 'Europe/Amsterdam',
    '2026-09-06', '2026-09-06', NULL, NULL, NULL, NULL, 'paid',
    '€210 per person — aperitif, 6-course menu, amuses and friandises, water, coffee and tea',
    'https://www.vanoostrestaurant.com/events-nl',
    'https://widget.guestplan.com/?id=LqaNhjf0bf9032816a33d3a21f990e91b65e2799a0c43fc7&locale=nl',
    NULL, 'upcoming', 'published', 'available', 'VanOost', 'https://www.vanoostrestaurant.com')
  RETURNING id
),
e_brunch AS (
  INSERT INTO public.events (name, description, event_type, venue_name, address, city,
    country_code, latitude, longitude, timezone, start_date, end_date, start_time, end_time,
    start_at, end_at, admission_type, admission_note, official_url, ticket_url, image_url,
    status, moderation_status, availability_status)
  VALUES ('Game Brunch', '<description>', 'experience',
    'Sainte Cécile Ballroom (Van Oys Maastricht Retreat)', 'Kasteellaan 1, 6245 SB Eijsden-Margraten',
    'Eijsden', 'NL', 50.796123, 5.70613, 'Europe/Amsterdam', '2026-10-18', '2026-10-18',
    '12:00:00', '15:00:00', '2026-10-18T10:00:00Z', '2026-10-18T13:00:00Z', 'paid',
    '€150 adult; children 4–11 €45, 12–17 €75, 0–3 free', 'https://www.vanoys.com/event-calendar/game-brunch/',
    'https://sevn.ly/xu9m3Tuz', NULL, 'upcoming', 'published', 'available') RETURNING id
),
e_diner AS (
  INSERT INTO public.events (name, description, event_type, venue_name, address, city,
    country_code, latitude, longitude, timezone, start_date, end_date, start_time, end_time,
    start_at, end_at, admission_type, admission_note, official_url, ticket_url, image_url,
    status, moderation_status, availability_status)
  VALUES ('Dîner Dansant', '<description>', 'dinner',
    'Sainte Cécile Ballroom (Van Oys Maastricht Retreat)', 'Kasteellaan 1, 6245 SB Eijsden-Margraten',
    'Eijsden', 'NL', 50.796123, 5.70613, 'Europe/Amsterdam', '2026-12-24', '2026-12-25',
    '19:00:00', '00:00:00', '2026-12-24T18:00:00Z', '2026-12-24T23:00:00Z', 'paid',
    '€245 per person — champagne aperitif, 4-course dinner, wines, live music and dancing',
    'https://www.vanoys.com/event-calendar/diner-dansant/', 'https://www.vanoys.com/event-calendar/diner-dansant/',
    NULL, 'upcoming', 'published', 'unknown') RETURNING id
),
e_chefs AS (
  INSERT INTO public.events (name, description, event_type, venue_name, address, city,
    country_code, latitude, longitude, timezone, start_date, end_date, start_time, end_time,
    start_at, end_at, admission_type, admission_note, official_url, ticket_url, image_url,
    status, moderation_status, availability_status)
  VALUES ('Chefs & Sommeliers Party', '<description>', 'dinner',
    'Pillows Luxury Boutique Hotel Inter Scaldes', 'Zandweg 2, 4416 NA Kruiningen',
    'Kruiningen', 'NL', 51.4532, 4.0258, 'Europe/Amsterdam', '2026-08-31', '2026-09-01',
    '18:00:00', '00:00:00', '2026-08-31T16:00:00Z', '2026-08-31T22:00:00Z', 'paid',
    '€325 per person — wines and champagnes selected by participating sommeliers included; complimentary courtesy car ≤15km separately available',
    'https://www.interscaldes.nl/eng/chefs-sommelier-party',
    'https://widget.guestplan.com/?id=FSDmZop002604654aa9c689c0c18ff0d0bcbec2a41bacda1&locale=nl',
    NULL, 'upcoming', 'published', 'available') RETURNING id
),
e_wine AS (
  INSERT INTO public.events (name, description, event_type, venue_name, address, city,
    country_code, latitude, longitude, timezone, start_date, end_date, start_time, end_time,
    start_at, end_at, admission_type, admission_note, official_url, ticket_url, image_url,
    status, moderation_status, availability_status)
  VALUES ('Winemakers Lunch — South Africa', '<description>', 'tasting', 'Restaurant Merlet',
    'Duinweg 15, 1871 AC Schoorl', 'Schoorl', 'NL', 52.6996668, 4.6942853, 'Europe/Amsterdam',
    '2026-09-12', '2026-09-12', NULL, NULL, NULL, NULL, 'paid',
    '€175 per person — 4-course lunch, champagne aperitif, 9 selected wines',
    'https://merlet.nl/evenementenagenda/12-september-winemakers-lunch',
    'https://widget.guestplan.com/?id=HRTig9K0f8333294b4ca22b74d69ce4a79685bd0ea87222f&locale=nl',
    NULL, 'upcoming', 'published', 'available') RETURNING id
),
e_joann AS (
  INSERT INTO public.events (name, description, event_type, venue_name, address, city,
    country_code, latitude, longitude, timezone, start_date, end_date, start_time, end_time,
    start_at, end_at, admission_type, admission_note, official_url, ticket_url, image_url,
    status, moderation_status, availability_status)
  VALUES ('Four Hands Dinner: Merlet x Restaurant Joann', '<description>', 'dinner', 'Restaurant Merlet',
    'Duinweg 15, 1871 AC Schoorl', 'Schoorl', 'NL', 52.6996668, 4.6942853, 'Europe/Amsterdam',
    '2026-11-22', '2026-11-22', '12:30:00', NULL, '2026-11-22T11:30:00Z', NULL, 'paid', NULL,
    'https://merlet.nl/evenementenagenda/22-november-four-hands-dinner-merlet-x-restaurant-joann',
    'https://merlet.nl/evenementenagenda/22-november-four-hands-dinner-merlet-x-restaurant-joann',
    NULL, 'upcoming', 'published', 'available') RETURNING id
),
e_sixhands AS (
  INSERT INTO public.events (name, description, event_type, venue_name, address, city,
    country_code, latitude, longitude, timezone, start_date, end_date, start_time, end_time,
    start_at, end_at, admission_type, admission_note, official_url, ticket_url, image_url,
    status, moderation_status, availability_status)
  VALUES ('Six Hands Dinner: Drie chefs, drie continenten, één avond', '<description>', 'dinner',
    'Bij Jef', 'Herenstraat 34, 1797 AJ Den Hoorn, Texel', 'Den Hoorn', 'NL', 53.0247743, 4.7498821,
    'Europe/Amsterdam', '2026-09-24', '2026-09-24', NULL, NULL, NULL, NULL, 'paid',
    '€225 per person, 6-course menu. Booking by phone (+31 222 31 96 23) or email (info@bijjef.nl) only.',
    'https://bijjef.nl/nl/specials/drie-chefs-drie-continenten-een-avond', NULL, NULL,
    'upcoming', 'published', 'available') RETURNING id
),
rel_flore AS (
  INSERT INTO public.event_restaurants (event_id, restaurant_id, is_host, is_venue)
  SELECT id, 'd656c75f-9354-4f57-b133-b5ce03b913a7'::uuid, true, true FROM e_flore RETURNING event_id
),
rel_brunch_hotel AS (
  INSERT INTO public.event_hotels (event_id, hotel_id, is_host, is_venue)
  SELECT id, '4d09cb3c-7dd0-408e-80ac-02642a6b320b'::uuid, true, true FROM e_brunch RETURNING event_id
),
rel_diner_hotel AS (
  INSERT INTO public.event_hotels (event_id, hotel_id, is_host, is_venue)
  SELECT id, '4d09cb3c-7dd0-408e-80ac-02642a6b320b'::uuid, true, true FROM e_diner RETURNING event_id
),
rel_chefs AS (
  INSERT INTO public.event_restaurants (event_id, restaurant_id, is_host, is_venue)
  SELECT id, '2ea838af-6205-4e76-8528-fc85d196f450'::uuid, true, true FROM e_chefs
  UNION ALL SELECT id, 'd2725c06-f3cf-43bc-b884-957c9e6762da'::uuid, false, false FROM e_chefs
  UNION ALL SELECT id, '3aa741e9-ad38-463c-a358-fa0ee8a2d698'::uuid, false, false FROM e_chefs
  UNION ALL SELECT id, '90d2b4ae-2b39-4bed-beec-31d6008a7ea8'::uuid, false, false FROM e_chefs
  UNION ALL SELECT id, 'fef9e0e6-5bd8-4bc5-8a0e-0ddfcedc1807'::uuid, false, false FROM e_chefs
  RETURNING event_id
),
rel_wine AS (
  INSERT INTO public.event_restaurants (event_id, restaurant_id, is_host, is_venue)
  SELECT id, '0f7aefc0-6384-468e-832f-2423d6fcb2ed'::uuid, true, true FROM e_wine RETURNING event_id
),
rel_joann AS (
  INSERT INTO public.event_restaurants (event_id, restaurant_id, is_host, is_venue)
  SELECT id, '0f7aefc0-6384-468e-832f-2423d6fcb2ed'::uuid, true, true FROM e_joann
  UNION ALL SELECT id, '6cd400f4-5fad-477a-8fc5-9b9adfb18789'::uuid, false, false FROM e_joann
  RETURNING event_id
),
rel_sixhands AS (
  INSERT INTO public.event_restaurants (event_id, restaurant_id, is_host, is_venue)
  SELECT id, 'd2725c06-f3cf-43bc-b884-957c9e6762da'::uuid, true, true FROM e_sixhands RETURNING event_id
)
SELECT
  (SELECT id FROM e_flore) AS flore_id, (SELECT id FROM e_vanoost) AS vanoost_id,
  (SELECT id FROM e_brunch) AS brunch_id, (SELECT id FROM e_diner) AS diner_id,
  (SELECT id FROM e_chefs) AS chefs_id, (SELECT id FROM e_wine) AS wine_id,
  (SELECT id FROM e_joann) AS joann_id, (SELECT id FROM e_sixhands) AS sixhands_id,
  (SELECT count(*) FROM rel_flore) + (SELECT count(*) FROM rel_wine) + (SELECT count(*) FROM rel_sixhands) AS single_restaurant_rels,
  (SELECT count(*) FROM rel_chefs) AS chefs_party_rels,
  (SELECT count(*) FROM rel_joann) AS joann_rels,
  (SELECT count(*) FROM rel_brunch_hotel) + (SELECT count(*) FROM rel_diner_hotel) AS hotel_rels;

COMMIT;
```

**Expected count deltas**:
```
events                +8   (9 → 17)
event_restaurants    +10   (1 Flore + 5 Chefs&Sommeliers + 1 Winemakers + 2 Merlet×Joann + 1 Six Hands)
event_hotels           +2   (Game Brunch + Dîner Dansant, both Van Oys)
event_chefs             0
event_confirmed_attendance  0 (unchanged)
```

**Post-write verification queries** (not run): re-select all 8 new
Events by name and confirm every field matches §15 exactly; re-select
all 9 pre-existing Events and confirm byte-for-byte unchanged;
re-count `event_restaurants`/`event_hotels` and confirm exact deltas;
re-confirm `event_confirmed_attendance` unchanged at its current
value.

## 21. PHYSICAL DEVICE PLAN

**Events list**: all 8 new Events appear, chronologically ordered
alongside the 9 existing ones (earliest: Chefs & Sommeliers Party,
Aug 31; latest: Dîner Dansant, Dec 24); placeholders render for all 8.

**Date/time formatting**: Flore x Sebastian Frank, VanOost x Herzig,
Winemakers Lunch, and Six Hands Dinner all show only a bare date, no
time of any kind. Merlet x Joann shows 12:30 with no end time/duration
implied. Game Brunch shows 12:00–15:00. Dîner Dansant shows 19:00 on
Dec 24 through 00:00 — confirm the UI correctly represents a
same-Event time window crossing into Dec 25 rather than rendering as
two separate days.

**Event Detail** (all 8): Tickets/Official website rows link out
correctly (note: Dîner Dansant's own official link currently
misroutes on the venue's own site — confirm Mantelier doesn't
compound this by masking or mislabeling it); admission info renders
correctly including Six Hands Dinner's phone/email-only note and Game
Brunch's tiered child pricing; venue/location renders correctly,
including VanOost's missing map pin (no coordinates) rendering as
absent rather than wrong.

**AT THIS EVENT**: Chefs & Sommeliers Party is the key test — confirm
all five entities (Inter Scaldes, Bij Jef, Zarzo, Parkheuvel, Zilte)
render, and confirm none of the four non-host entries display any
host-implying UI treatment.

**Reverse Hosted-Event Discovery (Step 8B)**: Flore's own Detail page
shows a second hosted Event (now two: the pilot + this one); Van Oys
Maastricht Retreat's own Detail page shows two hosted Events (Game
Brunch + Dîner Dansant); Inter Scaldes's own Detail page shows Chefs &
Sommeliers Party; Merlet's own Detail page shows two hosted Events
(Winemakers Lunch + Merlet x Joann); Bij Jef's own Detail page shows
**two** hosted Events (its own Six Hands Dinner) but must **not** show
Chefs & Sommeliers Party (participant-only there) — this is the
sharpest negative test in this whole batch, since Bij Jef genuinely
hosts one Event and merely participates in another. Zarzo's, Parkheuvel's,
and Zilte's own Detail pages show **zero** newly hosted Events from
this batch (participant-only). Joann's own Detail page shows zero.

**Placeholder imagery**: all 8 render the branded Mantelier
placeholder, no broken image state.

**Interested/Going**: available on all 8 like any other Event; does
not place anything in Passport.

**Passport**: none of the 8 appears in any test account's Passport
before a genuine confirmed attendance exists.

## 22. VALIDATION

`dart format --set-exit-if-changed .`: clean (no Dart touched — see
accompanying chat report for the exact re-run count). `flutter
analyze`: no issues. `flutter test`: baseline unchanged. `supabase
migration list --linked`: 39/39 `local == remote`. `supabase db push
--linked --dry-run`: "Remote database is up to date." `git status
--short`: only this new untracked file — nothing staged.

## DATABASE

Production writes = 0. Schema changes = 0. Migrations = 0. RLS changes
= 0. Storage writes = 0.

## GIT

Nothing staged, committed, or pushed.

## HARD STOP CONFIRMATION

No Event inserted or modified. No Restaurant/Hotel/Private Chef
created. No image uploaded. No migration created. No RLS changed. No
Event UI, Step 8A, Step 8B, or Step 8C modified. No second Dutch batch
researched.

## EXACT RECOMMENDATION

All 8 candidates clear every gate this app has applied to every prior
batch — insert all 8, plus their 12 relationship rows (10
`event_restaurants`, 2 `event_hotels`). Two operational notes to carry
into the actual apply, neither a hold reason: (1) Dîner Dansant's live
booking CTA is currently broken on Van Oys's own site — worth a human
re-check before go-live rather than propagating a dead link; (2)
several booking widgets (SevenRooms, GuestPlan) are JS-rendered and
their live seat-availability could not be confirmed by automated
fetch — `availability_status` values above reflect the absence of any
sold-out marker on the surrounding page, not a confirmed live seat
count.

DUTCH EVENT ENRICHMENT — BATCH 1 DEEPLY VERIFIED, PRODUCTION-READY
DUTCH EVENT SUBSET PREPARED, READY FOR HUMAN APPLY REVIEW
