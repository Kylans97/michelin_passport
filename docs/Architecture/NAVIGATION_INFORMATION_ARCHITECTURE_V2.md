# Navigation & Information Architecture V2

Status: **human-approved on physical device, finalized and committed.**

This document accumulated across several review/refinement passes (each
noted below and detailed in the numbered sections that follow, kept for
their rationale/audit trail). This top section is the authoritative
summary of the FINAL, approved state — read this first; treat sections
below as historical detail and superseded-note cross-references, not as
independently authoritative.

## Final approved state (summary)

**Primary navigation — exactly five destinations**, unchanged from §1:
Explore · Passport · News · Community · Profile. No bottom-nav destination
exists for Rankings, Wishlist, Trips, or Guides — all four live inside the
information architecture instead (see below).

- **Explore** — Restaurants, Hotels, Events (incl. Near Me), Private
  Chefs, Collections (the existing Guides catalogue, relabeled — no
  backend change). Untouched by any pass in this document beyond that one
  label.
- **Passport** — the personal collection/history view (Restaurants/
  Hotels/Events, year filter, metric strip, "Your Collection") plus a
  compact secondary nav — "Passport · Wishlist · Ranking · Trips" — into
  `WishlistScreen`, `RankingsScreen` (now purely personal — see §11), and
  `PlannedTripsScreen`. **No Stats destination** — the existing metric
  strip already is Passport's statistics (§10).
- **News** — a placeholder tab only (`NewsScreen`, `CsComingSoon`). News
  V1 (real articles, categories) is explicitly the next, separate
  workstream — not started here.
- **Community** — "What people are chasing." Landing hierarchy: Hottest
  Places (real backend, real restaurant hero when the community rating
  threshold is met — currently empty in production, see Known Launch
  Blockers item 1), Community Rankings (title + description + "View
  rankings →" link into `CommunityRankingsScreen`, now genuinely
  functional — see `docs/Architecture/COMMUNITY_RANKINGS_V1.md`), Dining
  Together (title + teaser + "Discover the concept →" link into
  `DiningTogetherScreen`, a concept-only page with zero real
  functionality). Meet the Community is absent — see §15/§18. Full detail
  in §18 (supersedes §12/§15's section-label/Dining Together specifics).
- **Profile** — Edit profile, Notifications, Sign out, and a **Delete
  account** entry — backend deployed and production-verified, see
  `docs/Architecture/ACCOUNT_DELETION.md`.

**Known launch blockers (remaining, each its own separate workstream):**
1. **`restaurant_rankings` currently returns zero rows in production** —
   the view itself is real, deployed, and correct (see
   `docs/Architecture/COMMUNITY_RANKINGS_V1.md`), but production has only
   one restaurant rating in total today, below the (deliberately
   principled, human-approved) 3-unique-rater minimum. Both Hottest
   Places and Community Rankings already handle this gracefully (see
   that document's §7) and will show real content the moment real usage
   crosses the threshold — no further backend work required. **This is no
   longer a missing-backend blocker — §17 below, describing the view as
   not existing, is now historical.**
2. ~~Account deletion backend does not exist~~ — **resolved.** Deployed to
   production, smoke-tested with disposable accounts (including a live
   attack test) and physically verified on-device. See
   `docs/Architecture/ACCOUNT_DELETION.md`.
3. **News V1** (real articles/categories) is not started.
4. **Dining Together** real functionality (matching, discovery, etc.) is
   not started — deliberately deferred given its privacy/safety
   complexity; only a concept-preview page exists.
5. **Meet the Community** is not started — deferred until genuine
   editorial/user-story content exists via News.

**Backend/schema impact of this document's own navigation/IA work:
none.** (Two later, separate workstreams referenced above — Account
Deletion and Community Rankings Backend V1 — did make real, deliberate
backend changes; see their own documents for full detail. Neither
touched navigation/IA itself.)

## 1. What changed

The bottom-navigation shell moved from five destinations organized around
content types (Passport / Explore / Rankings / Wishlist / Profile) to five
destinations organized around user questions:

| Old destination | New destination |
|---|---|
| Passport | Explore |
| Explore | Passport |
| Rankings | News |
| Wishlist | Community |
| Profile | Profile |

Rankings and Wishlist are no longer bottom-navigation tabs. Both are fully
intact — re-homed as screens pushed from Passport's new quick-access row.

## 2. Rationale

The old structure named destinations after content types (a Rankings tab, a
Wishlist tab). That scales poorly: every new content type competed for a
bottom-nav slot, and there was no natural home for News or Community. The
new structure names destinations after the question they answer, and each
question owns however many content types it needs underneath it:

- **Explore** — "Where can I go / what can I discover?" Restaurants,
  Hotels, Events, Private Chefs, Collections.
- **Passport** — "Where have I been / where do I want to go?" Visited,
  Wishlist, My Ranking, Trips, Stats.
- **News** — "What's happening?" (placeholder in this phase; real content
  is a separate, later workstream).
- **Community** — "What are other people doing?" (Community Rankings today;
  Activity/Friends/Reviews/Event social/Dining Together are future scope).
- **Profile** — identity, account, settings.

This also gives Private Chefs and Events room to be first-class Explore
categories without needing their own bottom-nav slot, and gives News and
Community a genuine permanent home instead of being left out of primary
navigation entirely.

## 3. Destination ownership and migrations

### Guides → Collections
Explore already had a permanent "Browse the Guides" row (a
`GuideDestinationRow`) routing to the existing `GuidesScreen`. The only
change is the label: "Browse the Guides" → **Collections**. The destination,
its content (Michelin / World's 50 Best / Gault&Millau catalogues), and its
underlying screen are unchanged. No new Collections backend was built — this
is the smallest safe migration toward the Collections concept; a dedicated
Collections screen/backend remains future scope.

### Wishlist → Passport
`WishlistScreen` is no longer a bottom-nav tab. It's pushed from Passport's
compact secondary nav ("Wishlist" item — see §10). Because it's now a pushed
route rather than a permanent tab body, it gained its own
`Scaffold(backgroundColor: AppColors.deepGreen)` and a leading
`EditorialBackButton` — the same pattern every other pushed dark-canvas
screen in this app uses (`PlannedTripsScreen`, `RankingsScreen`). No other
change: selector, states, and row content are byte-identical to before.

### My Ranking → Passport
`RankingsScreen` is pushed from Passport's compact secondary nav ("Ranking"
item). **UI Refinement**: its former "My Rankings"/"Community" `TabBar` was
removed — see §11.

### Trips → Passport
`PlannedTripsScreen` is pushed from Passport's compact secondary nav ("Trips"
item), exactly as it already was from Wishlist's "Trips" text action (that
entry point is unchanged and still present inside `WishlistScreen`). No code
change to `PlannedTripsScreen` itself.

### Private Chefs → Explore
Private Chefs was already reachable only from Explore (a
`GuideDestinationRow`, alongside Collections), never nested under
Restaurants. No code change was required here — Navigation V2's target model
already matched the existing implementation. Documented here for
completeness.

### News (new)
`NewsScreen` is a new bottom-nav tab body (no own `Scaffold`, matching
`ExploreScreen`/`PassportScreen`'s convention). It shows a title, a supporting
line, and a `CsComingSoon` placeholder. News V1's real content system
(Latest/Chasing Stars/Interviews/Restaurants/Events/Awards categories, three
launch stories) is explicitly out of scope for this phase — no fake articles
were built.

### Community (new, redesigned in the UI Refinement pass — see §12)
`CommunityScreen` is a new bottom-nav tab body with a real landing hierarchy:
Hot Right Now, Community Rankings, Meet the Community, Dining Together.

### Profile
Audited, unmodified except for the Account Deletion addition — see §13.
Existing rows: Edit profile, Notifications, Sign out, and now Delete account.
No dedicated Privacy / Feedback / About rows exist today. See §8 for why
these were not fabricated in this phase.

### Stats — removed as a destination (UI Refinement pass — see §10)
No dedicated cross-type Passport statistics screen exists — only the
existing inline per-filter `CsMetricStrip` shown in Passport itself, which
is treated as Passport's own statistics. Building a genuine aggregated Stats
page (visits + stays + events in one view) is real new product work,
explicitly out of scope. The original pass shipped Stats as a Coming Soon
destination; the UI Refinement pass removed it as a destination entirely
(physical-device review: it read as an empty promise rather than a useful
placeholder) — see §10.

## 4. Coming Soon strategy

One reusable component, `CsComingSoon` (`lib/core/widgets/cs_coming_soon.dart`):
a centered icon (outlined, never gold), a title, and an optional description.
No construction graphics, no gradients, no emoji, no cartoon styling, no fake
disabled controls. Used only where functionality genuinely doesn't exist yet:

- `NewsScreen` — no content source exists at all yet.
- Community's "Hot Right Now," "Meet the Community," and "Dining Together"
  sections (a `compact: true` variant added in the UI Refinement pass — see
  §12 — so three of these stacked on one scrolling page still read as a
  coherent page, not a wall of empty states).

Explicitly **not** used to replace anything already working — Community
Rankings, Wishlist, Trips, and My Ranking are all shown/reached as real
content, not behind a placeholder. Stats is no longer a destination at all
(§10), so it no longer needs a Coming Soon state either.

## 5. Home / landing question

Audited: no separate landing/home surface exists distinct from the tab
destinations. `AuthGate` gates directly into `_MainNavigation` (the five-tab
shell); there was never a dedicated Home screen to migrate or remove. The
five-tab navigation is considered to satisfy the product's landing-surface
need — no sixth "Home" destination was created.

## 6. Navigation state and back-navigation

No architectural change: the shell still uses `IndexedStack` to preserve
each tab's scroll/state across switches, and all newly-pushed screens
(`WishlistScreen`, `RankingsScreen`, `PlannedTripsScreen`,
`CommunityRankingsScreen`, `DeleteAccountScreen`) use the same
`Navigator.push` / `MaterialPageRoute` + `EditorialBackButton` pattern
already established for every other pushed screen in this app. Passport's
compact secondary nav (§10) is not itself a nested `Navigator` or persistent
sub-navigation shell — "Passport" is simply always its active item (you're
already there); the other three items call the same `Navigator.push` used
everywhere else in the app. No nested `Navigator` was introduced anywhere in
this workstream.

## 7. Deliberately deferred / not done in this phase

- **News V1 content** (real stories, categories) — separate, later
  workstream.
- **A real Collections backend** — Explore's "Collections" row still routes
  to the existing `GuidesScreen`; a dedicated Collections screen/data model
  is future scope.
- **Full Community feature set** — Activity, Friends, Event social, Dining
  Together's actual matching/chat/booking mechanics remain unbuilt; only
  Community Rankings is real today. "Hot Right Now" and "Meet the Community"
  are Coming Soon (§12).
- **A genuine cross-type Stats/analytics screen** — no longer even a
  destination (§10); the existing inline `CsMetricStrip` is Passport's
  statistics.
- **Profile Privacy / Feedback / About rows** — the target product model
  lists these under Profile, but no such rows exist in the current
  `ProfileScreen`. Building them would mean either real settings screens
  (out of scope for an IA-migration phase) or fake disabled rows, which the
  Coming Soon guidance explicitly rules out. This gap is intentionally left
  undocumented-as-built and only noted here, in `ProfileScreen` itself.
- **Gault&Millau exposure** — unrelated to this workstream; unaffected by
  it.

## 8. Backend impact

None. This is an application/navigation-only workstream: no schema change,
no RLS change, no production-data write.

## 9. Files touched (initial pass)

New: `lib/core/widgets/cs_coming_soon.dart`, `lib/features/news/news_screen.dart`,
`lib/features/community/community_screen.dart`.

Modified: `lib/app.dart` (five-tab shell), `lib/features/wishlist/wishlist_screen.dart`
(own Scaffold + back button), `lib/features/passport/passport_screen.dart`
(quick-access row + Stats Coming Soon screen), `lib/features/explore/explore_screen.dart`
(Collections relabel).

Tests: `test/bottom_navigation_test.dart` (updated), `test/wishlist_screen_shell_test.dart`
(updated), `test/explore_guides_entry_test.dart` (updated), plus new
`test/cs_coming_soon_test.dart`, `test/news_screen_test.dart`,
`test/community_screen_shell_test.dart`, `test/passport_quick_access_row_test.dart`.

See §14 for the UI Refinement pass's own file list.

## 10. UI Refinement — Passport simplified

Physical-device review found the four full-width `GuideDestinationRow`
quick-access rows made Passport read as a menu/dashboard rather than a
personal collection. Replaced with a compact, text-only secondary nav:
**Passport · Wishlist · Ranking · Trips** (`_PassportSecondaryNav` /
`_SecondaryNavItem`, private widgets in `passport_screen.dart`). "Passport"
is always the active item (color/weight only — ivory + w600 vs
secondaryOnDark + w500, the same rule the bottom `NavigationBar` itself
already uses) and has no `onTap` — you're already there. The other three
call the same `_openWishlist`/`_openMyRanking`/`_openTrips` methods as
before, unchanged. Stats was removed as a destination entirely —
`_openStats` and `_StatsComingSoonScreen` were deleted; the existing inline
`CsMetricStrip` (visited / countries / awards, already shown further down
Passport) is treated as Passport's statistics. Passport's default content
when you tap the bottom-nav tab is unchanged: Restaurants/Hotels/Events,
year filter, metric strip, "Your Collection."

## 11. UI Refinement — My Ranking is now purely personal

`RankingsScreen` no longer has a `TabController`/`TabBar` — its former
"Community" tab (`CommunityRankingsTab`) was removed from this screen
entirely. `RankingsScreen` is now a plain `StatelessWidget` showing only
`PersonalRankingsTab` (the current user's own visited/rated content) under
its existing `SliverAppBar` header. `CommunityRankingsTab` itself was not
deleted or changed — the same widget class is now hosted by
`CommunityRankingsScreen` (§12) instead, reachable from the primary
Community destination, which is where any ranking based on other users
belongs per this refinement's product-ownership rule.

## 12. Community — launch hierarchy (superseded by §15, Community Launch
Refinement)

`CommunityScreen` no longer opens directly into what is effectively a
rankings screen. The first pass gave it four sections (Hot Right Now,
Community Rankings, Meet the Community, Dining Together), with Hot Right
Now and Meet the Community both rendered as large `CsComingSoon` blocks.
Physical-device review found this read as a product roadmap rather than a
living destination — **superseded by the Community Launch Refinement,
§15.**

## 15. Community Launch Refinement — a real landing hierarchy at launch
(superseded in part by §18, Community Typography + Dining Together)

**Core rule: hide unavailable Community content rather than filling the
screen with Coming Soon placeholders.** This rule still holds; the section
*labels* and Dining Together's *landing-page treatment* described below
were revised in §18 — see there for the current copy/typography. The
underlying data/architecture decisions in this section are unchanged.
Community's launch hierarchy:

- **HOT RIGHT NOW — the visual hero, not a Coming Soon block.** Audited
  before building anything (no new backend aggregation, no migration): a
  real, already-aggregated, cross-user signal exists for restaurants
  (`RankingsRepository.getCommunityRankings()`, the same
  `restaurant_rankings` view `CommunityRankingsTab` already uses) — the
  community's highest-rated restaurant. **No equivalent exists for
  hotels** anywhere in the repository layer. **No equivalent exists for
  events** either — confirmed via a fresh, targeted re-audit of
  `event_social_repository.dart`, `events_repository.dart`, and
  `docs/Architecture/EVENTS_V2_STEP_8A_PERSONALIZED_RANKING_PRE_FINAL.md`,
  which explicitly documents this exact gap ("no batched/array variant" of
  the going-count RPC — only an O(k)-per-event path exists). Rather than
  wire one of three categories real and silently omit or fabricate the
  other two, only the one real, honestly-labeled category renders: a
  single hero card (`_HotRightNowRestaurantCard` in `community_screen.dart`)
  captioned **"Highest rated by the community"** — never "Trending,"
  "Hottest," "This week," or any other claim of recency the data doesn't
  support. If the underlying query is ever empty (a brand-new install with
  zero community ratings) or fails, the entire section — eyebrow included —
  is omitted, never a placeholder claiming something is missing.
  `RestaurantRepository` gained one small additive method,
  `getById(String id)` (same `restaurants_full`/`restaurantFullColumns`
  query `getAll()`/`search()` already use, just filtered to one row), so
  tapping the hero card can push the canonical `RestaurantDetailScreen`
  (which requires a full `Restaurant`, not the summary fields a
  `CommunityRankingEntry` carries) — no schema/RLS/migration change.
- **COMMUNITY RANKINGS** — unchanged from §12: real content, a
  `GuideDestinationRow` ("View rankings") pushes `CommunityRankingsScreen`.
- **MEET THE COMMUNITY — removed from the launch screen entirely.** No
  heading, no `CsComingSoon` block, nothing — no genuine editorial/user-story
  content exists yet, and a Coming Soon placeholder for it was exactly the
  "roadmap" problem this refinement fixes. Future architecture (documented,
  not built): **News owns the Article; Community surfaces a selected
  user-focused story under this heading once one exists**, linking to the
  canonical News Article Detail. This also folds in the previously-agreed
  News launch strategy (Article 1 pre-tester-launch, Article 2 around
  public launch, Article 3 ~2 weeks after) — those three articles are not
  created in this pass; genuine future user interviews can live in News and
  be surfaced contextually here, avoiding two competing article systems.
- **DINING TOGETHER — the one intentional Coming Soon teaser.** Compact and
  editorial (a title line + "Coming soon" caption), not the large
  `CsComingSoon` component — this is deliberately NOT tappable (no
  destination exists). No matching, chat, messaging, booking, group
  creation, location sharing, moderation, or identity verification exists
  or was started; this needs its own dedicated architecture for privacy,
  user safety, moderation, no-shows, reservation responsibility, and group
  size before any of it is buildable.

`CsComingSoon`'s `compact: true` variant (added in §12's pass) is no
longer used anywhere in `community_screen.dart` — Hot Right Now is real
content now, Meet the Community is hidden rather than shown as Coming
Soon, and Dining Together's teaser is small enough to not need the shared
component at all. `compact` remains available for future use elsewhere.

## 13. Account Deletion (App Store readiness)

Added to Profile as real functionality, not a Coming Soon placeholder — see
the pre-approval report's dedicated answers for the full audit findings
(schema cascade behavior, Storage, Sign in with Apple status). Summary:

- **Entry point**: a "Delete account" row in Profile's ACCOUNT section,
  directly visible alongside Edit profile/Notifications/Sign out — never
  buried behind Privacy/Terms/About/a support email. Styled with
  `AppColors.error` as a destructive-action clarity signal (not a dark
  pattern — the row is exactly as large and tappable as any other).
- **Confirmation**: `DeleteAccountScreen` explains what deletion does, then
  requires an explicit final confirmation in a system `AlertDialog`
  ("Delete your account?" / Cancel / Delete). Never deletes on the first
  tap. A clear Cancel exists at both the screen level and the dialog level.
- **Abstraction**: `AccountDeletionRepository.deleteCurrentAccount()` takes
  no parameters at all — the client can only ever request deletion of its
  own session's account; there is no way to pass another user's id through
  this API surface.
- **Backend status — NOT YET READY.** Audited 2026-08-23: no
  `supabase/functions/` directory exists in this project, so there is no
  Edge Function, RPC, or any other mechanism that safely deletes an
  `auth.users` row today. `deleteCurrentAccount()` calls
  `client.functions.invoke('delete-account')`, which will fail in production
  right now (the function doesn't exist) — honestly, via a caught,
  restrained error, never a false "success." This is real, wired
  functionality blocked on a documented, separate backend deliverable, not a
  fake button.
- **Required future Edge Function** (NOT implemented in this pass —
  deliberately kept as its own controlled sub-step, per this addendum's own
  commit gate): a `delete-account` Edge Function, using the service-role key
  server-side only (never in the client), that (1) verifies the caller's
  identity from their own JWT (never accepts a client-supplied user id), (2)
  deletes that user's objects from the `visit-photos` Storage bucket
  (`{user_id}/...` — **not** covered by Postgres FK cascade, confirmed by
  audit), (3) calls the Supabase Admin API to delete the `auth.users` row.
  Step 3 alone is sufficient for all Postgres-side data: `profiles.id` is
  `ON DELETE CASCADE` from `auth.users(id)`, and every user-owned table
  (`visits`, `wishlist`, `planned_trips`, `planned_venues`, `photos`,
  `event_attendance`, `event_confirmed_attendance`, `follows*`,
  `friendships`, `private_chef_enquiries`) cascades from `profiles.id` —
  confirmed via a live, read-only `information_schema` query against the
  linked project.
- **Sign in with Apple**: audited — **not currently implemented**.
  `AuthRepository` only has `signUp`/`signIn` (email+password)/`signOut`; no
  `sign_in_with_apple` package is even a dependency. No token-revocation
  work is needed until Apple Sign-In is actually built; documented here so
  it isn't forgotten if that's added later.
- **App Store readiness**: **not yet claimed.** The UI/UX is complete and
  tested; the destructive backend operation is not deployed. This is
  explicitly flagged as the next, separate, controlled step — not
  something this workstream silently shipped.

## 14. Files touched (UI Refinement + Account Deletion pass)

New: `lib/features/community/community_rankings_screen.dart`,
`lib/data/repositories/account_deletion_repository.dart`,
`lib/features/profile/delete_account_screen.dart`.

Modified: `lib/core/widgets/cs_coming_soon.dart` (`compact` param),
`lib/features/passport/passport_screen.dart` (secondary nav replaces the
quick-access stack; Stats removed), `lib/features/rankings/rankings_screen.dart`
(Community tab removed — purely personal now), `lib/features/community/community_screen.dart`
(new Hot Right Now/Community Rankings/Meet the Community/Dining Together
hierarchy — since superseded by §15/§16), `lib/features/profile/profile_screen.dart`
(Delete account row).

## 16. Files touched (Community Launch Refinement pass)

New: none.

Modified: `lib/features/community/community_screen.dart` (Hot Right Now
became the real hero; Meet the Community removed; Dining Together shrunk to
a compact teaser), `lib/data/repositories/restaurant_repository.dart`
(added `getById`).

Tests: `test/community_screen_shell_test.dart` (rewritten — CommunityScreen
is Supabase-eager again now that it loads a real signal in `initState`, so
this reverted to the mirror-testing pattern used by every other
Supabase-eager screen in this app).

## 17. Hot Right Now Bugfix — `restaurant_rankings` does not exist in production

Physical-device validation of §16 found "HOT RIGHT NOW" completely absent
on-device, while Community Rankings and Dining Together rendered fine. Root
cause, confirmed via a live, read-only query against the linked production
database and a full git-history search of `supabase/migrations/`:

**`restaurant_rankings` — the Postgres view `RankingsRepository.
getCommunityRankings()` queries — does not exist in production, and has
never existed in this repository's tracked migration history.**
`select count(*) from restaurant_rankings;` fails with `42P01: relation
"restaurant_rankings" does not exist`; `information_schema.tables`,
`pg_views`, and `pg_matviews` all confirm no object by that name (or
containing "ranking") exists in any schema. This is not an RLS issue, not
an empty-result issue, and not a key/identifier mismatch between
`CommunityRankingEntry.restaurantId` and `restaurants_full.id` (both are
uuids, confirmed) — `getCommunityRankings()` never gets far enough to
return rows or hit `RestaurantRepository.getById` at all.

**This means Community Rankings — believed throughout this whole
workstream, and the workstreams before it, to be "real, already-working
content" — has, as far as this repository's history shows, never actually
returned data in production.** `CommunityRankingsTab`'s own error/empty
states ("Could not load community rankings" / "No community data yet")
were presumably always what a real user actually saw there; nobody had
verified this against live production data until this bugfix's audit.

**Hot Right Now's own code is correct and was not changed for this
reason** — hiding the section on any error (§16's `catch (_) { return
null; }`) is exactly the previously-agreed "hide unavailable content"
behavior, correctly applied to data that is, in fact, unavailable. What
*was* fixed:

- **A constructor-injection testability seam** on `CommunityScreen`
  (`loadCommunityRankings`, `getRestaurantById` — same pattern
  `DeleteAccountScreen` already established), so the real widget can be
  pumped and exercised directly with hand-rolled fakes in tests, no mocking
  framework, no mirrored copy of its `build()` logic.
- **`test/community_screen_shell_test.dart` rewritten** to pump the real
  `CommunityScreen` with fakes covering: a real ranked entry (full hero
  renders), an empty list (graceful omission, no fabrication), a thrown
  exception shaped like the actual production error (no crash, siblings
  still render), and a failed restaurant lookup on tap (no crash, no
  navigation).

**Explicitly NOT fixed in this pass** (out of scope — this was a targeted
bugfix, not a backend workstream): the missing `restaurant_rankings` view
itself. Creating it requires real product/data decisions (what exactly
defines `community_rating` — likely an aggregate over `visits`/ratings per
restaurant — and whether it should require a minimum visit count before a
restaurant qualifies) that go beyond "fix the rendering path," and this
whole set of workstreams has consistently treated new backend/schema work
as its own controlled, explicitly-authorized step rather than something to
bundle silently into a UI fix. **Until that view is created, both Hot
Right Now and Community Rankings will continue to show no data in
production** — this is now a known, documented gap, not a silent one.

### Testability lesson

No widget test — mirrored or, as here, DI-seamed and pumping the real
widget — can catch "the query target doesn't exist in production." Fakes
prove the app's OWN logic (rendering, error-handling, navigation-triggering)
is correct once given real inputs; they cannot prove the inputs are ever
actually reachable. Only a live, read-only data audit against the linked
project (as run here) can catch a missing-backend-object defect like this
one. The DI seam added here is still valuable — it's what let the
day-to-day rendering/error-handling logic be verified quickly and
precisely once the real cause was found — but it should not be read as
"this class of bug is now covered by tests."

Tests: `test/primary_tab_headers_test.dart` (Rankings mirror — TabBar
removed), `test/passport_quick_access_row_test.dart` (rewritten for the
secondary nav), `test/community_screen_shell_test.dart` (rewritten — now
pumps the real `CommunityScreen`, which has no Supabase dependency of its
own), `test/cs_coming_soon_test.dart` (compact-mode coverage added), plus
new `test/community_rankings_screen_test.dart`,
`test/delete_account_screen_test.dart`,
`test/profile_delete_account_entry_test.dart`.

## 17a. Community Header Alignment Bugfix

Physical-device revalidation of §17's fix found Community's header
("Community" / "What people are chasing.") rendering **centered**, not
left-aligned like Explore/Passport. Root cause: `CommunityScreen`'s outer
`Column` had no explicit `crossAxisAlignment`, defaulting to `center`. A
plain `Column` loosens the cross-axis (width) constraint it gives
non-flex children, so the header shrank to its own widest line and sat
centered under that default — unlike Explore/Passport, which reach their
headers through a `SliverToBoxAdapter` (slivers force a *tight* cross-axis
width on their child, which is why they never had this problem). This was
masked in earlier checks at exactly one logical width (390px) because the
subtitle happened to wrap onto two lines that filled the available width,
canceling the visible offset — confirmed by measuring the title's actual
X position at 320/390/430/800px: correct only at 390, visibly centered
everywhere else. **Fix:** `crossAxisAlignment: CrossAxisAlignment.stretch`
added to the outer `Column`, forcing the header and scrollable body to the
same full tight width Explore/Passport get for free. No `textAlign`
change, no header redesign. `test/community_screen_shell_test.dart` gained
a permanent regression group asserting every section's left edge equals
`CsSpacing.pageHorizontal` across 320/390/430/800px, with and without the
Hottest Places card present.

## 18. Community Typography + Dining Together Refinement

Physical-device re-review (after §17a's fix) approved the alignment but
flagged visual hierarchy: "Community Rankings" and "Dining Together" read
as small category labels (the `_sectionEyebrow` tiny tracked-uppercase
style, reused from Explore/Passport's own sub-label conventions) when they
are actually Community's three major topics, and the content/action
beneath them was reading as more prominent than the topic itself.

**Section titles.** All three major topics — **Hottest Places** (renamed
from "Hot Right Now" — the old label implied a temporal trending algorithm
the data doesn't support, and this section will eventually cover
Restaurant/Hotel/Event together, so an editorial/luxury framing fits
better than a social-media "trending" widget), **Community Rankings**, and
**Dining Together** — now render via one shared `_sectionTitle()` helper:
`CsTypography.placeTitle` (serif, ivory), clearly smaller than the
"Community" page title (`screenTitle`) and clearly larger than their own
description/action text below. `_HotRightNowRestaurantCard` was renamed
`_HottestPlacesRestaurantCard` to match (same widget, same behavior — see
§17's own description of its data logic, unchanged).

**Community Rankings** now reads: section title → description ("See how
the community rates every restaurant.", `body`/secondaryOnDark) → a small
`_CommunityActionLink` ("View rankings →", `bodyMedium`/ivory + a 16px
arrow icon) — replacing the previous `GuideDestinationRow`, whose own
label was styled as prominently as a section title, competing with
"Community Rankings" itself. Tapping still pushes the same, unchanged
`CommunityRankingsScreen`.

**Dining Together** now reads: section title → teaser copy ("Great tables
are better shared.") → the same `_CommunityActionLink` style ("Discover
the concept →"). Both `_CommunityActionLink` sites are deliberately
identical so the two topics read consistently. The landing page no longer
shows "Coming soon" directly — instead, the action link pushes a new,
dedicated `DiningTogetherScreen` (`lib/features/community/
dining_together_screen.dart`): an editorial concept/preview page (title,
lead line, two paragraphs on the product vision, four bulleted future
concepts, and a restrained "Coming soon" at the bottom — no icon, no card,
no `CsComingSoon` component). **Zero Dining Together functionality
exists** — no matching, chat, messaging, invitations, group creation,
booking, reservation coordination, profile verification, location
sharing, moderation, or user discovery; no fake waitlist, fake matching
button, or fake member profiles. `DiningTogetherScreen` is a pushed screen
(`Scaffold` + `EditorialBackButton`, no Supabase dependency at all — safe
to pump directly in tests, unlike most pushed screens in this app).

**Meet the Community** — unchanged, still absent (§15).

**Hottest Places data limitation** — only the restaurant "highest rated
by the community" signal is real; Hotel and Event remain structurally
absent (not degraded), deliberately out of scope for V1 — see
`docs/Architecture/COMMUNITY_RANKINGS_V1.md` §13 for their documented
future requirements. **The `restaurant_rankings` backend view itself is
now real and deployed** (Community Rankings Backend V1, after this
Community Typography pass) — it currently returns zero rows because
production has only one restaurant rating in total, below the
3-unique-rater minimum; this is a data-volume state, not a missing-
backend one. See that document's §4 and §7.

**Bug found and fixed during this pass:** `_CommunityActionLink`'s `Row`
originally wrapped its label in a bare `Text` (no `Flexible`/`Expanded`).
A `Row`'s non-flex children receive *unbounded* main-axis constraints to
measure their own natural single-line width — so an unwrapped `Text`
never wraps, it only overflows when too wide. This surfaced as a real
`RenderFlex overflowed` failure at 320px width with the longer "Discover
the concept" label (confirmed via an isolated test before fixing). Fixed
by wrapping the label in `Flexible`. `DiningTogetherScreen`'s own
`_ConceptLine` bullets were already correctly built with `Expanded` and
never had this problem.

Files changed: `lib/features/community/community_screen.dart` (section
titles, action links, Dining Together navigation, the `Flexible` fix),
new `lib/features/community/dining_together_screen.dart`. Tests:
`test/community_screen_shell_test.dart` (rewritten for the new
copy/hierarchy), new `test/dining_together_screen_test.dart`. No
backend/schema/RLS changes.
