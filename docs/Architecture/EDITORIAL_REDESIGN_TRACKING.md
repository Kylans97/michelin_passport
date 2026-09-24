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
- [~] 4 — Passport — **superseded by a much larger scope, built out of
      order (like item 6 was), not the original "4a header/tabs/stats
      only" plan.** The Passport sub-tab is being rebuilt as an actual
      passport booklet (closed cover → 3D-open → bound data page →
      swipeable stamp pages, in three explicitly agreed rounds; see this
      file's own dedicated section below for what Round 1 shipped and
      what Rounds 2–3 still owe).
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
    .dart` and the Plan sheet's "Send invitation"): `DinnerInvitation` is
    a client-local stub — sending one persists nothing anywhere and
    nothing on the recipient's side ever renders it. The confirmation
    toast was corrected 2026-09-25 from "Invitation sent to {name}."
    (false — nothing was sent) to "This is a preview — invitations
    aren't sent yet." — update that copy the moment a real send exists.
    See "New backend needs" below for exactly what's missing.
  - **Follow-up, same date**: `VisitDetailScreen`/`StayDetailScreen` (the
    screens a stamp/verdict row opens) now gate their edit/delete
    controls on actual ownership (`visit.userId == currentUser.id`) —
    the gap flagged above when this screen first started opening
    someone else's visit is now fixed. `VisitPhotosSection` gained a
    `readOnly` param for the same reason (its Add/Delete photo
    affordances were an identical instance of the same problem, found
    while fixing the first one — not mentioned in the original ask, but
    the same failure mode). Both screens' non-owner path renders no "⋯"
    menu at all, not a disabled one.
  - Tests: still none — same deferral rationale as §0. A preview harness
    (0/3-mixed/12+ visits, shared/unshared wishlist, the Plan sheet both
    with and without a preselected venue) was built and visually
    reviewed instead, per explicit instruction — it's what caught the
    TabController bug above, and a context bug in the harness itself
    (unrelated to the shipped code — `showModalBottomSheet` called with
    a context above the harness's own `MaterialApp`/Navigator, fixed
    with a `navigatorKey`).

## Passport booklet redesign (item 4, built out of order)

Replaces `PassportCollectionBody` (filter chips + flat stamp-page list)
with an actual passport booklet: closed cover with yearly volumes fanned
behind it → 3D open → bound data page → (Round 2) swipeable stamp pages.
Agreed as 3 rounds before any code was written, with an explicit stop
after the cover + data page — this section covers Round 1 only.

**Reuse audit done first, before writing anything**: the whole ink-stamp
engine from the earlier Passport redesign (commit 29f5178) — hash/
variant/ink/rotation/jitter in `passport_stamp_style.dart`, the 5 painters,
`paintStampInk`/`drawArcText`/`drawIconGlyph`, `PassportStampWidget`'s own
"just stamped" animation, `paginateStamps`, `PassportPage`'s guilloché-ring
+ slot-anchor + adjacency logic, `PassportPageView`'s page-dots — all of it
stays, all reused as-is for Round 2, none of it duplicated. Four widgets
(`passport_collection_header.dart`, `passport_stats_panel.dart`,
`passport_restaurant_card.dart`/`passport_hotel_card.dart`/
`passport_event_card.dart`) were found to already be dead code (zero real
consumers, verified by grep, not assumed) independent of this redesign —
flagged, not touched. `passport_view_model.dart` (`PassportFilterResult`)
and `passport_filter_type.dart`'s enum stay: both are cross-feature (My
Map; `journey_metrics.dart`), not exclusive to the old Passport list.

**Round 1 — cover + data page — shipped:**
- `passport_booklet_data.dart` (new) — `PassportVolume` +
  `buildPassportVolumes`: the complete passport plus one volume per year
  with at least one entry, newest first. ENTRIES/COUNTRIES/STARS are all
  computed per-stamp (not per-venue), matching how the stamp system itself
  already counts visits, not venues.
- `widgets/passport_cover.dart` (new) — `PassportCoverFace` (single cover,
  reused for both the front face and a peeking sliver via a `depth` param)
  + `PassportCoverStack` (the fanned stack, swipe/tap to bring a volume
  forward, "Tap to open", page dots). Capped at 5 peeking slivers — a
  scaling simplification for an unrealistically long visit history,
  disclosed rather than silently assumed away.
- `widgets/passport_data_page.dart` (new) — the bound data page: photo/
  initials, HOLDER/MEMBER NO./VALID fields, the ENTRIES/COUNTRIES/STARS
  trio, country-code chips, and the MRZ-style footer.
- `widgets/passport_collection_body.dart` (rewritten) — orchestrates
  load → cover ↔ open-book state, a real 3D rotateY flip
  (`Transform`+`Matrix4`, no package) for the open/close transition, and a
  plain cross-fade fallback when Reduce Motion is on. Open/closed state
  and which volume is open live in this widget's own `State` and survive
  subsection switching for the life of the app session (PassportScreen
  already keeps this whole widget alive via `IndexedStack`) — never
  written to disk, matching "remembered per session," not permanently.
- `CsMastheadLogo` gained an optional `tint` param (a `ColorFilter`) so the
  cover's logo can render in gold — no gold SVG asset exists, and adding
  one would be a third bundled variant for one screen; tinting the
  existing ivory-ink asset is the standard dependency-free way to do this.

**Real bugs the preview harness caught, not analyze/tests** (built and
reviewed per explicit instruction, before this round was called done):
  - The peeking-sliver stack initially rendered every volume at the exact
    same `Positioned(bottom: 0, ...)` — the depth offset was written into
    `stackHeight`'s calculation but never actually applied to each card's
    own position, so every sliver sat fully hidden behind the front cover
    with nothing peeking at all.
  - Once fixed, the year label on each sliver was still invisible — it
    used a fractional `Alignment(0, -0.88)` against the card's full 410pt
    height, landing it right at the edge of (or just past) the ~24pt band
    that's actually visible above the card in front. Switched to a fixed
    7pt inset from the card's own top edge instead of a fraction of its
    full height.
  - Cormorant Garamond numerals (the ENTRIES/COUNTRIES/STARS trio, MEMBER
    NO., the sliver year labels) rendered with visibly uneven digit
    heights — the same oldstyle-figure font fallback `CsTypography`'s own
    `_liningFigures` exists to prevent, but this page hardcodes its own
    literal spec sizes rather than reusing those roles, so the
    `FontFeature.enable('lnum')` fix had to be repeated locally in both
    `passport_data_page.dart` and `passport_cover.dart`.
  - The data page's fixed height (430) was too short once real content
    (photo + fields + stat row + wrapped country chips + MRZ) was laid
    out — with scrolling deliberately disabled (it's meant to read as a
    fixed bound page, not a scrolling list), the MRZ lines were silently
    clipped off the bottom with no visible error. Raised to 480.
  Screenshots taken and reviewed: 0/1/4/5/13 visits, complete vs. a yearly
  volume, and a long name/long holder name (truncation + MRZ line length)
  — per the explicit "make previews of..." list. All via the real
  `PassportCoverStack`/`PassportDataPage` widgets fed by hand-built
  fixtures, not a mock of the whole screen — `PassportCollectionBody`
  itself isn't seamed for fake repositories (unlike Wishlist/Ranking/
  Trips' injectable bodies), so the harness bypassed its Supabase-backed
  `_load()` entirely rather than adding an injection seam for a throwaway
  file.

**Interpretive calls made, disclosed, not asked about individually:**
  - **STARS metric**: sums stars-AT-VISIT across every restaurant stamp in
    scope (never the current award — same historical-snapshot rule every
    other visit surface follows), and sums per-stamp, not per-venue —
    consistent with ENTRIES also counting every visit, not every venue.
    Hotel keys and event types don't contribute; the brief's own field is
    literally named "STARS," not "AWARDS."
  - **No gold text beyond the brief's own enumerated list**: the brief
    names gold-foil for "logo, MANTELIER, rand" only. The cover's italic
    tagline, the COMPLETE/year label, and "NO. {member}" are rendered
    ivory instead of gold — applying this app's own established "gold is
    ornament-only" rule (see the friend-profile redesign's identical
    correction) rather than treating the brief's silence on those three
    as an invitation to gold them.
  - **Open-book topbar's map icon dropped**: the brief's own 10b topbar
    names a right-hand map icon. `PassportScreen`'s persistent outer
    header (untouched, per this round's own scope) already carries one —
    a second map icon two rows below would read as a mistake, not a
    feature, so this round's topbar keeps only "‹ Close" and the volume
    label.
  - **ID photo fallback**: rendered as a filled ink-green tile with
    initials (the same fallback convention `MemberAvatar`/
    `CsEditorialImageFallback` already use elsewhere), not a hollow
    outlined frame — "een lege lijst met initialen" reads as ambiguous
    between the two; the filled-tile reading was chosen for visual
    consistency with the rest of the app's own identity fallbacks.

**Backend gap flagged, not silently worked around**: no `member_number`
column exists on `profiles` (checked, not assumed). "MEMBER NO." and the
MRZ strip's second line use `derivedMemberNumberPlaceholder` —
deterministic from the user id via the stamp system's own stable hash, so
it's at least constant across sessions, but explicitly NOT a real assigned
number. Every call site is commented for replacement the moment a real
column exists. User confirmed this placeholder approach for Round 1 rather
than blocking on a migration.

**Not built yet — Rounds 2 and 3, by design:**
  - Round 2: the swipeable stamp pages themselves (per-year grouped pages,
    year-in-corner label, the empty-slot tile's filled "+" affordance which
    doesn't exist on today's stamp pages), plus the 5 stamp designs'
    literal size/detail adjustments from the reuse-audit comparison
    (oval 190×100→200×106 and italic 26→30; double-frame padding
    16h/10v→12h/18v; round-seal centre showing month+year, not year alone).
  - Round 3: the 2-step "add a visit" flow (venue picker with wishlist/
    events/search → date/score/note + live stamp preview + same-venue-
    same-date duplicate check), wired to the stamp pages' entrance
    animation.
  - Tests: none yet — same deferral rationale as §0 and the friend-profile
    round (a preview harness catches real layout/lifecycle bugs a widget
    test's own fake-driven setup wouldn't; unit/widget tests come once the
    booklet has proven stable in real use, matching this file's own
    established pattern).

## New backend needs surfaced along the way

Anything a screen's design calls for that the backend doesn't have yet gets
listed here with a stub in the Dart code (never a live migration written as
a side effect — see CLAUDE.md's "never create migrations... as a side
effect of another task"). Filled in as each screen is built.

- **Friendship acceptance date** — not exposed by `get_friends`/
  `get_profile_identity`. Needed for "Friends since {month year}" on the
  Friend Profile header, still not shown anywhere.
- **Member number** — `profiles` has no such column. The Passport
  booklet's cover ("NO. {member}") and data page (MEMBER NO. + the MRZ
  strip's serial) currently use `derivedMemberNumberPlaceholder` — a
  deterministic, user-id-derived placeholder, explicitly not a real
  assigned number. Needs: a `member_number` column (assigned at signup,
  stable, human-shown), then every call site of
  `passport/utils/passport_member_number.dart` swapped for the real
  value.
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
