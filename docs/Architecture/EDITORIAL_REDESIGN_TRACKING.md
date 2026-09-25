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

**Backend gap flagged, then resolved same day**: no `member_number` column
existed on `profiles` at first (checked, not assumed). MEMBER NO./the MRZ
strip briefly used `derivedMemberNumberPlaceholder`, a hash-derived stand-
in — the user then asked for the real thing instead of leaving it as a
placeholder. See "Follow-up, same date (round 1 revisions)" below for what
shipped; the placeholder file is deleted, not kept alongside.

**Follow-up, same date (Round 1 revisions)** — two changes requested after
seeing Round 1's own screenshots, both shipped before Round 2 started:

  - **Real member numbers.** `20260925120000_add_profiles_member_number
    .sql` adds a permanent, sequential, never-reused `member_number` to
    `profiles` — a real Postgres `SEQUENCE` behind a column `DEFAULT`, not
    a computed `row_number()`/rank, specifically because a rank would
    silently shift or reuse a number the moment an earlier row disappeared
    (`profiles.id references auth.users(id) on delete cascade`, so a
    deleted account's row is genuinely gone, not soft-deleted — a sequence
    never reissues a value regardless). Backfilled the real pre-existing
    accounts in `created_at` order (kylan = 1, confirmed against the live
    data, not assumed). Two accounts (`test`, `kylan2`) were excluded from
    numbering by explicit instruction — they read as throwaway/test
    accounts, and a number once assigned is permanent, so the column is
    NOT `NOT NULL` (those two rows keep `member_number = null`); a future
    signup is unaffected since the `DEFAULT` only skips a column that's
    explicitly specified, which the trigger never does. A `BEFORE UPDATE`
    trigger (`prevent_member_number_change`) blocks changing an
    already-assigned number (RLS's `profiles_update` policy only
    restricts *which row* a user can touch, not *which column*, so this
    is the only thing stopping a direct REST call from overwriting one)
    but still allows filling in a currently-NULL one later, since "don't
    number them now" was the actual ask, not "never number them." Real
    count discrepancy caught before applying: the user said 10 existing
    profiles, production actually had 11 — surfaced via
    `supabase db query --linked` against live data rather than assumed
    away, and the user resolved it (exclude `test`/`kylan2`) before the
    migration was pushed. Validated twice in a rollback transaction
    (including simulating a real new signup via `auth.users` and a
    deliberate illegal update) before either `supabase db push --linked`.
    `UserProfile.memberNumber` (nullable `int`) and every Dart call site
    now read the real column; `passport_member_number.dart`'s placeholder
    helper is deleted, not left dangling.
  - **Bigger booklet.** The cover and data page were both hardcoded to
    one fixed pixel size (270×410 / 320×480) — too small on a real device
    per direct visual feedback ("dit is te klein... op een scherm anders
    voelt dan in een screenshot"). Both now derive their size from a
    `LayoutBuilder` in `PassportCollectionBody` itself: ~92% of the
    screen's own available width (already inset by the page's existing
    `CsSpacing.pageHorizontal` margin), clamped to [240, 480]pt, height
    derived from the cover's own original 270:410 aspect ratio — so the
    cover and the data page (and, in Round 2, every stamp page) always
    render at the exact same [Size], keeping the booklet one consistent
    physical object while paging through rather than changing shape
    screen to screen. `PassportCoverFace`/`PassportCoverStack` gained a
    `size`/`faceSize` parameter (defaulting to the original design size
    for any caller that doesn't care); `PassportDataPage` needed no
    change at all — it was already sized by whatever box its caller gives
    it, never by its own now-renamed `baseWidth`/`baseHeight` reference
    constants. Internal type sizes/logo size/border insets stay literal,
    unscaled pixel values on purpose, the same reasoning a real printed
    passport's own trim doesn't rescale with however far away you're
    holding it — only the outer booklet grows. Verified via the preview
    harness at 320/390/800px simulated screen widths (floor, typical
    phone, wide-screen clamp) plus both member-number states (a real
    number and the two-excluded-accounts' null case, confirmed to show an
    honest "—" / MRZ filler rather than reviving the deleted placeholder).

## Round 2 — the swipeable stamp pages — shipped

One continuous `PageView` now spans the data page (index 0) and every
stamp page: `widgets/passport_open_book_pager.dart` (new) replaced
`_OpenBookFrame`'s bare `PassportDataPage` with this pager, and the
now-fully-superseded old `passport_page_view.dart` (dead the moment this
landed — its only job, paging through JUST stamp pages, is what the new
pager does instead) was deleted rather than left orphaned.

- `passport_stamp_source.dart` gained `PassportStampPage` +
  `buildYearGroupedStampPages` — the complete passport's pages are
  grouped by year (newest first, per the spec's own literal "nieuwste
  eerst"), every year always starting a fresh page even if the previous
  year's last page had room; a single-year volume is just the one-group
  case of the same function, not a separate code path. The single
  "add your next stamp" `NextStampSlot` still belongs to exactly one page
  for the whole scope (the very last page of the very last, oldest, year
  group) — literally what "de laatste pagina van het complete paspoort"
  says, even though that reads unexpectedly (it lands deep in your oldest
  year, not your most recent) — implemented literally rather than
  silently "fixed" to something that felt more intuitive.
- `PassportPage` gained: a `size` param (defaults to the data page's own
  320×480 base size, so existing tests keep passing unchanged), a `year`
  corner label (bottom-left, Cormorant 26 ink-green + "YEAR OF ENTRY"),
  a `parallaxDx` param wired to a subtle ±24pt background-only drift on
  the guilloché layer as the pager scrolls ("een subtiel parallax-
  effect"), and the empty-slot tile now has the filled dark-green "+"
  circle inside the dashed ring plus corrected copy ("Add your next
  stamp" / a11y label "Add a visit", matching the Kwaliteit section's own
  example) — neither existed before this round.
- The 5 stamp designs' literal size/detail deviations flagged in the
  original reuse audit are now applied: round seal shows month+year
  ("Mar 2026"), not year alone; double-frame padding is 12×18 (was
  16×10 — backwards from spec); oval is 200×106 with 30pt italic venue
  text (was 190×100/26) — re-verified against a long name ("8½ Otto e
  Mezzo Bombana") at the new size, same as the original tuning's own
  precedent.
- New-stamp entrance animation + auto-scroll-to-new-stamp — dropped
  entirely when Round 1 rewrote this screen (there were no stamp pages
  yet to scroll to) — is reinstated: `_knownStampIds`/`_newStampIds`
  diffing lives in `PassportCollectionBody` again, computed off the
  complete volume's own item list (index 0 of `_volumes`, always the
  full set, per `buildPassportVolumes`' own contract) rather than
  per-filter-type sets the way the pre-Round-1 screen did it, since there
  are no more type filters to diff against.
- Tapping a stamp reopens `RestaurantDetailScreen`/`HotelDetailScreen`/
  `EventDetailScreen` — the exact dispatch the pre-Round-1 screen had,
  reinstated verbatim. Tapping the empty slot opens Explore, an EXPLICIT
  interim stand-in for Round 3's real "add a visit" flow (matching that
  same pre-Round-1 screen's own fallback for the same tap target), not a
  new placeholder invented for this round.
- "Remember which page" (deferred from Round 1's own "remember open/
  volume" note) is now real: `_bookPageIndex` lives in
  `PassportCollectionBody`, resets to 0 only when `_open` targets a
  DIFFERENT volume than before, and is otherwise restored exactly when
  reopening the same volume you last closed — a deliberate simplification
  over one memory slot per volume, which the booklet's own "close and
  reopen the same book" usage pattern doesn't need.
- `PassportPageDots` (new, in `widgets/passport_page_dots.dart`) — the
  cover's own `_CoverDots` and this round's new pager dots were about to
  become two near-identical private widgets, so it was promoted to one
  shared public widget instead, the same threshold this codebase already
  applied to `drawArcText`/`drawIconGlyph`.

**A real overlap bug found and iterated on twice via this round's own
preview harness** (not caught by `flutter analyze`/tests, same as every
prior round's harness-only catches): a round seal and a double frame
landing on adjacent anchors overlapped well past the design spec's
"maximaal ~10%" — confirmed directly by screenshotting a dense (4-filled-
slot) real page, something no unit test exercises. Two fixes, in order:
  1. Retuned `_slotAnchors` from the old middle/bottom pair (tuned
     against the pre-booklet, full-screen-width stamp page) to four
     quadrant-leaning anchors, for more baseline separation on the
     booklet's own narrower ~320-480pt page.
  2. Added a proper three-pass layout to `_StampField.build` — resolve
     each stamp's raw anchor+jitter position, run a few iterations of
     PAIRWISE, SYMMETRIC relaxation moving any two stamps closer than the
     spec's 10% allowance apart, and only clamp to the page bounds once,
     at the very end. (The first version of this fix clamped-then-pushed
     per stamp, which let the page-bounds clamp silently undo part of
     every push — confirmed by re-testing the exact same overlapping
     case and seeing it barely improve.)
  Disclosed, not claimed as fully solved: an adversarial single page (6
  same-year items, filling all 4 anchors) can still show a moderate
  round-seal/double-frame overlap after both fixes — a genuine geometric
  limit of fitting stamps up to ~212pt diagonal on a ~320-480pt page, not
  an unexamined gap. Every screenshot taken kept all text/stars legible
  despite the residual touching; shrinking the literal stamp sizes to
  close this gap the rest of the way was considered and rejected (Round 1
  deliberately keeps them unscaled — "a real passport's print doesn't
  rescale").

Screenshots taken and reviewed: 0/1/4(exact-page-boundary)/5/13(across 3
years, mixing restaurant+hotel stamps) visits, a long name on every
variant, the empty-slot tile, and the "exactly a full page then a wholly
new trailing page" pagination edge case.

**Still not built — Round 3, by design:**
  - The 2-step "add a visit" flow (venue picker with wishlist/events/
    search → date/score/note + live stamp preview + same-venue-same-date
    duplicate check), wired to the stamp pages' entrance animation that
    already exists (reinstated this round) and currently has nothing
    real feeding it.
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
- ~~**Member number**~~ — RESOLVED same day by
  `20260925120000_add_profiles_member_number.sql`. See "Follow-up, same
  date (Round 1 revisions)" above for the full shape (sequence-backed,
  immutable, two test accounts excluded).
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
