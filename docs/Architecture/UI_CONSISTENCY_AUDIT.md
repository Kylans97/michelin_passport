# UI Consistency Audit

Read-only design-system audit, companion to `FRIENDS_PRIVACY_COMMUNITY_INTELLIGENCE.md`. No screens were changed. Method: checked each screen for the legacy token set (`AppColors.background/card/surface/textPrimary/textSecondary`, `AppTypography`, direct `GoogleFonts.*` calls, standard Material `AppBar`) versus the current dark-editorial set (`AppColors.deepGreen/textOnDark/secondaryOnDark/subtleBorderDark/gold`, `CsTypography`, `CsSpacing`, `CsRadius`, `CsPrimaryButton`/`CsSecondaryButton`, `EditorialBackButton`).

## Canonical green system (Green Token Consistency Migration)

Two dark greens exist in `app_colors.dart` and both remain in active use —
they are **not interchangeable**, and confusing them is exactly what this
migration corrected:

| Token | Hex | Role |
|---|---|---|
| `AppColors.deepGreen` (alias of `brandGreen`) | `#16302A` | **PRIMARY.** Every full-screen dark canvas, masthead, hero, and the bottom navigation. If a widget's job is to BE the dark surface a screen opens on, it uses this. |
| `AppColors.forestGreen` | `#23473D` (visibly lighter) | **SECONDARY / elevated.** A panel, pill, or accent sitting ON TOP of a `deepGreen` canvas, one shade lighter so it stays visually distinct rather than disappearing into it (see `CsSurfaces.greenElevated`'s own doc comment — that role name predates this migration and already said exactly this). Also the color of ordinary text/icons drawn on the *ivory* content canvas (a separate, unrelated use — ivory text needs a dark, readable color, and this is the one already established everywhere). Never a canvas/masthead/hero itself. |
| `AppColors.ivory` | `#F4F0E7` | Primary light content surface. |
| `AppColors.taupe` | `#726A60` | Secondary text/hairlines on ivory. |
| `AppColors.secondaryOnDark` (`warmStone`) | `#B8B0A3` | Secondary text/icons on `deepGreen`. |
| `AppColors.gold` | `#AC8244` | Recognition only — Michelin stars (`StarRow`) / Keys (`KeyRow`). Never decorative, never a UI/selection state. |

Concrete example of the secondary role in production: `CsFilterChip`'s
`CsSurface.dark` unselected background is deliberately `forestGreen` — a
chip pill lifted off whatever `deepGreen` canvas it sits on (Wishlist's
Restaurants/Hotels selector today). See `cs_filter_chip.dart`'s own doc
comment.

A third, separate token — `AppColors.brandGreenLight` (`#25453C`, visually
near-identical to `forestGreen`) — is used across the whole Trips feature
and Profile's Journey/Friends card panels. It was flagged during this
migration's audit as a likely source of *additional* visual confusion
(easy to mistake for `forestGreen` on a physical device) but was
deliberately left untouched: it's a separate, already-established,
actively-used token outside this migration's scope (`forestGreen` call
sites), not a `forestGreen` usage to migrate or keep. Worth a dedicated
decision later; not decided here.

---

## Classification

| # | Screen | File(s) | Class | Evidence |
|---|---|---|---|---|
| 1 | Login | `lib/features/auth/login_screen.dart` | **A** | `Scaffold(backgroundColor: AppColors.deepGreen)`, `CsSpacing.*` layout, `CsPrimaryButton` |
| 2 | Signup | `lib/features/auth/signup_screen.dart` | **A** | `Scaffold(backgroundColor: AppColors.deepGreen)`, `CsTypography.screenTitle`, `CsPrimaryButton` |
| 3 | Passport | `lib/features/passport/passport_screen.dart` | **A** | `AppColors.deepGreen`/`forestGreen` canvas, `CsTypography.screenTitle`, `CsSpacing.pageHorizontal` throughout |
| 4 | Add-visit sheet (review creation) | `lib/features/visits/widgets/add_visit_sheet.dart` | **C** | Zero `Cs*` tokens; `AppColors.card`/`textPrimary`/`textSecondary`/`surface`/`gold*` throughout |
| 5 | Restaurant Detail | `lib/features/restaurants/restaurant_detail_screen.dart` | **C** | `Scaffold(backgroundColor: AppColors.background)`, `AppTypography.metadata`/`.body`; zero `Cs*` tokens |
| 6 | Hotel Detail | `lib/features/hotels/hotel_detail_screen.dart` | **C** | Identical pattern to #5 |
| 7 | Explore | `lib/features/explore/explore_screen.dart` | **A** | `AppColors.deepGreen` canvas, `CsTypography.eyebrow`, `CsSpacing.pageHorizontal` throughout |
| 8 | Guides (landing + catalogue) | `lib/features/guides/guides_screen.dart`, `michelin_restaurant_guide_screen.dart` | **A** | `Scaffold(backgroundColor: AppColors.deepGreen)`, `CsTypography.screenTitle`/`.eyebrow`, `CsSpacing.section` |
| 9 | Rankings | `lib/features/rankings/rankings_screen.dart` | **C** | `Scaffold(backgroundColor: AppColors.background)`, `SliverAppBar` via `AppTypography.editorialHeading`; zero `Cs*` tokens |
| 10 | Wishlist | `lib/features/wishlist/wishlist_screen.dart` | **C** | `SliverAppBar(backgroundColor: AppColors.background)`, `AppColors.card`, direct `GoogleFonts.inter` calls |
| 11 | Trips (root + detail) | `lib/features/trips/planned_trips_screen.dart`, `trip_detail_screen.dart` | **A** | `Scaffold(backgroundColor: AppColors.deepGreen)` + `CsTypography`/`CsSpacing` throughout. One trivial legacy exception: `trip_detail_screen.dart`'s `_showSnack` snackbar helper still uses `AppColors.textPrimary`/`GoogleFonts.inter` directly |
| 12 | Profile | `lib/features/profile/profile_screen.dart` | **C** | `Scaffold(backgroundColor: AppColors.background)`, `AppColors.card`/`surface` throughout; zero `Cs*` tokens. **Also currently broken** — see below |
| 13 | Events | `lib/features/events/events_screen.dart` | **C** | `Scaffold(backgroundColor: AppColors.card)`, `SliverAppBar` via `AppTypography.editorialHeading`; zero `Cs*` tokens |
| 14 | Event Detail | `lib/features/events/event_detail_screen.dart` | **C** | `Scaffold(backgroundColor: AppColors.background)`, standard `AppBar`, `AppTypography.metadata`/`.body` |
| 15a | Country picker sheet | `lib/core/widgets/country_picker_sheet.dart` | **C** | `AppColors.card`/`divider`/`textPrimary`, direct `GoogleFonts.inter` calls |
| 15b | Date card | `lib/features/visits/widgets/date_card.dart` | **C** | `AppColors.surface`/`cardBorder`/`gold*`/`textPrimary`, direct `GoogleFonts.inter` calls |
| 15c | Save button | `lib/features/visits/widgets/save_button.dart` | **C** | `AppColors.gold` fill, direct `GoogleFonts.inter`; no `CsPrimaryButton` |

**No B (partially modernized) screens found** among the 15 sampled — the split is clean, not blended within a single screen (aside from Trips' one trivial snackbar exception).

## Overall pattern

The app divides cleanly along **when a feature was built**, not by feature importance. Everything from the recent "dark editorial" push — Auth (Login/Signup), Passport, Explore, Guides, and Trips — is fully on the current system (A). Everything that predates that push — Restaurant/Hotel Detail, Rankings, Wishlist, Profile, Events/Event Detail, the visit-review creation sheet, and the shared pickers/cards it depends on (country picker, date card, save button) — remains entirely on the original light-ivory system (C). This matches `app_colors.dart`'s own documentation of `deepGreen`/`textOnDark`/`secondaryOnDark`/`subtleBorderDark` as an additive foundation not yet adopted everywhere.

## A pre-existing functional bug found during this audit (not a design-system issue)

`lib/features/profile/profile_screen.dart` renders a "Friends" section (via `FriendshipRepository.searchUsers`/`getFriends`/`getPendingRequests`), a "Community Stats" tier-distribution section, and a tier badge — all backed by tables/views (`friendships`, `user_tiers`, `tier_stats`, `profiles.tier`) that were dropped by the `20260805141519_production_schema_v1.sql` migration and never recreated. A live read-only query against the linked production database during this audit confirmed none of `friendships`/`user_tiers`/`tier_stats`/`trophies`/`user_trophies` exist, and `profiles` has exactly `id, username, display_name, avatar_url, home_country_code, is_public, created_at` — no `tier` column. **These Profile screen sections will throw at runtime today**, independent of anything in this spike. See `FRIENDS_PRIVACY_COMMUNITY_INTELLIGENCE.md` §1 and §44 for how this intersects with the friendship work this spike recommends.

## Redesign priority (informational — not requested to implement)

If/when legacy screens are modernized, the natural order follows this spike's own MVP dependency chain, not alphabetical or arbitrary order:

1. **Profile** — already broken (above), and is the literal home of the friend-request UI this spike recommends building next. Fixing the schema gap and modernizing the visual system are best done in the same pass, since the Friends section needs to be rebuilt against a real schema either way.
2. **Add-visit sheet** — becomes the home of any future visibility control (§11 of the main document); worth modernizing when that ships, not before.
3. **Restaurant/Hotel Detail** — highest-traffic legacy screens (every Explore/Guides/Trips result routes here), but functionally correct today; a visual-only pass, not urgent.
4. **Rankings, Wishlist, Events/Event Detail** — lower urgency; no functional or privacy work in this spike touches them directly.
5. **Shared pickers/cards** (country picker, date card, save button) — used across several legacy screens; ride along with whichever screen above needs them modernized first rather than a standalone pass.

This is a sequencing observation for a future design task, not a commitment made by this spike.

## Update — Wishlist UI Consistency Step 1

Row 10 above (Wishlist, Class C) is now stale: Wishlist has been migrated
to the current editorial system. No repository, RLS, or navigation
changes — presentation only.

- **Canvas**: deep-green masthead (`WISHLIST`, supporting line,
  Restaurants/Hotels selector) over an explicit ivory body — the same
  composition Guides' catalogues and Friends use, adapted for Wishlist's
  own architecture: it is a permanent bottom-navigation tab body (see
  `app.dart`'s `_MainNavigation`), not a pushed route, so it owns no
  `Scaffold` of its own and needs no back affordance — the tab shell
  already provides both. Safe area: scoped
  `AnnotatedRegion<SystemUiOverlayStyle>(value: .light)`, deep-green
  reaching the status bar, explicit ivory `ColoredBox` body — the same
  fix pattern established for `GuideCatalogueLayout`/`FriendProfileScreen`/
  `FriendsScreen`. (Green Token Consistency Migration: `AppColors.
  deepGreen`, not `forestGreen` — see this doc's "Canonical green system"
  section; this masthead originally shipped on `forestGreen`.)
- **Selector**: `CsFilterChip` (`CsSurface.dark`) — restrained pill chips,
  reusing an already-approved-but-previously-unwired primitive rather than
  reskinning the shared `VenueTypeSelector` (which stays legacy/gold for
  its other call site, `visited_map_screen.dart`, out of scope here).
  Restaurants/Hotels only, Restaurants default — unchanged, already
  regression-tested by `wishlist_default_venue_type_test.dart`.
- **Rows**: `WishlistVenueRow` replaces the old bordered `WishlistCard` —
  same 52×52 `VenueThumbnail` + inline `StarRow`/`KeyRow` + city/flag
  language `FriendWishlistTile` established, plus its own remove
  affordance (a second, independently-semantic target, not folded into
  the row's merged navigation label). Taupe hairlines between rows
  (N-1, no orphan trailing divider), never a card border.
- **Removed as a deliberate simplification, not a functional regression**:
  the inline "Plan visit"/"Plan stay" shortcut each row used to offer.
  The target row structure has no slot for a secondary action beneath the
  name, and `showPlanVenueSheet` remains one tap away on
  `RestaurantDetailScreen`/`HotelDetailScreen` (which the row's own tap
  already opens) — the capability isn't lost, only the direct shortcut.
- **Explore CTA in empty states**: omitted. Wishlist and Explore are
  sibling tabs in the same `IndexedStack` with no shared controller
  exposing the active tab index — switching tabs from within a tab body
  would require new cross-tab navigation infrastructure, out of scope for
  a UI-only pass.

## Update — Bottom Navigation UI Consistency Step 1 + Step 1A

`_MainNavigation` (`app.dart`) redesigned onto the current editorial
system. Information architecture frozen throughout both steps: exactly 5
destinations, same order/labels/icons/routing as before —
Passport/Explore/Rankings/Wishlist/Profile, `IndexedStack`-backed (all 5
tab widgets stay permanently mounted; switching `_index` never rebuilds or
disposes a hidden tab, which is why Explore's filters, Wishlist's
Restaurants/Hotels selection, and scroll position all survive a tab
switch with no code of their own needed for it). No Private Chefs tab, no
tab added/removed/reordered/renamed.

Step 1 shipped an ivory navigation surface; Step 1A (physical-device
feedback) changed the surface to a dark green; the Green Token Consistency
Migration then corrected *which* dark green — `AppColors.deepGreen`, not
`forestGreen` (see "Canonical green system" above) — after physical
review found the bar visibly didn't match Explore/Passport/Event Detail's
own `deepGreen` canvases. The values below are the current, final state.
Documented once rather than as three separate, partly-contradictory
entries.

- **Surface**: `AppColors.deepGreen`, explicit on the wrapping `Container`
  and on `NavigationBar.backgroundColor` — never relying on
  `_MainNavigation`'s own `Scaffold.backgroundColor` (left as the legacy
  `AppColors.background`, untouched — every tab body already paints its
  own full-bleed background, so nothing actually depends on it). The
  composition is now a deliberate green-top/ivory-middle/green-bottom
  frame, matching how several primary screens already open on a
  `deepGreen` hero.
- **Selected**: ivory icon + label (`CsTypography.navigation`, `w600`).
  **Unselected**: `AppColors.secondaryOnDark`, `w500`. No gold anywhere —
  Step 1's own starting point had a gold `indicatorColor`/selected-label
  color, a direct hard-rule violation corrected in Step 1.
- **Indicator**: `indicatorColor: Colors.transparent` — no Material
  selection pill; selection reads through icon/label tone and weight
  alone.
- **Hairline**: none. Step 1 used a taupe hairline (right for an
  ivory-on-ivory transition); Step 1A removed it — a dark-green bar
  against an ivory tab body is already a full color-block boundary, the
  same reasoning `GuideCatalogueLayout`'s own masthead-to-content
  transition already established.
- **Elevation**: `shadowColor`/`surfaceTintColor: transparent`,
  `elevation: 0` — no floating-card shadow.
- Bar `height` (68) and icon size (22) are unchanged from before Step 1 —
  no evidence either was a problem, so left alone rather than
  gratuitously altered.
- `CsNavStyle` (`cs_theme.dart`) — originally a "documented future
  direction" written before the ivory/deep-green system existed,
  proposing a dark-green bar with a mutedBrass (gold-family) selected
  state. Corrected in Step 1 to ivory/forestGreen/taupe, corrected again
  in Step 1A to forestGreen/ivory/secondaryOnDark, and corrected once
  more in the Green Token Consistency Migration to
  deepGreen/ivory/secondaryOnDark — the actually-canonical primary
  surface. Still unused/inert elsewhere (`_MainNavigation` doesn't
  reference it), kept only as a named reference — three corrections in a
  row is itself the argument for treating this comment as descriptive,
  never authoritative.

**Step 1B finding (not a code change): two distinct "forest greens"
coexist in this app.** `AppColors.forestGreen` (`0xFF23473D`) is what
Wishlist, Friends, and Guides — and the bottom nav — all use.
`AppColors.deepGreen` (an alias of `brandGreen`, `0xFF16302A`, visibly
darker) is what Explore's canvas, Passport's canvas, and Event Detail's
hero still use — an older token that predates `forestGreen` and hasn't
been migrated in this session's UI-consistency work. Physical-device
feedback that "the nav green doesn't match" was accurate, but the
mismatch is between `deepGreen` and `forestGreen` on *those* screens, not
a bug in the bottom nav: the nav already resolved to the same
`AppColors.forestGreen` Wishlist/Friends/Guides use, byte-for-byte, in
`app.dart`, `AppTheme.chasingStars.navigationBarTheme`, and `CsNavStyle`
alike. It's most visible against Passport/Explore specifically because
the nav sits directly, permanently adjacent to their `deepGreen` canvas —
unlike Wishlist, where the nav and header don't touch. Per this step's
own explicit instruction, Explore/Passport/Event Detail were not changed
to match; `forestGreen` remains the token multiple already-approved
screens agree on, and is what the nav (correctly) targets.

## Update — Primary Tab Header Consistency Step 1

Physical-device review of the five bottom-navigation tabs
(Passport/Explore/Rankings/Wishlist/Profile) found their title text
starting at visibly different vertical positions, and inconsistent
casing (`PASSPORT`/`EXPLORE`/`WISHLIST` vs. `Rankings`/`Profile`).
Wishlist was designated the physical reference. Presentation only — zero
repository/navigation/data changes on any of the five screens.

**Title Case** — all five now read exactly `Passport` / `Explore` /
`Rankings` / `Wishlist` / `Profile`. The first three were literal
uppercase strings (not a shared widget, not `.toUpperCase()`), fixed at
the source in each screen's own header. `Rankings`/`Profile` were already
correct. Section eyebrows elsewhere (`MICHELIN GUIDE`, `VISITED`,
`GOING`, Friend Profile's own `WISHLIST` section label, etc.) are
unrelated and untouched — this only ever concerned the five primary
screen titles.

**Canonical vertical position** — `SafeArea` (or the screen's own
built-in equivalent) + `CsSpacing.lg` before the title's top edge, with
`CsSpacing.pageHorizontal` as the title's left inset. Both are Wishlist's
own pre-existing values, unchanged; every other screen's title now
matches them:
- **Explore**: top padding was `CsSpacing.sm`, now `CsSpacing.lg`.
- **Passport**: title used to sit below a separate map-icon row (added
  real height above it); the icon now sits beside the title/subtitle in
  one `Row` instead of stacking above it, and the extra nested
  `CsSpacing.sm` horizontal indent around the title `Column` (which had
  put its left edge at `pageHorizontal + sm`, not just `pageHorizontal`)
  is removed. Top padding was `CsSpacing.sm`, now `CsSpacing.lg`.
- **Profile**: top `ListView` padding was `CsSpacing.md`, now
  `CsSpacing.lg`.
- **Rankings**: structurally different from the other four — a Material
  `SliverAppBar` whose `title:` slot always vertically *centers* its
  content within `toolbarHeight`, which cannot be pinned to a fixed
  offset the way a plain `SafeArea`+`Padding` header can. Fixed by
  moving the title into `flexibleSpace` (a `SafeArea`+`Padding`+`Align`
  matching the other four exactly) instead of `title:`, leaving
  `toolbarHeight` (64, already correctly sized), `pinned: true`, and the
  entire `TabBar`/`TabController`/tab content wiring untouched. Verified
  empirically (not just by inspection) via a widget test comparing all
  five screens' rendered title `Y` — all five land within 1px of each
  other.

**Typography** — all five now use `CsTypography.screenTitle` (same font,
size, weight, line height). Rankings previously used the older
`AppTypography.editorialHeading` at `fontSize: 22`, a visibly smaller,
different-family title — this was the single biggest hierarchy mismatch
found, corrected alongside the position fix rather than as a separate
pass, since both required touching the same `SliverAppBar`.

**Color** — all five title `Text` widgets now use `AppColors.ivory`
(previously a mix of `ivory` and the separate, near-identical
`AppColors.textOnDark` token — see this doc's "Canonical green system"
section for why two near-identical tokens are worth normalizing away
where the wording explicitly calls for it, as this task's brief did:
"Color should follow surface: on deepGreen → ivory").

**Not changed**: `AppColors.deepGreen` remains every screen's primary
canvas (Passport/Explore/Rankings/Profile were already correct from the
Green Token Consistency Migration; this step never touched a canvas
color, only the title text within it). Bottom navigation's own approved
state (surface/selected/unselected/indicator/height) — untouched.
Rankings' `backgroundColor: AppColors.brandGreen` was renamed to the
canonical `AppColors.deepGreen` (identical value — `brandGreen` is
`deepGreen`'s alias — a naming-consistency touch, not a color change).
`AppColors.brandGreenLight` (Profile's Journey/Friends panels) — still
explicitly out of scope, not migrated in this step either.

**Known pre-existing gap, not fixed here (out of scope)**: only Wishlist
currently scopes an `AnnotatedRegion<SystemUiOverlayStyle>` for its
status-bar icon color: Passport, Explore, Profile, and Rankings have none
— predates this step, unrelated to title casing/position, and matches
this session's established pattern of treating status-bar-icon-color
fixes as their own dedicated task rather than bundling them into
unrelated work.
