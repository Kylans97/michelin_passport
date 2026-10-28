# Trips: multiple destinations and shared trips (plan)

Status: **applied to production 2026-10-28** as
`supabase/migrations/20261022120000_add_trip_destinations_and_members.sql`
(renamed from 20261021120000 before applying: feature/guide-sources had
taken that version). The first apply failed on a backfill/RLS ordering
issue and rolled back cleanly; see the changelog. Checks:
`docs/Engineering/checks/trip_destinations_and_members_checks.sql`, 44/44.
Product-owner decisions in §0; the three remaining points in §7 were
settled as proposed. The app side is built on `feature/trips-redesign`. Written 2026-10-28 on `feature/trips-redesign`, against
`main` at `e46c282` (ledger: 102 migrations, last `20261019130000`;
`feature/editorial-selection` holds an unapplied `20261020120000`).

## 0. Product-owner decisions (2026-10-28)

1. **The trip title is free text; a destination is not.** A destination has
   to be found in the app (a catalogue country, optionally a catalogue
   city), since otherwise there are no hotels or restaurants to offer
   there. No free-text destination label.
2. **Events, multi-country:** a trip proposes events in **each** of its
   destination countries, for the dates the user is in that country.
3. **Leg dates are required once a trip has more than one destination.**
   The user says where they will be on which dates. A single-destination
   trip's leg is simply the whole trip.
4. **Any member of a trip can invite** (accepted members, not only the
   owner).
5. **Unfriending:** the unfriended person stays on **past** trips and is
   removed from **future** trips.

These replace §7's open questions; the sections below are updated to match.

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
  -- This leg's dates; must sit inside the trip's own range (enforced by
  -- trigger, since a CHECK can't see planned_trips). Required whenever the
  -- trip has more than one destination (decision 3, enforced by
  -- save_trip_destinations); NULL only on a single-destination trip, where
  -- the leg is the whole trip.
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
  Decision 1 reverses the original free-text choice for destinations: a
  destination is always something the catalogue knows, a country or a
  catalogue city, because that's what the pickers can offer venues for.
  There is no free-text label column. (The trip *title* stays free text.)
- **Leg dates:** required on a multi-destination trip (decision 3), so a
  stay or visit always falls in a known leg. Never invented: the user
  enters them, and the UI won't save a second destination without them.
- `position` gives an itinerary order; the lowest one is the trip's primary
  destination (see §4).

### 3.2 `planned_venues`: no new column

A stay or visit already has its own dates, and its venue already has a
`country_code`/`city_id`. Since every leg of a multi-destination trip now
has dates (decision 3), which leg a plan belongs to is derived, not stored:
the leg whose place matches the venue (`city_id`, or `country_code` for a
whole-country leg) and whose dates contain the plan's start date. A stored
`destination_id` would be a second source of truth that can disagree with
the venue's own location, the same failure mode `is_in_hotel` had
(DATABASE_ARCHITECTURE §5). Defaults follow from the same rule: a stay
added under a leg starts with that leg's dates, not the whole trip's.

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
| `invite_to_trip(trip_id uuid, friend_id uuid)` | caller must be a member (`is_trip_member`: the owner or any accepted member, decision 4); the invitee must be the **caller's** friend (`is_friend(friend_id)`) and neither side has blocked the other; inserts/re-opens a `pending` row with `invited_by = auth.uid()`; writes a `trip_invite_received` notification. |
| `respond_to_trip_invite(member_id uuid, accept boolean)` | caller must be the invitee; sets `accepted`/`declined` + `responded_at`; on accept notifies the owner (`trip_invite_accepted`). |
| `leave_trip(trip_id uuid)` | a member removes themself; **their own** `planned_venues` on that trip get `trip_id = null` (kept as standalone plans, same as deleting a trip does today). |
| `remove_trip_member(member_id uuid)` | owner removes a member; same detaching of that member's own plans. |
| `save_trip_destinations(trip_id uuid, destinations jsonb)` | owner replaces the destination list atomically and keeps `planned_trips.country_code` equal to the position-0 destination (§4). |

### 3.4a Unfriending (decision 5)

Unfriending is a client `delete` on `friendships` (RLS `friendships_delete`,
`FriendshipRepository.removeFriendship`); blocking is `block_user()`, which
sets `status = 'blocked'`. An `AFTER DELETE` trigger, plus an
`AFTER UPDATE … WHEN (new.status = 'blocked')` trigger, on `friendships`
(`SECURITY DEFINER`, its own `revoke execute … from public, anon`) does this
for the two people A and B:

- On every trip **owned by A** whose `end_date >= current_date` (not yet
  over), remove B's membership row (any status), and the reverse for trips
  owned by B. B's own plans on those trips are detached (`trip_id = null`),
  the same as `leave_trip`.
- Trips that have already ended are untouched, so B stays on past trips.

"Today" is `current_date` in the database's timezone; a trip ending today
counts as current, so nobody is removed mid-trip on its last day.

**Not covered:** A and B are both members of a third person C's trip. One
reading of decision 5 removes neither, since the trip isn't either of
theirs. The other removes whoever B was invited by A. The proposal above
does neither: it only acts on trips the unfriending pair own. To confirm
(§7).

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

*Built 2026-10-28 on `feature/trips-redesign`, as described below. Not
built: a "Shared with you" marker on trip cards (shared trips simply appear
among the user's trips), and per-leg picker chips (each leg's own section
has its own scoped Add actions instead).*

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
- **Event matching (decision 2):** `eventMatchesTrip` runs per leg: the
  event's dates overlap **that leg's** dates (the whole trip's for a
  single-destination trip) **and** its `country_code` is the leg's. So a
  trip through France then Italy proposes French events during the French
  dates and Italian events during the Italian ones, and the screen fetches
  events for every distinct leg country, not just the first.
  City narrowing: events have no `city_id`, only free-text `city`, and
  comparing that with a catalogue city name would be matching on a name.
  So legs match on country + dates, and today's free-text city comparison
  is dropped for legs. It could come back if events gain a `city_id`
  (separate change).
  Step 8A's order and "filtering before ranking" are unchanged: trip
  relevance is just computed over every leg of every trip the user is on.
- Create/Edit Trip enforces decision 3: adding a second destination
  requires dates on every leg, inside the trip's range.

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

## 7. Settled as proposed (2026-10-28)

1. **Unfriending inside someone else's trip:** nothing changes; the trigger
   only acts on trips owned by one of the two people.
2. **Withdrawing invites:** the owner can remove anyone; whoever sent an
   invite can withdraw it while it's still pending (`remove_trip_member`).
3. **Overlapping legs:** allowed; the place decides which leg a plan is in.

## 8. What the migration does, beyond §3

- **Saving is one call.** `save_trip_destinations(trip, start, end, legs)`
  updates the trip's dates and replaces its legs atomically. The
  leg-inside-trip check is a deferred constraint trigger on both tables,
  so it runs once at commit and the order of the two writes doesn't matter.
- **`planned_trips.city` follows the first leg.** Saving destinations sets
  it to the first leg's catalogue city name (or null for a whole-country
  leg), because the installed build still displays it. This overwrites the
  old free-text city when the trip is saved from the new build.
- **Installed build narrowing a multi-leg trip's dates** past a leg gets an
  error, rather than the leg being silently clamped.
- **Notifications** follow the existing versioning pattern:
  `get_notifications_v3()` and `get_unread_notification_count_v3()` include
  the trip types. v2 now reads through v3 minus the trip types, so v1
  (which reads v2) and both older counts never show them to installed
  builds.
- **`get_trip_members(trip)`** returns the owner (status `owner`) and every
  non-declined member with their username/display name/avatar. Members
  needn't be friends with each other, so the app can't rely on `profiles`
  RLS for that list.
- **Removing someone from a trip** (leave, remove, unfriend, block) also
  deletes the notifications about that membership, and detaches their own
  plans on that trip into standalone plans.
- Internal helpers (`delete_trip_membership`, `detach_member_plans`) are
  callable by no client role; trigger functions likewise have no grants.

**Before applying:** re-check that `20261022120000` still sorts after every
migration on every branch, then apply with `supabase db push --linked` and
confirm `supabase migration list --linked`. The app work in §5 is a separate
build; until it ships, production behaves exactly as now for 1.2.0 users,
apart from the backfilled destination rows.
