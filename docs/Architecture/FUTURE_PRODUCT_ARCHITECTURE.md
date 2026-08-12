# Future Product Architecture — Navigation, Community, Trips, Venue Profiles, Verified Stamps

Read-only architecture spike, 2026-08-12. No code was changed, no database was touched beyond read-only queries already covered by this project's established `supabase db query --linked` audit channel, no migrations were created, nothing was staged/committed/pushed. This document is a recommendation for a future product decision, not an implementation plan that's been approved.

---

## 0. Headline finding

**Trips already exists**, more completely than the brief assumed. `planned_trips` + `planned_venues` (migration `20260810120000`, applied to production) plus `lib/features/trips/` (three screens, a repository, a model) plus `lib/models/event_trip_match.dart` (a tested, pure event↔trip matching function) are a working implementation of almost exactly what section 12–13 of the brief asks for — it's just not wired into bottom navigation, currently reached only via a link from `WishlistScreen`. Several of this document's recommendations are therefore "finish wiring what exists" rather than "design from scratch." The code's own comments say "not yet applied" in a few places — that's now stale; `supabase migration list` confirms `20260810120000` (Trips), `20260810160000` (Events), and `20260810180000` (event admission) are all live in production today.

---

## 1. Current state audit

### 1.1 Bottom navigation (`lib/app.dart`, `_MainNavigation`)

Five tabs, `IndexedStack`-backed, no lazy construction: **Passport · Explore · Rankings · Wishlist · Profile**. `GuidesScreen` is not one of them — Guides (Michelin/World's 50 Best/Gault&Millau) is fully built (Steps 2A–2D) but has no entry point in the shipped app yet; it was only ever reached via a temporary preview harness during device review.

### 1.2 Events (`public.events` / `event_restaurants` / `event_hotels`)

- **Table shape**: `id, name, description, start_at, end_at, country_code, city (free text), venue_name, address, latitude, longitude (plain double, not PostGIS), official_url, ticket_url, image_url, event_type (festival|dinner|tasting|market|experience|other), status (upcoming|cancelled|completed), admission_type (free|paid|mixed|unknown), admission_note, created_at`.
- **Venue links**: two normalized join tables, `event_restaurants` and `event_hotels`, each a real cascading FK + `unique(event_id, venue_id)` — deliberately not the polymorphic `entity_type/entity_id` pattern `visits`/`wishlist`/`planned_venues` use, because one event can link both a restaurant and a hotel simultaneously, and PostgREST embedding needs a real FK either way.
- **RLS**: public read (`anon, authenticated`), **no insert/update/delete policy for any client role** — events are catalogue-style content, written only by the service role (import scripts), exactly like `restaurants`/`hotels` themselves.
- **No ownership/source concept at all today.** There is no `created_by`, `source_type`, `organizer_id`, or moderation state — every row is implicitly "Chasing Stars editorial," because nothing else has ever written here.
- **Flutter**: `Event` model, `EventsRepository` (read-only: `loadEvents`, `loadEventsForCountry`, `getCountries`, `loadEventById`, `loadLinkedVenues`), `EventsScreen`, `EventDetailScreen`, `EventCard`, `EventFilterBar`. Reached today from `ExploreScreen`'s `WhatsOnSection` (`_openEventsScreen`).
- **Trip integration already exists**: `eventMatchesTrip`/`eventsMatchingTrip` (pure, unit-tested) compare `event.startAt/endAt` to `trip.startDate/endDate` by calendar date, require exact `country_code` match, and require city match **only when both sides have a city** — otherwise falls back to country-level. `TripDetailScreen` already calls this against `EventsRepository.loadEventsForCountry`.

### 1.3 Trips (`public.planned_trips` / `public.planned_venues`)

- `planned_trips`: `id, user_id, title, start_date, end_date, country_code, city (free text), notes, created_at`. Check constraint `end_date >= start_date`.
- `planned_venues`: polymorphic `entity_type (hotel|restaurant) + entity_id` (no FK, same convention as `visits`/`wishlist`), `trip_id` nullable **`ON DELETE SET NULL`** (deleting a trip detaches its items, never deletes them), `start_date` + optional `end_date` (restaurant = single date, hotel = check-in/out), `status (planned|completed|cancelled)`, `notes`.
- **RLS: owner-only, no public read at all** — a deliberate, documented departure from `visits`/`wishlist` (which allow `profile_is_visible()` reads for future social features): a future trip's dates/destination are judged more sensitive than past-visit history.
- **Flutter**: `PlannedTrip` model, `PlannedTripsRepository`, `PlannedTripsScreen`, `TripDetailScreen`, `TripCard`, `CreateTripSheet` — reached today via a link inside `WishlistScreen`, not from bottom navigation.

### 1.4 Wishlist (`public.wishlist`)

- `user_id, entity_type (hotel|restaurant), entity_id, added_at, priority`, `unique(user_id, entity_type, entity_id)`. RLS allows public read via `profile_is_visible(user_id)` (owner or a public profile), write is owner-only.
- Deliberately the **lighter-weight sibling** of `planned_venues`: no dates, no status, no trip association — "I'd like to go" vs. Trips' "I'm going, here's when." These are two real, already-coexisting concepts today, not a single thing waiting to be built.
- `WishlistScreen`/`WishlistRepository`/`WishlistViewModel` (`defaultWishlistVenueType` — a pure helper deciding the initial Restaurants/Hotels tab).

### 1.5 Passport / Visits (`public.visits`, `public.photos`)

- `visits`: polymorphic `entity_type/entity_id`, `visited_on`, `rating` (1–10) + independent `food_rating/service_rating/wine_rating/value_rating` sub-scores, `menu_type (tasting_menu|a_la_carte|both)`, `notes`, `price_paid`, `currency`, and — important for future verified stamps — **`keys_at_visit`/`stars_at_visit`: the venue's award frozen at the moment of the visit**, already proving the "freeze a fact at claim time" pattern this document reuses for stamp verification.
- Multiple visits per venue are first-class: "a second dinner is a second row," never merged or overwritten.
- RLS: read via `profile_is_visible(user_id)` (already social-ready), write owner-only.
- `photos`: `user_id, visit_id (nullable FK, NOT cascading — a visit can't be deleted while photos still reference it, enforced by deleting photos first), entity_type/entity_id, storage_path, caption, taken_at, is_public`. `VisitedRepository.deleteVisitById` deletes photos first, precisely because there's no cascade.
- **100% self-reported today** — no verification concept of any kind exists on `visits`.

### 1.6 Venue relationships (`hotel_restaurants`)

`hotel_id, restaurant_id, link_confidence (exact|campus|manual_review), evidence, verified_at`, `unique(hotel_id, restaurant_id)`. This is the one existing precedent in the schema for "a verified relationship between two entities with a confidence/evidence trail" — directly reusable as a naming/shape template for Venue Claims (§7) and Stamp Claims (§6).

### 1.7 RLS patterns actually in use today

Three, and only three, patterns exist — any new table should pick one of these, not invent a fourth:

1. **Public catalogue** (`restaurants`, `hotels`, `events`, `hotel_restaurants`, `award_history`…): public read, zero client write policies, service-role-only writes.
2. **Owner-visible-or-public** (`visits`, `wishlist`, `photos`): read via `profile_is_visible()`, write restricted to `user_id = auth.uid()`.
3. **Owner-only, no public read** (`planned_trips`, `planned_venues`): both read and write restricted to `user_id = auth.uid()`.

### 1.8 A naming collision to flag now, not later

`lib/features/rankings/widgets/community_rankings_tab.dart` already uses **"Community"** to mean "aggregate/crowd rankings" (as opposed to "Personal Rankings"). Introducing a bottom-nav tab literally called **Community** for curated gastronomic communities will sit next to that existing usage. Not a blocker, but the final copy/labelling pass before shipping a Community tab must not let "Community Rankings" (existing) and "Community" (new tab) read as the same feature — recommend renaming the existing tab's label at that point (e.g. "Overall"/"Everyone") rather than carrying the collision forward.

---

## 2. Recommended long-term product architecture

### 2.1 Five-tab structure — recommended, not yet approved

**Passport · Explore · Community · Trips · Profile.**

| Current tab | Recommendation |
|---|---|
| Passport | Unchanged — already matches the target role exactly. |
| Explore | Unchanged as a concept; gains a Guides entry point and keeps What's On. |
| Rankings | **Retired as a primary tab**, folded into Explore (or Profile — see §11) as a destination, not deleted as a feature. |
| Wishlist | **Retired as a primary tab**, becomes "Saved" inside Trips (see §4.3) — the data model (`wishlist` table) does not need to disappear, only its nav-level prominence. |
| (new) Community | Built on top of the *existing* Events architecture, not a new event system. |
| (new) Trips | **Already built** (§1.3) — wire in, don't redesign. |
| Profile | Unchanged; gains membership/venue-claim entry points later. |

### 2.2 Guides placement

Guides has no entry point today. Recommended: a discovery-section destination inside Explore ("Browse the Guides" → `GuidesScreen`), not a tab of its own — it's a reference catalogue, the same category as What's On, not a distinct product pillar. Zero schema impact; Flutter-only, additive (one new `ExploreDiscoverySections` entry).

### 2.3 Rankings migration

Keep `RankingsScreen`/`rankings_repository.dart`/`ranking_entry.dart` entirely as-is. Move its entry point into Explore (or Profile, if it reads more like "my standing" than "discover"). This is a navigation change only — no data model is affected, and the §1.8 naming collision should be resolved in the same pass.

### 2.4 Wishlist migration

Do **not** drop the `wishlist` table. Recommended target UX: `Save` (from anywhere in Explore) → lands in a "Saved" list inside the Trips tab → user optionally promotes a saved item into a dated `planned_venues` row attached to a specific trip. This is additive to the existing schema (see §4.3) and preserves every existing saved item with no user-facing data loss.

### 2.5 Events placement

Stays reachable from Explore → What's On exactly as today. Once Community exists, the **same** `events` rows also surface inside a community's feed via a new link table (§3.5) — never a second copy of the event.

### 2.6 Community's role

A curated, editorially-scoped index of gastronomic activity for a geography (§3.2), built by projecting the *existing* `events` table (plus, later, editorial content) through membership + geography — not a general social feed and not a new event source.

### 2.7 Trips' role

Already correct today (§1.3): destination + dates + saved/planned venues + matched events. Needs navigation wiring and a "Saved" (ex-Wishlist) view, not new tables.

### 2.8 Profile's role

Unchanged for now. Long-term home for membership status and (once built) "Venues I manage."

---

## 3. Events architecture

### 3.1 Can the existing model remain canonical? — **Yes, unconditionally recommended.**

`events`/`event_restaurants`/`event_hotels` should be the single source for Explore, Community, Trips, and future venue-managed events. There is no genuine architectural reason for `explore_events`/`community_events`/`venue_events` — every one of those "views" is a *filtered read* of the same rows (by country/city for Explore, by community membership for Community, by `eventMatchesTrip` for Trips), never a structurally different fact. Splitting the table would immediately create a data-integrity problem (which copy is authoritative when a "venue event" also needs to show in Explore?) that the current single-table design has zero risk of.

### 3.2 Additive changes recommended (all nullable/defaulted, all backward-compatible)

| Column | Purpose | Default for existing rows |
|---|---|---|
| `source_type` | `'editorial' \| 'venue' \| 'partner' \| 'community_curator'` | `'editorial'` — every existing row (incl. 't Preuvenemint) really is editorial |
| `organizer_type` | `'restaurant' \| 'hotel' \| null` | `null` |
| `organizer_id` | the restaurant/hotel that submitted it, if any | `null` |
| `created_by` | `auth.uid()` of the submitting user (venue manager) | `null` |
| `moderation_status` | see §3.4 | `'published'` (grandfathers every existing/editorial row) |

Do **not** add `verification_status` here — that concept belongs to visits (§5), not events; an event doesn't need "verification," it needs moderation. Do not add a generic `organizer_id` FK without `organizer_type` — a bare polymorphic FK without a type discriminator is exactly the anti-pattern this schema has consistently avoided (see `entity_type + entity_id` everywhere else).

### 3.3 Venue-managed events

A restaurant/hotel manager (§7) creates an `events` row with `source_type='venue'`, `organizer_type`/`organizer_id` set to their own venue, and it enters `moderation_status='draft'`. It becomes visible via the *same* public-read RLS policy only once `moderation_status='published'` — see §3.4 for exactly how.

### 3.4 Moderation model — smallest useful version

The brief's suggested seven-state lifecycle (DRAFT/SUBMITTED/APPROVED/PUBLISHED/REJECTED/CANCELLED/ARCHIVED) is more than an MVP needs. Recommended four states, reusing the existing `status` column's *pattern* (text + CHECK) for a **new**, separate column rather than overloading `status` (which already means upcoming/cancelled/completed — a genuinely different axis):

```
moderation_status: draft | pending_review | published | rejected
```

- `draft` — venue is still editing, never queried by any public read.
- `pending_review` — venue submitted; an admin queue (future, not built now) reviews it.
- `published` — the only state the public RLS policy actually needs to check.
- `rejected` — terminal, visible only to the submitting venue manager.

`cancelled`/`completed`/`archived` are already covered by the *existing* `status` column and don't need moderation-state duplicates. Two independent axes (`status` = event lifecycle, `moderation_status` = publication gate) is simpler than one combined seven-value enum, and matches how this schema already separates orthogonal concerns (see `visits.rating` vs. `visits.menu_type` — independent facts, not one combined taxonomy).

**RLS implication**: the current `events_public_read` policy (`using (true)`) must become `using (moderation_status = 'published')` once this ships — an additive, backward-compatible change (every existing row defaults to `'published'`), but a real policy edit that needs its own reviewed migration, not a silent add.

### 3.5 Event → Community linking

New join table, mirroring `event_restaurants`'s exact shape:

```sql
create table public.event_communities (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  community_id uuid not null references public.communities(id) on delete cascade,
  unique (event_id, community_id)
);
```

Many-to-many, zero event duplication — a Netherlands-wide event can also link to a future Amsterdam community without a second `events` row. Community feeds become "events joined to my communities" reads, never a separate events source.

### 3.6 Event → Trip linking

**Already solved, ship as-is.** `eventMatchesTrip`/`eventsMatchingTrip` are pure, tested, and require no schema change — a trip's own `country_code`/`city`/`start_date`/`end_date` already carry everything needed. The only future gap: a user "saving" a specific event to a specific trip (today it's a computed match, not a stored choice) — that's a `trip_items`-shaped need, see §4.2.

---

## 4. Trips architecture

### 4.1 Recommendation: **do not build a new Trips table set.** Extend the existing one.

`planned_trips` already is the `trips` table the brief describes. Its `city` being free text (not a `cities` FK) is the *correct* call, already made and already commented as deliberate — a trip destination must not be restricted to catalogue cities.

### 4.2 "Trip items" — already `planned_venues`, needs one addition

`planned_venues`' polymorphic `entity_type (hotel|restaurant) + entity_id` is exactly the brief's requested "polymorphic reference" — and it's the *safe* version of polymorphism this schema already uses everywhere (`visits`, `wishlist`), specifically because it deliberately has **no FK** on `entity_id` (a real FK can't point at two different tables depending on a value in another column; this schema's answer, consistently, is "don't try — check `entity_type` at the application layer instead"). That is the right call here too, not an oversight to fix.

**One additive change is genuinely needed**: extend `entity_type`'s CHECK constraint to allow `'event'`, so a specific event can be attached to a specific trip as a first-class saved item (closing the gap noted in §3.6), alongside the already-supported `'restaurant'`/`'hotel'`. `start_date`/`end_date` already fit an event's own dates fine.

```sql
alter table public.planned_venues drop constraint planned_venues_entity_type_check;
alter table public.planned_venues add constraint planned_venues_entity_type_check
  check (entity_type in ('hotel', 'restaurant', 'event'));
```

Purely additive, zero effect on existing rows (all currently `hotel`/`restaurant`).

### 4.3 Wishlist → Trips/Saved migration path

Do not delete or replace `wishlist`. Recommended path, in order:

1. **Now (safe)**: build a "Saved" view inside the Trips tab that reads the existing `wishlist` table — zero schema change, pure navigation/UI work.
2. **Later**: add a "Add to Trip" action on a saved item that inserts a `planned_venues` row (with `trip_id` set) referencing the same `entity_type`/`entity_id` — the wishlist row is left untouched (a user may still want it in Saved even after planning a specific date), not deleted or moved. Saved and Planned coexist by design, exactly as `wishlist` and `planned_venues` already coexist in the schema today.
3. **Not recommended**: any migration that copies/deletes wishlist rows into `planned_venues` — this would be a real, riskier data migration for zero product benefit, since both tables already answer genuinely different questions ("I want to" vs. "I'm going, on this date").

### 4.4 Explore → Trip loop

`Explore → venue/event detail → Save → Add to Trip` needs no new entities: `Save` writes to `wishlist` (unchanged), a Trip-scoped "Add" writes to `planned_venues` (unchanged, once `event` is a valid `entity_type`). The reusable link is exactly the `entity_type + entity_id` pair every relevant repository (`VisitedRepository`, `WishlistRepository`, `PlannedTripsRepository`) already speaks.

---

## 5. Verified stamps

### 5.1 Current visit model compatibility — good foundation, needs additive columns only

`visits` already proves the pattern this needs: `keys_at_visit`/`stars_at_visit` are facts frozen at the moment of a user action, never live-derived. Verification fields follow the identical shape.

### 5.2 Recommended additive columns on `visits`

```sql
alter table public.visits add column verification_status text not null default 'self_reported'
  check (verification_status in ('self_reported', 'venue_verified', 'event_verified'));
alter table public.visits add column verification_claim_id uuid references public.stamp_claims(id);
alter table public.visits add column verified_at timestamptz;
```

No `verification_method` as a separate concept from `verification_status` — for this product, "how" and "what kind" collapse to the same fact (a venue-verified visit was necessarily verified *by* a venue scan; there's no case yet where the method varies independently of the status). Keep it to one column unless a real second dimension appears later — see §41 principle 8.

Every existing row defaults to `'self_reported'`, `verified_at`/`verification_claim_id` both null — zero behavioral change for the entire current dataset.

### 5.3 Token/claim architecture

**New table, not an extension of `visits`** — a claim token needs to exist and be validated *before* a visit necessarily exists (see §5.6 for why "both" is the right answer), so it can't live as columns on a row that might not be created yet.

```sql
create table public.stamp_claims (
  id                uuid primary key default gen_random_uuid(),
  token_hash        text not null unique,       -- see §5.4, never the raw token
  entity_type       text not null check (entity_type in ('restaurant', 'hotel', 'event')),
  entity_id         uuid not null,
  issued_by         uuid,                        -- venue manager who generated it (§7)
  issued_at         timestamptz not null default now(),
  expires_at        timestamptz not null,
  service_date      date,                        -- optional: the specific sitting/date the venue is stamping for
  claimed_by        uuid references public.profiles(id),
  claimed_at        timestamptz,
  visit_id          uuid references public.visits(id),
  status            text not null default 'issued'
    check (status in ('issued', 'claimed', 'expired', 'revoked'))
);
```

### 5.4 QR / security model

- **Never a static per-venue QR.** Every printed/displayed code encodes a fresh, single-use token minted per receipt/service — a static code is trivially photographed and shared online, defeating the entire point.
- The QR encodes an opaque, cryptographically-random token (client never sees or computes anything meaningful from it). The server stores only `token_hash` (e.g. SHA-256 of the token) — **never the raw token at rest** — the same principle as never storing a password in plaintext; a leaked database dump must not itself hand out claimable stamps.
- `expires_at` is short (hours, not days) — a receipt-printed code should be claimable that sitting, not next week.
- `status` transitions strictly `issued → claimed` (terminal, never re-claimable) or `issued → expired` (a background/on-read check, not a client decision) or `issued → revoked` (venue-initiated cancel, e.g. printed in error).
- **The Flutter client never decides verification truth.** It POSTs the scanned token to a server-side function (Supabase Edge Function or a `security definer` RPC); the function alone checks hash match, `status='issued'`, `expires_at > now()`, sets `claimed_by`/`claimed_at`/`status='claimed'` atomically, and only then returns success. A client-side "looks valid" check is not verification — this is the one piece of this entire document that must not be implemented as a plain client-writable table with open RLS.

### 5.5 Replay protection

`token_hash unique` + the `issued → claimed` one-way transition together are the replay guard: a second claim attempt on an already-`claimed` token is rejected by the same server function, not by a separate mechanism. No raw token is ever stored, so a claimed row can't be "replayed" even by someone with direct database read access.

### 5.6 Do claims create visits, verify existing ones, or both? — **Both, claim-decides.**

- If `claimed_by` has no existing `visits` row matching `entity_type/entity_id` for a reasonable window around `service_date`, the server function **creates** a new `visits` row (`verification_status='venue_verified'`, `verification_claim_id` set) — covers the common case where scanning the receipt *is* the user's only record of the visit.
- If a matching self-reported visit already exists (the user logged it manually first, then scanned later), the function **upgrades** that row's `verification_status` in place rather than creating a duplicate visit for the same sitting — avoiding the exact "two rows for one dinner" problem `visits`' own design otherwise treats as a *feature* (repeat visits are legitimately separate rows) but would be wrong here, since claim + self-report describe the same event, not two dinners.
- This dual behavior lives entirely in the server function, not in schema — `stamp_claims.visit_id` simply records whichever visit resulted.

### 5.7 Restaurant vs. hotel vs. event stamps — one generic model

`stamp_claims.entity_type` (restaurant|hotel|event) is the same `entity_type + entity_id` pattern used everywhere else in this schema (`visits`, `wishlist`, `planned_venues`). A single `stamp_claims` table, not three parallel token tables — avoids exactly the kind of premature per-type duplication §41's principles warn against, with no loss of referential safety since (per §4.2's own reasoning) this schema already accepts "no FK on a polymorphic entity_id" as the correct, established tradeoff here.

### 5.8 Self-recorded vs. verified display — architecture only

`Visit.verificationStatus` (mapped from the new column) is enough for `PassportRestaurantCard`/`PassportHotelCard`/`RestaurantVisitsCard` to render a small, quiet "Verified" label distinct from the default self-reported state — no new table, no new screen, an additive field on an existing, already-rendered model. No implementation in this task.

### 5.9 Future privilege compatibility

Because `verification_status` + `verified_at` + `entity_id` are real, queryable, indexed-by-default columns (not a derived/computed fact), a future rule like "5 verified Michelin visits in Amsterdam" is a straightforward `count(*) where verification_status != 'self_reported' and ...` query against data that already exists in the shape it needs — no rules engine required now, and none of this document's recommendations foreclose building one later.

---

## 6. Venue profiles

### 6.1 Ownership boundary — the one hard rule

**Recognition data (Michelin stars, Gault&Millau score/toques, World's 50 Best rank) is never venue-editable, ever.** This isn't new policy — it's the same boundary `DATABASE_ARCHITECTURE.md` and the Gault&Millau architecture review already established for `inclusion_reason` vs. current recognition (`award_history`/`gault_millau_awards`/`worlds_50_best`): a venue manager operates at the same layer a Chasing Stars editor does today, and recognition tables have never had a client write policy — that doesn't change.

| Venue-controlled | Chasing Stars-controlled |
|---|---|
| Photos | Michelin stars |
| Description | Gault&Millau score/toques |
| Booking link | World's 50 Best rank |
| Events (subject to moderation, §3.4) | Hall of Fame status |
| Announcements (future) | Address/coordinates/identity (catalogue data) |

### 6.2 Venue claim architecture

One unified table for both restaurants and hotels — the same `entity_type/entity_id` pattern, not `restaurant_managers` + `hotel_managers` as two parallel tables:

```sql
create table public.venue_managers (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.profiles(id) on delete cascade,
  entity_type   text not null check (entity_type in ('restaurant', 'hotel')),
  entity_id     uuid not null,
  role          text not null default 'manager' check (role in ('manager', 'owner')),
  status        text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected', 'revoked')),
  requested_at  timestamptz not null default now(),
  approved_at   timestamptz,
  unique (user_id, entity_type, entity_id)
);
```

`status` gates everything: a `pending` claim grants no write access at all; only `approved` rows are checked by any future venue-write RLS policy (on `events.organizer_id` matches, or a future `venue_content` table). Verification of a real-world claim ("prove you work at/own this restaurant") is a product/ops process, not a schema concern — this table only records the *outcome* of that process.

### 6.3 Moderation

Reuses §3.4's `moderation_status` pattern for anything a venue manager submits (events today; description/photo changes later, if that's ever built) — one consistent gate concept across every venue-submitted content type, not a bespoke moderation model per feature.

---

## 7. Community

### 7.1 Table recommendation

```sql
create table public.communities (
  id            uuid primary key default gen_random_uuid(),
  name          text not null,
  slug          text not null unique,
  geography_type text not null check (geography_type in ('country', 'city', 'region')),
  country_code  char(2) references public.countries(country_code),
  city          text,   -- free text, same reasoning as planned_trips.city/events.city
  region_label  text,   -- free text editorial geography, e.g. "Côte d'Azur" — not a cities/regions FK
  description   text,
  created_at    timestamptz not null default now()
);

create table public.community_memberships (
  id            uuid primary key default gen_random_uuid(),
  community_id  uuid not null references public.communities(id) on delete cascade,
  user_id       uuid not null references public.profiles(id) on delete cascade,
  role          text not null default 'member' check (role in ('member', 'moderator', 'admin')),
  joined_at     timestamptz not null default now(),
  unique (community_id, user_id)
);
```

No `community_content_links` generic table — content types (events, later editorial) each get their own typed join table (`event_communities`, §3.5), the exact same reasoning `event_restaurants`/`event_hotels` already use over a generic polymorphic events↔venues link. A generic content-link table would need its own `content_type/content_id` polymorphism for no real benefit over two small typed tables, and would blur the Event-vs-editorial separation §9 argues for keeping distinct.

### 7.2 Geography model

`geography_type` (country|city|region) plus **free-text** `city`/`region_label` — never a hard FK to `cities`, matching the already-established precedent (`planned_trips.city`, `events.city`) that geography-for-editorial-grouping purposes must not be constrained to the curated Michelin-guide city list. Netherlands (country), Paris (city), Côte d'Azur (region) all fit one table with no special-casing.

### 7.3 Membership model

`role` (member|moderator|admin) is included from day one — not because MVP needs moderators, but because retrofitting a role column onto a table with existing rows is trivially additive today and mildly annoying later; the brief's own instruction not to over-build applies to the *behavior* those roles unlock (no moderator tooling needs building now), not to the column's presence.

### 7.4 Feed/content model

A community's feed is a **read**, not a stored table: events joined via `event_communities` (§3.5), filtered to `moderation_status='published'`, plus — later — editorial content joined via an equivalent `editorial_content_communities` table (§9). No community-specific content is ever authored directly; everything a community shows is a projection of content that already has its own canonical home.

### 7.5 Privileges/offers — recommendation: **C, defer entirely.**

No `privileges` table now. Reasoning: every example in the brief (priority booking, early access, complimentary pairing) is describable today as an `events` row with `event_type='experience'`, `source_type='venue'`, and a description that says what the privilege is — the *existing* model already covers the MVP need without a new concept. A dedicated `privileges` table would be premature abstraction (§41 principle 8) until a real case appears that `events` genuinely can't express (e.g. a privilege with no date at all, rather than a bookable window) — that's the trigger to revisit, not a guess made now.

---

## 8. Editorial content

### 8.1 Events vs. editorial — keep separate, do not collapse

An event is time-bound and actionable (has a date, you either attend or don't); editorial content (News, Editor's Choice, Ones to Watch, Road to Michelin) is a story with no inherent expiry or attendance action. Collapsing both into one generic "content" table to save a table would immediately need a nullable `start_at`/`end_at` and a way to distinguish "browse this" from "attend this" anyway — the two-table separation costs one extra table and removes that ambiguity entirely. Recommended only if/when editorial is actually built:

```sql
create table public.editorial_content (
  id            uuid primary key default gen_random_uuid(),
  content_type  text not null check (content_type in ('news', 'editors_choice', 'ones_to_watch', 'road_to_michelin')),
  title         text not null,
  body          text,
  published_at  timestamptz,
  entity_type   text check (entity_type in ('restaurant', 'hotel')),
  entity_id     uuid,   -- optional: the article's subject, if it has one
  status        text not null default 'draft' check (status in ('draft', 'published', 'archived'))
);
```

Not built now — Explore currently has no editorial surface, and inventing the shape before a real content type exists risks guessing wrong. Documented here only so a future Community/Events change doesn't accidentally collapse editorial into either of them.

---

## 9. MVP prioritization

### 9.1 MUST PREPARE NOW

Nothing. There is no change required *before* continuing event/community-facing work — the existing `events`/`planned_trips` architecture is already sound enough to build on directly. This is worth stating plainly since the brief assumes some prep debt exists; the audit found the opposite.

### 9.2 SAFE TO BUILD LATER (additive, no painful migration)

In rough dependency order:
1. Wire `GuidesScreen` + `RankingsScreen` into Explore/Profile as destinations (Flutter-only).
2. Wire `PlannedTripsScreen` into a real Trips tab; add a "Saved" (wishlist-reading) view inside it.
3. `communities` + `community_memberships` + `event_communities` (net-new tables, zero impact on anything existing).
4. `events` additive columns (`source_type`, `organizer_type/id`, `created_by`, `moderation_status`) + the RLS policy edit that starts actually checking `moderation_status`.
5. `venue_managers` (net-new table).
6. `planned_venues.entity_type` widened to include `'event'`.
7. `visits` additive verification columns + `stamp_claims` (net-new table) + the server-side claim-validation function.
8. Bottom-nav swap to the five-tab structure, once Community/Trips have enough real content to justify top-level billing.

### 9.3 DO NOT BUILD YET

- `privileges`/offers as a dedicated table (§7.5) — reuse `events` until a real gap appears.
- Editorial content table (§8) — no editorial surface exists to hang it off yet.
- A rules engine for privilege eligibility (§5.9) — the data will be ready when this is actually needed.
- Push notification infrastructure (§10) — only the *fields* below are worth reserving.
- Any generic "content" or "claim" abstraction wider than what's specified above — every table in this document is typed to a specific need, not a speculative platform.

### 9.4 Recommended next implementation step

Wire Guides + Trips + Rankings into existing navigation (item 1–2 of §9.2) — pure Flutter, zero schema risk, and it turns two already-built-but-hidden features (Guides, Trips) into shipped product before any new backend work starts.

---

## 10. Notifications (fields only, no infrastructure)

Worth reserving now, cheap to add later, no table needed yet:
- `community_memberships.notify` (boolean or enum, default sensible) — a future "notify me about this community's events."
- `events.moderation_status` transitioning to `published` — the natural trigger point for a future "new event near you" notification.
- `events.start_at` proximity — the natural trigger for a future "starts soon" reminder.

No notification-specific table is justified yet; these are just call-outs for where a future notification service would hook in.

---

## 11. Analytics (documentation only, nothing built)

Key future product events worth instrumenting when analytics is actually built: `community_joined`, `event_saved`, `venue_added_to_trip`, `stamp_claimed`, `venue_event_viewed`, `venue_claim_submitted`, `venue_claim_approved`. Not implemented, not designed further, here only so a future analytics pass has a starting vocabulary that matches this document's own concepts.

---

## 12. Migration path — no big bang

1. **Flutter-only navigation work** (Guides + Rankings entry points into Explore; Trips wired into bottom nav; Wishlist folded into Trips as "Saved"). Zero schema risk, ships independently, delivers value immediately from features that already exist.
2. **Community foundation** (`communities`, `community_memberships`, `event_communities`) — net-new tables, reuses existing `events` unchanged.
3. **Events extended** (`source_type`/`organizer_*`/`created_by`/`moderation_status` + updated RLS) — additive, but the RLS policy edit is a real, reviewed change, not a no-op.
4. **Venue claims** (`venue_managers`) — unlocks venue-submitted (draft) events; nothing becomes publicly visible until moderation ships.
5. **Trips extended** (`planned_venues.entity_type` widened) — lets a saved event become a trip item.
6. **Verified stamps** (`visits` additive columns + `stamp_claims` + server-side claim function) — the highest-trust, most security-sensitive piece; recommended last, after the lower-risk foundation is live and the moderation/claims pattern from steps 3–4 has already been proven once.
7. **Bottom-nav swap** to the five-tab structure — a UX change best made once Community/Trips have real content, not on day one of the schema existing.
8. **Privileges** — deferred indefinitely per §7.5, revisited only if `events` genuinely proves insufficient.

---

## 13. File / code impact map

**Flutter — reuse as-is**: `EventsRepository`, `Event`, `EventCard`, `EventDetailScreen`, `PlannedTripsRepository`, `PlannedTrip`, `TripCard`, `TripDetailScreen`, `PlannedTripsScreen`, `CreateTripSheet`, `eventMatchesTrip`/`eventsMatchingTrip`, `WishlistRepository`, `visited_repository.dart`, `RankingsScreen` + its repository, `GuidesScreen` + all four Step 2B–2D guide screens.

**Flutter — add later**: a Community tab/screen family (list, detail, feed), a venue-management console (claim submission, event drafting), a QR scan screen for stamp claiming, a "Saved" view inside Trips, Explore/Profile destination rows for Guides/Rankings.

**Flutter — retire (as primary tabs, not as code)**: `RankingsScreen`/`WishlistScreen` stop being `_MainNavigation` entries; the files/logic remain, reused from their new homes.

**Repositories — reuse**: all of the above.
**Repositories — new, later**: `CommunitiesRepository`, `VenueManagersRepository`, `StampClaimsRepository` (client-side thin wrapper; the actual claim validation is server-side, §5.4).

**Supabase — reuse unchanged**: `restaurants`, `hotels`, `restaurants_full`, `hotels_full`, `hotel_restaurants`, `events`, `event_restaurants`, `event_hotels`, `planned_trips`, `planned_venues`, `wishlist`, `visits`, `photos`, `profiles`, `countries`.
**Supabase — additive columns**: `events` (§3.2), `visits` (§5.2), `planned_venues.entity_type` widened (§4.2).
**Supabase — new tables**: `communities`, `community_memberships`, `event_communities`, `venue_managers`, `stamp_claims`, and (deferred) `editorial_content`.

---

## 14. Backward compatibility

Every recommendation in this document is additive: new nullable/defaulted columns, new tables, and one RLS policy tightening (`events_public_read`, gated on a column that defaults every existing row to the visible state). Nothing here requires deleting, renaming, or backfilling existing `visits`, `wishlist`, `planned_trips`/`planned_venues`, `events`, restaurant/hotel, or RLS state — no user-facing data loss, no forced re-migration of existing users.

---

## 15. Core principles applied throughout this document

Restated from the brief, because every recommendation above was checked against them: one canonical restaurant/hotel/event (§3.1); dedicated recognition tables stay authoritative and venue-uneditable (§6.1); user-owned data stays RLS-isolated (§1.7); venue content never controls external recognition (§6.1); stamps are server-trusted, never client-trusted (§5.4); no abstraction before real use exists (`privileges` deferred, §7.5; editorial deferred, §8); migrations stay additive (§14); MVP velocity preserved by reusing Trips/Events as-is rather than redesigning either (§0, §4.1).
