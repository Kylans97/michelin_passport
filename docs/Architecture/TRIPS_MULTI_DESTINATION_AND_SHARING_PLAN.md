# Trips: multiple destinations and shared trips (plan)

Status: **proposal, waiting for product-owner review.** No migration has been
written or applied. Written 2026-10-28 on `feature/trips-redesign`, against
`main` at `e46c282` (ledger: 102 migrations, last `20261019130000`;
`feature/editorial-selection` holds an unapplied `20261020120000`).

Three requests, one data model:

1. A trip can cover several countries/destinations, with several hotel stays
   and several restaurant visits across them.
2. The stay/restaurant pickers only offer venues linked to the trip's
   destinations, keyed on codes and never names, never on `property_name`.
3. Friends can be invited to a trip; once they accept, the trip is theirs
   too.

---

## 1. How trips work today

### Schema (`20260810120000_create_planned_trips.sql`, widened by `20260819143000`)

| Table | Shape | Notes |
|---|---|---|
| `planned_trips` | `id`, `user_id → profiles`, `title`, `start_date`, `end_date`, **`country_code char(2) NOT NULL → countries`**, **`city text`** (free text, deliberately not a `cities` FK), `notes`, `created_at` | **Exactly one country per trip.** RLS: owner-only for every verb. |
| `planned_venues` | `id`, `user_id`, `entity_type in ('hotel','restaurant','event')`, `entity_id` (no FK, polymorphic), `trip_id → planned_trips ON DELETE SET NULL`, `start_date`, `end_date`, `notes`, `status in ('planned','completed','cancelled')` | One row per planned visit/stay. Already allows **any number** of hotels and restaurants per trip, each with its own dates. RLS: owner-only. |
| `visits.converted_from_planned_venue_id` | unique, `ON DELETE SET NULL` | Provenance for a future trip-completion flow. |

Anon has no grants on either table (`20260918130000`). `delete-account` relies
on `profiles` cascades for both.

### Who reads the single country/city

| Reader | Uses |
|---|---|
| `TripsBody` (Passport → Trips) | featured trip's `countryCode` to fetch events |
| `TripDetailScreen` | `countryCode` for events; `city` for display |
| `eventMatchesTrip` / `eventsMatchingTrip` (`lib/models/event_trip_match.dart`) | date overlap **and** `event.country_code = trip.country_code` **and**, when both have one, a case-insensitive **name** comparison of `event.city` to `trip.city` |
| `EventDiscoveryService._safeTripSignals` | the same matcher; feeds Step 8A's first ranking signal (trip relevance) |
| `PlanVenueSheet` | lists trips by title/date only |
| `CreateTripSheet` | writes `country_code` + free-text `city` |
| **Shipped 1.2.0 (13)** | all of the above, with `.eq('user_id', …)` on every trips/venues read |

### What the app does on top (before today's change)

- Pickers searched the **whole** catalogue, any country.
- Trip Detail's "Change hotel" **deleted every hotel on the trip** and
  added one, so a second stay planned via the venue's own Plan sheet was
  silently thrown away. Fixed app-side on this branch: "Add stay" now adds.

---

## 2. What ships now without a schema change (this branch)

App-only, already on `feature/trips-redesign`:

- **Pickers scoped to the trip's country**: `HotelRepository.search` /
  `RestaurantRepository.search` with `countryCode`, a server-side
  `country_code = …` filter. No names, no `property_name`.
- Create Trip: venue pickers stay disabled until a destination is chosen;
  changing the destination drops already-picked venues from another
  country.
- Multiple stays per trip ("Add stay" no longer replaces).

That covers request 2 at **country** granularity for single-country trips.
City-level scoping and several countries need the schema below.

---

## 3. Proposed data model

### 3.1 `planned_trip_destinations` (new)

```sql
create table public.planned_trip_destinations (
  id            uuid primary key default gen_random_uuid(),
  trip_id       uuid not null references public.planned_trips(id) on delete cascade,
  position      smallint not null check (position >= 0),
  country_code  char(2) not null references public.countries(country_code),
  -- Optional narrowing to one catalogue city. NULL = the whole country.
  city_id       uuid references public.cities(id),
  -- Optional dates for this leg; must sit inside the trip's own range
  -- (enforced by trigger, since a CHECK can't see planned_trips).
  start_date    date,
  end_date      date,
  created_at    timestamptz not null default now(),
  constraint planned_trip_destinations_dates_valid
    check (end_date is null or start_date is null or end_date >= start_date),
  unique (trip_id, position)
);
create unique index planned_trip_destinations_place_uidx
  on public.planned_trip_destinations (trip_id, country_code, city_id) nulls not distinct;
create index on public.planned_trip_destinations (trip_id);
```

Why this shape:

- **Codes, not names.** A destination is `country_code` plus an optional
  `city_id`, the catalogue's own keys. Pickers filter
  `restaurants_full` / `hotels_full` (both already expose `city_id` and
  `country_code`) with
  `city_id in (<city destinations>) or country_code in (<whole-country destinations>)`.
  Nothing joins on a name or on `property_name`.
- **`city_id` is the curated catalogue city**, unlike `planned_trips.city`.
  The original free-text decision ("a trip destination isn't restricted to
  catalogue cities") still holds: a destination with no catalogue city is
  simply a whole-country destination. The trade-off: a destination like
  "Lake Como" can't be stored as such. If that matters, add a display-only
  `label text`, never joined or matched. **Question 1** below.
- **Leg dates are optional.** "Known date ≠ known time" applies in spirit:
  no leg dates are invented. Without them a leg just spans the whole trip.
- `position` gives an itinerary order; the lowest one is the trip's primary
  destination (see §4).

### 3.2 `planned_venues`: no new column

A stay or visit already has its own dates, and its venue already has a
`country_code`/`city_id`. Which leg it belongs to is derived, not stored:
same `city_id` (or `country_code` for a whole-country leg), tie-broken by
dates when a trip returns to the same place. A stored `destination_id`
would be a second source of truth that can disagree with the venue's own
location, the same failure mode `is_in_hotel` had (DATABASE_ARCHITECTURE
§5). **Question 2** below, in case per-leg grouping should be stored.

### 3.3 `planned_trip_members` (new, for sharing)

```sql
create table public.planned_trip_members (
  id            uuid primary key default gen_random_uuid(),
  trip_id       uuid not null references public.planned_trips(id) on delete cascade,
  user_id       uuid not null references public.profiles(id) on delete cascade,
  invited_by    uuid references public.profiles(id) on delete set null,
  status        text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined')),
  created_at    timestamptz not null default now(),
  responded_at  timestamptz,
  unique (trip_id, user_id)
);
create index on public.planned_trip_members (user_id, status);
```

- The **owner stays `planned_trips.user_id`**, not a member row, so the
  shipped build's owner-only RLS and `.eq('user_id', …)` reads keep working
  unchanged.
- A status column here, unlike `venue_managers_*` ("active access is the
  absence of revocation"): an invitation really has three states the UI
  shows, the same reasoning as `friendships.status`. Leaving deletes the
  row; there's no `left` state to keep.

### 3.4 Helper and RPCs (all `SECURITY DEFINER`, all with their own `revoke execute … from public, anon` in the same migration, verified with `has_function_privilege`)

| Function | Does |
|---|---|
| `is_trip_member(trip_id uuid) returns boolean`, stable | owner, or an `accepted` member. Used by RLS so policies don't recurse into `planned_trip_members`' own policies. |
| `invite_to_trip(trip_id uuid, friend_id uuid)` | caller must be the owner; `is_friend(friend_id)` must hold and neither side has blocked the other (`friendships.status = 'blocked'`); inserts/re-opens a `pending` row; writes a `trip_invite_received` notification. |
| `respond_to_trip_invite(member_id uuid, accept boolean)` | caller must be the invitee; sets `accepted`/`declined` + `responded_at`; on accept notifies the owner (`trip_invite_accepted`). |
| `leave_trip(trip_id uuid)` | a member removes themself; **their own** `planned_venues` on that trip get `trip_id = null` (kept as standalone plans, same as deleting a trip does today). |
| `remove_trip_member(member_id uuid)` | owner removes a member; same detaching of that member's own plans. |
| `save_trip_destinations(trip_id uuid, destinations jsonb)` | owner replaces the destination list atomically and keeps `planned_trips.country_code` equal to the position-0 destination (§4). |

`invite_to_trip` is **owner only in V1**: members can't invite onward.
**Question 3** below.

### 3.5 RLS

| Table | select | insert / update / delete |
|---|---|---|
| `planned_trips` | `user_id = auth.uid() or is_trip_member(id)`, plus a pending invitee can read the trip they were invited to (title/dates/destinations, enough to decide) | unchanged: owner only |
| `planned_trip_destinations` | `is_trip_member(trip_id)` (+ pending invitee) | none for clients; writes only via `save_trip_destinations` |
| `planned_trip_members` | the row's own `user_id`, or a member of that trip | none for clients; RPCs only |
| `planned_venues` | `user_id = auth.uid() or (trip_id is not null and is_trip_member(trip_id))` | unchanged: owner of the row only, and inserting with a `trip_id` additionally requires `is_trip_member(trip_id)` (today a client could attach a plan to any trip id it knew; harmless while trips were private, not once they're shared) |

What "they will also have that trip" means concretely: an accepted member
sees the trip in their own Trips list, its destinations, and **everyone's**
planned stays/visits on it, each labelled with who added it. Each person
edits only their own plans. Nothing here touches the Passport. Stamps still
come only from confirmed attendance, and a friend's planned visit never
becomes your visit.

### 3.6 Notifications

`notifications.type` gains `trip_invite_received` and `trip_invite_accepted`
(maybe `trip_invite_declined`); `subject_type` gains `planned_trip_member`.
Both are CHECK constraints redefined in `20261018130000`, so the migration
drops and re-adds them with the full current list. The shipped build is
safe here: `AppNotification.fromRow` returns null for an unknown type
(`tryFromWire`), so 1.2.0 just doesn't show the new ones.
`get_notifications()` needs the trip title joined in for the new types.

---

## 4. Shipped-build compatibility (three-step rule)

1.2.0 (13) reads and writes `planned_trips.country_code` (NOT NULL) and
`city`. Neither can be removed or go stale while that build is out.

- **Step 1 (this migration):** add the new tables. Backfill one
  position-0 destination per existing trip from `country_code`, with
  `city_id = NULL`. Free-text `city` is **not** mapped to a `city_id`:
  that would be matching on a name, which CLAUDE.md forbids. The legacy
  text stays on `planned_trips.city` and is still shown.
- **Keeping both shapes correct in the middle step:**
  - New build: writes destinations through `save_trip_destinations`, which
    also sets `planned_trips.country_code` to the position-0 destination.
  - Old build edits a trip's country: an `AFTER UPDATE OF country_code`
    trigger on `planned_trips` moves the position-0 destination to the new
    country (and clears its `city_id`), so the two never disagree.
  - Old build creates a trip: an `AFTER INSERT` trigger creates its
    position-0 destination.
  - Old build reads with `.eq('user_id', …)`: it never sees trips shared
    with that user, nor other members' plans. That's correct for a build
    with no sharing UI. It can't break, only miss things.
- **Step 2:** ship the build that reads destinations and members.
- **Step 3 (later, once 1.2.0 is gone):** decide whether
  `planned_trips.country_code` / `city` go away or stay as the cached
  primary destination.

Migration naming: after the highest existing file at the time it's
written. Today that's `20261020120000` on `feature/editorial-selection`,
so `20261021120000` or later. Re-check against every branch before
creating it.

---

## 5. App changes that follow

- `PlannedTrip` gains `destinations` and `members`; `loadTrips` drops
  `.eq('user_id')` and relies on RLS (own + shared).
- Create/Edit Trip: a destination list (country → optional city from
  `cities` for that country, by `id`), reorderable; optional leg dates.
- Pickers: `search(…)` gains `cityIds`/`countryCodes` filters (an `.or()`
  on `city_id.in.()` / `country_code.in.()`); a destination chip row in
  the picker to narrow to one leg.
- Trip Detail: legs as sections (destination header, then that leg's
  stays and dining, derived per §3.2), a "Travelling with" row of
  `MemberAvatar`s, "Invite friends" opening a friends-only picker.
- Trips list: a "Shared with you" marker; pending invitations shown at the
  top of Trips (accept/decline) as well as in Notifications.
- **Event matching:** `eventMatchesTrip` runs per destination: dates overlap
  the leg (or the trip if the leg has no dates) **and** `country_code`
  matches. The current city refinement compares free-text names. For
  `city_id` destinations, keep it only if events gain a `city_id`
  (separate change); otherwise match on country + dates. **Question 4.**
  Step 8A's order and "filtering before ranking" are unchanged: trip
  relevance is just computed over every leg of every trip the user is on.

---

## 6. Verification plan for the migration session

- Fresh replay of all migrations on a scratch stack (`supabase start`),
  backfill checked against a copy of production's row counts.
- RLS matrix on the local stack, as owner / accepted member / pending
  invitee / declined / stranger / blocked friend / anon: select and write
  on all four tables.
- `has_function_privilege('anon', …, 'EXECUTE')` false for every new
  function; `authenticated` true only where intended.
- Old-build simulation: run 1.2.0's exact queries (`.eq('user_id')`
  reads, country edits) against the migrated schema and confirm the
  triggers keep destinations in step.
- `delete-account`: owner deleted → trip, destinations and members
  cascade; member deleted → their membership and own plans cascade, the
  owner's trip stays.
- `supabase migration list --linked` in agreement after apply; CHANGELOG
  entry.

---

## 7. Questions for the product owner

1. **Non-catalogue places.** Is a destination limited to a country plus,
   optionally, a catalogue city, or should it also carry a free display
   label ("Lake Como", "Provence")? A label is display only and never
   used for matching or scoping.
2. **Per-leg grouping:** derive it from each venue's own location and
   dates (proposed), or let the user assign a stay/visit to a leg
   explicitly (a stored `destination_id`)?
3. **Who can invite:** owner only (proposed), or any accepted member?
   And can members add destinations, or only the owner?
4. **Event matching per destination:** country + dates only for
   catalogue-city destinations (proposed), or keep today's free-text
   city-name comparison until events have a `city_id`?
5. **Unfriending:** does removing a friend also remove them from shared
   trips, or does membership stand on its own once accepted (proposed:
   it stands, the owner can remove)?
