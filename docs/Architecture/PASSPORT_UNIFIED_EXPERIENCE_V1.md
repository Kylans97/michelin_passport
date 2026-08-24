# Passport Unified Experience V1

Status: **human-approved on physical device, finalized and committed.**
Includes both the initial shell/architecture pass and the follow-up "UI
Polish V2" visual pass (open stats row with a single globe emblem, "Last
visit" removed from collection-card footers, a real wired wishlist
bookmark, widened local-tab-bar spacing) — both reviewed together on
device and approved as one cumulative Passport state.

## 1. What this is

A focused redesign of the Passport experience only. Passport, Wishlist,
Ranking, and Trips are no longer four separate screens connected by
`Navigator.push` — they're one continuous personal space with a
persistent header and a local tab bar, where switching subsections swaps
only the content region in place. Explore, Community, News, Profile, and
the bottom navigation are untouched beyond what this required.

Superseded, not deleted: `docs/Architecture/NAVIGATION_INFORMATION_
ARCHITECTURE_V2.md`'s own "pushed secondary destinations" description of
Wishlist/Ranking/Trips has a pointer to this document at the top of its
final-approved-state summary; the historical sections below it document
how Wishlist/Ranking/Trips got to Passport in the first place and remain
accurate for that history.

## 2. Core product decision

The "same page" illusion applies to exactly four subsections — Passport,
Wishlist, Ranking, Trips. Deep detail navigation (Restaurant/Hotel/Event/
Trip Detail, My Map) is unaffected: those remain normal pushed screens
with their own back arrow.

**Architecture**: `PassportScreen` (`lib/features/passport/passport_screen
.dart`) is now the persistent shell. It owns exactly one header, one local
tab bar, and an `IndexedStack` whose four children are the four
subsection bodies. `_subsection` is local `State`, switched via
`setState` — never `Navigator.push`, never a route, never a back button.

**Lazy + cached construction**: subsection bodies are built lazily
(`_bodies` map, `putIfAbsent`) — Passport's own body is built eagerly on
first mount (the default, always-visible tab); Wishlist/Ranking/Trips are
not constructed, and therefore never fetch anything from Supabase, until
the user actually taps that tab. Once built, a body stays in `_bodies`
for the screen's lifetime, so `IndexedStack` keeps its `State` alive
across every later switch — filters, scroll position, and in-flight
loads all survive a Wishlist → Ranking → Wishlist round trip exactly as
they would on a real persistent page.

**Testability**: `PassportScreen` takes four optional injected bodies
(`passportBody`/`wishlistBody`/`rankingBody`/`tripsBody`), the same
constructor-injection seam this app's other Supabase-eager screens
already use (`CommunityScreen`, `DeleteAccountScreen`,
`CommunityRankingsTab`). All four default to the real bodies in
production; tests inject lightweight fakes so the real shell — not a
hand-mirrored copy of it — is what's actually exercised.

## 3. Persistent shell

`_PassportExperienceHeader` ("Passport" / "Your collection of remarkable
places." / a restrained rounded-outline map button) and
`_PassportLocalTabBar` ("PASSPORT WISHLIST RANKING TRIPS", active item
ivory + bold + a thin ivory underline, inactive muted, a fainter
full-width baseline divider beneath the whole row) are both built exactly
once and never rebuilt when the subsection changes — only the `Expanded`
`IndexedStack` below them swaps.

**Bug found and fixed**: the local tab bar's own `Row` overflowed even at
the default 390px test width once real font metrics were exercised
(confirmed via a real-widget test before fixing). Initially fixed with
tight fixed gaps (`CsSpacing.sm`) plus a `SingleChildScrollView` safety
net. UI Polish V2 revised this again on explicit feedback that the tabs
read as "too close together": the row is now `Row(mainAxisAlignment:
MainAxisAlignment.spaceBetween)` — items spread across the full
available width instead of clustering left, with each item wrapped in
`Flexible` (label `maxLines: 1, overflow: ellipsis`) as the overflow
safety net instead of a scroll view. Confirmed via a widget-test sweep at
320/375/390/430px, plus a direct proof that the gap between the first and
last item grows on a wider screen (not a fixed gap).

**Map button**: audited per the task's own instruction not to fabricate
functionality. It already had a real destination (`VisitedMapScreen`) —
preserved unchanged; only the visual container (rounded outline) is new.

## 4. Passport subsection — visual redesign

`PassportCollectionBody` (`lib/features/passport/widgets/
passport_collection_body.dart`) is the extracted, restyled former body of
`PassportScreen` itself. All data-loading/filtering logic is unchanged
from before this pass (same `VisitedRepository`/
`EventConfirmedAttendanceRepository` calls, same year-filter/venue-type
state machine, same `didPopNext` refresh-on-return behavior) — only the
header/secondary-nav slivers were removed (now owned by the shell) and
the visual treatment of what remains was redesigned to match the
approved reference:

- **Entity filter** — `CsFilterChip` (already the canonical, shared
  filter-chip component) now carries a leading icon per type
  (`restaurant_outlined`/`bed_outlined`/`confirmation_number_outlined`),
  reusing its existing icon slot rather than a new component.
- **Time filter** — `YearFilterControl` unchanged; it already matched the
  reference (a compact "All time ▾" trigger, visually secondary to the
  entity filter).
- **Stats panel** — `PassportStatsPanel` (`widgets/passport_stats_panel
  .dart`) is an open, editorial row: a single circular-outline globe
  emblem (`Icons.public_outlined`) to the left, three value/label columns
  with thin dividers, **no border, no background, no per-metric icon**.
  This is the UI Polish V2 revision of this same widget — an initial
  version shipped with a bordered panel and a tonal icon circle per
  metric; explicit follow-up direction ("remove the dashboard-card
  container... this area should breathe") replaced that with the current
  shape. Still deliberately a new, Passport-local widget rather than a
  change to `CsMetricStrip` itself — that component is shared with
  Profile's Journey metrics, which were deliberately de-iconified in an
  earlier pass; a change made here must not regress that.
- **"YOUR COLLECTION"** — unchanged; `PassportCollectionHeader` was
  already text-only with no logo/emblem, matching the required deviation
  from the visual reference before this pass even started. A direct
  regression test now asserts no `Icon`/`Image`/`CsImagePlaceholder`/
  `CircleAvatar` precedes it.
- **Collection cards** — `CsPlaceCard` gained two optional slots
  (`bookmark`, `fullWidthFooter`) rather than being forked into a
  parallel component; `PassportRestaurantCard`/`PassportHotelCard` are
  the only consumers. The footer is a single line — a rating icon plus
  "X.X average · N visits" — **"Last visit DATE" was removed** (UI Polish
  V2, explicit product direction: a collection card answers what/where/
  recognition/rating/visit-count/saved, not also a date, which belongs on
  Restaurant/Hotel Detail's own visit history). `PassportEventCard` is
  untouched — Events weren't part of the visual reference and neither
  pass touched it.

### Michelin star/Key color — explicitly resolved, not guessed

The visual reference's own instructions said Passport's Michelin stars/
Keys should render dark green, not gold — directly conflicting with
CLAUDE.md's settled, protected rule that gold is reserved exclusively for
Michelin star/Key recognition app-wide. Flagged and put to the user
explicitly rather than silently choosing an interpretation (per this
project's own "never guess" rule). **Decision: keep gold, unchanged,
everywhere** — `StarRow`/`KeyRow` were not modified. The reference
image's dark-green stars are treated as a mockup rendering choice, not a
literal instruction to reverse a settled product decision.

### Bookmark — a real, wired wishlist toggle (UI Polish V2)

The first version of this pass shipped `PassportCardBookmark` as a
deliberately static, non-interactive glyph — no existing "toggle wishlist
status from a Passport card" entry point existed, and adding one wasn't
in that pass's scope. UI Polish V2 explicitly authorized and requested
exactly that feature, naming the canonical mechanism to reuse: the
existing `WishlistRepository`/`wishlist` table, the same one Explore/
Restaurant Detail/the Wishlist subsection already read and write. No
second, parallel "saved" concept was created.

`PassportCollectionBody` loads wishlist membership in bulk alongside its
main data load (`WishlistRepository.loadWishlistRestaurantIds`/the new
`loadWishlistHotelIds` — the latter added this pass, mirroring the
former exactly, never one query per card) and passes `isWishlisted`/
`onToggleWishlist` down to each card. A tap flips local state
optimistically, calls `toggleWishlist`/`toggleHotelWishlist` (already
used elsewhere in the app), and reconciles or reverts against the
server's own returned state on mismatch or failure.

`PassportCardBookmark` owns its own `Material`/`InkWell`, isolating its
tap target from the card's outer tap-to-navigate `InkWell` — nested
`InkWell`s resolve to the innermost hit target in Flutter's gesture
arena, so a bookmark tap is fully consumed and never also opens
Restaurant/Hotel Detail. Directly tested, including proof that tapping
the bookmark never triggers the Supabase-eager detail-screen navigation
that would otherwise throw in a test with no live session.

## 5. Wishlist subsection

`WishlistBody` (renamed from `WishlistScreen`, same file) lost its own
`Scaffold`/`AnnotatedRegion`/back button/title-subtitle — all now owned
by the shared shell — and its previous in-body "Trips" quick-link
(`SubtleTextAction`), which became redundant once Trips was one tap away
on the shared local tab bar. Added a "YOUR WISHLIST" section heading,
matching Passport's own "YOUR COLLECTION" pattern. Everything else —
Restaurants/Hotels filter, loading/error/empty states, the venue list
itself, `WishlistRepository` calls — is unchanged. `WishlistVenueRow` and
`WishlistRowDivider` were not touched.

## 6. Ranking subsection

`PersonalRankingsTab` (My Ranking's real content: venue-type selector,
dimension dropdown, year filter, ranked list) required no changes at all
— it was already a clean, content-only widget with no header or
`Scaffold` of its own, the ideal shape for a subsection body. It's now
wrapped directly in a `_RankingBody` that supplies the light canvas
(`AppColors.background`) it already assumed, matching its previous host
(the deleted `RankingsScreen`). This is My Ranking only — Community's own
ranking (`CommunityRankingsScreen`) is unrelated and untouched, reached
only from the Community tab as before.

## 7. Trips subsection

`TripsBody` (renamed from `PlannedTripsScreen`, same file) lost its own
`Scaffold`/`SafeArea`/back button/title-subtitle. "Create trip" moved
from beside the old back button to beside a new "YOUR TRIPS" heading.
Trip loading, trip creation, planned-venue actions, and navigation to a
specific `TripDetailScreen` (still a normal pushed screen with its own
back arrow — the "same page" rule applies only to the four subsections
themselves) are all unchanged.

**Bug found and fixed**: the new "YOUR TRIPS" + Create-trip header row
overflowed by 11px at 320px width (confirmed via a widget test before
fixing) — `CsSectionTitle` had no `Expanded`/ellipsis to yield space to
the icon button beside it. Wrapped in `Expanded` with `maxLines: 1,
overflow: TextOverflow.ellipsis`, matching the defensive pattern used
throughout this codebase for exactly this shape (a title sharing a row
with a fixed-size trailing control).

## 8. Removed obsolete screens

`WishlistScreen`, `RankingsScreen`, and `PlannedTripsScreen` as
independently-scaffolded, pushed screen classes no longer exist —
audited first (`grep`) to confirm nothing outside `passport_screen.dart`
referenced any of the three; none did. `RankingsScreen`'s file
(`rankings_screen.dart`) was deleted outright (nothing in it survived —
`PersonalRankingsTab` was already extracted). `WishlistScreen`/
`PlannedTripsScreen` were repurposed in place (`WishlistBody`/
`TripsBody`, same files) rather than deleted-and-recreated, to keep the
diff minimal and git history intact.

## 9. Tests

- `test/passport_unified_shell_test.dart` (new) — the real `PassportScreen`
  pumped with fake, state-counting bodies (`_CountingBody`) and a
  push-recording `NavigatorObserver`: Passport-default state; tapping each
  of Wishlist/Ranking/Trips swaps only the `IndexedStack` index (no back
  button, no additional `Navigator.push`); repeated switching through all
  four multiple times never re-initializes an already-visited body's
  `State` (proves lazy construction *and* state preservation, not just
  that labels appear); local tab bar active/inactive styling swaps
  correctly; 320px responsive; map button present and gold-free.
- `test/passport_stats_panel_test.dart` (new, rewritten again for UI
  Polish V2) — three columns, exactly one globe emblem (never a
  per-metric icon), no wrapping bordered/background container,
  gold-free, 320/375/390/430px, long values at 320px, 1.6x text scale.
- `test/passport_cards_test.dart` — extended for UI Polish V2: bookmark
  outline-vs-filled state per `isWishlisted`, tapping the bookmark fires
  `onToggleWishlist` without also triggering the card's own Supabase-eager
  navigation, "Last visit"/the calendar icon are confirmed absent,
  320/375/390/430px.
- `test/passport_collection_header_test.dart` — extended with an explicit
  "no decorative emblem/logo" regression test.
- `test/wishlist_screen_shell_test.dart`, `test/trips_root_states_test
  .dart` — rewritten to mirror the new `WishlistBody`/`TripsBody` shapes
  (no Scaffold, no back button, new headings) rather than left mirroring
  a shell that no longer exists. The obsolete in-body "Trips" quick-link
  test (`wishlist_trips_entry_test.dart`) was deleted outright — the
  feature it tested was removed, not relocated.
- `test/primary_tab_headers_test.dart` — its comparison set was Passport/
  Explore/Rankings/Wishlist/Profile, a set that stopped matching the real
  bottom navigation as far back as Navigation & Information Architecture
  V2 (Explore/Passport/News/Community/Profile). Updated to the real five
  tabs rather than left validating headers that don't exist anymore.
- `test/passport_quick_access_row_test.dart` — deleted; its subject
  (`_PassportSecondaryNav`, push-based) no longer exists, fully
  superseded by `passport_unified_shell_test.dart`'s more rigorous,
  real-widget coverage of the new `_PassportLocalTabBar`.

**Full suite: 1830 passed, 0 failed** (1820 after the initial shell
pass; UI Polish V2 added net new coverage for the globe/no-panel stats
shape, the interactive bookmark, and the widened tab-bar spacing sweep).

## 10. No backend changes

Zero backend/schema/RLS changes. UI Polish V2's bookmark feature reuses
`WishlistRepository` end-to-end — its one addition,
`loadWishlistHotelIds`, is a plain read query against the existing
`wishlist` table mirroring the already-existing `loadWishlistRestaurantIds`
exactly, not a schema or RLS change. `PlannedTripsRepository`,
`RankingsRepository`, `VisitedRepository`, and
`EventConfirmedAttendanceRepository` are all called exactly as before.

## 11. Commit gate

Reviewed on the physical "kylan" iPhone (all four subsections, both
passes) and explicitly approved before this document's own commit.
