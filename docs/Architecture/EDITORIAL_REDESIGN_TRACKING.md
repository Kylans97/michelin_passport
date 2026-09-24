# Editorial (Magazine) Redesign — Tracking

Working checklist for the app-wide editorial/magazine redesign (§0 foundation
+ screens 1–6). Not a design spec — see the conversation/commit history for
that. This file only tracks status and explicitly-deferred work, so nothing
agreed along the way gets silently dropped.

## §0 — Foundation (tokens + shared components)

Status: **built, reviewed, approved.**

- Tokens: `lib/core/constants/app_colors.dart`, `lib/core/theme/cs_typography.dart`
- Components: `CsEditorialTabBar`, `CsEditorialTabs`, `CsOrnamentDivider`,
  `CsInvitationCard`, `FriendsStack`, `CsEditorialImageFallback`,
  `CsIndexRow`, `CsCountryLabel`/`CsKeyGlyph`/`CsEditorialKeyRow`/
  `CsEditorialStarRow`, `CsMastheadLogo` — all under `lib/core/widgets/`.

**Deferred, explicitly (not forgotten):**

- [ ] Unit/widget tests for the 9 §0 components. Deliberately skipped while
      the components were still first-review-pending ("uitputtend testen
      voordat ik het gezien heb is voorbarig") — write these once the
      screens that exercise them are in and the components have proven
      stable in real use, not before.
- [ ] `CsEditorialTabBar` is built and previewed but **not wired into
      `app.dart`** — global blast-radius change, deliberately left as a
      separate decision. Confirmed 2026-09-24: leave unwired for now.
- [ ] The tab bar uses Material `_outlined`/`_rounded` icons, not literal
      1.4pt hand-drawn line icons. Confirmed 2026-09-24: fine for now.
      Swappable later without touching call sites.

## Screens (in order, per the agreed Werkwijze — each its own commit)

Order changed mid-stream: after §0 was approved, the very next request was
"Ga door met scherm 1" (Explore), but before any work started on it the user
redirected to a full, separately-specced three-layout redesign of the
Friend Profile screen instead (originally screen 6). That work is done;
Explore ("Tonight") is still next once resumed.

- [ ] 1 — Explore "Tonight" cover — next up
- [ ] 2 — Events list (calendar edition)
- [ ] 3 — Event detail (the invitation)
- [ ] 4 — Passport (stamped page) — 4a header/tabs/stats only; the stamp
      pages themselves already ship (see the Passport ink-stamp redesign,
      commit 29f5178)
- [ ] 5 — Community (your circle)
- [x] 6 — Friend profile — **built out of order, twice.** First pass:
      three full layouts (A/B/C) behind a `kDebugMode` A/B/C picker, per
      an explicit "build 3 layouts so we can compare them" request. Second
      pass, same session, **superseded the first entirely**: one profile,
      three TABS (Overview / Passport / Together) plus a "Plan a dinner"
      sheet — the picker, `FriendProfileLayout` enum, and all three
      `layouts/friend_profile_layout_{a,b,c}.dart` files were deleted, not
      kept alongside. If anything here reads as "three layouts", that's
      stale — the current shape is the one described below.
  - Style correction in the second pass: **no gold text anywhere** (not
    even for the "Stars" stat, which the first pass had rendered gold) —
    gold is ornament-only (stars, Key glyphs, the active tab's
    underline, the invitation card's border, the primary button's own
    fill). Every numeral/label/link is ivory or a warm stone tint.
  - Files: `friend_profile_screen.dart` (rewired again: a `TabController`
    + `NestedScrollView` with a pinned tab-bar sliver, replacing the old
    layout dispatcher), `friend_profile_data.dart`,
    `friend_profile_dinner_invitation.dart` (new stub model),
    `friend_profile_all_visits_screen.dart` (new, the Overview tab's
    "All →"), `tabs/friend_profile_{overview,passport,together}_tab.dart`
    (new), `widgets/friend_profile_{header,stamp,stamp_page,verdict_row,
    widgets,venue_picker_sheet,plan_dinner_sheet}.dart` (header/stamp/
    stamp_page/widgets rewritten; verdict_row/venue_picker_sheet/
    plan_dinner_sheet new; the old standalone `friend_profile_topbar.dart`
    was folded into the new header file and deleted).
  - Stamps are now TYPE-SCOPED, not a flat rotation: a restaurant visit
    picks between round seal (146pt) / double frame; a hotel stay always
    gets the new oval variant (210×112) — there's only one hotel design,
    so no hash choice needed there. 3 stamps per page now (was 2), page
    height 360pt (was 250pt).
  - **Real, working actions, not stubs**: the Together tab's "+" really
    calls `WishlistRepository.toggleWishlist`/`toggleHotelWishlist` for
    the viewer's own wishlist (with a haptic + an implicit-animation
    move into the shared section); "Change place" runs live
    `RestaurantRepository.search`/`HotelRepository.search` — the same
    combined search Explore already uses, not a separate implementation.
  - **A real bug found and fixed via the preview harness**: `late final
    _tabController = TabController(...)` as a field initializer only
    constructs on first READ — this screen's own loading/error states
    never read it, so the very first read ended up being inside
    `dispose()`, lazily constructing a controller (which needs a live
    `vsync` ancestor lookup) after the element was already deactivated,
    throwing "Looking up a deactivated widget's ancestor is unsafe."
    Fixed by constructing it eagerly in `initState` instead — the
    standard `TabController` lifecycle, for exactly this reason. Caught
    by the existing `friend_profile_screen_navigation_test.dart` (both
    its cases exercise the loading/error paths this bug lived in) before
    this could have shipped.
  - **Interpretive calls made, not asked about, disclosed here**: Going/
    Interested event sections (present in the pre-redesign screen) stay
    dropped — neither pass's data scope named them. Restaurant visits show
    stars, hotel stays show Keys (same convention as the main Passport
    stamps), even though the brief's own prose mostly just says
    "sterren."
  - **Real backend capability used, verified first, not assumed** (kept
    from the first pass): visit photos use a batched
    `PhotoRepository.loadCoverPhotoUrlsForVisits`, added only after
    directly querying the live `storage.objects` RLS policies (not
    inferring from a comment) to confirm a friend can actually read
    another user's visit photo when that visit is friends-visible.
  - **A real, disclosed gap, not silently worked around**: tapping a
    stamp/verdict row opens the existing `VisitDetailScreen`/
    `StayDetailScreen` (per explicit instruction to reuse them) — but
    both screens render Delete/visibility-toggle controls keyed to
    `Supabase.instance.client.auth.currentUser`, with no check that the
    viewer actually owns the visit being shown. RLS blocks the actual
    mutation for a non-owner either way, so nothing can be corrupted, but
    the controls themselves still render, which reads as an affordance
    the viewer has no right to use. Fixing this means touching those two
    screens, which is out of scope here ("laat andere schermen
    ongemoeid") — flagged, not fixed, not silently ignored.
  - **TODO, not guessed**: "Friends since {month year}" is never shown —
    neither `get_profile_identity` nor `get_friends` returns a friendship
    acceptance date today. See "New backend needs" below.
  - **TODO, explicitly marked in code** (`friend_profile_dinner_invitation
    .dart` and `_PlanTableButton`'s successor, the Plan sheet's "Send
    invitation"): `DinnerInvitation` is a client-local stub — sending one
    shows the "Invitation sent" toast but persists nothing anywhere and
    nothing on the recipient's side ever renders it. See "New backend
    needs" below for exactly what's missing.
  - Tests: still none — same deferral rationale as §0. A preview harness
    (0/3-mixed/12+ visits, shared/unshared wishlist, the Plan sheet both
    with and without a preselected venue) was built and visually
    reviewed instead, per explicit instruction — it's what caught the
    TabController bug above, and a context bug in the harness itself
    (unrelated to the shipped code — `showModalBottomSheet` called with
    a context above the harness's own `MaterialApp`/Navigator, fixed
    with a `navigatorKey`).

## New backend needs surfaced along the way

Anything a screen's design calls for that the backend doesn't have yet gets
listed here with a stub in the Dart code (never a live migration written as
a side effect — see CLAUDE.md's "never create migrations... as a side
effect of another task"). Filled in as each screen is built.

- **Friendship acceptance date** — not exposed by `get_friends`/
  `get_profile_identity`. Needed for "Friends since {month year}" on the
  Friend Profile header, still not shown anywhere.
- **Dinner invitations** — no `dinner_invitations` table/RPC exists.
  Needs: the table itself (id, from_user, to_user, venue_id, venue_type,
  proposed_dates[], meal_type, note, status, chosen_date, created_at),
  RLS (both participants read; only the sender inserts; only the
  recipient updates status/chosen_date), a repository, AND a recipient-
  side surface to actually see/accept/decline one (no inbox or
  notification hook exists for this yet — see the in-app notifications
  feature for the likely integration point). Full shape documented in
  `lib/features/friends/friend_profile_dinner_invitation.dart`'s own
  TODO. "Send invitation" today only ever produces a client-local object
  and a confirmation toast — nothing is persisted, nothing reaches the
  other person.
