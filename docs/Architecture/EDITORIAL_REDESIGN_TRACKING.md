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
- [x] 6 — Friend profile (their passport) — **built out of order**, three
      full layouts (A "Hun paspoort" default / B "Samen dineren" / C "De
      column"), switchable live via a `kDebugMode`-only A/B/C row on the
      screen itself (`FriendProfileLayout`, default `.passport`). Files:
      `lib/features/friends/friend_profile_screen.dart` (rewired, legacy
      hero/action UI kept only for non-accepted relationship states — out
      of scope for this pass), `friend_profile_data.dart`,
      `friend_profile_layout.dart`, `layouts/friend_profile_layout_{a,b,c}
      .dart`, `widgets/friend_profile_{stamp,stamp_page,topbar,widgets}
      .dart`. Two small, already-shipped Passport internals
      (`_drawArcText`/`_drawIconGlyph` in passport_stamp_painters.dart)
      were promoted to public (`drawArcText`/`drawIconGlyph`) so this
      screen's own two stamp variants could reuse the real rendering
      technique rather than re-deriving it.
  - **Interpretive calls made, not asked about, disclosed here**: Going/
    Interested event sections (present in the old screen) are dropped from
    all three new layouts — the task's own "data to read" list only named
    friend + visits + wishlist, and none of the three exhaustively-specced
    layouts had a slot for them. Restaurant visits show stars, hotel stays
    show Keys (same convention as the main Passport stamps) on all three
    layouts' stamp/verdict/review rows, even though the brief's own prose
    only ever said "sterren."
  - **Real backend capability used, verified first, not assumed**: visit
    photos ("Lately"'s mini-reviews, layout C) use a new batched
    `PhotoRepository.loadCoverPhotoUrlsForVisits`. Before building it, the
    live `storage.objects` RLS policies were queried directly (not
    inferred from a comment) to confirm a friend can actually read another
    user's visit photo when that visit is friends-visible
    (`visit_photos_read_friends` policy) — confirmed, and confirmed it
    composes with `visits_read`'s own friends-gating with no extra
    client-side filtering needed.
  - **TODO, not guessed** (see `friend_profile_screen.dart`'s own class
    doc): "Friends since {month year}" is never shown anywhere — neither
    `get_profile_identity` nor `get_friends` returns a friendship
    acceptance date today. Needs `get_friends`/`get_profile_identity` to
    start returning the friendship row's own `created_at`/`accepted_at`.
  - **TODO, explicitly marked in code** (`layouts/friend_profile_layout_b
    .dart`'s `_PlanTableButton`): "Plan a table together" has no real
    share/invite flow yet — shows a "coming soon" snackbar. Needs a real
    share-sheet or in-app-chat flow before this is a real feature, not
    just a placeholder.
  - Tests: none yet, same deferral rationale as §0 above — a preview
    harness (0/2/9+ visits, shared/unshared wishlist, long names, a visit
    with a note and one without) was built and visually reviewed instead,
    per explicit instruction, and caught nothing wrong that needed fixing
    this round.

## New backend needs surfaced along the way

Anything a screen's design calls for that the backend doesn't have yet gets
listed here with a stub in the Dart code (never a live migration written as
a side effect — see CLAUDE.md's "never create migrations... as a side
effect of another task"). Filled in as each screen is built.

- **Friendship acceptance date** — not exposed by `get_friends`/
  `get_profile_identity`. Needed for "Friends since {month year}" on the
  Friend Profile screen (layout A). See that screen's own TODO.
- **Table-planning / invite flow** — no share-sheet or in-app-chat
  mechanism exists yet for layout B's "Plan a table together". Stubbed as
  a "coming soon" snackbar with an explicit code TODO.
