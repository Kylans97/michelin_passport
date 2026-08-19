# Events V2 — Core Product + Social + Analytics Architecture

**Status: read-only architecture design. Nothing in this document has been implemented.** No migration has been deployed, no production data written, no Dart code changed, no commit made. This is the output of a dedicated audit-then-design phase, following the same "spike, not a plan" convention as `FUTURE_PRODUCT_ARCHITECTURE.md` and `FRIENDS_PRIVACY_COMMUNITY_INTELLIGENCE.md` — a foundation the next implementation phase can build from, not a promise of what ships next.

This document assumes the reader has *not* re-read the five audits that produced it. Where a design decision rests on a specific existing file/line, that reference is given inline; the full audit transcripts are not reproduced here.

## Table of contents

0. [Product direction](#0-product-direction)
1. [Core product loop](#1-core-product-loop)
2. [Source of truth vs. analytics](#2-source-of-truth-vs-analytics-the-hard-rule)
3. [Trip lifecycle & post-trip review](#3-trip-lifecycle--post-trip-review)
4. [Audit summary](#4-audit-summary)
5. [Events as first-class entities](#5-events-as-first-class-entities)
6. [Host / venue / participant model](#6-host--venue--participant-model)
7. [Event curation standard](#7-event-curation-standard)
8. [Reference case matrix](#8-reference-case-matrix)
9. [User event intent: Interested / Going / Attended](#9-user-event-intent-interested--going--attended)
10. [Event ratings](#10-event-ratings)
11. [Event photos](#11-event-photos)
12. [Event → Passport & My Map](#12-event--passport--my-map)
13. [Personal history source](#13-personal-history-source)
14. [Duplicate history protection](#14-duplicate-history-protection)
15. [Follow](#15-follow)
16. [Friends: Interested, Going, Activity](#16-friends-interested-going-activity)
17. [Privacy model](#17-privacy-model)
18. [Notifications (candidate triggers only)](#18-notifications-candidate-triggers-only)
19. [Event publication / host self-management](#19-event-publication--host-self-management)
20. [Publication vs. lifecycle vs. availability state machines](#20-publication-vs-lifecycle-vs-availability-state-machines)
21. [Cancelled, rescheduled & series events](#21-cancelled-rescheduled--series-events)
22. [Event location, price, category, imagery](#22-event-location-price-category-imagery)
23. [Event Detail product direction](#23-event-detail-product-direction)
24. [Host profile → Events](#24-host-profile--events)
25. [Future wineries & bars](#25-future-wineries--bars)
26. [Event discovery](#26-event-discovery)
27. [Guides / recognition position](#27-guides--recognition-position)
28. [Future navigation & information architecture](#28-future-navigation--information-architecture)
29. [Database architecture](#29-database-architecture)
30. [Security](#30-security)
31. [Analytics architecture](#31-analytics-architecture)
32. [Implementation phasing](#32-implementation-phasing)
33. [Analytics implementation phasing](#33-analytics-implementation-phasing)
34. [Migration strategy](#34-migration-strategy)
35. [Open questions for the product owner](#35-open-questions-for-the-product-owner)

---

## 0. Product direction

Chasing Stars is repositioning from a guide-centric discovery app to a curated high-end gastronomy experience platform, organized around five pillars: **Discover** (places and people), **Events** (gastronomic moments, now promoted to a primary reason to return), **Passport** (confirmed personal history), **Trips** (future planning that converts into Passport history), and **Profile/Community** (Friends and social discovery).

External recognition — MICHELIN Guide, World's 50 Best, Gault&Millau, and future sources — remains canonical, accurate, and prominently surfaced, but functions going forward as a **recognition layer attached to Places**, not as the organizing principle of the navigation or the product's identity. The app's own defensible value increasingly comes from data nobody else has: canonical Places, Private Chefs, curated Events, Follow relationships, Friends signals, Interested/Going/Attended, Trips, Passport, My Map, and — new as of this phase — first-party behavioral intelligence about how all of the above connect.

This section is a restatement of the brief, not a new decision; §27 and §28 below translate it into a concrete, staged navigation change.

## 1. Core product loop

```
DISCOVER
  → EVENT / HOST PROFILE VIEW
    → FOLLOW / INTERESTED
      → GOING
        → TICKET / RESERVATION INTENT (external)
          → EVENT ENDS
            → "DID YOU MAKE IT?"
              → NO  → (nothing created)
              → YES → optional rating / photos / comment
                        → ATTENDED
                          → PASSPORT
                            → MY MAP
                              → future discovery / social signals
```

Three states are deliberately never collapsed, and every section below that touches them repeats this distinction rather than assuming it:

| State | Meaning | Proves attendance? |
|---|---|---|
| Interested | "This is relevant to me" | No |
| Going | "I intend to go" | No |
| Ticket-link click | "I clicked through to book/buy" | No — not even purchase |
| Attended | Explicit user confirmation, post-event | **Yes — this is the only state that is confirmed history** |

## 2. Source of truth vs. analytics (the hard rule)

**The application database is the sole source of truth for transactional/product state.** Interested, Going, Attendance, Follow, Trip items, Visits, Stays, ratings, and Passport membership are all rows in Postgres tables, governed by RLS, exactly as every other piece of user-owned state in this codebase already is (`visits`, `wishlist`, `friendships`, `event_attendance` — see §4).

**Analytics is never authoritative for any of the above and must never be queried to reconstruct them.** Analytics answers a categorically different question: what was viewed, where it was discovered, what interaction preceded a state change, which surfaces generate engagement. A screen that needs to know "is this user Going to this event" always reads `event_attendance` (or its Events V2 successor, §29); it never infers that from an analytics event stream. This mirrors a distinction this codebase already draws elsewhere — `get_event_attendance_count()` (a k-anonymized aggregate RPC) is architecturally separate from `event_attendance` row data (§4, Friends audit §6) — Events V2 analytics extends that same separation to a first-class, general principle rather than a one-off.

Practically, this means: every analytics event that describes a state transition (`event_going`, `follow_added`, `event_attendance_confirmed`) is a **behavioral echo** fired *after* the authoritative database write succeeds, never a replacement for it, and never the trigger that performs it. §31.16 (server-side vs. client-side) revisits this for the specific case of which side fires the echo.

## 3. Trip lifecycle & post-trip review

**Confirmed: no post-trip review flow exists today** (Trips/Passport audit §3) — `PlannedVenueStatus.completed` is a legal enum value with zero call sites; the only wired transition in `showPlannedVenueActions` is `planned → cancelled`. Trips and Passport are today two entirely independent repositories with no code path connecting them.

Design (not built): a trip is eligible for post-trip review once `planned_trips.end_date` has passed. This is **evaluated at read time** (comparing `end_date` against "now" when `PlannedTripsScreen`/`TripDetailScreen` loads), not a scheduled job or a stored "is this trip over" flag — trips have no natural server-side trigger point the way an event's own lifecycle does, and a client-side date comparison is sufficient because the prompt only ever needs to appear when the user is already looking at the trip.

For each `planned_venues` row still in `status = 'planned'` attached to a past trip (plus, per the Events V2 schema in §29, `planned_venues` rows of `entity_type = 'event'`), the review flow asks one question per item, matching the item's type:

| Item type | Question | YES | NO |
|---|---|---|---|
| Restaurant | "Did you visit {name}?" | Log Visit (rating/photos/notes all optional) → Passport | `planned_venues.status → cancelled`, no visit created |
| Hotel | "Did you stay at {name}?" | Add Stay (ratings/photos optional) → Passport | same |
| Event | "Did you make it to {name}?" | Confirm Attendance (rating/photos/comment optional) → Passport | same |

The system nudges **plan → confirmed history**; it never fabricates history. A "NO" answer is itself meaningful — it converts the plan's `status` from `planned` to `cancelled` (reusing the exact enum value/transition `showPlannedVenueActions` already writes today for manual cancellation, Trips audit §3) so the item stops resurfacing in future review prompts. §14 covers how the flow detects and skips items already logged manually before the prompt ever appears.

## 4. Audit summary

Five parallel audits preceded this design (full transcripts available in this conversation; not reproduced here). Headline findings, each cited again inline wherever it drives a specific decision below:

- **Events** already exist as a first-class catalogue domain — `events` + typed-FK `event_restaurants`/`event_hotels` join tables (deliberately not polymorphic — "an event can link BOTH restaurants AND hotels at once," `20260810160000_create_events.sql:65-72`), `event_attendance` (single legal status `'going'`, friends-visible by default), and a documented-but-never-built `event_chefs` table in the *exact* shape this document recommends building (§6, §29).
- **Friends** is a mature, symmetric, acceptance-required model (`friendships`, `is_friend()`) with a single reusable privacy predicate already threaded through `visits`/`photos`/`wishlist`/`event_attendance`. No activity-feed infrastructure exists or is recommended (`FRIENDS_PRIVACY_COMMUNITY_INTELLIGENCE.md` §4.3: derive feeds live, never a `posts` table).
- **Trips/Passport/My Map/Wishlist** are all built and working, but entirely disconnected from each other and from Events at the schema level — `planned_venues.entity_type` doesn't include `'event'` yet, no post-trip-review flow exists, `visits` has zero uniqueness constraint (multiple visits per user per venue is explicit intended behavior, unlike `wishlist`/`event_attendance` which are single-membership).
- **Follow, Analytics, Notifications**: **none of the three exist today.** A legacy one-way `follows` table exists in the schema, is referenced by zero Dart code, and every doc that mentions it recommends retiring it, not extending it (Private Chefs/Follow/Analytics audit §4). Private Chefs' `publication_status` (`draft|published|archived`) is the one real precedent for a moderation-gated catalogue.
- **Navigation/RLS/security**: five reusable RLS shapes exist across 26 migrations (public catalogue, gated-catalogue, owner-only, owner-or-friends, RPC-mediated state machine — full catalogue in §30). Bottom nav is five tabs (Passport/Explore/Rankings/Wishlist/Profile); Events, Guides, Private Chefs nest inside Explore; Trips nests inside Wishlist; Friends nests inside Profile.

## 5. Events as first-class entities

**Confirmed already true at the schema level, not a change this document needs to make.** An `events` row has never had a required FK to `restaurants`/`hotels`/`private_chefs` — it links to zero, one, or many venues of either type via `event_restaurants`/`event_hotels`, and `'t Preuvenemint` existed in production for years with **zero** linked venues (§4; Events audit §1). The only real gap is that `private_chefs` has no equivalent join table yet (`event_chefs` is designed, not built — §6), and there is no first-class concept of "host" distinct from "participant" on any of the existing join tables (both are currently un-roled membership rows).

This document's job here is narrower than "make Events standalone" (already true) — it's "add the host/participant distinction and chef support without breaking the standalone property." §6 does that.

## 6. Host / venue / participant model

### 6.1 Definitions

- **HOST** — primary organizer/publisher of the event. Zero or more per event; supports single-host (Club Leroy: Parkheuvel), multi-host (Hotel × Chef × Winemaker), and fully-external (Preuvenemint: "the event organization," not any canonical Chasing Stars entity).
- **VENUE** — where it physically occurs. Always present (an event without a location isn't useful to a traveller), but is *not* always a canonical Chasing Stars entity (Vrijthof, a public square, will never be a `restaurants`/`hotels` row).
- **PARTICIPANT** — an entity taking part without organizing. Preuvenemint's non-hosting restaurants; a guest bartender at someone else's bar.
- **COLLABORATOR** — rejected as a distinct concept, per the brief's own steer. "Participant + role" already expresses everything a "collaborator" would.

### 6.1a MVP chef hosting boundary

For MVP, supported canonical Event host types are exactly three: **Restaurant, Hotel, Private Chef.** `event_chefs.chef_id` (§6.3, §29) references `private_chefs.id` — an independent, freelance chef business already catalogued as its own entity.

A chef employed by or associated with a Restaurant/Hotel who is **not** independently represented as a Private Chef is **not** a standalone Event host in MVP:

| Scenario | Canonical host in MVP |
|---|---|
| Restaurant chef-led Event | **Restaurant** is the canonical host (`event_restaurants`, `is_host=true`) |
| Hotel chef-led Event | **Hotel** is the canonical host (`event_hotels`, `is_host=true`) |
| Private Chef Event | **Private Chef** may be the canonical host (`event_chefs`, `is_host=true`) |
| Restaurant/hotel-employed chef hosting *independently* of their employer | Non-canonical — `events.external_host_name`/`external_host_url` (the same fallback Club Leroy uses, §8 case 1) |

**Do not insert ordinary Restaurant/Hotel chefs into `private_chefs` merely to make them Event hosts.** `private_chefs` represents an independent chef *business* (its own publication status, pricing, biography, restaurant-history precedent) — not a generic staff directory, and using it as a workaround to grant host status to an employed chef would misrepresent that chef as running an independent business they don't run.

**Post-MVP**: evaluate a broader canonical `chefs` domain — supporting restaurant chefs, hotel chefs, and independent chefs uniformly, with historical/current restaurant affiliations and independent Event-hosting capability for all three. At that point, "Private Chef" should be evaluated as a *capability/business model* a Chef can have, not automatically synonymous with every Chef. This is explicitly deferred and requires **no** Step 1 schema change — `event_chefs.chef_id`'s current FK to `private_chefs.id` is exactly right for MVP scope and needs no hedging or generalization now.

### 6.2 Architecture comparison

| | A. Polymorphic `event_entities` | B. Dedicated typed join tables | C. Canonical entity registry |
|---|---|---|---|
| Referential integrity | No real FK possible (multi-type `entity_id`) | Real cascading FK per type | Real FK to registry, but registry itself needs a sync layer to stay current with `restaurants`/`hotels`/`private_chefs` |
| Extensibility to new types | New `entity_type` value only | New table per type | New registry row-type only |
| Query simplicity ("all entities for this event") | One query | Small UNION across 2-5 tables | One query, but "resolve to a real Restaurant/Hotel" still needs the same UNION one layer down |
| Fit with existing precedent | **Contradicts** this schema's explicit, written anti-pattern warning: *"Do not add a generic organizer_id FK without organizer_type — a bare polymorphic FK without a type discriminator is exactly the anti-pattern this schema has consistently avoided"* (`FUTURE_PRODUCT_ARCHITECTURE.md:129`) | **Matches** `event_restaurants`/`event_hotels` exactly, and the *already-documented, never-built* `event_chefs` (`20260810160000_create_events.sql`'s own comment block) | No precedent anywhere in this schema; introduces a shadow-index synchronization risk this schema has consistently declined to take on elsewhere (`ENGINEERING_REVIEW.md` — real FKs were rejected for user tables specifically to avoid a comparable sync/complexity tradeoff in the other direction) |
| New tables required now | 1 | 1 (`event_chefs`) + 2 alter statements | 1 registry table + 1 join table, and a migration to backfill every existing restaurant/hotel/private_chef into it |

**Recommendation: B, dedicated typed join tables**, for the same reason this schema already chose it for `event_restaurants`/`event_hotels`, `hotel_restaurants`, and pre-designed it for `event_chefs`: catalogue-linking relationships get real FKs in this codebase, by consistent, repeated, explicit precedent (§4; Navigation/RLS audit §4). Option C solves a problem this schema doesn't have yet (dozens of entity types) at the cost of a synchronization layer nobody asked for — directly against the brief's own instruction to "avoid generic polymorphic chaos" and "not create unnecessary taxonomy."

### 6.3 Concrete schema (design only — see §29 for full migration-level detail)

**Correction (superseding the original single-value `role` design below the line)**: a first version of this section gave `event_restaurants`/`event_hotels` a single `role text check (role in ('host','participant'))` column and folded "venue" entirely into `events.venue_*`, reasoning that a canonical entity hosting its own dinner (Parkheuvel/Club Leroy) makes host and venue the same fact. **That reasoning doesn't hold in general.** Club Leroy is itself evidence against it: Parkheuvel may be the physical venue while "Club Leroy"/Erik van Loo — not Parkheuvel as an entity — is the organizing presenter. A single-value column cannot express "this canonical restaurant is the venue but a *different*, non-canonical party is the host," nor can it express the equally real opposite case (Parkheuvel hosts its own dinner, genuinely both host and venue at once) without two conflicting rows for the same `(event_id, restaurant_id)` pair — which the existing `unique(event_id, restaurant_id)` constraint (confirmed live in production, `event_restaurants_event_id_restaurant_id_key`) forbids outright. **Host and venue must be independently settable facts about the same relationship row, not mutually exclusive labels on it.**

**Corrected design**: replace the single `role` column with two independent, non-exclusive booleans:

```
is_host  boolean not null default false
is_venue boolean not null default false
```

on `event_restaurants` and `event_hotels`, and identically on the new `event_chefs` table. A row's mere existence already means "this entity participates in this event" — that's the baseline, unmarked meaning (Preuvenemint↔Tout à Fait: `is_host=false, is_venue=false`, correctly describing a plain participant). `is_host`/`is_venue` are additive flags layered on top, independently true or false, so all four real-world combinations are expressible in exactly one row per entity, with no combinatorial explosion and no second row:

| `is_host` | `is_venue` | Meaning | Example |
|---|---|---|---|
| false | false | Participant only | Tout à Fait at Preuvenemint |
| true | false | Hosts, but not the physical location | "Club Leroy"/Erik van Loo, if ever modeled as a canonical entity rather than left as `external_host_name` |
| false | true | The physical location, but someone else organizes | Parkheuvel for Club Leroy, if Club Leroy itself stays non-canonical (the common case today) |
| true | true | Both at once | Parkheuvel hosting its own anniversary dinner, with no external presenter |

Both flags default `false`, so widening every existing `event_restaurants`/`event_hotels` row costs nothing to backfill correctly — the one live row (Tout à Fait↔Preuvenemint) is genuinely `false/false`, exactly matching the default.

**Never auto-infer either flag from address-matching or any other heuristic.** Whether a linked restaurant is the venue, the host, both, or neither is a fact recorded at event-authoring time by whoever links it — never derived at query time from "this restaurant's address equals `events.address`." This is stated explicitly because it's the exact mistake the brief's own Club Leroy example warns against, and nothing about the schema above tempts inferring it automatically — the two booleans exist precisely so the fact is stored, not guessed.

`events.venue_name` / `address` / `latitude` / `longitude` (already live columns, unchanged) remain the single, always-populated source of truth for physical location — necessary because a venue is not always a canonical entity at all (Vrijthof, §22) and `is_venue` on a join-table row is only ever a *cross-reference* confirming "this canonical entity happens to be at that location," never a replacement for the independently-populated address fields.

**Fully-external hosts** (Preuvenemint's organizing body, or "Club Leroy" itself while it stays non-canonical) get two new nullable columns directly on `events`: `external_host_name text`, `external_host_url text` — mirroring the proven `restaurant_name_text` fallback pattern `private_chef_restaurant_history` already uses for "an entity real enough to record but not real enough for the catalogue" (Private Chefs audit §1). No sixth join table, no `external_person`/`external_organization` entity type, no FK-to-nothing. This is unchanged from the original design — only the canonical-entity side of host/venue/participant needed correcting.

"Give me this event's host(s)" is a small, N+1-free UNION across `event_restaurants`/`event_hotels`/`event_chefs` filtered to `is_host = true`, plus a check of the two `external_host_*` columns; "give me this event's venue" checks `is_venue = true` across the same three tables first, falling back to `events.venue_name`/`address` when no canonical row is flagged — the exact same batched-resolve shape `EventsRepository.loadLinkedVenues` already implements for two tables today (Events audit §2); extending it to four sources, each independently filterable by either flag, is the same pattern repeated, not a new one.

## 7. Event curation standard

Unchanged from the brief, restated as the standing editorial bar: *"Would a high-end gastronomy traveller reasonably make plans around this?"* One-night dinners, four-hands collaborations, chef's tables, rare tasting/vertical/library tastings, wine and Champagne dinners, restaurant anniversaries, gastronomic hotel weekends, destination festivals, masterclasses, guest bartender shifts — suitable. Normal service, routine brunch/happy hour, generic markets/tastings, every winery tour, every food festival — not suitable by default.

This is enforced by the moderation-status gate in §20, not by any filterable taxonomy field — curation is an editorial decision at publication time, never a runtime query filter a user could accidentally see through (no "show me everything, curated or not" mode exists anywhere in this design).

## 8. Reference case matrix

Validated against §6's **corrected** host/venue/participant model (independent `is_host`/`is_venue` booleans, §6.3) and §9's Interested/Going/Attended state machine. Host and venue are shown as separate columns throughout, deliberately, to make clear neither is ever inferred from the other:

| Case | Host(s) | Venue | Participants | Admission |
|---|---|---|---|---|
| 1. Club Leroy at Parkheuvel | `events.external_host_name = 'Club Leroy'` (Erik van Loo's presenting brand — not a canonical Chasing Stars entity) | `event_restaurants` row, Parkheuvel, `is_venue=true, is_host=false` — Parkheuvel is where it happens, not who organizes it | none | paid, fixed €249, external ticket URL |
| 2. Preuvenemint | `external_host_name` (or left null if no named organizer exists) | `events.venue_name='Vrijthof'` (no canonical entity at all — never a restaurant/hotel row) | `event_restaurants`, Tout à Fait, `is_host=false, is_venue=false` (live in production today, correctly the all-`false` default) | mixed |
| 3. Lucas de Jager × Winery X | `event_chefs` row (Lucas, `is_host=true`) **+** future `event_wineries` row (`is_host=true`) once Wineries ships — genuinely two simultaneous hosts | future `event_wineries` row, `is_venue=true` (the same row that's also `is_host=true` — one row, both flags) — or event-specific text if held off-site | none | paid, limited seats |
| 4. Apostelhoeve special event | future `event_wineries` row, `is_host=true` | same row, `is_venue=true` | possibly an `event_chefs` row, `is_host=false, is_venue=false` | paid |
| 5. Hotel × Chef weekend | `event_hotels` row (`is_host=true`) **+** `event_chefs` row (`is_host=true`) — two simultaneous hosts | `event_hotels` row, `is_venue=true` (same row as the hotel's host flag — the hotel is both host and venue; the chef is host but not venue) | none | paid, multi-day |
| 6. World's 50 Best Bar guest shift (future) | future `event_bars` row for the home bar, `is_host=true` **+** a second `event_bars`/`event_chefs`-equivalent row for the guest bartender, `is_host=true` (both genuinely host, only one is also the location) | the home bar's row, `is_venue=true` | none beyond the two hosts above | mixed |
| 7. Private Chef at external non-canonical venue | `event_chefs` row (`is_host=true, is_venue=false`) | `events.venue_name`/`address`/`lat`/`lon` populated independently — no canonical entity is `is_venue`, since the location isn't in the catalogue at all | none | varies |

Case 1 is the corrected model's own worked example: **the previous version of this table auto-inferred Parkheuvel as the host simply because it's the event's location — exactly the mistake the brief's own Club Leroy example calls out.** Under the corrected model, Parkheuvel is linked with `is_venue=true` (a factual, independently-recorded statement about location) while the actual organizing presenter — Club Leroy — is recorded separately via `external_host_name`, with no row anywhere claiming Parkheuvel organizes the event. If Parkheuvel had instead thrown its own anniversary dinner with no external presenter, the correct row would be `is_host=true, is_venue=true` on the *same* `event_restaurants` row — still never two rows, still never inferred, just a different pair of independently-set facts.

Case 7 remains the reason `events.venue_name`/`address`/`latitude`/`longitude` must always be populated independently at event-creation time, never derived from a host's own address by default — a private chef's event location and a private chef's home city are two different facts, and the schema must never conflate them (directly enforces §12's "Private Chef home location is NOT a visited Place" rule).

No event is inserted as part of this design phase — this table is validation only, per the brief's explicit instruction.

## 9. User event intent: Interested / Going / Attended

### 9.1 Why the existing `event_attendance` table cannot simply be widened as-is

`event_attendance.status` today has `check (status in ('going'))` — a single legal value (Events audit §1). The brief's hard rule (§2 above) is that Going and Attended must never be collapsed. Widening this one table's CHECK to `('interested', 'going', 'attended')` would violate that rule structurally: "attended" would become just another status on the same row, indistinguishable in shape from "going," and a single `visibility`/`created_at` pair would have to describe two conceptually different things (an intent, and a confirmed historical fact — which should carry a rating/photos/comment and never be silently overwritten by an intent-state change).

### 9.2 Recommended split — two tables, not one

**`event_attendance`** (existing table, widened, additive, backward-compatible) becomes the **intent** table:

```sql
alter table public.event_attendance
  drop constraint event_attendance_status_check,
  add constraint event_attendance_status_check
    check (status in ('interested', 'going'));
```

Every existing row already has `status = 'going'` — the widened CHECK accepts that value unchanged, so this is a zero-data-impact migration (§34). `unique (event_id, user_id)` (already present) continues to mean "one intent row per user per event" — moving from Interested to Going is an `UPDATE`, not a new row, matching the brief's explicit requirement to support "Interested → Going," "Going → Interested," and "Going → none" (§9/§10 of the brief) as simple, single-row transitions.

**`event_confirmed_attendance`** (new table) is the **confirmed history** table:

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid pk` | |
| `event_id` | `uuid not null references events on delete cascade` | |
| `user_id` | `uuid not null references profiles on delete cascade` | |
| `confirmed_at` | `timestamptz not null default now()` | |
| `rating` | `smallint check (rating between 1 and 10)` | nullable — overall only, see §10 |
| `comment` | `text` | nullable |
| `visibility` | `text not null default 'private' check (in 'private','friends')` | see §17 |
| `source` | `text not null default 'manual' check (in 'manual','post_event_prompt','trip_completion')` | see §13 |
| `converted_from_planned_venue_id` | `uuid references planned_venues on delete set null, unique` | nullable, populated only by the trip-completion flow — see §14 (corrected) |
| `created_at` | `timestamptz not null default now()` | |

`unique (event_id, user_id)` — one confirmed attendance per user per event, deliberately *unlike* `visits` (which intentionally allows repeat rows — you can dine at a restaurant many times) — a specific dated event genuinely happens once for a given attendee, matching `wishlist`'s and the intent table's own single-membership shape, not `visits`' shape (Trips/Passport audit §8). This constraint alone already gives full database-level idempotency for confirmed attendance across every creation path — see §14 for why `converted_from_planned_venue_id` is added anyway, for symmetry/provenance, not because it's structurally required here the way it is for `visits`.

A row existing in `event_confirmed_attendance` is entirely independent of whatever `event_attendance.status` currently says — deleting/changing an intent row after the fact never touches confirmed history, and confirmed history is never created "solely because Going = true" (brief §11, honored structurally, not just by application-code discipline).

### 9.3 State machine

```
(no row)
   │ mark Interested
   ▼
INTERESTED ──── mark Going ────▶ GOING
   ▲                                │
   └──────── mark Interested ───────┘
   │                                │
   └──── remove ────▶ (no row) ◀────┘

Independently, at any point (typically post-event):
(no row in event_confirmed_attendance)
   │ user confirms "yes, I made it" (manual, prompt, or trip completion)
   ▼
CONFIRMED  (rating/comment optional, added now or later via update)
```

`event_attendance` supports direct Going without ever passing through Interested (brief §10: "direct Going without Interested"), Going→Interested (downgrade, not just removal), and full removal — all as `UPDATE`/`DELETE` against the single existing row, no new RPC needed (plain ownership RLS, Shape C, is sufficient — no role-asymmetric transition rule exists here the way friend-request accept/decline needs one, so no `SECURITY DEFINER` RPC is warranted, consistent with §30's stated decision rule for when this codebase uses an RPC vs. plain RLS).

## 10. Event ratings

**Recommendation: overall rating only (1–10, matching every other rating scale in this schema), plus optional comment and photos.** Do not reuse restaurant dimensions (food/service/wine/value) or hotel dimensions (room/experience/value) — an event can be a festival, tasting, masterclass, or bar shift, and none of those five-dimension breakdowns generalize (brief §12 makes this explicit; the audit confirms restaurant and hotel dimensions are already genuinely different from each other for exactly this reason, Trips/Passport audit §7). Multi-dimensional event ratings are deferred, not rejected outright — if a strong universal dimension set emerges once real event-attendance volume exists, it can be added additively to `event_confirmed_attendance` the same way `room_rating`/`experience_rating` were added to `visits` after the fact (`20260816120000_add_hotel_room_experience_ratings.sql`).

## 11. Event photos

**Two structurally separate systems, matching this codebase's own existing separation between admin-curated and user-owned imagery** (Private Chefs audit §3 — `private_chef_photos` vs. `public.photos` are already two unrelated systems):

- **Official event media** — admin/editorial-curated, plain `image_url` text column(s) on `events` (already exists: `events.image_url`, currently unused in production — Events audit §1), following the exact `private_chef_photos` pattern (no `user_id`, no Storage bucket, gated only by the event's own publication status) if more than one official image is ever needed.
- **User attendance photos** — reuse the existing `public.photos` table and `visit-photos`-equivalent Storage pattern, with a new nullable `attendance_id uuid references event_confirmed_attendance(id) on delete cascade` column alongside the existing `visit_id` column, mirroring exactly how `photos.visit_id` already works (Trips/Passport audit §4/§7). A photo is owned by the user who confirmed attendance, inherits that row's `visibility` for friends-read the same way a visit-photo inherits its parent visit's visibility (Shape C, §30) — never a second, independently-set visibility.

Never scrape random imagery for official event media — priority order: (1) official event asset, (2) rights-cleared host asset, (3) branded placeholder. Matches the brief's §35 instruction exactly; no new architecture needed here beyond the column above.

## 12. Event → Passport & My Map

Confirmed `event_confirmed_attendance` rows join Passport's existing unified-venue concept. `PassportVenue` today is a two-variant sealed class (`RestaurantVenue`/`HotelVenue`, Trips/Passport audit §5) fed by `VisitedRepository.loadPassportVenues`; Events V2 adds a third variant, `EventVenue(Event)`, and `VisitedRepository`'s (or a renamed successor's) query gains a third batched-resolve query against `event_confirmed_attendance` joined to `events`, following the exact same "3 queries total regardless of row count" pattern already used for restaurants+hotels.

**My Map** — confirmed-attended events get their own pin, at the event's own `latitude`/`longitude` (never a host's home address, per §8 case 7 / brief §15). The existing `ExploreVenueType`-style filter (`all/restaurants/hotels`, Trips/Passport audit §6) gains an `events` value; the underlying pin-loading pattern (`MapRepository`, deliberately isolated, degrades silently to an empty result on error) extends with a third `loadEventCoordinates` method of the same shape. **Never** plotted: Interested, Going, or upcoming Trip plans — only `event_confirmed_attendance` rows, matching the brief's explicit "only confirmed historical activity belongs on visited map" rule.

## 13. Personal history source

`event_confirmed_attendance.source` (added in §9.2: `manual | post_event_prompt | trip_completion`) remains the coarse "how was this created" tag. **Correction**: this document's original draft treated that column, plus a query-time existence check, as the *entire* dedup mechanism (§14 below). That's sufficient for suppressing a duplicate *prompt* — it is not sufficient for protecting a *write* from firing twice (a retried request, a double-tap, a flaky connection resubmitting the same trip-completion action) when the underlying table has no natural uniqueness to fall back on, which is exactly `visits`' situation (§14 explains why a plain `unique(user_id, entity_id)` is wrong there). The fix is an explicit provenance link, detailed in §14, not a change to `source` itself — `source` still answers "how," the new column answers "from which specific plan item, if any."

## 14. Duplicate history protection

Two structurally different problems, requiring two different mechanisms — conflating them was the gap in this document's original draft:

**Problem 1 — the same trip-completion action must never write history twice**, even under retry/double-submit. This needs a real database-level guarantee, not just a query-time check, and the brief explicitly asks for "an explicit provenance/link... rather than fuzzy date/name matching." Fix: a new nullable column, populated **only** when a row is created by the trip-completion flow specifically (never by a manual Log Visit/Add Stay, never by the post-event prompt):

```
visits.converted_from_planned_venue_id
  uuid references planned_venues(id) on delete set null, unique

event_confirmed_attendance.converted_from_planned_venue_id
  uuid references planned_venues(id) on delete set null, unique
```

Postgres treats `NULL` as distinct from every other `NULL` for `UNIQUE` purposes — so every ordinary, manually-logged visit/stay/confirmation (which never populates this column, leaving it `NULL`) is entirely unaffected by the constraint; only two rows both claiming the *same specific* `planned_venues.id` would ever collide, which is precisely and only the failure mode being guarded against. A retried trip-completion write for the same plan item now fails at the database, not merely at the UI layer — the strongest available guarantee, and the one the brief asked for. `on delete set null` (not cascade) matches `planned_venues.trip_id`'s own existing behavior exactly (Trips/Passport audit §1: detaches, never deletes the dependent row) — deleting the plan item afterward severs the provenance link but never touches the real history it produced, honoring this schema's "history is never overwritten or destroyed" doctrine.

This column exists on **both** `visits` and `event_confirmed_attendance` for consistency, but it carries different weight in each: on `visits`, it is the *only* real idempotency mechanism available, because a table-level `unique(user_id, entity_id)` is explicitly ruled out (a user must be able to visit/stay at the same venue many times — Trips/Passport audit §8's own documented, deliberate design). On `event_confirmed_attendance`, the existing `unique(event_id, user_id)` (§9.2) *already* provides full database-level idempotency across every creation path on its own — a specific dated event happens once for a given attendee, full stop, regardless of whether the confirming action came from a manual tap, the post-event prompt, or trip completion. The new column there is added for **symmetry and precise provenance** (so a query can ask "which confirmed attendances came specifically from this trip" without inferring it from timing), not because attendance needed a new idempotency mechanism — it already had one.

**Problem 2 — detecting a visit/stay/attendance the user already logged manually, before a prompt is ever shown**, so the same real-world event isn't asked about twice through two different flows (once via a manual log, once via a later prompt). This has no provenance link to check, by definition — a manually-logged visit was never created by the trip-completion flow, so `converted_from_planned_venue_id` is and should stay `NULL` on it. This step therefore remains the query-time existence check from this document's original draft, unchanged: before ever rendering "did you visit {name}?", check for an existing `visits` row matching `(user_id, entity_type, entity_id, visited_on between trip.start_date and trip.end_date)` (restaurants/hotels) or an `event_confirmed_attendance` row matching `(event_id, user_id)` (events) — a match suppresses that item's prompt outright, and can optionally mark the corresponding `planned_venues` row `completed` immediately, since the answer is now already known.

Net result, satisfying every requirement in the brief: repeated genuine visits remain fully possible (no venue-level uniqueness anywhere); the same planned trip item cannot accidentally create history twice (the new `unique` provenance column, enforced by the database, not application discipline); manual visits remain entirely independent (they simply never populate the new column); event attendance remains independently protected (it already was, via `unique(event_id, user_id)`, now made explicit rather than merely implied); no destructive migration (both new columns are nullable, additive, default `NULL`); no fabricated visit dates (the provenance link records *which plan item*, never invents or copies a date — `visited_on`/`confirmed_at` are still always set by whatever flow creates the row, exactly as today).

## 15. Follow

### 15.1 Model

Follow means *"tell me about new activity from this entity,"* explicitly distinct from Wishlist (*"I want to visit this Place"*) — a user can visit Parkheuvel, remove it from Wishlist, and keep Following it for years (brief §18, restated as a hard requirement). Supported entity types at launch: Restaurant, Hotel, Private Chef. Winery/Bar join the moment those catalogues exist, at zero schema cost (see below).

### 15.2 Architecture comparison

Same three options as §6.2, re-assessed for Follow's different access pattern (a user's follow list is read far more often — every event-feed load potentially checks it — while an event's host list is read once per Event Detail view):

| | A. Polymorphic `follows` | B. Dedicated typed tables | C. Canonical registry |
|---|---|---|---|
| Precedent | The *existing* legacy `follows` table is already this shape, but one-way/no-acceptance, unrelated to entity-following, and every doc says retire it, not extend it (§4) — reusing its name/shape for a different concept would be actively confusing | None yet for user→catalogue-entity follow, but structurally identical to `event_restaurants`/`wishlist` in spirit | None |
| FK integrity | No | Yes | Yes, but via a sync layer |
| "Does user X follow entity Y" query | 1 table, 1 query, any type | 1 query per type (3 at launch) | 1 query, but through the registry indirection |
| "All follows for a feed query" (§15.3) | 1 query, then per-type resolve | Small UNION, then per-type resolve — **same second step either way** | 1 query, resolve through registry |
| Extensibility (Winery/Bar) | Free (new `entity_type` value) | New table + migration | Free |

This is a genuinely closer call than §6.2 — Follow's query shape (frequent, potentially cross-type "does the current user follow any of these 40 feed items") mildly favors a single table. But the deciding factor is the same one that decided §6.2: **this schema's own explicit, repeated preference for typed FKs on catalogue-linking relationships**, plus the fact that a *bare* polymorphic follow table with no FK is precisely the shape already flagged as an anti-pattern precedent to avoid extending (`follows` itself). **Recommendation: B, dedicated typed tables** — `follows_restaurants`, `follows_hotels`, `follows_private_chefs` (each `user_id, entity_id, created_at, unique(user_id, entity_id)`, Shape C-adjacent RLS — see §17), following the `wishlist`-style single-membership shape exactly, not the multi-row `visits` shape. Winery/Bar add `follows_wineries`/`follows_bars` only once those catalogues exist — zero cost paid today.

The legacy `follows` table itself is untouched by this design (dropping it is a separate, low-priority cleanup with no functional urgency, per existing doc guidance — Private Chefs/Follow audit §4).

### 15.3 Follow → Events discovery

Query relationship (design only, not built — brief explicitly defers the ranking/feed engine): "Events from places & people you follow" is `select e.* from events e join event_restaurants er on er.event_id = e.id join follows_restaurants f on f.entity_id = er.restaurant_id where f.user_id = :uid and er.is_host = true` unioned with the equivalent for hotels and chefs, filtered to upcoming/published. `is_venue`-only rows (a followed restaurant that's merely the location, not the organizer, per §6.3) are deliberately excluded from this specific query — "tell me when someone I follow announces a new event" is a host-relationship question, not a venue one. This is a plain SQL view or a repository-level batched query, not a new table — no ranking model, no notification wiring (§18 covers notification *candidates* only).

## 16. Friends: Interested, Going, Activity

**Friends Going** already exists and needs no redesign (Friends audit §7) — `EventAttendanceRepository.getVisibleAttendeeUserIds` + `friendsGoingToEvent` already read exactly the right RLS-gated rows; once §9's split lands, this same code path simply filters `event_attendance.status = 'going'` (excluding `'interested'`) to keep its current meaning unchanged.

**Friends Interested** is the identical pattern one status value over — no new repository shape, no new RLS shape, just `status = 'interested'` instead of `'going'`, read through the same `is_friend()`-gated `event_attendance` table. A combined "4 friends interested · 2 friends going" summary line (brief §21) is one query returning both counts, grouped by `status`, rather than two separate calls.

**Friends Activity** — per the brief's own explicit restraint instruction and the existing product doctrine (no activity-feed table, no timeline, "avoid noisy feeds" — Friends audit §5, `COMMUNITY_FRIENDS_UX.md` §13's explicit "not built" list), this document recommends **against** building any aggregated cross-signal activity feed. Recommended classification of the three signals the brief asks about:

| Signal | Where it should appear |
|---|---|
| Friend is Interested in Event X | Aggregate count only ("4 friends interested"), on Event Detail — never a named list unless the viewer taps through, matching the existing Friends Going pattern exactly |
| Friend is Going to Event X | Named list, but only within Event Detail's own Friends Going section (already built) — never pushed into a cross-event feed |
| Friend attended Event X | Surfaces passively via Friend Profile's existing per-friend sections (§16 below extends the existing VISITED/WISHLIST/GOING pattern with a fourth, ATTENDED, section) — never a notification, never a feed entry |

None of the three should generate a notification by default (§18 lists them only as low-priority, opt-in candidates) and none should "enter Friends Activity" as a standalone concept, because that concept does not and should not exist.

## 17. Privacy model

Extends the existing two-tier model (`private | friends`, no public individual-activity tier — the single most consistent convention across every audited table, Friends audit §6) rather than inventing a third tier anywhere:

| Data | Visibility column | Default | Reasoning |
|---|---|---|---|
| Interested (`event_attendance`, status=interested) | `visibility` (existing column, reused) | `private` | An early, often-abandoned signal — showing it to friends by default risks manufactured social pressure; conservative default per brief §24 |
| Going (`event_attendance`, status=going) | `visibility` (existing column, reused) | `friends` (unchanged from today) | Already shipped this way; an event is already public catalogue content, so confirmed intent to attend is lower-sensitivity than a private rating — least-disruptive choice, matches existing documented reasoning verbatim (Events audit §1) |
| Attended (`event_confirmed_attendance`) | `visibility` (new column) | `private` | Matches `visits.visibility`'s own default exactly — personal history is the most sensitive tier in this schema and gets the most conservative default everywhere else, no reason to special-case events |
| Ratings/photos/comments on confirmed attendance | inherits parent `event_confirmed_attendance.visibility` | — | Matches `photos`/`visits` child-inherits-parent rule exactly (Friends audit §6, point 4) — no independent rating/photo visibility column |
| Follow | no visibility column at all | — (always own-only read) | A user's own follow list is never shown to others in this design (no "N followers" surfaced anywhere per-user); mirrors `planned_trips`' "no public/friends tier at all" pattern, not `wishlist`'s |

Every check remains a live, uncached `SELECT`-time subquery via the existing `is_friend()` function — no new predicate, no materialized permission grant, matching convention #3 of Friends audit §6 exactly. Aggregate/anonymous counts (a future "X people interested" shown to non-friends, or venue-facing dashboards, §31.13/§31.19) go through the same k-anonymized `SECURITY DEFINER` RPC pattern `get_event_attendance_count()` already established (≥5-unique-user threshold, never row-level, Friends audit §6 point 6) — this pattern is reused verbatim, not redesigned.

## 18. Notifications (candidate triggers only)

**Not built in this phase.** Candidate triggers, each with a recommended default and rationale, extending `FUTURE_PRODUCT_ARCHITECTURE.md` §10's existing "fields only, no infrastructure" stance rather than superseding it:

| Trigger | Example copy | Default | Rationale |
|---|---|---|---|
| Follow → new event from followed host | "Parkheuvel added a new event." | **Opt-in** | High-value but easy to over-fire once a user follows many hosts; needs batching design before default-on is safe |
| Interested → tickets available | "Tickets are now available." | Opt-in | Depends on ticketing-state data this design doesn't yet model (§22) |
| Going → reminder | "Club Leroy is tomorrow." | **Default on** | Low-volume (one per attended event, ever), high-utility, low risk of feeling like spam |
| Friends → social proof | "3 friends are going." | Opt-in, batched | Exactly the kind of signal §16 says should stay passive/aggregate, not push |
| Post-event → attendance prompt | "Did you make it?" | **Default on** | This *is* the mechanism that fills `event_confirmed_attendance` — without it, Passport under-fills; low-volume, directly useful |
| Trip completion | "Your Barcelona trip is complete." | Default on | Same reasoning as post-event — this is the trigger for §3's review flow, not a vanity notification |

General governance recommendation: per-host follow notifications need frequency protection (a batched daily/weekly digest once a user follows more than a handful of hosts, not one push per new event) before they can ever default on; the two "prompt" triggers (post-event, trip completion) are structurally different from the rest — they're the *delivery mechanism* for §3/§9's own flows, not marketing-adjacent engagement pushes, and should be prioritized first if notifications are ever built, ahead of any social-proof trigger.

## 19. Event publication / host self-management

Future verified host types (Restaurant, Hotel, Private Chef, later Winery, Bar) get a draft → submit → review → publish workflow, never direct publish — this reuses `private_chefs.publication_status`'s exact precedent (`draft | published | archived`, gate the public SELECT policy on it, service-role/admin-only writes today, Private Chefs audit §1/§6) rather than inventing a new shape, extended with one intermediate state events specifically need (`submitted`) that private chefs didn't (a chef profile has no "draft submitted by the chef themself" step yet — it's fully admin-authored).

**Ownership split**, directly from the brief, mapped onto concrete columns:

| Category | Fields | Who writes |
|---|---|---|
| Host-manageable (future) | title, description, date/time, ticket URL, price, photos, practical details | Host, via a future submission RPC — never direct `UPDATE` (§20 explains why) |
| Chasing Stars controlled | publication approval, editorial promotion, host verification, recognition, curation status | Service role / admin only, same as every other moderation field in this schema |
| User owned | Interested, Going, Attendance, rating, photos, comment | The attending user, via the plain-RLS ownership pattern already used for `event_attendance`/`visits` |

## 20. Publication vs. lifecycle vs. availability state machines

Three independent axes, never collapsed into one enum — directly extending the exact reasoning `FUTURE_PRODUCT_ARCHITECTURE.md` §3.3-3.4 already worked out for a simpler version of this problem (Navigation/RLS audit §6), with one axis (availability) added:

```
PUBLICATION   draft ──▶ submitted ──▶ published ──▶ archived
                                   └─▶ rejected

LIFECYCLE     scheduled ──▶ cancelled
                        └─▶ completed

AVAILABILITY  available ──▶ sold_out
                        └─▶ unknown (default — most events never report this)
```

- `events.moderation_status` (new, additive, default `'published'` for every existing row so nothing already live changes visibility — identical migration-safety pattern to `FUTURE_PRODUCT_ARCHITECTURE.md:150`'s own proposal) — gates the public SELECT policy: `events_public_read` moves from `using (true)` to `using (moderation_status = 'published')`.
- `events.status` (existing column, unchanged) stays exactly what it already is — `upcoming | cancelled | completed` — this document does not touch it.
- `events.availability_status` (new, additive, default `'unknown'`) — `available | sold_out | unknown`. Deliberately left mostly unused at launch (no ticketing integration exists, §22) — reserved so a future manual "mark sold out" admin action, or eventual ticketing-partner webhook, has a column to write to without another migration.

Every state-transition RPC touching `moderation_status` (submit-for-review, approve, reject) follows the friendship-RPC precedent exactly: no direct client `UPDATE` policy, `SECURITY DEFINER` function instead, because the legal transition depends on both current state and caller identity/role — precisely the condition Navigation/RLS audit §5 identifies as this codebase's own decision rule for choosing an RPC over plain RLS.

## 21. Cancelled, rescheduled & series events

**Cancelled** (`events.status = 'cancelled'`, already-existing lifecycle value — no schema change): the Going→attendance-prompt pipeline (§3/§9) must check `status != 'cancelled'` before ever surfacing "did you make it?" (mirrors `canAttendEvent`'s existing `!event.isCancelled` guard, Events audit §3 — the same guard extends to gate the new prompt, not just the existing Going toggle). Trip Detail's "WHAT'S ON" section shows a cancelled badge rather than hiding the event outright (matches `EventCard`'s existing cancelled-badge behavior, Events audit §3). `event_attendance`/`event_confirmed_attendance` rows are never deleted on cancellation — they remain as internal historical record, simply no longer actionable.

**Rescheduled**: same `events.id`, `start_at`/`end_at` updated in place — Interested/Going rows persist automatically (they key off `event_id`, not date). A genuinely separate future occurrence (next year's Preuvenemint) is a new `events` row, never a reschedule of the old one (§8 below explains why for the series case specifically). No new column needed for this — it's a data-entry convention, not a schema concept.

**Series/recurring**: each dated occurrence is an independent `events` row — tickets, attendance, Passport entries, Friends signals, and analytics all differ per occurrence, exactly as the brief states. A parent `event_series` grouping table is explicitly deferred, not designed here — nothing in this phase needs it, and adding it later is a pure-addition migration (a nullable `series_id` column) with zero impact on anything built in this phase.

## 22. Event location, price, category, imagery

**Location** — no schema change (§6.3 already covers this): `events.venue_name`/`address`/`latitude`/`longitude` remain the single source of truth, populated independently of any linked host's own address, always required at event-creation time.

**Price/admission** — `events.admission_type` (`free|paid|mixed|unknown`, existing) and `admission_note` (existing free text) are sufficient for MVP; brief §33 asks for `fixed price / from price / free / paid add-on / sold out / external ticket URL`. Recommendation: do **not** expand `admission_type` into a richer enum yet — `admission_note` already carries "from €X" / "€249 p.p." / "add-on ticket available" as free text today, and a structured price field (`price_amount numeric`, `price_currency char(3)`, `price_unit text check (per_person|per_experience)`) is worth adding only once a real filtering/sorting need exists (§26 MVP sorting doesn't require it). `ticket_url` (existing) plus the new `availability_status` (§20) cover "external ticket URL" and "sold out" respectively. No payments — explicitly out of scope, matching the brief.

**Category vs. descriptors** — `events.event_type` (existing enum: `festival|dinner|tasting|market|experience|other`) stays as the filterable **category** axis, unchanged. Editorial **descriptors** ("SPECIAL LUNCH," "LIVE MUSIC," "LIMITED SEATING," visible in the Club Leroy reference layout, §23) are free text, not a controlled taxonomy — recommend a new nullable `events.descriptor_tags text[]` (array, editorial-authored, never user-filterable) rather than mixing them into `event_type`'s CHECK constraint, matching the brief's explicit "do not mix taxonomy with editorial labels" instruction.

**Imagery** — covered in §11.

## 23. Event Detail product direction

Design only, not implemented. Extends the current, already-editorial `EventDetailScreen` (Events audit §3) rather than replacing its structure:

```
HERO           Club Leroy at Parkheuvel
               SPECIAL LUNCH · LIVE MUSIC · LIMITED SEATING   (descriptor_tags)
               20 September 2026 · Rotterdam · €249 p.p.

INTENT ROW     [ Interested ]  [ Going ]
               4 friends interested · 2 going                (§16 aggregate line)

               [ Tickets ]                                    (existing ticket_url button)

ABOUT          (existing description)

HOSTED BY      Parkheuvel                                     (§6 host resolution)
               Rotterdam
               ★★ Michelin                                    (reads live from Restaurant, never duplicated — existing MichelinAtEventSection precedent, Events audit §3)

DETAILS        date/time · price · ticketing · location        (existing EventMetaSection)

FRIENDS        (existing EventFriendsGoingSection, extended per §16 to also show Interested)

MAP            (new — event's own lat/lon, reuses the same pin/preview-sheet pattern My Map already has)

── after the event has ended ──
ATTENDANCE     Did you make it?  [ Yes ] [ No ]                (§3/§9 prompt, inline on the screen itself
                                                                 as one path into it — not the only path,
                                                                 §18's notification is the other)
```

The one structural change from today: recognition ("★★ Michelin") stays visually and semantically attached to the *host*, never the event — "Michelin recognition belongs to Parkheuvel, not the Event" (brief §8) is already how `MichelinAtEventSection` works today (reads live off `Restaurant.michelinStars`, Events audit §3/§8) and this design changes nothing about that. Marketplace clutter (price comparison, review-count badges, "X sold") is deliberately absent — matches the brief's "keep editorial/high-end" instruction.

## 24. Host profile → Events

Future "UPCOMING EVENTS" section on Restaurant/Hotel/Private Chef Detail — a filtered query against the relevant `event_restaurants`/`event_hotels`/`event_chefs` table joined to `events` where `status = 'upcoming'` and `moderation_status = 'published'`, `is_host`/`is_venue` both irrelevant here (every appearance — host, venue, or plain participant — is worth showing on a venue's own profile; a participating-but-not-hosting restaurant still benefits from the visibility). "PAST EXPERIENCES" (completed events the venue hosted/participated in) is lower priority — recommend building only once "Upcoming Events" itself proves valuable, since a host's *current* activity is the higher-value signal for a returning visitor deciding whether to plan around this venue again.

## 25. Future wineries & bars

Not built in this phase, per explicit instruction. Architecture readiness confirmed by construction, not by any new work: §6.3's per-type join-table pattern extends to `event_wineries`/`event_bars` the moment those catalogues exist, at the identical cost `event_chefs` will cost when it's built (one migration, ~15 lines, zero changes to `events` itself). §15.2's Follow tables extend the same way (`follows_wineries`/`follows_bars`). Apostelhoeve (winery reference) and World's 50 Best Bars guest-shift (bar reference) both validate cleanly against §8's reference-case matrix using only the host/venue/participant model already designed — no bar- or winery-specific schema concept was needed anywhere in this design.

## 26. Event discovery

**MVP sorting** (no recommendation ML, per explicit instruction) — a simple weighted/tiered ordering, not a scored ranking model:

1. Editorially featured (a future boolean/priority column, not built this phase — `event_type`/`moderation_status` alone don't capture "we want this at the top")
2. Followed host (§15.3's query, boosted to the top of the non-featured set)
3. Date proximity (soonest first — matches `EventsRepository.loadEvents`' existing `start_at` ascending order, Events audit §2, unchanged)
4. Availability (`available` before `sold_out`, once §20's column is populated)

**Trip-aware discovery** ("WHILE YOU'RE IN BARCELONA") — query path only, not implemented: identical to `eventsMatchingTrip`'s existing logic (Trips/Passport audit §2 — country-match required, city-match only if both sides specify one, calendar-date overlap), surfaced as a *discovery* entry point (Explore, or a future Trips-tab prompt) rather than only inside Trip Detail's "WHAT'S ON" section as it is today. No new matching logic — a new surface for the same existing pure function.

## 27. Guides / recognition position

Restated from the brief, with one concrete, additive consequence for this design: recognition (MICHELIN/W50B/Gault&Millau, future sources) stays canonical data on Places, continues to be read live wherever it's shown (never copied into any Events V2 table — extends the exact rule `EVENT_PARTICIPANT_ENRICHMENT_STANDARD.md` §9 already established for `event_restaurants`, Events audit §5/§8), and Guides itself is **not removed or restructured** in this phase. The one forward-looking hook this design leaves open: a future Discover filter set (`Michelin | World's 50 Best | Gault&Millau | World's 50 Best Bars`) reads the same live recognition data Event Detail's "HOSTED BY" section already reads — no new recognition storage anywhere.

## 28. Future navigation & information architecture

### 28.1 Target IA

**Option B — Passport · Discover · Events · Trips · Profile** — five top-level tabs, over Option A (Discover · Events · Passport · Trips · Profile). Reasoning: Passport-first matches this app's existing home-tab precedent (Passport is already index 0 today, `lib/app.dart:42-47`, Navigation/RLS audit §1) and the product's own stated identity (*"confirmed personal gastronomic history"* is listed second only after Discover in the brief's own five pillars, §0 — but this app already treats Passport as the returning-user's front door, and nothing in this phase's audit surfaced a reason to relitigate that).

**Correction to this document's earlier draft**: the first version of this section named Trips inside "Option B" 's own five-tab label (Passport · Discover · Events · **Trips** · Profile) but then, in the migration table below it, left Trips' placement "undecided" and never actually gave it a tab slot — an internal contradiction. It's resolved here, in Trips' favor, for two independent reasons that agree: (1) the label this document already committed to literally names Trips as a top-level tab, and (2) the brief's own restated target sketch for this continuation independently arrives at the identical five-name list. **Trips is a full top-level tab in the target IA — this is no longer an open question** (§35 is updated accordingly).

Renamed from "Explore" to **"Discover"** only if that rename is judged worth the churn separately — this document takes no position on the label itself, only the structural changes below.

### 28.2 Current vs. target inventory

| | Today | Target |
|---|---|---|
| Tab 0 | Passport | Passport (unchanged) |
| Tab 1 | Explore | Discover (rename only; Events removed from its nested position, everything else nested inside it today stays nested) |
| Tab 2 | Rankings | **Events** (new top-level tab) |
| Tab 3 | Wishlist | **Trips** (promoted from its current nested position inside Wishlist) |
| Tab 4 | Profile | Profile (unchanged) |
| — | Guides (nested in Explore) | stays nested in Discover — not promoted, not removed (§27) |
| — | Private Chefs (nested in Explore) | stays nested in Discover |
| — | Friends (nested in Profile) | stays nested in Profile — never a top-level tab, explicitly (brief §46, already the de facto behavior) |
| — | Rankings (was tab 2) | becomes a **Passport** sub-entry — "how does my history compare" is closer to Passport's own subject matter than Discover's catalogue-browsing subject matter (brief §45) |
| — | Wishlist (was tab 3) | becomes a **Discover** sub-entry (brief §44) — Places-oriented, belongs beside catalogue browsing, not inside the now-promoted Trips tab it used to contain |

Net effect: two tab slots (2 and 3) change what they point to; tabs 0, 1 (renamed only), and 4 keep their position and identity. No destination is removed — every one of Rankings/Wishlist/Guides/Friends keeps a reachable home, just demoted from top-level to nested, matching the brief's explicit "do not remove any destination simply because the target architecture is known" instruction.

### 28.3 Sequencing — which change happens first, and what must exist before each step

Each step is independently shippable, and **every screen this plan needs already exists today** — this is a navigation-wiring change, not a screens-to-build list:

| Step | Change | Prerequisite screens (already built) | New nav code |
|---|---|---|---|
| 1 | Ship §29's data model + §23's Event Detail redesign, **navigation untouched** | none beyond what already exists | none |
| 2 | Promote Events to a real top-level tab (slot 2, displacing Rankings) | `EventsScreen` (exists today, reached via push — Events audit §3) | `_screens` list in `_MainNavigation` gains `EventsScreen()`; Rankings moves to a Passport sub-entry (a new push destination from `PassportScreen`, not a new screen — `RankingsScreen` itself is unchanged, only what pushes it changes) |
| 3 | Promote Trips to a real top-level tab (slot 3, displacing Wishlist) | `PlannedTripsScreen` (exists today, reached via push from `WishlistScreen` — Trips/Passport audit §3) | `_screens` list gains `PlannedTripsScreen()`; Wishlist moves to a Discover sub-entry (same pattern — `WishlistScreen` itself is unchanged, only what pushes it changes) |
| 4 | Rename "Explore" → "Discover" (label/icon only, if pursued at all) | n/a | one string/icon change |

Steps 2 and 3 are deliberately split rather than shipped together — each swaps exactly one tab slot, so a regression is trivially attributable to one change, not a combined diff. Step 2 is sequenced first because Events' promotion is the brief's own stated primary goal ("Events is no longer secondary"); Trips' promotion (step 3) has no dependency on step 2 and could ship first or be reordered after it without any technical consequence — the ordering here is priority-driven, not dependency-driven.

### 28.4 State preservation (`IndexedStack`)

Today's `_MainNavigation` (`lib/app.dart:39-54`) holds a `static const _screens` list of exactly five widgets inside a single `IndexedStack(index: _index, children: _screens)` — all five screens are built once and kept alive; switching tabs only changes which one is visible, never rebuilds or disposes the others. This mechanism is **unaffected in kind** by steps 2-3 above: the list's *contents* change (which five widgets occupy which index), but the list is still exactly five `const` widgets inside the same `IndexedStack` — scroll position and in-tab navigation stacks (e.g. a pushed detail screen sitting on top of a tab) are preserved exactly as they are today, for whichever five screens end up in the list.

The one real adjustment needed, not a state-preservation risk but a presentation one: `EventsScreen` and `PlannedTripsScreen` are built today assuming they're always reached via `Navigator.push` (Events audit §3, Trips/Passport audit §3) — each likely renders its own `AppBar` with an implicit back button in that context. Moving either into the root `IndexedStack` slot means it becomes a tab root the same way `PassportScreen`/`ExploreScreen` already are — the back button must not render there, matching how every other current tab root already handles this. This is a small, scoped change to each screen's own `AppBar`/`Scaffold` configuration, not a rebuild of either screen.

### 28.5 Deep-linking & routing compatibility

**Confirmed: no deep-linking or named-route infrastructure exists anywhere in this app today** (`MaterialApp.home` is a bare `AuthGate(child: _MainNavigation())`, no `onGenerateRoute`, no `initialRoute`, no `getInitialLink`/`uriLinkStream`/`AppLinks(` call anywhere in `lib/` — verified directly for this continuation). There is therefore **no existing deep-link behavior this migration could break** — this is a genuine non-issue for the current app, not a risk being waved away. If a future universal-link scheme for sharing an Event Detail URL is ever built, it should resolve to "select the correct top-level tab index, then push the detail screen on top of it" — a standard pattern for `IndexedStack`-based navigation — but that is new infrastructure for a feature that doesn't exist yet, not a compatibility concern for this migration.

### 28.6 What must remain untouched until its replacement exists

`RankingsScreen` and `WishlistScreen` themselves are **not modified** by steps 2-3 — only their entry point changes (tab slot → pushed sub-entry). Neither screen's internal implementation, data loading, or tests need to change for this migration; the only new code is the small "sub-entry" push affordance added to `PassportScreen`/the renamed Discover screen respectively, plus removing their old tab-bar entries. Nothing is deleted until its replacement entry point is confirmed working — matching the brief's explicit instruction not to remove a destination simply because the target architecture is known.

No navigation code changes are made in this phase, per explicit instruction — §28.2-28.6 above describe a plan to execute later, not work performed now.

## 29. Database architecture

Every table this design touches, classified `KEEP` (no change) / `MODIFY` (additive column(s)) / `NEW`. Nothing is `DEPRECATE`d — no destructive change anywhere in this design, matching §34's migration-strategy constraint.

| Table | Classification | Change |
|---|---|---|
| `events` | MODIFY | + `moderation_status text not null default 'published' check (in draft/submitted/published/archived/rejected)` (§20); + `availability_status text not null default 'unknown' check (in available/sold_out/unknown)` (§20); + `external_host_name text`, `external_host_url text` (§6.3); + `descriptor_tags text[]` (§22) |
| `event_restaurants` | MODIFY | + `is_host boolean not null default false`, `is_venue boolean not null default false` (§6.3, corrected — replaces the single `role` column from this document's original draft) |
| `event_hotels` | MODIFY | + `is_host boolean not null default false`, `is_venue boolean not null default false` (§6.3) |
| `event_chefs` | NEW | `id, event_id → events cascade, chef_id → private_chefs cascade, is_host boolean not null default false, is_venue boolean not null default false, unique(event_id, chef_id)` — the exact shape already documented in `20260810160000_create_events.sql`'s own comment, plus the two flags (§6.3) |
| `event_attendance` | MODIFY | widen `status` CHECK to `('interested', 'going')` (§9.2) — becomes the **intent** table |
| `event_confirmed_attendance` | NEW | full shape in §9.2, **plus** `converted_from_planned_venue_id uuid references planned_venues(id) on delete set null, unique` (§13, corrected) — the **confirmed history** table |
| `photos` | MODIFY | + `attendance_id uuid references event_confirmed_attendance on delete cascade` (§11) |
| `planned_venues` | MODIFY | widen `entity_type` CHECK to add `'event'` — the one gap `FUTURE_PRODUCT_ARCHITECTURE.md` §3.6 already flagged as "genuinely needed" (Trips/Passport audit §1/§10) |
| `visits` | MODIFY | + `converted_from_planned_venue_id uuid references planned_venues(id) on delete set null, unique` (§13/§14, corrected) |
| `follows_restaurants` | NEW | `user_id → profiles cascade, entity_id → restaurants cascade, created_at, unique(user_id, entity_id)` (§15.2) |
| `follows_hotels` | NEW | same shape, `entity_id → hotels` |
| `follows_private_chefs` | NEW | same shape, `entity_id → private_chefs` |
| `follows` (legacy) | KEEP, untouched | out of scope — a separate, low-priority cleanup (§15.2) |
| `restaurants`, `hotels`, `private_chefs`, `friendships`, `wishlist`, `planned_trips`, `profiles` | KEEP | no change from this design |

## 30. Security

Every new table above fits one of the five existing RLS shapes this schema already uses (Navigation/RLS audit §3) — this design introduces **zero new RLS shapes**:

| New/modified table | Shape | Policy |
|---|---|---|
| `events` (moderation gate) | A′ (gated catalogue, matches `private_chefs`) | `select` gated on `moderation_status = 'published'`, replacing today's unconditional `using (true)` |
| `event_restaurants`/`event_hotels`/`event_chefs` | A (public catalogue) | unchanged — still public-read, service-role-write only |
| `event_attendance` (intent) | C (owner-or-friends via `is_friend()`) | unchanged shape, just a wider legal `status` set |
| `event_confirmed_attendance` | C (owner-or-friends) | new policy, identical shape to `event_attendance`'s existing one |
| `follows_restaurants`/`follows_hotels`/`follows_private_chefs` | B (owner-only, no public/friends read — a user's own follow list is private, §17) | `user_id = auth.uid()` for all of select/insert/delete |
| `planned_venues` (widened) | B (owner-only, unchanged) | no RLS change — only the CHECK constraint widens |

**Published catalogue stays read-only** for every client role — no new broad authenticated `UPDATE` grant anywhere in this design (brief §82's explicit instruction). **Complex transitions use the RPC pattern**, exactly where the friendship precedent's own decision rule says to (Navigation/RLS audit §5): event `moderation_status` transitions (submit/approve/reject) go through `SECURITY DEFINER` RPCs, because the legal transition depends on both current state and caller role — the same condition that put friend-request accept/decline behind an RPC instead of raw RLS. Plain ownership actions (Interested/Going toggle, Follow/unfollow, confirm attendance) stay plain RLS `INSERT`/`UPDATE`/`DELETE`, exactly like `visits`/`wishlist`/`event_attendance` today — no unnecessary RPC overhead for actions with no role-asymmetric rule.

Admin/service-role remains the only writer for `events`/`event_restaurants`/`event_hotels`/`event_chefs` moderation and content fields in this phase — host self-service submission (§19) is designed at the ownership-model level here but its actual RPC is future work, not built now.

## 31. Analytics architecture

**Step 2 update**: the vendor-neutral analytics foundation designed in this section has been implemented (`lib/core/analytics/`) and its operational counterpart, `docs/Architecture/EVENTS_V2_ANALYTICS_CONTRACT.md`, is now the canonical file for "which event to emit, when, with which properties" — this section remains the design rationale; that document is the implementation-facing contract Step 3+ actually works from. Two properties were added during that step, not present in §31.3's original list: `attendance_source` (mirrors `event_confirmed_attendance.source` exactly, needed once the taxonomy was checked against the Step 1 database's own constraint) and `host_count` (needed for correct multi-host attribution, §10 of the contract doc) — both purely additive, nothing below changed meaning.

### 31.1 Product principle

Analytics becomes a first-class capability in this phase (as documentation and architecture only — no SDK is installed, no event is fired, per explicit instruction), oriented around nine goals the brief names verbatim: improving UX, understanding engagement drivers, curating better events, understanding which places/hosts create repeat interest, demonstrating platform value to future host partners, supporting future commercial partnerships, understanding recognition-source value, improving future MICHELIN/W50B/Gault&Millau conversations, understanding city/country demand, and improving Event/Trip recommendations. It must stay privacy-conscious, purpose-limited, first-party, explainable, non-creepy, and structurally separate from product state (§2) — explicitly not an ad-tech surveillance platform.

### 31.2 Canonical event taxonomy

The brief's own draft list (§49) is a reasonable starting vocabulary; auditing it against §2's separation principle and this schema's real states surfaces a few redundancies and one naming inconsistency, corrected below. Final recommended taxonomy, grouped by funnel stage, `snake_case`, past-tense verb for completed actions:

| Category | Events |
|---|---|
| Discovery | `event_impression` *(deferred — see §31.14)*, `event_opened`, `event_search_performed`, `event_filter_applied` |
| Host/Place | `host_profile_opened`, `follow_added`, `follow_removed` |
| Event intent | `event_interested_added`, `event_interested_removed`, `event_going_added`, `event_going_removed` |
| Ticketing | `ticket_link_opened` |
| Attendance | `event_attendance_prompted`, `event_attendance_confirmed`, `event_attendance_denied` |
| Content | `event_rating_added`, `event_photo_added`, `event_comment_added` |
| Trips | `trip_event_added`, `trip_restaurant_added`, `trip_hotel_added`, `trip_review_opened`, `trip_item_confirmed`, `trip_item_rejected` |
| Passport | `passport_item_created`, `passport_item_removed` |
| Friends | `friends_signal_opened` |

Two corrections from the brief's draft list: (1) `event_interested`/`event_going` renamed to `event_interested_added`/`event_going_added` — a bare noun-phrase event name doesn't distinguish state-entry from state-exit at a glance in a dashboard event list, where `_added`/`_removed` pairs sort together and read unambiguously; this is purely a naming-consistency fix, not a new event. (2) `event_rating_updated` from the brief's draft is dropped — a rating on `event_confirmed_attendance` is a single mutable field, and analytics doesn't need to distinguish "first rating" from "changed their mind and re-rated" for any goal in §31.1; one `event_rating_added` fired on every save (create or update) is sufficient and avoids tracking a distinction nobody will query. `followed_host_event_opened`/`notification_opened` (brief's "potential future" list) are correctly left out entirely — Follow and Notifications aren't built yet (§15/§18); naming events for unbuilt features invites exactly the "instrument features that don't exist" anti-pattern §33 warns against.

### 31.3 Context / event properties

Classified `REQUIRED` / `OPTIONAL` / `DO_NOT_TRACK`, evaluated per the brief's own instruction — never include a property merely because it's collectable:

| Property | Classification | Notes |
|---|---|---|
| `event_name` | REQUIRED | the taxonomy value itself |
| `timestamp` | REQUIRED | client-generated, sent with every event |
| `user_internal_id` | REQUIRED (post-login) | `auth.uid()` — never email/name/phone |
| `session_id` | REQUIRED | client-generated per app session |
| `schema_version` | REQUIRED | see §31.10 |
| `entity_id` / `entity_type` | REQUIRED where applicable | the event/restaurant/hotel/chef being acted on |
| `source_surface` | REQUIRED where applicable | §31.6 |
| `source_context` | OPTIONAL | §31.6, only when a more specific reason is known |
| `host_id` / `host_type` | OPTIONAL | only on events where a host is unambiguous (§6) |
| `city` / `country_code` | OPTIONAL | the **event's/venue's** city/country — never the user's location, see below |
| `event_category` | OPTIONAL | `events.event_type` |
| `admission_type` | OPTIONAL | |
| `price_bucket` | OPTIONAL | a coarse bucket (`free/under_100/100_250/over_250`), never the exact `price_amount` if that field is ever added (§22) — coarsening is deliberate, not an oversight |
| `trip_id` | OPTIONAL | only on Trip-funnel events |
| `followed_host` | OPTIONAL | boolean, only on discovery events where relevant to §31.8 |
| `position_in_feed` | OPTIONAL | only where impression-adjacent tracking is actually built (§31.14) |
| `friend_signal_type` | DO_NOT_TRACK as a friend identifier — OPTIONAL as an **aggregate count only** | see §31.9 — never a specific friend's id/name |
| `attendance_source` | REQUIRED on `event_attendance_confirmed` | added Step 2 — mirrors `event_confirmed_attendance.source` exactly (`manual\|post_event_prompt\|trip_completion`) |
| `host_count` | OPTIONAL | added Step 2 — always safe to include when known, regardless of `host_id`/`host_type` being populated; see the contract doc §10 for why a bare single `host_id` is unsafe for multi-host events |
| precise user GPS | DO_NOT_TRACK | §31.7 — city/country of the *content*, never the user's coordinates |
| rating/comment/photo **content** | DO_NOT_TRACK | only the fact that an action occurred, never the payload (§31.9, §31.15) |

### 31.4 Source / attribution taxonomy

Controlled enum, not arbitrary strings — `source_surface`:

`events_feed | event_search | discover | host_profile | friend_activity | trip_recommendation | passport | map | push_notification | deep_link | external_share`

`source_context` (optional, only when more specific than the surface alone): `featured | followed_host | nearby | trip_destination | friend_signal | search_result`.

### 31.5 Attribution model

Funnel is tracked (`event_opened → event_interested_added/event_going_added → ticket_link_opened → event_attendance_confirmed`) but never treated as proof of causation between adjacent steps, per §2's own hard rule and the brief's explicit "avoid fake causality" instruction: a ticket click never implies purchase, Going never implies attendance, attendance never implies ticket conversion. Recommend **session-scoped, last-touch `source_surface`** as the MVP attribution model — the surface the user was on immediately before opening the event — rather than any multi-touch model. First-discovery (the very first surface a user ever saw a given event on, across sessions) is a nice-to-have, not MVP: it requires either a persisted "first seen" record per (user, event) pair or a warehouse join across historical raw events, neither of which is justified before any product decision depends on the distinction (§31.20's stance on premature warehousing applies equally here).

### 31.6 Venue/host value metrics

Recommended venue-facing vocabulary, precisely named to avoid the exact overstatement trap the brief flags (§53):

| Metric | Derived from | Never worded as |
|---|---|---|
| Event views | `event_opened` count | — |
| Interested | `event_attendance` rows, `status='interested'` | — |
| Going | `event_attendance` rows, `status='going'` | — |
| Ticket-link clicks | `ticket_link_opened` count | **never** "tickets sold" |
| Confirmed attendees | `event_confirmed_attendance` row count | **never** "verified attendance" (it's self-reported, not checked-in) |
| Follower count / growth | `follows_*` row count over time | — |
| Average event rating | `event_confirmed_attendance.rating` mean | only once a minimum-count threshold is met (§31.19) |

### 31.7 Partner/recognition value metrics

Aggregate-only, engagement-framed, never redistribution-framed — the brief's own "Users discovered X Michelin-recognized restaurants through Chasing Stars" vs. "We redistributed Michelin's Guide" distinction (§54) is the load-bearing principle here. Concretely: joins between analytics events and the *existing, canonical* `michelin_stars`/award data already on `restaurants`/`hotels` (never a new recognition-specific analytics table) — e.g. "% of `event_opened` events where the host holds current MICHELIN stars," "distinct recognized venues discovered per month." All aggregate, all engagement-side, never anything resembling a usage report *of* Michelin's own data back to Michelin as if redistributing it.

### 31.8 Internal product metrics

Classified North Star / Core / Diagnostic, avoiding vanity metrics (raw open counts, follower totals without a rate) per the brief's explicit instruction:

- **North Star** — see §31.9.
- **Core**: Event → Interested rate, Interested → Going rate, Going → Confirmed Attendance rate, Follow → Event Engagement rate, Trip → Confirmed Experience rate, Passport growth (confirmed items/active user/month).
- **Diagnostic**: Ticket-click rate, Friends-influenced Event Open rate, Repeat Event Engagement (same user, multiple confirmed attendances), Events per active destination, Published Events per active host.

### 31.9 North Star

Recommend **"Monthly Confirmed Experiences per Active User"** (restaurant visits + hotel stays + confirmed event attendances, summed, divided by monthly active users) over a raw "Monthly Confirmed Experiences" count — the per-user denominator is what prevents the metric from rewarding pure volume/lower-quality Event proliferation, directly addressing the brief's own explicit warning (§56). A single North Star is judged useful at this stage specifically because it's the one number that ties Events, Trips, and the pre-existing Passport concept together into one already-comprehensible product story — but it should be revisited once real usage data exists, not treated as permanent.

### 31.10 Identity model

`user_internal_id` = `auth.uid()`, `session_id` = client-generated per app session, merged automatically post-login since every analytics call already happens inside an authenticated session in this app's actual usage pattern (there is no meaningful pre-login browsing surface to instrument — Explore/Events require no auth today, but recommend **not** building anonymous pre-login tracking in this phase: the brief's own instruction is "if not necessary at MVP, say so," and nothing in the nine goals of §31.1 requires distinguishing anonymous sessions before a first login-driven baseline exists). Never email/phone/name as an identifier, anywhere, matching the brief's explicit instruction and this codebase's own existing discipline (RLS keys exclusively off `auth.uid()`, Private Chefs/Follow audit §8).

### 31.11 Privacy

Explicit do-not-track list, matching the brief's §58 verbatim, restated as this document's own binding constraint: no continuous/background user GPS, no contacts, no message content, no free-text review/comment body, no uploaded image contents, no private notes, no exact friend graph sent to a third-party provider, no sensitive inferred traits, no payment data. Location analytics uses event/venue city/country (already a property on `events`, §31.3) never continuous user coordinates; if a future "Near Me" feature is ever built, its precise GPS is never persisted into analytics without a separate, explicit justification pass.

### 31.12 Social analytics privacy

Never `friend_email`/`friend_name` in any payload. `friend_signal_type` (§31.3) is an enum (`interested|going|attended`) describing *what kind* of friend signal preceded an action, never *which* friend — matching the brief's own example (`friend_count_interested = 3` as an aggregate, never a named list) and this codebase's own existing discipline (Friends Going already never sends a friend's identity anywhere outside RLS-gated product queries, Friends audit §7).

### 31.13 Consent / legal readiness

No legal conclusions drawn here, per explicit instruction — architecture only. Recommend treating this phase's entire taxonomy as **product analytics**, not marketing/advertising, and not mixing the two categories into one provider/consent flow (brief §60's explicit instruction). Flagged for future counsel review, not decided here: user-facing transparency requirements (a privacy-policy addition once any provider is chosen), whether product analytics needs its own consent toggle distinct from the account-creation flow, and account-deletion cascade behavior for analytics data specifically (§31.14 covers the retention side of this).

### 31.14 Data retention

Transactional state (`follows`, `event_attendance`, `event_confirmed_attendance`) retained per normal product/account-history rules — no special retention policy beyond what already governs `visits`/`wishlist` today (indefinite, tied to account lifecycle, `ON DELETE CASCADE` from `profiles`). Raw analytics events: recommend a bounded raw-event retention window (a specific number of months is a product/legal decision this document doesn't set) with aggregated/rolled-up metrics retained longer once real aggregation infrastructure exists (§31.20) — explicitly **not** arbitrary forever-retention for raw events, per the brief's own instruction. Account deletion must cascade through analytics identifiers the same way it already cascades through every other user table (`ON DELETE CASCADE` pattern, consistent architecture, exact mechanism depends on the eventual provider choice, §31.15).

### 31.15 Analytics provider strategy

No SDK is installed in this phase. Conceptual comparison only:

| | Fit for this app |
|---|---|
| PostHog | Self-hostable / EU-region cloud option addresses data-residency concerns directly; strong funnel/retention/cohort tooling; Flutter SDK exists; open-source reduces lock-in risk |
| Amplitude | Best-in-class funnel/retention analysis; primarily US-hosted (EU add-on exists but adds cost/complexity); heavier vendor lock-in on export |
| Mixpanel | Similar strength/weakness profile to Amplitude; EU hosting available on higher tiers |
| Supabase-native/custom event table | Zero new vendor, full data ownership/residency by construction, raw-export trivial (it's already Postgres) — but no built-in funnel/cohort UI, meaning the team builds and maintains that tooling itself |
| Privacy-focused alternatives (e.g. Plausible-style) | Excellent for aggregate/pageview-style analytics; generally too shallow for the funnel/cohort/attribution needs in §31.5/§31.8 |

No provider is selected in this document — "evidence is [not yet] sufficient" per the brief's own instruction; a real choice needs a cost/EU-hosting/export-rights comparison this design phase doesn't have the inputs for. The **abstraction layer** in §31.16 is what makes deferring this decision safe.

### 31.16 Analytics abstraction

Recommended shape (design only, no implementation):

```
AnalyticsService.track(event: AnalyticsEvent, properties: AnalyticsProperties)
```

- `AnalyticsEvent` — an enum/sealed class matching §31.2's taxonomy exactly, not a bare string (compile-time typo protection).
- `AnalyticsProperties` — a typed context object matching §31.3's REQUIRED/OPTIONAL property list, not a loose `Map<String, dynamic>`.
- A single provider adapter behind `AnalyticsService` translates to whichever vendor SDK (or Supabase table) is eventually chosen — product code never imports a vendor SDK directly, anywhere. This is what lets §31.15's decision be deferred without cost.

### 31.17 Schema versioning

`schema_version` (§31.3, REQUIRED on every event) — an integer or semver-lite string bumped whenever an existing event name's *meaning* changes materially (not on every taxonomy addition). Governance rule: adding a new event name never needs a version bump; changing what an existing name means always does, and the old meaning is retired under a new name instead wherever feasible, rather than silently reinterpreted (brief §64's explicit "event_interested v1 should not later mean something materially different" instruction).

### 31.18 Event impressions

Recommend **against** impression tracking in MVP. `event_opened` (a detail-screen open) is the highest-confidence, lowest-noise signal already available and sufficient for every §31.1 goal; "50 cards technically loaded" is explicitly the wrong bar per the brief's own instruction, and viewport-visibility-based impression tracking adds real client-side cost/complexity for a signal none of this phase's metrics (§31.8) actually require. Revisit only if a future goal specifically needs feed-position/scroll-depth data — not before.

### 31.19 Unique views / duplicate behavior

`event_opened` is a raw-count event; venue-facing dashboards (§31.6) should report **unique users** (distinct `user_internal_id` per event per period) rather than raw open count, to avoid inflating a host's dashboard through repeated reloads — this is a query-time aggregation choice (`count(distinct user_internal_id)`), not a new tracking mechanism. No promise of perfect person-level attribution is made (a user across two devices double-counts) — acceptable, not solved, matching the brief's own "do not promise perfect person-level attribution" instruction.

### 31.20 Ticket link attribution

`ticket_link_opened` captures `event_id`, `source_surface`, host context (`host_id`/`host_type`), and `session_id`/timestamp (§31.3's standard context) — nothing beyond that. Terminology discipline is the entire architecture here: every venue-facing surface says **"ticket clicks,"** never **"tickets sold"** (§31.6) — no conversion-confirmation mechanism exists without a future official ticketing-partner integration, explicitly out of scope.

### 31.21 Follow analytics

`follow_added`/`follow_removed` (§31.2) — the transactional `follows_*` tables (§29) remain authoritative for "is this user following this entity right now" (§2's rule applied here specifically); analytics answers the adjacent questions the brief names — which profiles/events generate follower growth, whether Follow measurably drives later event engagement (a join between `follow_added` timestamps and later `event_opened`/`event_going_added` events for the same followed host).

### 31.22 Friends influence analytics

`friend_signal_type` context property (§31.3/§31.12) on `event_opened`/`event_interested_added`/`event_going_added` captures *that* a friend signal preceded the action, never *which* friend. Answers "does Friends make Events more useful" (brief §69) without ever identifying a specific friend in the analytics payload.

### 31.23 Trip analytics

Funnel: `trip_event_added`/`trip_restaurant_added`/`trip_hotel_added` → `trip_review_opened` (§3's post-trip flow) → `trip_item_confirmed`/`trip_item_rejected` → `passport_item_created`. "Trip → Confirmed Experience Conversion" (§31.8 Core metric) is exactly this funnel's completion rate. No private trip content (destination, dates, notes) is sent as an analytics property beyond what's already OPTIONAL/coarse in §31.3 (`trip_id`, `city`/`country_code` — the trip's own destination, not the user's location).

### 31.24 Passport analytics

`passport_item_created`/`passport_item_removed` (structural events only) — explicitly **never** review text, private notes, or photo content, per the brief's own instruction and matching this codebase's existing discipline (`visits.notes` is never queried by anything outside the owning user's own RLS-gated reads today).

### 31.25 Data export / future BI

No warehouse is built in this phase — premature per the brief's own instruction. The Supabase-native option in §31.15, if chosen, makes future BI trivial by construction (it's already Postgres — a read replica or scheduled export is sufficient once volume justifies it); a third-party-SDK choice would need a documented export/data-portability guarantee evaluated before commitment, specifically because of this future need. No decision made here beyond "keep this door open," which §31.16's abstraction layer already guarantees regardless of which provider is eventually chosen.

### 31.26 Venue dashboard privacy

Future host-facing dashboards never expose named users — no "which exact user viewed this," no named Interested/Going lists, ever, unless a future feature intentionally exposes a specific social interaction *to the user themselves* (e.g. a host seeing their own event's aggregate stats is fine; a host seeing "Kylan viewed this 4 times" is never fine). Only aggregate counts, trends, and conversion ratios (§31.6) reach any venue-facing surface.

### 31.27 Small-number privacy

Extends the exact ≥5-unique-user k-anonymity threshold `get_event_attendance_count()` already establishes (§17, Friends audit §6 point 6) to every future venue/geographic analytics breakdown — a city/demographic slice with fewer than 5 distinct users is suppressed or coarsened to a broader bucket, never shown as an exact small number, on any future dashboard.

### 31.28 Host event self-management analytics

Once §19's host self-management ships, a host's own dashboard (views/interest/going/ticket-clicks/confirmed-attendance/follower-growth, §31.6/§31.8) requires no analytics identifiers the host manages themselves — every metric derives from `host_id`/`host_type` already present on the event's own host join-table rows (§29), so there's no separate "connect your analytics account" step for a venue, ever.

### 31.29 Analytics data quality

Recommend client-generated idempotency keys (a UUID per fired event, deduplicated provider-side) for any event tied to a state transition (`event_going_added`, `follow_added`) to guard against retry/offline-queue duplicates and double-tap firing — but **not** for every event category; a pure `event_opened` screen-view firing twice on a rebuild is low-cost noise, not worth idempotency-key overhead. Critical conversions (attendance confirmation, follow) are additionally cross-checked against the authoritative database state (§2) rather than trusted from the event stream alone — this is the practical mechanism that makes §2's "analytics is never authoritative" rule actually hold at reporting time, not just in principle.

### 31.30 Server-side vs. client-side events

| Event | Fired from |
|---|---|
| `event_opened`, `event_search_performed`, `event_filter_applied`, `ticket_link_opened`, `host_profile_opened` | Client — inherently a UI action with no reliable server-side equivalent |
| `follow_added`/`removed`, `event_interested_added`/`removed`, `event_going_added`/`removed`, `event_attendance_confirmed` | **Server-side** (a Postgres trigger or an edge function reacting to the authoritative table write) — more reliable than trusting a client to fire after every successful write, and structurally guarantees the analytics event can never fire without the underlying database row actually existing, which is the strongest possible version of §2's separation rule |
| `trip_review_opened`, `passport_item_created` | Client for the "opened" moment (a UI event with no DB row of its own), server-side for `passport_item_created` (mirrors the transactional-write trigger above) |

No event in this taxonomy is fired both client- and server-side for the same underlying action — avoids double-counting by construction, rather than by a dedup step layered on afterward.

### 31.31 Event catalogue performance metrics

Which categories/cities/host-types/price-ranges/friend-engagement-levels perform (brief §78) is answerable entirely from the metrics already defined above (§31.6/§31.8) sliced by `events.event_type`/`city`/host type — no new metric category. Explicit constraint, restated as binding: these metrics **inform** editorial curation (§7); they never **automate** it — no auto-promotion, no algorithmic surfacing based on engagement alone, preserving the brief's own "Chasing Stars remains curated" instruction.

### 31.32 Success-criteria self-audit

Every measurement goal checked against the taxonomy/architecture actually specified above (§31.2-§31.31), with a pointer to what satisfies it — not a rubber stamp. Where a criterion is satisfied only with a scope caveat, the caveat is stated rather than smoothed over, per the instruction to correct the document if anything genuinely fails.

| Can we measure… | Satisfied by | Note |
|---|---|---|
| Event discovery | `event_opened`, `event_search_performed`, `event_filter_applied` (§31.2) | — |
| Event Detail engagement | `event_opened` + whichever downstream event follows it (§31.2/§31.5) | **Scope caveat, not a gap**: this measures "opened, then did X happen" — never sub-screen engagement (scroll depth, which section was read). §31.18 deliberately excludes that granularity from MVP; this is the same decision restated, not a new finding |
| Follow | `follow_added`/`follow_removed` (§31.2/§31.21) | — |
| Interested | `event_interested_added`/`removed` (§31.2) | — |
| Going | `event_going_added`/`removed` (§31.2) | — |
| Ticket intent | `ticket_link_opened` (§31.2/§31.20) | Terminology-disciplined: "clicks," never "sold" |
| Confirmed Attendance | `event_attendance_confirmed`/`denied`/`prompted` (§31.2), backed by the authoritative `event_confirmed_attendance` table (§9/§29) | Analytics event is a behavioral echo of the DB write, never the other way around (§2, §31.30) |
| Friend-influenced discovery | `friend_signal_type` context property (§31.3/§31.22) | Never identifies which friend (§31.12) |
| Trip conversion | Full `trip_*` funnel (§31.23) | — |
| Passport creation | `passport_item_created`/`removed` (§31.2/§31.24) | Structural only, never content |
| Discovery source/attribution | `source_surface`/`source_context` (§31.4), session-scoped last-touch model (§31.5) | Multi-touch/first-discovery explicitly deferred (§31.5), not silently dropped |
| Host performance | §31.6 (views, Interested, Going, ticket-clicks, confirmed attendees, followers, rating) | Precise terminology enforced (§31.6/§31.20) |
| Destination performance | City/`country_code` properties (§31.3), sliced against the metrics above (§31.31) | Answered by slicing existing metrics, not a dedicated named metric — sufficient for every stated goal, called out explicitly rather than implied |

**Without-list audit** — every constraint the brief attached to the measurement goals above, checked against the specific mechanism that enforces it:

| Constraint | Enforced by |
|---|---|
| No invasive tracking | §31.11's explicit do-not-track list (no continuous GPS, no contacts, no message/comment/note/photo content) |
| No unnecessary personal data | §31.3's REQUIRED/OPTIONAL/DO_NOT_TRACK classification — nothing collected "because it could be" |
| Analytics never confused with transactional truth | §2's hard rule, structurally reinforced by §31.29's cross-check requirement and §31.30's server-side-fires-from-the-DB-write pattern for every state-transition event |
| No false ticket-purchase claims | §31.20's mandatory terminology ("ticket clicks," never "tickets sold") |
| No individual users exposed to hosts | §31.26 (aggregate-only venue dashboards) + §31.27 (≥5-user k-anonymity suppression, reusing `get_event_attendance_count()`'s proven precedent) |
| No hard vendor coupling | §31.16's abstraction layer (`AnalyticsService.track`) + §31.15's deliberately deferred, evidence-gated provider choice |

**Result: every criterion is satisfied by the architecture as already specified.** No correction to the analytics design was required by this audit — the one nuance surfaced (Event Detail "engagement" granularity) is a documented MVP scope decision already made deliberately in §31.18, not an unaddressed gap, and is called out above for clarity rather than left implicit.

## 32. Implementation phasing

**Correction to this document's original order**: the first draft sequenced the analytics abstraction as step 4, after Interested/Going (step 2) and Follow (step 3) had already shipped — meaning those two features would have gone out uninstrumented and needed retrofitting. That's backwards relative to what §31's own architecture requires: analytics stays non-authoritative and vendor-agnostic (§2, §31.15-31.16), but the *contract* (taxonomy + `AnalyticsService` abstraction) needs to exist before the first Events V2 user interaction ships, specifically so Interested/Going/Follow are instrumented from their very first release rather than retrofitted. Corrected order (each step still independently shippable/testable, per instruction):

1. **Database foundation** — every `NEW`/`MODIFY` table in §29, additive-only migration(s), backward-compatible with the live `event_attendance` data (§34 covers the exact migration mechanics). *This is the step this document's current pass, Step 1, prepares.*
2. **Analytics abstraction + taxonomy contract** — `AnalyticsService` (§31.16) and the full taxonomy (§31.2), built and ready to call — no vendor selected yet (§31.15 stays deliberately deferred), no events fired yet (nothing downstream exists to fire them from). This now precedes every product feature below, by design.
3. **Interested + Going** — widen the existing Going UI to a two-state toggle (§9), instrumented with `event_interested_added/removed`/`event_going_added/removed` from its first release, using the contract step 2 already built.
4. **Follow layer** — §15's three new tables + minimal UI (a follow button on Restaurant/Hotel/Private Chef Detail), instrumented with `follow_added/removed` from its first release, for the same reason.
5. **Confirmed Attendance → Passport / My Map** — §9's `event_confirmed_attendance` table gets its first real UI (the "Did you make it?" prompt, §3/§23), feeding Passport/My Map (§12); instrumented with `event_attendance_prompted/confirmed/denied` and `passport_item_created`.
6. **Friends Interested + Friends Going** — §16, now that Interested exists as a real state (step 3) to extend the existing Friends Going pattern onto; instrumented with `friends_signal_opened`.
7. **Event Detail V2** — §23, now that every state it needs to render (Interested/Going/Attended/Follow/Friends) actually exists.
8. **Trip completion → Passport** — §3's full flow, extending the pattern step 5 already proved for events onto restaurants/hotels too, using the `converted_from_planned_venue_id` idempotency mechanism (§14, corrected); instrumented with the full trip funnel (§31.23).
9. **Host profile → Upcoming Events** — §24, low-complexity once §6's corrected host/venue/participant model (step 1) is live.
10. **Events-first navigation restructuring** — §28, deliberately kept late among the shippable product steps, per §28.3's own sequencing reasoning (validate the product before touching the IA).
11. **Notifications** — §18, candidate triggers only; real implementation is future work beyond this phasing.
12. **Host submissions / management** — §19/§20's submission RPC and moderation workflow.
13. **Venue-facing aggregate analytics** — §31.6/§31.26-31.28, deliberately last — needs real usage volume (from step 3 onward) before any dashboard number is meaningful, and needs the k-anonymity threshold (§31.27) to have real data to suppress against.

## 33. Analytics implementation phasing

Matches the corrected product phasing (§32) tier-for-tier, with one structural change from this document's original draft: **the taxonomy contract itself now exists as of step 2, before any product event fires** — the table below shows *when each specific event name starts firing*, not when the underlying capability to fire events was built (that's step 2, uniformly, for everything listed):

| Product phase | Analytics added |
|---|---|
| Analytics contract (step 2) | `AnalyticsService` + full taxonomy exist; nothing fires yet — no feature to fire from |
| Interested/Going (step 3) | `event_interested_added/removed`, `event_going_added/removed` — first events to actually fire, from this feature's first release |
| Follow (step 4) | `follow_added`, `follow_removed` |
| Ticketing (already live — `ticket_url` exists today) | `ticket_link_opened` |
| Attendance (step 5) | `event_attendance_prompted`, `event_attendance_confirmed`, `event_attendance_denied`, `passport_item_created` |
| Friends (step 6) | `friends_signal_opened` |
| Trips (step 8) | the full trip funnel from §31.23 |
| Discovery (ongoing, from step 2 onward wherever the relevant screen already exists) | `event_opened`, `source_surface` |

No event fires ahead of the feature that produces it, and — corrected in this pass — no *feature* ships ahead of the contract that instruments it. This table is the binding constraint on §33, not merely a suggestion; "100 meaningless events at launch" (brief §84) is avoided by construction, not by later pruning.

## 34. Migration strategy

**No destructive rebuild, anywhere in this design** — every `MODIFY` in §29 is a pure addition (new nullable/defaulted column, or a CHECK-constraint widening that accepts every value already present in production). Specifically:

- `events.moderation_status` defaults `'published'` — every one of the currently-live events (including 't Preuvenemint, the Tout à Fait link, and any other production rows) stays exactly as visible as it is today, with zero backfill query needed beyond the column default itself.
- `event_attendance.status`'s widened CHECK (`'interested','going'` replacing `'going'`-only) accepts the value every existing row already has (`'going'`) — no data touches, no backfill.
- `event_restaurants.is_host`/`is_venue` and `event_hotels.is_host`/`is_venue` both default `false` — correctly describes the one live relationship (Tout à Fait ↔ Preuvenemint, a plain participant) without any manual correction needed.
- `planned_venues.entity_type`'s widened CHECK is purely additive — no existing row uses `'event'` yet, so nothing existing is affected.
- `visits.converted_from_planned_venue_id` defaults `NULL` — every one of the 5 currently-live visit rows stays exactly as it is, since none of them were created by a trip-completion flow that doesn't exist yet.
- Every `NEW` table (`event_chefs`, `event_confirmed_attendance`, `follows_restaurants`/`follows_hotels`/`follows_private_chefs`) starts empty — no backfill exists because no prior data for these concepts exists anywhere in this schema.

Explicitly preserved, verified against nothing in this design touching them: current Events, Preuvenemint's existing participant link, event attendance rows, Trip↔Event client-side matching (`eventsMatchingTrip`, unaffected since it doesn't read `moderation_status`/`is_host`/`is_venue` at all — those are additive columns the existing function simply never selects), Friends Going, admission fields, URLs, imagery, publication state (there was none before — `moderation_status` is new, defaulting to the most-permissive value so behavior is unchanged).

## 35. Open questions for the product owner

This design phase resolved every architecture question the brief posed with enough evidence to decide confidently. Two genuinely open items remain — flagged rather than guessed at:

1. **Analytics provider choice** (§31.15) — deliberately deferred pending an EU-hosting/cost/export-rights comparison this design phase didn't have the inputs to make; the abstraction layer (§31.16) makes this safe to defer without blocking any other step in §32/§33.
2. **Raw analytics retention window** (§31.14) — a specific number of months is a product/legal call, not an architecture one; flagged for a future pass with counsel input per §31.13.

**Resolved in this continuation pass, previously listed here as open**: Trips' final navigation home. The original draft of §28 named Trips inside "Option B" 's own five-tab label while separately leaving its placement "undecided" in the migration table — an internal contradiction, not a genuine architectural toss-up. It's resolved in §28.1-28.2: Trips is a full top-level tab (slot 3), Rankings and Wishlist both move to nested sub-entries instead.

Nothing else in this document is blocked on a decision outside this document's own scope.
