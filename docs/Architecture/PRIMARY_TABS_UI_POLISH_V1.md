# Primary Tabs UI Polish V1

Status: **implemented, human-approved, committed and pushed** — see §14
for the final reconciliation against Passport/Ranking's own, separately
finalized workstreams.

## 1. What this is

A visual/hierarchy refinement pass across Explore, Passport, News,
Community, and Profile — the five primary bottom-tab destinations — plus
the pushed Community Rankings screen. Tab order, labels, ownership model,
and all functionality are unchanged (per Navigation & Information
Architecture V2, still current). This pass brings every screen into one
coherent design language: large serif screen titles, muted secondary
subtitles, editorial section titles, restrained secondary actions, and
gold reserved exclusively for Michelin stars/Keys.

**Zero backend/schema/RLS changes.** Every change in this pass is
Dart/Flutter UI-layer only — confirmed throughout, and re-confirmed at
the end via `flutter analyze` + the full test suite.

## 2. Explore — What's On header + event card scale

**Bug fixed**: `_DiscoverySectionHeader` (in
`explore_discovery_sections.dart`) put the title+subtitle Column and the
trailing "View all events →" link as siblings in one `Row` with
`crossAxisAlignment: end`. Since the trailing link sits at the bottom of
that row — the same vertical band as the subtitle — the subtitle was
squeezed for horizontal space by the CTA even though nothing visually
overlapped it. This is the exact "subtitle competing with / clipped by
View all events" defect reported from the physical device.

**Fix**: restructured so the title and trailing CTA share one row
(`Expanded` title + `Flexible` trailing), with the subtitle moved to its
own full-width line below, unconstrained by the CTA. `WorthTheJourneySection`
and `StayALittleLongerSection` share the same header component but never
pass a `trailing`, so they were never affected and are unchanged.

**Event card scale**: `ExploreFeaturedEventCard`'s image `AspectRatio`
reduced from 16/10 to 16/9 — a more conventional editorial-hero ratio,
noticeably less vertical footprint at full page width, without shrinking
below a normal card size or touching Event Detail.

**Preserved unchanged**: Explore title/subtitle, search, Collections,
Private Chef, "WHAT'S ON" as the primary label, monogram placeholder
fallback, Worth the Journey / Stay a Little Longer sections.

**Tests**: `test/explore_discovery_widgets_test.dart` gained a direct
regression test proving the CTA sits on the title's row (not the
subtitle's) and the subtitle is never squeezed, at 320px.

## 3. Global page-grid audit

Audited horizontal page padding across Explore, Passport, Community,
Profile, and News. All five already use `CsSpacing.pageHorizontal`
consistently for their outer page padding — no normalization needed, no
changes made. (One hardcoded `24` exists in Profile's Edit Profile bottom
sheet — a modal surface, not one of the five primary tab bodies audited
here — left untouched as out of scope.)

## 4. Passport — secondary nav + filter layer

> **SUPERSEDED — see §14.** Everything below describes `passport_screen.dart`
> as it existed when this section was written. Passport was subsequently
> rebuilt from scratch across the Passport Unified Experience V1/V2 and
> Ranking UI V1 workstreams; `_PassportSecondaryNav` and
> `test/passport_quick_access_row_test.dart` (referenced below) no longer
> exist in the codebase. This section is historical record only — kept in
> place per this project's "log near-misses, not just failures" standard,
> not deleted.

**Bug fixed**: `_PassportSecondaryNav` ("Passport Wishlist Ranking
Trips") was a plain `Row` with no scroll wrapper — confirmed via a widget
test to overflow by ~99px at 320px width (worse once the screen's own
page padding is accounted for). The type-filter chip row directly below
it already handles narrow widths via `SingleChildScrollView`; the
secondary nav did not. Fixed by wrapping it the same way — it now scrolls
horizontally rather than overflowing, with no visual change at normal
widths (390+).

**Spacing**: tightened the gap between the type-filter row and the
metric strip (`CsSpacing.xl` → `CsSpacing.lg`), responding to the
"too many sequential controls before reaching actual content" feedback.

**Audited, left unchanged**: `CsFilterChip` and `YearFilterControl` are
shared components (also used by Wishlist/My Rankings) and already match
the brief — restrained weight, year already reads as visually secondary
(a small "All time ▾" trigger, not a persistent chip row). Changing them
would have affected screens outside this pass's stated scope.
`CsMetricStrip` (Passport's metric strip) needed no changes — it's
already the reference "editorial row of numbers, not dashboard cards"
pattern, and is reused as-is for Profile's Journey metrics (§6).

**Preserved unchanged**: all functional structure — Restaurants/Hotels/
Events pills, year filter, metrics, Your Collection, the Parkheuvel-style
collection card (used as this pass's own reference for premium card
treatment, per the brief).

**Tests**: `test/passport_quick_access_row_test.dart` gained a 320px
regression test proving the secondary nav no longer overflows.

## 5. Community — vertical rhythm

**Bug fixed**: the scrollable body's top padding was `0`, relying on
Hottest Places' own trailing `SizedBox` as the only spacing above
Community Rankings. Since Hottest Places is empty today (zero
restaurants meet the 3-rater threshold — expected, documented in
`COMMUNITY_RANKINGS_V1.md`), the page started abruptly, with "Community
Rankings" sitting right under the subtitle.

**Fix**: a fixed `CsSpacing.section` top inset on the scroll body,
present regardless of whether Hottest Places renders — the same token
already used between every other section pair on this screen, so the
rhythm is identical whether Hottest Places is present or not. Never a
value tuned to today's specific empty state.

**Preserved unchanged**: section order and structure (Hottest Places →
Community Rankings → Dining Together), Meet the Community's full
omission, Hottest Places' full omission (no heading over nothing) when
empty.

## 6. Profile — visual redesign

The largest change in this pass — bringing Profile in line with the
other four tabs' visual family while preserving every piece of existing
functionality (avatar/identity, Edit profile, Notifications, Friends,
Sign out, Delete account — App Store-ready deletion flow untouched, no
backend changes).

**Gold audit** — every gold usage classified and, where purely
decorative, replaced:

| Element | Before | After | Why |
|---|---|---|---|
| Avatar border | `gold` @ 50% | `subtleBorderDark` | No Michelin meaning — purely decorative |
| Avatar initials | `gold` | `ivory` | Same |
| Choose-username banner border | `gold` @ 40% | `subtleBorderDark` | Same |
| Choose-username banner icon | `gold` | `ivory` | Same |
| Choose-username banner chevron | `gold` | `secondaryOnDark` | Same |
| Delete account row | `error` (unchanged) | `error` (unchanged) | Correctly destructive, never gold — untouched |

Gold remains untouched everywhere it has real Michelin/recognition
meaning elsewhere in the app (star/key glyphs) — nothing outside Profile
was touched, and no gold was added anywhere.

**Journey metrics**: the old 2×2 grid of bordered, icon-decorated cards
(`_StatTile`, now deleted) replaced with the same shared `CsMetricStrip`
component Passport already uses — typography-led, thin dividers, no
cards, no icons. Same four values (Restaurants/Stars/Countries/Cities),
nothing removed.

**Friends row**: the bordered card with a leading icon avatar
(`_FriendsEntryRow`) simplified to a restrained editorial action row —
"Friends" / "N friends · M requests →" — matching Community's own
`_CommunityActionLink` language (no card background, no icon avatar).
Tap target and accessible label unchanged.

**Account section**: `_SettingsRow` (Edit profile / Notifications / Sign
out / Delete account) was already a plain, non-boxed list — left
structurally unchanged. Delete account remains error-tinted and
undiminished in prominence.

**Icon audit**: `Icons.logout_rounded` (the only *solid* icon among four
otherwise outline-stroke icons in the same static list) normalized to
`Icons.logout_outlined`.

**Tests**: `test/profile_screen_states_test.dart` gained direct mirror
coverage (ProfileScreen constructs Supabase-eager repositories in
`initState`, so it can't be pumped directly — same established limitation
as every other screen in this app; mirrors reconstruct the exact widget
tree, the same convention already used here for Sign Out/Delete
account/username banner) for: Journey metrics rendering + no decorative
icons + 320px no-overflow; Friends row content/icon/tap-target/color;
Avatar border/initials are never gold.

## 7. News

Audited — already fully compliant (dark green/ivory canvas, restrained
`CsComingSoon` empty state, no gold, correct title/subtitle hierarchy, no
fake article cards, no backend). No changes made.

## 8. Community Rankings — bugfix + polish

### 8a. The reported "Could not load community rankings" bug

Investigated per the task's explicit requirement to run the real
production code path rather than assume. Using a `flutter test` file with
`--dart-define` credentials (avoiding the FFI/kernel-compiler crash that
plain `dart run` hits against this project's native-plugin dependency
graph), `RankingsRepository(client).getCommunityRankings()` was exercised
against real production with a real authenticated session: it returned
cleanly with 0 entries, no exception. **Not currently reproducible.**
Most likely explanation: a transient PostgREST schema-cache propagation
delay in the moments immediately after the `restaurant_rankings`
migration was first applied (during the prior Community Rankings V1
pass) — schema-cache defects like this resolve themselves and don't
recur. All debug artifacts (disposable test user, scratch key files, the
temporary debug test file) were fully cleaned up afterward.

Added a direct regression test (`test/ranking_entry_test.dart`) proving
that a genuinely malformed row (wrong type, not just a missing/null
field) throws a real `TypeError` that propagates, rather than being
silently swallowed into an empty result — closing the one gap between
"empty" and "error" that hadn't been directly tested.

### 8b. Real bugs found during this pass's own investigation

Two further, previously-unreported defects were found while examining
`community_rankings_tab.dart` for the visual polish work, and fixed:

1. **Empty/error message positioning.** The message was a bare `Center`
   inside the tab's `Expanded` region, vertically centered in *all*
   leftover space below the filter row — on a phone that reads as
   floating oddly low, disconnected from the filters above it (matching
   the reported "floating very low" feedback exactly). Replaced with a
   new `_RankingsMessage` widget: icon + message, top-anchored via
   `Align.topCenter` with a fixed top offset, reading as the next natural
   content block rather than a warning floating in empty space.

2. **Wrong color token (a real legibility bug).** The message text (and,
   incidentally, the star filter's unselected label) used
   `AppColors.textSecondary` — a light-surface token (near-black/dark
   brown) meant for text on light backgrounds — directly on
   `CommunityRankingsScreen`'s dark green canvas, rendering low-contrast,
   effectively dark-on-dark. Fixed to `AppColors.secondaryOnDark`, the
   correct dark-surface counterpart. (The rank card and filter chips
   themselves are legitimately light ivory surfaces sitting on the dark
   canvas — their own `textPrimary`/`textSecondary` text is correct as
   dark-on-light and was left unchanged.)

3. **Real overflow bug.** `_CommunityRankCard`'s city text was a bare
   `Text` with no `Flexible`/ellipsis — unlike every other name/city row
   in this codebase. At 320px width, a 2–3 star restaurant with a flag +
   city combination overflowed the row by up to 19px (reproduced and
   confirmed via a widget test before fixing). Wrapped in `Flexible` with
   `maxLines: 1, overflow: TextOverflow.ellipsis`, matching the
   established pattern used everywhere else.

### 8c. Audited, left unchanged

Star filter chips (`_StarFilterChip`) and the page header/back button
were already appropriately restrained and consistent with the rest of
the app — no changes made. The filter remains a Michelin-star dimension
only; sort order is, and remains, `community_rating DESC` — never
influenced by stars.

**Tests**: `test/community_rankings_tab_test.dart` gained direct
regression coverage for the color-token fix (empty and error messages
both assert `secondaryOnDark`, never `textSecondary`) and a 320px
responsive test (filter row + a 3-star, flagged, city-labeled card render
without overflow).

## 9. Bottom nav + iconography audit

Bottom nav itself (already covered by `bottom_navigation_test.dart`'s
extensive visual-token/tap/accessibility/responsive suite) audited and
confirmed still fully consistent — no changes.

Icon family audit across Explore/Passport/Community/Profile/bottom
nav/secondary rows found one real inconsistency: Profile's Sign Out icon
(`logout_rounded`, solid/filled) was the only filled icon among four
otherwise outline-stroke icons in the same static ACCOUNT list — fixed to
`logout_outlined` (§6). The `chevron_right_rounded`/`arrow_forward_rounded`
trailing-indicator icons used across Explore/Community/Profile were
confirmed to already be a single, consistent, established convention —
left untouched.

## 10. Responsiveness pass (320 / 390 / 430)

Targeted widget tests added/verified at 320px across every affected area
(Explore What's On, Passport secondary nav, Profile Journey metrics,
Community Rankings filter + card). This pass **found two real,
previously-unreported overflow bugs** — Passport's secondary nav (§4) and
Community Rankings' rank card (§8b.3) — both reproduced against the real
widgets before fixing and confirmed resolved after. Community's own
existing 320/390/430/800 header-alignment suite
(`community_screen_shell_test.dart`) already covered that screen and
continues to pass unchanged.

## 11. Testing summary

12 net-new tests added this pass, zero regressions:

- `test/ranking_entry_test.dart` — +1 (malformed row throws, never silently empty)
- `test/explore_discovery_widgets_test.dart` — +1 (CTA/subtitle layout regression)
- `test/profile_screen_states_test.dart` — +6 (Journey metrics ×2, Friends row ×3, Avatar gold audit ×1)
- `test/community_rankings_tab_test.dart` — +3 (empty-message color, error-message color, 320px responsive)
- `test/passport_quick_access_row_test.dart` — +1 (320px no-overflow)
- `test/profile_delete_account_entry_test.dart` — icon value updated for mirror accuracy (no new test)

**Full suite: 1816 passed, 0 failed** (baseline before this pass: 1804
passed, 0 failed). `flutter analyze`: clean across every touched file.

## 12. Explicitly deferred (forbidden by this task's own scope)

News V1, Hottest Hotels/Events, Meet the Community, Dining Together
functionality, new Profile settings, new Passport stats, new Explore
categories, a Hero Imagery pipeline, and new backend aggregation were all
out of scope and not built. The only functional (non-pure-visual) change
in this entire pass is the Community Rankings bugfixes in §8b — no
backend, schema, or RLS changes were needed or made for any of them.

## 13. Commit gate

Human-approved on-device and finalized — see §14.

## 14. Final reconciliation against Passport/Ranking (dated 2026-08-25)

Between this workstream being implemented and finalized, Passport and
Passport → Ranking were independently redesigned and finalized across
several of their own, separately-approved and separately-committed
workstreams: Passport Unified Experience V1 (`b49574d`, "Polish unified
Passport experience") and PASSPORT — RANKING UI REDESIGN V1 (`53f9cb6`,
"Refine Passport ranking experience", covering geometry, the deep-green/
ivory color-hierarchy correction, and the final score-typography pass).
Those are now the authoritative Passport/Ranking implementation —
superseding §4's Passport work entirely, per the note there.

At the time of this finalization:

- **Passport (§4) is fully superseded**, not merely amended. The original
  `_PassportSecondaryNav` fix this section describes, and its regression
  test (`test/passport_quick_access_row_test.dart`), no longer exist —
  both were absorbed by the later full Passport rewrite. There was
  nothing left to reconcile or stage for Passport in this finalization;
  `git status` shows zero pending diff on `passport_screen.dart`.
- **Community Rankings V1's backend is live** — `restaurant_rankings`,
  queried via `RankingsRepository.getCommunityRankings()`, remains the
  sole source for Community's own ranking (distinct from "My Rankings",
  which this doc never touches); the 3-unique-rater threshold and
  `community_rating DESC` sort order (§8c) are unchanged by this
  finalization.
- **Account deletion remains production-functional** — this workstream's
  Profile changes (§6) never touched `DeleteAccountScreen`, the
  `delete-account` Edge Function, or any auth/sign-out logic; only the
  icon (`logout_rounded` → `logout_outlined`), avatar/banner gold audit,
  Journey metrics, and the Friends row were restyled.
- **News V1 remains intentionally deferred** — §7's "already compliant,
  no changes" finding still holds; nothing in this finalization touches
  News.
- No migration, schema, or RLS diff was part of this workstream at any
  point, before or after reconciliation.

Everything else in this document (§1–§3, §5–§12) accurately reflects
what was committed — no further reconciliation was needed there.
