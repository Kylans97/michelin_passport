# EVENTS V2 STEP 8 — PERSONALIZED DISCOVERY ARCHITECTURE AUDIT

Read-only architecture/UX audit. No Dart code, SQL, migrations, or production data were changed by this document.

## CURRENT EVENTS EXPERIENCE

**What a user sees today**: a single flat, unsectioned, chronological list (`EventsScreen` → `EventsRepository.loadEvents`, default filter `upcoming`, sorted `start_at` ascending). No headings, no "For You," no social proof anywhere on the browse screen. The only non-list content is a filter bar (search + date-mode chips + country) and, when applicable, a single "Did you make it?" post-event attendance-prompt card injected above the list — unrelated to browsing, about a past event the viewer already said they were Going to.

**Ordering**: pure chronology, soonest-first. No personalization whatsoever influences order or inclusion today.

**What's already personalized**: nothing on the browse/discovery surface. Personalization exists only *after* drilling into a specific context: Event Detail shows the viewer's own Interested/Going state and Friends Going/Interested (Step 3/7); Trip Detail shows events matching that one trip's country+dates (pre-existing `eventMatchesTrip`); Passport shows the viewer's own confirmed-attendance history. None of these feed back into the top-level Events browse list.

**What's global/static**: the entire `EventsScreen` list, Explore's "What's On" single-featured-event slot (picks soonest non-cancelled event, `selectFeaturedEvent` — no personalization, not even a real "featured" flag), and Explore's Events search-filter results.

**Where Friends signals show**: Event Detail only (`EventFriendsGoingSection`/`EventFriendsInterestedSection`), never on any card or list.

**Where Trips influence Events**: Trip Detail screen only, via a dedicated "culinary events during your trip" section built from `loadEventsForCountry` + client-side `eventsMatchingTrip` (country, then city-if-known, then inclusive date-range overlap, cancelled events excluded). This is one-directional — Trips look up matching Events, Events never look up matching Trips.

**Where Follow influences Events**: nowhere. `is_host`/`is_venue` are not even read by `EventsRepository.loadLinkedVenues` today (it selects `restaurant_id`/`hotel_id` only) — the columns exist in the schema (Step 1) but have zero Dart consumers anywhere in the codebase as of this audit.

## AVAILABLE RELEVANCE SIGNALS

| Signal | Step 8 MVP? | Reasoning |
|---|---|---|
| A. Friends Going | **Yes** | Strongest, most explainable personal signal; infrastructure already exists (Step 7) |
| B. Friends Interested | **Yes, as enrichment only** | Real signal but weaker than Going (soft intent); should not earn its own top-level section — see FRIEND SIGNALS |
| C. Followed-host events | **Yes, architecturally — expect it to surface nothing today** | The capability should exist now; production currently has zero qualifying events (see FOLLOWED HOSTS DATA REALITY) — building it now means it activates automatically as the catalogue grows, no future migration needed |
| D. During an Upcoming Trip | **Yes** | Matching logic already exists and is proven (Trip Detail); uniquely high-actionability signal — the user will physically be there |
| E. Geographic relevance (device location) | **No — defer** | No permission flow exists; audit explicitly warns against assuming device location; Trip destination is the safer, already-available substitute (see LOCATION) |
| F. Event date / soon | **Yes, as ranking tiebreaker, not a section** | Chronology already works; formalize as deterministic time-decay within relevance tiers |
| G. Anonymous member Going count | **Yes, as a coarse popularity band only** | Numeric ranking on a 0-2-user platform would be meaningless and could look broken; a band (none/some/popular) is honest at any scale |
| H. Editorial/featured | **No — defer a stored field** | No field exists; current curated, quality-controlled ingestion + chronology is sufficient at 4-events scale; revisit once concurrent live events regularly exceed what chronology alone can differentiate (see EDITORIAL) |
| I. Event category/type | **No — not as a filter/section** | Real enum exists (6 values, 3 currently used) but is not surfaced on any card today and catalogue depth doesn't justify a new filter chip yet; may appear as light card context text only if it ever needs to justify a ranking decision (it doesn't currently) |
| J. "At this event" participants | **No, explicitly excluded from ranking** | Participant/venue-only links must never imply relevance the way a *host* link does — using them would violate the host/venue/participant separation Steps 1–7 deliberately built |

## RECOMMENDED PRODUCT HIERARCHY

**Do not build the suggested section stack (FOR YOU / FRIENDS ARE GOING / FROM PLACES & CHEFS YOU FOLLOW / DURING YOUR TRIPS / TRENDING / DISCOVER / UPCOMING) as literal parallel horizontal sections.** Reasoning: production has exactly **4 events total**. Every proposed section would render 0–1 cards. A page with six mostly-empty section headings is worse than today's plain list — it reads as broken, not curated, and cannot avoid either (a) showing the same 1–2 qualifying events repeated across multiple sections, which §14 explicitly forbids, or (b) hiding sections down to nothing, which leaves the page looking sparse and unfinished for *every* user, not just cold-start ones.

**Recommendation: one single, deduplicated, ranked list — no section headers at all for MVP** (the existing chronological `EventsScreen` list, now re-ordered by relevance and annotated with at most one small "why" badge per card). This is not "no personalization" — it's personalization expressed as ranking + a one-line reason, not as page structure. It satisfies §5's explainability requirement (the badge *is* the explanation), §14's deduplication requirement (one placement per event, full stop, by construction — there is no second section to duplicate into), and §19's cold-start requirement (a user with zero signals simply gets today's exact chronological list back, with no badges — the *same screen*, not a degraded fallback view).

Sections become worth building only once the catalogue is deep enough that a single ranked list would bury genuinely different discovery intents (e.g., dozens of concurrent events across many cities) — explicitly a **post-MVP, catalogue-depth-triggered decision**, not a Step 8 one.

This does not touch Trip Detail's own existing "during your trip" section (unrelated screen, already correctly scoped, left alone) or Explore's existing "What's On" single-card slot (unrelated screen; could later read the same ranking, not required for Step 8).

## FRIEND SIGNALS

**Going > Interested, enforced structurally, not just by ordering.** Recommendation: Friends Going is a genuine relevance tier of its own (a card whose strongest reason is "N friends going" ranks above one whose strongest reason is "N friends interested"). Friends Interested never earns a card's *primary* badge if a stronger reason (Trip, Friend Going, Followed host) also applies to that same event — it only becomes the primary badge when it's the strongest signal available for that card. Neither gets a dedicated horizontal section (see above). No identity is ever shown beyond what Event Detail's existing RLS-gated Friends sections already permit — the discovery list itself only ever needs *counts* ("2 friends going"), never names, so it can reuse `EventAttendanceRepository.getVisibleUserIds` counts without needing to resolve full `Friendship` objects for the list view at all (a meaningful performance simplification — see QUERY ARCHITECTURE).

## FOLLOWED HOSTS

**Confirmed the current schema and RLS already support this safely, no new table, no RLS change.** `event_restaurants`/`event_hotels`/`event_chefs` all carry `is_host boolean` and are fully public-read (`qual: true` on all three, re-verified live). `follows_restaurants`/`follows_hotels`/`follows_private_chefs` are owner-only RLS (`user_id = auth.uid()`, re-verified in Step 6/7). A query joining "my follows" (own rows only, RLS-enforced) against "public host links" (public data) leaks nothing — it can only ever return events hosted by entities *this* user already follows.

**Smallest query architecture — reasoned, not assumed**: a dedicated `SECURITY DEFINER` RPC is **not required for security** here (unlike the Step 7 member-count RPC, which needed to bypass RLS to count *other* users' rows — this query never needs to see anything but the caller's own follows plus already-public data). The real question is only performance/simplicity. Recommend **Dart-side composition for MVP**: reuse `FollowRepository`-style id lists (or a new tiny batched method) to fetch the caller's own followed restaurant/hotel/chef ids (short-circuiting to an empty result with zero query cost when a user follows nothing, mirroring `EventsRepository.loadLinkedVenues`'s existing empty-list short-circuit), then one `.eq('is_host', true).inFilter(...)` query per entity type against the already-public `event_restaurants`/`event_hotels`/`event_chefs` tables, then resolve the matched event ids via the existing `loadEvents`-style batched fetch. Bounded, never per-event, never per-follow — same shape as every other batched repository method in this codebase. **A single SQL view/RPC becomes the better choice only once follow-graph and catalogue scale grow enough that collapsing 3–7 round trips into 1 clearly matters** — an explicit future optimization, not a Step 8 requirement.

## VENUE VS HOST VS PARTICIPANT

No current data violates the intended semantics (re-verified live): the one existing `event_restaurants` row (`'t Preuvenemint` ↔ its restaurant participant) has `is_host = false, is_venue = false` — a bare participant link, exactly as documented in the Step 5 audit ("Tout à Fait is NOT the venue"). `event_hotels`/`event_chefs` are currently empty. Nothing today incorrectly marks a participant as a host. The discovery ranking logic must — and per this design does — read `is_host = true` exclusively for the "followed host" signal, never `is_venue` or bare participation, preserving the separation Steps 1–7 established.

## TRIP PERSONALIZATION

**One combined reason per qualifying event, not a dedicated Trips section on the Events screen** — reuse the existing, already-correct `eventMatchesTrip` function as the underlying test, applied per-event against the viewer's own upcoming trips (owner-only data, never another user's). For 0 trips: no trip-based badge ever appears, no cost. For 1 trip: straightforward. For multiple upcoming trips: an event can in principle match more than one trip (e.g., two trips to the same city with overlapping windows) — recommend the badge always names the *soonest* matching trip only ("During your Maastricht trip, 26–31 Aug") rather than listing all matches, keeping the card clean; this is a presentation choice, not a ranking one (the event still only gets ranked once). This event-owns-one-reason design also directly prevents the duplicate-card risk the task calls out explicitly for users with multiple trips.

## LOCATION

**Do not request device location for Step 8.** Ranked, in order of usefulness-to-privacy-cost: (1) an upcoming Trip's destination (already fully available, zero new permission, directly reuses existing Trip data); (2) Passport history's most-visited country/city (available, zero new permission, weaker signal — past behavior, not future intent); (3) an explicit user-selected "home city/country" (does not exist today — would need a new profile field, a real but small future addition, still zero device permission); (4) device GPS location (highest complexity, highest privacy cost, an explicit permission prompt, and the audit found no existing permission-request infrastructure for it anywhere in this codebase). **Recommended Step 8 signal: Trip destination only** — it's the only one that's both available today and directly tied to near-term actionability (you're actually going to be there).

## POPULARITY

**Recommend a 3-band signal, never the raw number, for ranking purposes**: `none` (0), `some interest` (1–thresholdN, e.g. 1–4), `popular` (thresholdN+ — could reuse Step 7's own capped RPC output directly, since `1–99` is already exact and `100` already means "100 or more"). This directly avoids two problems: numeric ranking would be noise at current real-world scale (production's real Going counts today are 0 or 1 — see PRODUCTION DATA QUALITY), and it correctly treats the capped `100` sentinel as "at least this popular," never as a literal, more-precise-than-it-is number for sorting purposes. A `popular` badge should only ever be the primary reason on a card when no stronger personal signal (Trip/Friend/Follow) applies — this is deliberately the *weakest* tier in the hierarchy, existing mainly so a brand-new user with zero personal signals still sees *some* differentiation instead of pure chronology forever.

## EDITORIAL / FEATURED

**No new field needed for Step 8.** Confirmed no `featured`/`priority`/`pinned` column exists; the closest related field, `moderation_status` (added Step 1, `draft|submitted|published|archived|rejected`, default `published`, RLS-enforced), is a publish gate, not a ranking signal, and is correctly left untouched here. Explore's current "featured" slot is entirely computed (soonest upcoming event) — not a stored editorial decision. At 4 total events, chronology plus quality-controlled ingestion (every live event was manually vetted before publishing, per this project's existing content pipeline) is sufficient — there is nothing for an editorial-priority field to meaningfully differentiate yet. **An explicit editorial-priority field becomes justified once the team needs to manually promote a specific event above what deterministic ranking alone would produce** (e.g., a major gala the team wants visible above a same-week smaller tasting despite lower Going/Trip signal) — a real future need, but not today's.

## EVENT CATEGORIES

**Current model is sufficient — no taxonomy change.** `EventType` (`festival|dinner|tasting|market|experience|other`) already exists, is small, and is not currently a bottleneck (only 3 of 6 values are in production use, and it isn't surfaced on any discovery card today). Do not add a category filter chip or expand the taxonomy for Step 8 — there's no evidence of need (4 events, 3 distinct types already). Confirmed "AT THIS EVENT" remains entity-neutral (participant display, not a category system) and MICHELIN recognition remains separate recognition metadata never conflated with `EventType` — both already correctly separated, nothing to change.

## DEDUPLICATION

**One primary placement per event, full stop — enforced by the "single ranked list, no sections" architecture itself**, not by a separate dedup pass bolted onto a multi-section design. Each event is scored once, assigned exactly one strongest-reason badge, and appears exactly once in the list. Additional qualifying reasons (e.g., a Trip match *and* 2 friends going *and* a followed host) are deliberately **not** stacked as multiple badges on one card — recommend showing only the single strongest reason, keeping cards visually calm (§17); a card overloaded with 3 badges reads as busy, not premium, and the task's own worked example under §14 already shows exactly one secondary line, not several. If product later wants a compact secondary context line, it should be added deliberately, not defaulted to.

## RELEVANCE PRIORITY

Reasoned (not accepted verbatim), final recommended hierarchy, strongest first:

1. **During an imminent/matching Trip** — uniquely strong because it reflects *certain future presence*, not just interest; the user has already committed travel plans that make this event trivially attendable.
2. **Friend Going** — the strongest personal social-proof signal available; someone the user explicitly trusts has committed to attend.
3. **Followed host** — a deliberate, standing taste/curation signal the user themselves created (following is an active choice, unlike being nearby or seeing a friend's activity).
4. **Friend Interested** — real but soft; interest frequently doesn't convert to attendance, so it should never outrank a host the user actively follows or a friend who's actually committed.
5. **Popularity band** — anonymous, generic; useful mainly as a cold-start floor signal, not a strong personal reason.
6. **Chronological / time decay** — always active as the tiebreaker within and beneath every tier above, and as the *entire* ranking for a user with none of tiers 1–5.

## TIME DECAY

Keep deterministic, no ML: within each relevance tier above, sort soonest-`start_at`-first (unchanged from today). Recommend one small addition: a light "happening soon" boost (e.g., events starting within the next 7 days) that can pull an otherwise-tier-6 (pure chronological) event slightly ahead of a lower-tier-but-more-distant one *within the chronological baseline only* — never allowed to outrank tiers 1–5. This keeps the system fully explainable ("soon" is a fact anyone can verify by looking at the date) and avoids the aggressive, hard-to-explain decay curves a scoring-model approach would introduce.

## EVENT CARD UX

**Do not add every available element to every card.** Recommended priority (already-present elements stay; the one addition is the relevance badge):
1. Image (existing — see IMAGERY for the real gap here).
2. Title (existing).
3. Date (existing).
4. City (existing).
5. Free/Paid badge (existing).
6. **One relevance badge, when a signal applies** ("2 friends going" / "From a chef you follow" / "During your Maastricht trip" / "Popular with members") — the only new element, and only ever one at a time (see DEDUPLICATION).

Explicitly **not** added to the card: exact member-Going count (the band language, "popular with members," is enough — a number would read as a metric, not a feeling), event-type label (no evidence of need per EVENT CATEGORIES), and participating-entities list (belongs on Event Detail's own "AT THIS EVENT," not a discovery card — cards should stay scannable).

## IMAGERY

**Architectural gap, not a Step 8 blocker, but directly limits how good personalized discovery can look.** Confirmed live: **0 of 4 production events have `image_url` set.** Every card today already degrades gracefully to `CsImagePlaceholder` — so nothing breaks — but a discovery experience specifically designed to feel "curated and alive" is undercut by four consecutive placeholder tiles. This reinforces the project's own prior direction (event imagery should come from legitimate event/organizer sources, not scraping) — flagged here as a content-pipeline gap the personalization work depends on for its intended feel, not something Step 8's own code should attempt to solve.

## COLD START

New user (0 friends, 0 follows, 0 trips, 0 attendance history): every relevance tier above chronological returns nothing for every event; the ranked list collapses to exactly today's existing chronological order, badge-free. This is the direct, load-bearing reason the "single list, no empty sections" architecture was chosen over the section-stack — there is no empty-heading state to design around, because there are no headings. An existing user with real friends/follows/trips sees the identical list mechanism simply produce a different (personalized) order with badges. One codepath, two outcomes, by construction.

## QUERY ARCHITECTURE

**Hybrid, reasoned per signal — not one option applied uniformly**:
- **Friends Going/Interested counts**: reuse `EventAttendanceRepository.getVisibleUserIds` per status, but only *counts*, not resolved `Friendship` objects, for the list view — cheaper than Event Detail's own full friend-resolution, appropriate since the list never shows names.
- **Followed hosts**: Dart-side composition (see FOLLOWED HOSTS) — bounded, batched, no RPC needed for MVP.
- **Trip matching**: reuse `eventMatchesTrip` exactly as Trip Detail already does — pure function, already proven, zero new query shape.
- **Popularity band**: reuse the existing Step 7 `get_event_going_member_count` RPC, one call per event under consideration (bounded by the finite upcoming-events list, never per-user).
- **Base event list**: reuse `EventsRepository.loadEvents` exactly as today.

None of this is one query per event, one query per friend, or one query per followed entity — every piece is either already batched (existing repositories) or newly bounded-batched (followed hosts). All independent pieces (friends counts, followed-host ids, trip list, popularity per visible event) should be started together and awaited in turn, mirroring this codebase's established "start together, await in turn" convention (Event Detail's own `_load()` already does exactly this for its five-way parallel load). At today's scale (4 events, near-zero social graph) total cost is trivial; at hundreds of events this remains bounded because every join is against the *viewer's own* small follow/friend/trip lists, never against the full event catalogue per-signal.

## SECURITY / PRIVACY

Every signal re-confirmed to stay inside its existing trust boundary — nothing proposed here weakens or bypasses any RLS policy re-verified live during this audit:
- **Friends**: identity (names/avatars) never appears on a discovery card — only counts, and only counts of rows RLS already permits the viewer to see (`event_attendance_select`'s existing `is_friend()` gate, unchanged).
- **Member Going count**: unchanged from Step 7 — anonymous, capped, identity-free.
- **Follow**: read only as the caller's own rows (`follows_*` RLS unchanged, owner-only) — never another user's follow graph.
- **Trips**: read only as the caller's own `planned_trips` rows — never another user's travel plans.
- No proposed query joins across users in a way that could expose another user's trips, follows, or non-friend attendance identities — every cross-entity join in this design is either against fully public data (`events`, `event_restaurants`/`hotels`/`chefs`) or the caller's own private rows, never another user's private rows.

## ANALYTICS

**No taxonomy gap — the existing contract already anticipates this exact step.** Re-confirmed live in `analytics_properties.dart`: `AnalyticsSourceSurface` already has `eventsFeed`/`discover`/`tripRecommendation` (perfect fits for "the personalized Events landing page" and "opened from the What's On/Trip-matched surface"); `AnalyticsSourceContext` already has `featured`/`followedHost`/`tripDestination`/`friendSignal`/`searchResult` — literally the Step 8 relevance-reason vocabulary, defined back in Step 2 and unused ever since (the same "documented ahead of implementation" pattern already found repeatedly in this project). **Recommend zero new analytics events/properties.** When Event Detail is opened from the new ranked list, wire the already-existing `sourceSurface`/`sourceContext` values through to whichever badge/reason won that card's placement — this is wiring an existing, already-approved vocabulary, not inventing one. Rendering the list itself (or any badge) should fire nothing, matching this project's consistent "passive rendering is not a trackable action" principle; only the resulting open/tap is worth attributing. No friend identity, no trip destination detail beyond the existing coarse `AnalyticsProperties.city`/`countryCode` fields, no exact member count ever belongs in a payload.

## WEB READINESS

Ranking logic (the relevance-tier ordering, time-decay tiebreak, badge selection) should live as **pure Dart domain functions** (repository/domain layer), not embedded in widget `build()` methods — directly mirroring `eventMatchesTrip`/`resolveIntentTap`/`visibilityForIntent`'s own established "pure, testable, framework-independent" pattern in this codebase. This keeps the actual business rule (what makes an event relevant, and in what order) reusable by a future web client without duplicating logic in two languages, while the underlying *data* (friends counts, follow ids, trip matches, popularity) is already fetched via the same Supabase client API that already works identically across platforms. Nothing here requires server-side ranking to be shareable — the rule itself is small and deterministic enough to stay client-side and still be trivially portable to a Dart-for-web or a future TypeScript reimplementation of the same documented rule.

## PRODUCTION DATA QUALITY

Read-only, re-verified live:

| Metric | Value |
|---|---|
| Total events | 4 |
| Upcoming | 4 |
| Completed | 0 |
| Cancelled | 0 |
| Coordinate coverage | 3 / 4 (Erloom × Henrique Sá Pessoa remains `MANUAL_REVIEW`, per Step 5) |
| Image coverage | **0 / 4** |
| Host-link coverage (`is_host=true` anywhere) | **0** (`event_restaurants`: 1 row, `is_host=false`; `event_hotels`: 0 rows; `event_chefs`: 0 rows) |
| Venue-link coverage (`is_venue=true`) | 0 |
| Participant-link coverage (any row) | 1 (`event_restaurants` only) |
| Admission data coverage | 4 / 4 |
| Ticket URL coverage | 4 / 4 |
| Availability-status coverage | 4 / 4 (column exists, unread by Dart today) |
| Descriptor-tags coverage | 0 / 4 |
| External-host coverage | 0 / 4 |
| Event type distribution | dinner: 2, tasting: 1, festival: 1 (market/experience/other: 0) |

This dataset is real but very small — every design recommendation above was deliberately calibrated against these actual numbers (e.g., the "no sections, single list" decision, the "band not number" popularity decision) rather than an assumed larger catalogue.

## CURRENT PERSONALIZATION COVERAGE (DATA REALITY)

Read-only, re-verified live, counts only:

- **Accepted friendships**: **0** — Friends Going/Interested have no organic data to surface today; the *architecture* is ready (Step 7), but production cannot currently exercise it for any real pair of users.
- **`event_attendance` rows**: 1 Going, 0 Interested.
- **Follow rows**: `follows_restaurants` 1, `follows_hotels` 0, `follows_private_chefs` 0.
- **Followed-host qualification** (direct join, re-verified live): **zero** production events currently qualify for "from a host you follow" — the one existing follow does not point at a host-linked entity for any event (the one `event_restaurants` row has `is_host=false`, and no hotel/chef host links exist at all). This will activate automatically once (a) a real host relationship is recorded with `is_host=true`, and (b) that same entity has a follower — no code or migration change is needed for it to start working the moment both conditions exist.
- **Trips**: 3 `planned_trips` rows exist; 1 has a country matching at least one live event's country (coarse check only — city/date-window overlap not separately verified here to avoid exposing more trip detail than a count requires, per the task's own instruction).

**Bottom line**: today's production data can exercise the Trip signal (weakly) and nothing else — Friends and Follow signals are architecturally complete but organically empty. This is expected pre-launch reality, not a defect, and is the central reason the "graceful collapse to plain chronology" design (COLD START) is the load-bearing requirement of this whole audit, not an edge case.

## MIGRATION DECISION

**NO — Step 8 MVP requires no migration.** Every signal recommended for MVP (Friends Going/Interested counts, followed-host query, Trip matching, popularity band, chronology/time-decay) reads from tables, columns, functions, and RLS policies that already exist and were already re-verified live during this audit: `event_attendance` + `is_friend()`, `follows_restaurants`/`follows_hotels`/`follows_private_chefs`, `event_restaurants`/`event_hotels`/`event_chefs.is_host`, `planned_trips`, and the Step 7 `get_event_going_member_count` RPC. The deferred signals (device location, editorial-priority field, event-category filtering) are exactly the ones that would eventually need new schema/columns — correctly excluded from MVP scope precisely because they're not needed yet, not because they're impossible.

## RECOMMENDED STEP 8 MVP

- **Sections**: none — one unified, ranked, deduplicated list, replacing today's plain chronological `EventsScreen` list in place.
- **Ordering**: the 6-tier relevance hierarchy above, soonest-first within each tier, with a small "happening within 7 days" nudge inside the chronological baseline only.
- **Ranking mechanism**: deterministic, explainable, pure-Dart scoring — no black box, no ML.
- **Duplicates**: structurally impossible — one placement per event, one badge per card (the strongest applicable reason only).
- **Signals implemented now**: Friend Going count, Friend Interested count (enrichment-tier only), followed-host (architecturally live, currently dormant), Trip-window match, popularity band, chronology/time-decay.
- **Signals explicitly deferred**: device location, editorial/featured field, event-category filtering, exact numeric popularity, multi-badge cards, per-signal horizontal sections.
- **Cold-start user**: sees exactly today's existing chronological list, badge-free — no degraded state, no empty headings, because there are no headings.

## IMPLEMENTATION PLAN

- **8A — Discovery domain model**: pure Dart types/functions for a relevance "reason" (enum + optional context, e.g. friend count, trip label) and the scoring/ranking function itself — directly unit-testable with fixtures, no Supabase, mirroring `event_trip_match.dart`'s own existing shape.
- **8B — Followed-host query**: the small batched Dart composition described under FOLLOWED HOSTS, independently testable against fixture ids (repository layer only — no live Supabase needed for the composition logic itself, only for the final PostgREST calls).
- **8C — Personalized list wiring**: `EventsScreen` (or its data layer) assembles the parallel signal fetches, feeds 8A's ranking function, renders the existing `EventCard` plus the one new badge slot.
- **8D — Deduplication/tie-break polish**: verify multi-trip, multi-signal, and boundary cases (exactly two tiers producing the same score, etc.) against 8A's pure function — cheap to get right early since it's pure and testable before any UI exists.
- **8E — Analytics wiring**: attach the already-existing `sourceSurface`/`sourceContext` values to Event Detail navigation originating from the new list — no new taxonomy, pure plumbing.
- **8F — Physical-device review**: visual/perf pass once real (or realistically-seeded, non-production) data is available to exercise more than the current single-friend/single-follow reality.

Each slice is independently testable before the next begins, and 8A/8B/8D can be fully built and tested without touching `EventsScreen` at all.

## VALIDATION

- `flutter analyze` — 0 issues.
- `flutter test` — **1367 passed**, 0 failed (current baseline, unchanged by this audit).
- `supabase migration list --linked` — all 36 migrations, local == remote, unchanged.
- `supabase db push --linked --dry-run` — `"upToDate": true`, zero pending migrations.
- `git status --short` — only pre-existing unrelated Michelin/Gault&Millau artifacts untracked; nothing staged (`git diff --cached` empty).

## DATABASE

Migrations created by this audit: **0**. Schema changes: **0**. Production writes: **0** — every query run was read-only (`SELECT`/`information_schema`/`pg_policies`).

## FILES

New: `docs/Architecture/EVENTS_V2_STEP_8_PERSONALIZED_DISCOVERY_AUDIT.md` (this document) — **not staged, not committed**. No other file created, modified, or deleted.

## GIT

Not staged. Not committed. Not pushed.

## NEXT

Recommended first implementation slice: **8A — the discovery domain model/relevance-reason ranking function**, since it is pure, fully unit-testable without any UI or live data, and both 8B (followed-host query) and 8D (deduplication polish) depend on its shape being settled first.

---

## EXPLICIT ANSWERS

1. **What should the Events landing page look like for an active user (friends/follows/trips present)?** The same visual list as today, reordered by relevance, with at most one small badge per card ("2 friends going" / "From a chef you follow" / "During your Maastricht trip" / "Popular with members") — no new section headings.
2. **What should it look like for a brand-new user?** Identical screen, same code path, simply producing today's exact plain chronological order with no badges — not a distinct "empty" design.
3. **Which signal is strongest: Trip, Friend Going, Followed Host, Friend Interested, or popularity?** Trip (imminent, certain future presence), then Friend Going, then Followed Host, then Friend Interested, then popularity — reasoned in RELEVANCE PRIORITY.
4. **Should one Event ever appear in multiple sections?** No — there are no sections in the MVP design; each event gets exactly one placement in the single ranked list, by construction.
5. **How should multiple relevance reasons be represented?** Only the single strongest reason is shown as a badge; other qualifying reasons are computed but not displayed, keeping cards calm and unambiguous.
6. **Can "From hosts you follow" be implemented safely with the current schema?** Yes — no RLS change, no new table; `event_restaurants`/`event_hotels`/`event_chefs` are public-read and `follows_*` are already owner-scoped, re-verified live. It will simply return nothing until real host-organized, followed events exist in production.
7. **Does Step 8 MVP require a migration?** No.
8. **What is the recommended query architecture?** Hybrid: reuse existing batched repository methods per signal (Friends counts, Trip matching, popularity RPC), plus one new small batched Dart-side composition for followed hosts — no new RPC needed for MVP; a single SQL view/RPC is a documented future optimization once scale justifies it.
9. **Which personalization signals should be deferred?** Device location, an editorial/featured field, event-category filtering/taxonomy expansion, exact numeric popularity display, multi-badge cards, and per-signal horizontal sections.
10. **What exact implementation slice should we build first?** 8A — the pure Dart discovery domain model and relevance-ranking function, independently testable before any UI or query wiring exists.

---

EVENTS V2 STEP 8 —
PERSONALIZED DISCOVERY ARCHITECTURE AUDITED,
READY FOR HUMAN PRODUCT REVIEW
