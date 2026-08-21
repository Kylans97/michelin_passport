# EVENTS V2 STEP 6 — FOLLOW ARCHITECTURE AUDIT

Read-only architecture audit. No Dart code, migrations, or production data were changed by this document.

## CURRENT DATABASE

All three follow tables already exist in production, deployed by the Step 1 database foundation, and re-verified live via `supabase db query --linked` for this audit:

| Table | Columns | PK | FK | Unique | created_at |
|---|---|---|---|---|---|
| `follows_restaurants` | `id, user_id, restaurant_id, created_at` | `id` | `user_id → profiles(id) ON DELETE CASCADE`; `restaurant_id → restaurants(id) ON DELETE CASCADE` | `(user_id, restaurant_id)` | yes, `now()` default |
| `follows_hotels` | `id, user_id, hotel_id, created_at` | `id` | `user_id → profiles(id) ON DELETE CASCADE`; `hotel_id → hotels(id) ON DELETE CASCADE` | `(user_id, hotel_id)` | yes, `now()` default |
| `follows_private_chefs` | `id, user_id, private_chef_id, created_at` | `id` | `user_id → profiles(id) ON DELETE CASCADE`; `private_chef_id → private_chefs(id) ON DELETE CASCADE` | `(user_id, private_chef_id)` | yes, `now()` default |

Secondary indexes exist on each entity-id column (`follows_restaurants_restaurant_idx`, `follows_hotels_hotel_idx`, `follows_private_chefs_chef_idx`) in addition to the unique-constraint indexes — a "how many people follow entity X" query is already index-backed if it's ever built later (see FOLLOW COUNTS below; not proposed now).

**One follow per user/entity pair**: guaranteed by the `unique(user_id, entity_id)` constraint on each table — a duplicate `INSERT` fails with `23505`, the same idempotency shape as `wishlist`/`event_confirmed_attendance`.

**Deleting a Restaurant/Hotel/Private Chef**: `ON DELETE CASCADE` on the entity FK — the follow row is removed automatically, never orphaned, never blocks the parent delete.

**Deleting a user**: `ON DELETE CASCADE` on `user_id → profiles(id)` — same guarantee.

**Timestamps**: `created_at` already exists on all three tables (`now()` default, `NOT NULL`). Step 6 needs it for exactly one purpose — ordering a future "Following" list newest-first, the same convention `visits`/`event_confirmed_attendance` already use — and it's already present, so no migration is needed for it.

**Production row counts today**: all three tables are empty (0 rows) — expected, since no Dart code writes to them yet.

**DOES STEP 6 REQUIRE A DATABASE MIGRATION? NO.** The schema, constraints, indexes, and RLS (below) are already fully deployed and already satisfy every MVP requirement. Step 6 is a pure Dart/UI implementation on top of existing infrastructure.

## RLS / PRIVACY

RLS is enabled on all three tables. Policies (identical shape across all three, re-verified live via `pg_policies`):

| Table | SELECT | INSERT | DELETE | UPDATE |
|---|---|---|---|---|
| `follows_restaurants` | `user_id = auth.uid()` | `with check (user_id = auth.uid())` | `user_id = auth.uid()` | none |
| `follows_hotels` | `user_id = auth.uid()` | `with check (user_id = auth.uid())` | `user_id = auth.uid()` | none |
| `follows_private_chefs` | `user_id = auth.uid()` | `with check (user_id = auth.uid())` | `user_id = auth.uid()` | none |

**Users can only create their own follows**: yes — `INSERT ... with check (user_id = auth.uid())` rejects any insert where `user_id` isn't the caller's own id.
**Users can only remove their own follows**: yes — `DELETE` policy is scoped identically.
**Follows are private to the owner / another user cannot query who I follow**: yes — `SELECT` is scoped to `user_id = auth.uid()` with **no `friends`/public tier at all**, unlike `visits`/`event_confirmed_attendance` (which both support an opt-in `friends` visibility). Follow has no visibility column and no path to a broader tier.
**No UPDATE policy exists on any table** — correct and intentional: a follow row has nothing mutable (no visibility, no note); the row's mere existence is the entire signal, so create/delete are the only two meaningful operations.

**Audited leak paths**: none found. No other table's RLS policy, view, or function references `follows_restaurants`/`follows_hotels`/`follows_private_chefs`. No `SECURITY DEFINER` function currently reads them. §17/§18 of `EVENTS_V2_ARCHITECTURE.md` (Privacy model / Notifications) already anticipate a *future* server-side/service-role process resolving "who follows host X" for notification fan-out — that is explicitly future work, not present today, and would run with the service role (bypassing RLS by design, same as any other service-role batch job), not as a client-exposed query. **No blocker found.**

## EXISTING UI PRECEDENTS

Three toggle-style precedents already exist; none is a generic reusable component — each is a private, per-feature widget:

**Wishlist** (`lib/data/repositories/wishlist_repository.dart`, `lib/core/widgets/venue_detail_hero.dart:191-223`): non-optimistic (write-then-flip-state), `_toggle` reads current state then calls a scoped `_add`/`_remove` (two round trips, not an atomic upsert), `_add` swallows `23505` for idempotency, `_remove` is a plain scoped delete. Icon-only hero toggle (`favorite_rounded`/`favorite_border_rounded`, translucent black circle, `AppColors.textOnDark`, state conveyed by fill vs. outline only). Explicit `uid == null` sign-in-prompt guard. **No `Semantics` label. No analytics fires on add/remove.**

**Event Interested/Going** (`lib/models/event_intent.dart`, `lib/data/repositories/event_attendance_repository.dart`, `lib/features/events/widgets/event_intent_controls.dart`): non-optimistic, explicitly documented as such in code (`event_detail_screen.dart`'s own comment: "non-optimistic UI, by design"). `busy`/`pendingTarget` state disables both pills during any in-flight write, preventing double-tap races, with a `CircularProgressIndicator` replacing the icon on the pending target only. `setEventIntent` tries `insert()`, catches `23505`, falls back to `update()` — same idempotency convention as Wishlist, extended to cover genuine status switches. Proper `Semantics(button: true, selected: ..., label: ...)`. Analytics fires only after a successful write, via `intentAnalyticsEvents`.

**Friendship** (`lib/data/repositories/friendship_repository.dart`): send/accept/decline/block go through Postgres RPCs, not raw insert/delete — a different shape driven by two-party asymmetric state, not directly comparable to a single-party Follow toggle.

**Recommendation**: Follow should replicate the **Event Interested/Going pattern**, not Wishlist's — it is the more complete precedent (busy/pending-target double-tap protection, proper accessibility semantics, post-success analytics, documented non-optimistic rationale). Wishlist's simpler pattern is missing exactly the two things Follow's own requirements (analytics contract already defined; accessibility bar already set elsewhere in the app) require.

## RESTAURANT DETAIL

`lib/features/restaurants/restaurant_detail_screen.dart`. Hierarchy: hero (title, star row, wishlist toggle) → city/country line → optional award-history link → divider → `VenueUtilityActions` (Directions/Website/Call/Michelin) → divider → "Plan visit" → optional score section → optional about section → divider → "Your Visits" + visit history → optional personal photos → optional "At This Hotel" linked-venue row → optional info card.

Wishlist lives **only** in the hero (`VenueDetailHero`'s `SliverAppBar.actions`), explicitly documented at the call site as the toggle's sole location. `VenueUtilityActions` is the closest existing action cluster and is flex-friendly (already handles 2–4 items), but its own doc comment scopes it explicitly to "Directions/Website/Call/Michelin only" — extending it for Follow would contradict that documented intent.

**Recommended placement: option A, a second icon in the hero, beside the existing Wishlist toggle** — same `SliverAppBar.actions` list, same translucent-circle treatment, a different icon (see WISHLIST VS FOLLOW below for how to keep the two from reading as duplicates). This is the smallest change: no new row, no redesign, and since both Restaurant and Hotel already share `VenueDetailHero`, adding one icon there updates both screens simultaneously.

## HOTEL DETAIL

`lib/features/hotels/hotel_detail_screen.dart`. Structurally identical hierarchy (Key row instead of Star row, "Plan stay"/"Your Stays" instead of visit wording, "Dining" section instead of "At This Hotel", one fewer utility action since `Hotel` has no `phone` field). Wishlist toggle is the **same shared** `VenueDetailHero` component, wired through `HotelHero`. No architectural divergence from Restaurant Detail — the same hero-icon placement recommendation applies identically, and because both screens consume the same shared `VenueDetailHero`/`VenueUtilityActions` widgets, Restaurant and Hotel automatically get a consistent Follow interaction for free rather than needing two separate implementations kept in sync by hand.

## PRIVATE CHEF

A canonical `PrivateChefDetailScreen` already exists (`lib/features/private_chefs/private_chef_detail_screen.dart`) and is architecturally mature: hero → about → background (restaurant history + education) → experience (guests/pricing/wine) → connect (Instagram/website). `PrivateChefRepository` and a full `PrivateChef` model already exist, reading the real `private_chefs` table. Entry point: Explore → "Browse Private Chefs" → `PrivateChefsScreen` catalogue → tap card → detail screen. **A Follow button can be added cleanly today** — the screen has a header area comparable to Restaurant/Hotel's hero, though it does not currently share `VenueDetailHero` (it's a bespoke hero, `PrivateChefHero`), so Follow there would need its own icon placement decision, not an automatic share.

One caveat: production currently has exactly **1** row in `private_chefs` — the entity type is UI-ready but catalogue-thin. This affects perceived value of Follow on this entity type at launch, not architectural readiness.

**event_chefs is NOT wired into any Dart code** — the join table exists in the schema (confirmed live: `event_chefs` table present, `is_host`/`is_venue` columns present) but no repository or screen reads it. Private Chefs are today reachable ONLY via the standalone Explore → Private Chefs catalogue, never from an Event's own "AT THIS EVENT" section, which is hardcoded to Michelin-starred Restaurant participants only.

**Correction to a stale in-repo comment**: the migration file `20260819140000_events_v2_host_venue_moderation.sql` (which added `is_host`/`is_venue` to all three event-participant tables, created `event_chefs`, and added `external_host_name`/`external_host_url` to `events`) carries a header comment claiming it is "for pre-deployment review only." Live production verification for this audit shows the opposite: `supabase migration list --linked` lists `20260819140000` as applied on both local and remote, and every column it adds (`is_host`, `is_venue`, `event_chefs`, `external_host_name`, `external_host_url`) is confirmably present and queryable in production today. The migration IS live; only its own header comment is stale. Not a blocker — noted so a future workstream doesn't mistakenly re-run or gate on it.

**A vs. B**: recommend **B** — build the shared Follow architecture (repository, domain model, widget) for all three entity types simultaneously (it's the same generic shape either way, see FOLLOW DOMAIN below), but expose the UI only on the two screens where it fits without new design work today: Restaurant Detail and Hotel Detail via the shared hero icon. Private Chef Detail can receive the identical shared widget in the same implementation pass since its screen already exists and is stable — there's no reason to defer it structurally — but its hero isn't shared with Restaurant/Hotel, so it needs its own (small, mechanical) integration point rather than coming "for free."

## RECOMMENDED FOLLOW DOMAIN

**Recommend Option C, adapted**: a typed `FollowEntityType` enum (`restaurant | hotel | privateChef`) paired with **one** `FollowRepository` exposing typed methods per entity (not a raw-string generic API) — e.g. `isFollowingRestaurant`/`followRestaurant`/`unfollowRestaurant`, and the hotel/chef equivalents, internally dispatching to the correct `follows_*` table by a private `switch` on `FollowEntityType`. This is deliberately **not** Option A (three separate repository classes) because the three tables are structurally identical (same columns, same constraints, same RLS shape) and three near-duplicate classes would just be the same logic copy-pasted three times — exactly the kind of premature-abstraction-avoidance the codebase already practices elsewhere (`VisitedRepository` unifies restaurant/hotel visit logic behind one class rather than two). It's also not bare Option B with untyped strings, because `AnalyticsEntityType`/`FollowEntityType` already exist as the controlled vocabulary this maps onto — a raw string parameter would be strictly worse with no benefit.

**Does Follow need its own model object?** No — a bare `bool isFollowing` (from a `.limit(1)` existence check, mirroring `VisitedRepository.isVisited`'s exact pattern) is sufficient for MVP UI state. The row itself (`id`, `user_id`, `entity_id`, `created_at`) has no field the UI currently needs individually — unlike `EventConfirmedAttendance`, which carries a rating/comment/would-recommend payload the UI reads back, a follow row is pure existence. If a future "Following" list screen is built, it would want a lightweight `FollowedEntry` pairing `FollowEntityType` + the hydrated `Restaurant`/`Hotel`/`PrivateChef` (mirroring `VenueEntry`'s existing shape) — not needed for Step 6's detail-screen toggle itself.

**Web/mobile/future**: Supabase remains the sole source of truth in this design — no local cache, no platform-specific persistence, works identically on Flutter mobile and (unbuilt) Flutter web/webapp since the repository is pure Dart + `supabase_flutter`, the same client package already used everywhere else in this codebase across platforms.

## STATE MODEL

MVP states: `notFollowing`, `following`, `busy` (three, matching the task's own minimum — a fourth "error" state is unnecessary since failure returns to whichever of the first two was true before the attempted write, exactly Wishlist/Interested-Going's existing "no rollback needed since state was never optimistically flipped" convention).

**Recommend non-optimistic**, matching both existing precedents (Wishlist and, more precisely, Interested/Going) and this codebase's own explicitly documented rationale for it. Concretely:

- `notFollowing → tap →` `busy=true` → `INSERT` (23505-tolerant, matching Wishlist's `_add`) → on success, `following=true, busy=false` → analytics `follow_added` → on failure, `busy=false` (state stays `notFollowing`), error feedback.
- `following → tap →` `busy=true` → `DELETE` (scoped `user_id`+entity id, matching every other owner-write in this codebase) → on success, `following=false, busy=false` → analytics `follow_removed` → on failure, `busy=false` (state stays `following`), error feedback.
- **Double/rapid taps**: the button must be non-interactive while `busy` (`onTap: busy ? null : ...`, the same guard `EventIntentControls` already uses on both pills) — this alone prevents a second write from firing mid-flight; the database's own unique constraint is the second, belt-and-suspenders layer if a race ever slips through.
- **Failure**: final state is whatever it was before the tap (no partial/ambiguous state possible, since nothing is flipped until the write succeeds); user feedback is a brief error message, matching Wishlist/Interested-Going's existing red-snackbar convention.
- No local cache competes with Supabase — `following`/`busy` are pure widget/screen state rehydrated from a fresh repository read on screen load, never persisted client-side between sessions.

## UX

**Wishlist vs. Follow — semantic distinction**: Wishlist = "I want to visit this place" (forward-looking intent to visit, naturally cleared or fulfilled by an eventual visit). Follow = "I want updates/content/events from this place" (an ongoing subscription, independent of whether the user has ever visited or still wants to). The task's own example is exactly right: a user can visit Parkheuvel, remove it from Wishlist (intent fulfilled), and keep Following it for years (unrelated, ongoing interest) — already documented as a hard requirement in `EVENTS_V2_ARCHITECTURE.md` §15.1.

**Can the UI communicate this clearly with two icons in the same hero?** Yes, with deliberate icon choice — Wishlist already uses a heart (`favorite_rounded`, "I want this"). Follow should use a visually and semantically distinct icon that doesn't read as "a second heart" — e.g. a bell (`notifications_none_rounded`/`notifications_active_rounded`, "notify me") or a bookmark/plus-person icon, NOT another heart-family icon and NOT a star (reserved for Michelin recognition throughout this app). Both icons keep the existing translucent-circle treatment and `AppColors.textOnDark` — state conveyed by fill/outline exactly as Wishlist already does, no gold, no third color introduced. Two distinctly-shaped icons side by side in the hero is a well-established mobile pattern (save vs. subscribe) and does not need a text label to stay legible at this size — but each MUST carry a proper `Semantics` label (fixing the gap Wishlist's own hero button currently has), since two unlabeled icon-only toggles side by side is a real accessibility/confusability risk a single icon alone is not.

## EVENTS HOST SEMANTICS

`event_restaurants`/`event_hotels`/`event_chefs` each carry `is_host`/`is_venue` booleans (live in production, confirmed above) — a row's mere existence means "participates"; the flags layer on top additively, never inferred from address-matching or any other heuristic (per the migration's own header). No Dart model currently reads these two columns — `EventsRepository.loadLinkedVenues` only selects `restaurant_id`/`hotel_id` and hydrates full `Restaurant`/`Hotel` objects, discarding `is_host`/`is_venue` entirely today.

**Confirmed, not challenged**: the task's hypothesis is correct and already the documented design (`EVENTS_V2_ARCHITECTURE.md` §15.3) — "Events from hosts you follow" must join on `is_host = true` only. A followed Restaurant that merely **participates** (venue-only, `is_venue = true, is_host = false`) must NOT cause that event to appear under that heading; a followed Restaurant that's the true organizer (`is_host = true`) must. This is a host-relationship question, not a venue/participation one — exactly 't Preuvenemint's own Vrijthof-vs-restaurant-participant distinction from Step 5, generalized.

## EXTERNAL HOSTS

`events.external_host_name`/`events.external_host_url` are live in production (confirmed) but unmapped in the `Event` Dart model — not read by any current code. Confirmed rule: external hosts have no canonical Chasing Stars entity id and are therefore **not followable** in MVP — no `follow_external_hosts` table should ever be created; a user simply cannot follow an external host until/unless that host is later onboarded as a canonical entity. **No current production Events data issue**: all 4 live Events (from Step 5) resolve to canonical venue_name/address fields already; none currently relies on `external_host_name`/`external_host_url` being non-null for basic display, so this rule creates no gap in what's already shipped.

## ANALYTICS

`follow_added`/`follow_removed` already exist verbatim in the canonical `AnalyticsEvent` taxonomy (`lib/core/analytics/analytics_event.dart:23-24`, wire names `follow_added`/`follow_removed`) — **Step 6 can implement Follow without any analytics contract change.** `AnalyticsEntityType` already has exactly `restaurant | hotel | privateChef | event` (`analytics_properties.dart:98-102`) — no new entity-type variant needed; `privateChef` is already present, confirming the task's explicit "do not invent restaurant_follow_added/hotel_follow_added/chef_follow_added" instruction is already structurally impossible to violate by accident (there is only one pair of events, parameterized by `entityType`).

Per the documented contract (`EVENTS_V2_ARCHITECTURE.md` §31.3), `entity_type`/`entity_id` are REQUIRED where applicable and ARE allowed for this event (`entity_id` is explicitly described there as "the event/restaurant/hotel/chef being acted on," never a user id — this is not user-identifying data). Minimal correct shape for both events: `entityType` (restaurant/hotel/privateChef), `entityId` (the followed row's id), `sourceSurface` where known. No name, email, URL, search text, or friend/user identifier belongs on either event — none of that is in `AnalyticsProperties` today and none should be added.

**One open, non-blocking question**: `sourceSurface`'s existing controlled vocabulary (`eventsFeed | eventSearch | discover | hostProfile | friendActivity | tripRecommendation | passport | map | pushNotification | deepLink | externalShare`) was designed around "where the user came from before this action" (e.g. opening Event Detail from Map). Follow is a same-screen toggle with no navigation involved — there is no obviously-correct existing value for "the user tapped Follow while already on Restaurant/Hotel/Private Chef Detail." `hostProfile` is the closest semantic fit but is itself currently unused anywhere in the codebase (defined, never wired — the same "documented ahead of implementation" gap already found for `eventOpened` in Step 5). This is a naming-fit question for a future analytics-wiring pass, not a blocker for Step 6's UI/repository work, and no new enum value is proposed here.

## FUTURE NOTIFICATIONS

Not built in Step 6, and the current tables need no notification-specific schema today. The owner-only RLS model (`user_id = auth.uid()` on every policy) means no *client* query can ever resolve "who follows host X" — by design. A future service-role process (bypassing RLS, the same pattern any backend batch job already uses in Postgres) could resolve this later purely by querying `follows_restaurants`/`follows_hotels`/`follows_private_chefs` directly with the existing `restaurant_id`/`hotel_id`/`private_chef_id` indexes already in place — no new column, no new table, no denormalization needed for that future capability. **Confirmed: Step 6 needs no notification-specific schema.**

## FUTURE PERSONALIZED EVENTS

Not built in Step 6. **CAN CURRENT FOLLOW + EVENT RELATIONSHIP TABLES SUPPORT "EVENTS FROM HOSTS YOU FOLLOW" WITHOUT A NEW SCHEMA? YES.** The exact join already exists as a documented (not-yet-built) query in `EVENTS_V2_ARCHITECTURE.md` §15.3: `events ⋈ event_restaurants (is_host=true) ⋈ follows_restaurants (user_id=:uid)`, unioned across the hotel/chef equivalents, filtered to published/upcoming. Every table and column that query needs is already live in production today (re-verified this audit) — no denormalization of follow data into `events` is needed or should ever be added; the join is cheap (indexed FKs on both sides) and keeps Follow data in exactly one place.

One documentation-drift note for whoever eventually builds this: `EVENTS_V2_ARCHITECTURE.md` §15.3's own illustrative SQL snippet writes `f.entity_id = er.restaurant_id`, but the actual deployed column is named `restaurant_id` (not a generic `entity_id`) on `follows_restaurants` — a cosmetic inaccuracy in the doc's example query, not a schema problem; the real column names are typed per table exactly as §15.2's own prose recommends.

## WEB READINESS

No temptation toward mobile-only persistence found or proposed — the recommended `FollowRepository` design (Supabase-only, no local cache, no device identifier) is platform-neutral by construction, identical to every other repository already audited in this codebase (`WishlistRepository`, `EventAttendanceRepository`, `VisitedRepository`) — all already work (or are architected to work) across Flutter mobile and a future Flutter web/webapp without modification, since `supabase_flutter`'s client API is itself platform-neutral.

## TEST PLAN

**Domain/repository** (pure-function/repository-level, no widget pump needed — mirroring `event_attendance_eligibility_test.dart`'s style): initial not-following (no row) → `false`; initial following (row exists) → `true`; follow succeeds → row created, idempotent on duplicate (`23505` tolerated, matching `WishlistRepository._add`'s exact pattern); unfollow succeeds → row removed; rapid double-tap while busy → second call never fires (covered at the widget layer via the disabled-while-busy guard, not the repository); a failed write leaves the pre-existing state correct. Each case run for all three entity types (Restaurant/Hotel/Private Chef) — three parameterized passes through the same test bodies, not three duplicated test files, mirroring how `VisitedRepository`'s own tests already share bodies across restaurant/hotel where the logic is identical.

**Widget**: not-following (outline icon) / following (filled icon) / busy (spinner or non-interactive, no visual "error" tint per Wishlist's own "a toggle state is not a failure" precedent) / `Semantics` label present and correct for both states / 320px width no overflow / 1.6x text scale no overflow / no gold anywhere.

**Screen integration**: Restaurant Detail — toggle renders in hero, tap flow works, Wishlist toggle unaffected by Follow's presence; Hotel Detail — identical; Private Chef Detail — identical modulo its own non-shared hero.

**Analytics**: `follow_added` fires only after a successful `INSERT`, never before, never on failure; `follow_removed` fires only after a successful `DELETE`; `entityType` matches the acted-on entity exactly; no PII/name/email/URL in either payload.

**Regression**: Wishlist toggle/behavior unaffected (separate icon, separate repository, separate state); Interested/Going unaffected (entirely separate feature); Event Attendance/My Map unaffected (Step 5's own feature surface, untouched by anything Follow-related).

## PHYSICAL DEVICE PLAN

**Restaurant**: open Restaurant Detail → tap Follow → reload app → Follow state persists → tap Unfollow → reload → state correctly cleared → confirm Wishlist toggle state is completely independent throughout (toggling one never affects the other).
**Hotel**: identical sequence.
**Private Chef**: identical sequence, on whichever entity currently exists in the (currently single-row) `private_chefs` catalogue.
**Failure**: enable airplane mode, tap Follow → UI recovers to a correct, non-ambiguous state (not stuck `busy`, not falsely `following`) → re-enable connectivity → retry succeeds.
**Rapid taps**: tap Follow multiple times quickly → confirm exactly one `follows_*` row is created (or the button was correctly non-interactive after the first tap) → no stuck busy spinner.
**Visual**: deepGreen/ivory only, no decorative gold, both hero icons legible and distinguishable at default and 1.6x text scale, no layout overflow on a 320px-class device.

## DATABASE

- Step 6 migrations required: **0** (schema, constraints, indexes, RLS all already deployed).
- Step 6 schema changes required: **0**.
- Production data writes performed by this audit: **0** (every query this audit ran was read-only `SELECT`/`information_schema`/`pg_policies`/`pg_constraint`/`pg_indexes`).

## VALIDATION

- `flutter analyze` — 0 issues (unchanged; no code was touched by this audit).
- `flutter test` — **1299 passed**, 0 failed (same baseline as the end of Step 5 — this audit made no Dart changes, so the count is identical, not merely "still passing").
- `git status --short` — only this new audit document plus the same pre-existing unrelated Michelin/Gault&Millau enrichment artifacts from before; every Step 5 file remains clean/committed.

## FILES

New: `docs/Architecture/EVENTS_V2_STEP_6_FOLLOW_AUDIT.md` (this document) — **not staged, not committed**, per instruction.

No other file was created, modified, or deleted by this audit.

## GIT

Not staged. Not committed. Not pushed. `git status --short` confirms only this new untracked audit document (plus pre-existing unrelated untracked enrichment artifacts) — no Step 5 file shows as modified.

## RECOMMENDED STEP 6 IMPLEMENTATION

**IN SCOPE**: `FollowEntityType` enum; one `FollowRepository` with typed per-entity methods (`isFollowingRestaurant`/`followRestaurant`/`unfollowRestaurant` + hotel/chef equivalents), non-optimistic, `23505`-tolerant, scoped-delete, mirroring `EventIntentControls`' busy/pending-target pattern; a small shared Follow toggle widget (bell or bookmark icon family, deepGreen/ivory, filled/outline states, proper `Semantics` label) added to `VenueDetailHero`'s actions (covering Restaurant + Hotel simultaneously) and separately to `PrivateChefDetailScreen`'s own hero; `follow_added`/`follow_removed` analytics wired with `entityType`/`entityId`/`sourceSurface` where known; full test suite per TEST PLAN above.

**OUT OF SCOPE**: Event follow; User follow; Winery/Bar follow; a generic polymorphic follow model; "Events from hosts you follow" query/feed; any notification wiring; follower counts/lists of any kind; adding Follow to "AT THIS EVENT," Explore, search, or any surface beyond the three canonical Detail screens; any change to `event_chefs`/`is_host` Dart wiring (still unread by any repository — a separate future step); resolving the `sourceSurface` naming-fit question (flagged, not decided).

MIGRATION REQUIRED: **NO**
PRODUCTION DATA WRITE REQUIRED: **NO**
ANALYTICS CONTRACT CHANGE REQUIRED: **NO**
PRIVATE CHEF UI READY: **YES** (catalogue-thin — 1 row in production — but architecturally ready)
EVENTS PERSONALIZATION IMPLEMENTED: **NO**
NOTIFICATIONS IMPLEMENTED: **NO**
FOLLOW COUNTS IMPLEMENTED: **NO**

---

EVENTS V2 STEP 6 —
FOLLOW ARCHITECTURE AUDITED,
READY FOR HUMAN REVIEW
