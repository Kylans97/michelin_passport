# Journeys — luxury trains and small ships (plan)

Status: **proposal, awaiting the product owner's approval.** Nothing here is
built or applied. Written 2026-11-16, branch `claude/trains-and-ships`.

On 2026-11-16 the product owner decided that high-end train journeys and
small, unique ships belong in the catalogue. This document proposes the shape.
Candidates are staged in `supabase/data/enrichment/journeys/`.

"Journey" is the working umbrella term in identifiers (a train or a ship you
travel on and sleep aboard). It is a neutral word, not the brand.

---

## 1. Why not the `hotels` table

A train or ship is not a hotel, and the hotel scope rules forbid it anyway:
`hotels` holds only MICHELIN Key hotels and 50 Best Hotels, with no stub rows
for any other property. A journey has an operator, one or more routes, a
season and departure pattern, cabins, and no fixed address. So it gets its own
tables. **No settled decision needs to change** for this, as long as:

- journeys never enter `hotels`, `restaurants` or `hotel_restaurants`;
- every relationship is a join table (journey ↔ operator is a plain FK to a
  lookup table, the same as `restaurants.city_id`; journey ↔ restaurant,
  journey ↔ event are join tables);
- recognition is editorial, never gold, never a `michelin_*` column.

Two points touch settled decisions without breaking them; both are listed in
§7 for an explicit yes.

## 2. Tables (first slice in bold)

| Table | Purpose |
|---|---|
| **`journey_operators`** | Lookup: Belmond, Rovos Rail, JR Kyushu, Aqua Expeditions, Aman… `operator_code` (`op_001`), name, website, country of registration. A lookup table, not free text, because grouping by operator (Belmond runs five trains) is a feature from day one — the `property_name` lesson. |
| **`journeys`** | One row per train or ship. `journey_code` (`train_001`, `ship_001`), `kind` (`train` / `ship`), `ship_type` (`river`, `expedition`, `sailing_yacht`, `motor_yacht`, `yacht`; NULL for trains), name, `operator_id`, `primary_country_code` (for the card and for code + country dedupe), `status` (`operating` / `announced` / `retired`), `first_departure_on` (announced only), `cabins_text`, `guest_capacity`, `dining_text`, `official_url`, `publication_status` (`draft` / `published`). Descriptive text is a starting value; the operator's own text takes over later (venue-supplied content rule). |
| **`journey_routes`** | One row per route: `route_code`, from/to place (text) and country, `nights`, `season_text`, `departure_pattern_text` — exactly as the operator publishes it, never inferred. |
| **`journey_route_stops`** | Ordered stops (place text, country, optional lat/lng) so a route can be drawn on the trip map and the globe. |
| **`journey_restaurants`** | Named dining partnerships that point at a catalogue restaurant (e.g. a chef's starred restaurant) with `role = 'dining_partner'`. A chef with no catalogue restaurant stays in `dining_text` only. |
| **`journey_travels`** | The Passport record: a member confirms they travelled — `journey_id`, optional `route_id`, `departed_on`, `arrived_on`, rating 1–10, comment, `visibility` (`private` default / `friends`), `source` (`manual` / `trip_completion`). Mirrors `event_confirmed_attendance`. **Only this table creates a stamp.** A wishlist entry or a trip plan never does. |
| `wishlist.entity_type` | Widened with `'journey'`. Shipped builds filter every wishlist read by `entity_type`, so an old build ignores journey rows rather than crashing on them (checked in `wishlist_repository.dart`). |
| `event_journeys` (later) | Host / venue / participant link for events aboard (a guest-chef dinner on a train), the same explicit semantics as `event_restaurants`. |
| `journey_departures` (later) | Dated departures, only where the operator publishes a calendar. Needed for trip planning, not for the first slice. |
| `venue_managers_journeys`, photo tables (later) | Operator claims and operator-supplied photos, through the existing review flow. |

All catalogue tables: RLS on, `select` to anon/authenticated, no client
write. `journey_travels`: RLS owner-write, read by owner and accepted friends
when `visibility = 'friends'`, the same policy shape as `visits`. The first
slice needs no `SECURITY DEFINER` function; any later one gets its own
`revoke execute … from public, anon` in the same migration.

Views: `journeys_full` (operator name, route count,
countries covered) — the app reads the view, as for restaurants and hotels.

## 3. Identity

- `id` uuid, never in CSVs. `journey_code`, `operator_code`, `route_code`
  are the stable human keys.
- Never match on name ("Orient Express" alone names three different products
  by two companies).
- Dedupe on `journey_code` + `primary_country_code`.

## 4. App

- **Explore**: a "Trains & Ships" segment beside Collections and Private
  Chefs, with one Filters affordance (train / ship, region). Calm cards:
  name, operator, from → to, nights. No badges.
- **Search**: journeys appear with operator and route as disambiguation.
- **Detail page**: a new `JourneyDetailScreen` with its own
  `JourneyDetailHero`. The three existing heroes stay separate; a fourth,
  separate hero follows the same reasoning.
- **Wishlist**: heart on the card and detail page.
- **Passport**: "I travelled on this" opens a short confirm sheet (route,
  dates). A confirmed travel gives a stamp in its own Passport filter.
- **Photos**: the content rule says photos come from the operator, so the
  first slice shows a typographic card (no scraped images) until operators
  supply photos through the claim flow.

## 5. Public site (`site-next/`)

Second slice: `/journeys` index and `/journeys/[slug]` pages generated from
`journeys_full`, same layout as restaurant pages; wishlist heart behind
sign-in.

## 6. Proposed first slice

1. Migration: operators, journeys, routes, stops, travels,
   `journey_restaurants`, wishlist widening, `journeys_full`. Tests on RLS and
   constraints.
2. Seed: the candidates the product owner picks. The first slice (9 trains,
   11 ships) was applied to production with the migration on 2026-11-16, on
   the product owner's approval.
3. App: Explore segment, detail screen, wishlist, confirm-travel + Passport
   stamp. Shown in the simulator.
4. CHANGELOG entries.

Later slices: site pages, events aboard, dated departures, Trips integration,
operator claims and photos, Off the beaten track (Peru) using these rows.

## 7. Decisions needed from the product owner

1. Approve the shape above (one `journeys` table with `kind`, not two tables).
2. Selection label: every journey is in the catalogue by editorial choice;
   show it as "Mantelier Selection" (never gold)? This widens the Selection
   beyond restaurants, which the Selection migration calls its own decision.
   **Reversed 2026-11-16 by the product owner** ("die treinen en ships zijn
   niet mantelier selection"): journeys are not in the Selection, carry no
   label, and `journey_selections` was dropped from the unapplied migration.
   A retired train still stays, like a restaurant that loses its stars.
3. A fourth, separate hero widget (`JourneyDetailHero`) — consistent with
   "do not unify", but it is a new hero.
4. No photos until operators supply them (content rule), or an exception.
5. Which candidates go in.
