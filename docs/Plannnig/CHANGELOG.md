# Changelog

All notable changes to Mantelier will be documented in this file.

The format follows Keep a Changelog.

---

## Unreleased

Pre-launch audit, 2026-10-31: three read-only checks — security
(production catalogs and the repo), App Store Review risks and links, and
the privacy policy against what the app and backend actually do.

### Added

- **Terms and Support pages** (`site/terms.html`, `site/support.html`).
  `/terms` and `/support` returned 200 but were the home page served as a
  fallback. Terms carries the "no tolerance for objectionable content or
  abusive users" clause App Review asks for under 1.2, the 24-hour report
  promise the report sheet already makes, and a line that Mantelier is
  not affiliated with Michelin, The World's 50 Best or Gault&Millau.
  Support gives the contact address and how to delete an account. All
  three site pages and the home page footer link to each other.
- **Sign-up states the agreement:** "By creating an account you agree to
  the Terms and the Privacy Policy", both linked, above Create account.
  Profile gains Terms and Support rows beside Privacy policy.
- **Migration `20261031130000_tighten_photo_ownership.sql` — prepared,
  NOT applied.** `photos_update` checked only the owner, so a member
  could repoint their own photo at someone else's visit or attendance,
  or at someone else's storage object, and have it served to that
  person's friends; the update check now matches `photos_insert`.
  `photos.storage_path` and `profiles.avatar_path` must sit in the
  owner's own folder, closing the same trick for avatars through
  `can_view_member_avatar_object`. Production has 0 rows that break
  either rule (checked read-only), so both constraints are VALID. Tested
  on a full local replay of all 122 migrations. A revoke of anon writes
  on PostGIS's `spatial_ref_sys` was in the first draft and taken out:
  on the replay anon kept INSERT, because those grants come from another
  grantor — moving PostGIS out of `public` is its own change.

### Changed

- **Privacy policy rewritten to match what the app does** (dated 31
  October 2026). It now covers: username, member number and member
  search (on by default); what friends see (friends-visible visits with
  ratings, notes and photos; Interested/Going shared by default; the
  wishlist, which has no toggle); profile photos for friends, pending
  requests and members who find you (`20261031120000`); trips; venue
  invites; push notifications and tokens; every usage record
  (page opens, website/booking/phone/directions taps, screens, that a
  search or filter happened — never the query); private ratings counting
  anonymously towards Rankings above three members; venue team names
  being public; claim notification emails; Resend, MapTiler, Apple push
  and Google Fonts in the app as processors; and an honest account of
  what deletion removes and what stays. The stale "until the app
  launches" waiting-list retention is gone.
- **Dining Together hidden for launch.** Its page is a "Possible future
  concepts… Coming soon" placeholder, which App Review can reject as
  incomplete (2.1/2.2). Behind `showDiningTogether` (false); the screen
  itself is untouched.

### Removed

- `lib/data/mock/mock_user.dart`, an unused mock carrying the product
  owner's real name and an old email address. Imported nowhere.

---

## v1.5.2 (20) — 2026-10-31

1.5.1 (19) was archived at 16:25 on 2026-10-30 from `a00d3e8`
("Prepare 1.5.1 (19)", committed three minutes earlier) and is live.
Everything after it ships here. Built from `main`, after merging six
branches into `release/1.5.1` on 2026-10-31:
- `claude/neutral-username-hint`: a neutral username example on sign-up;
- `claude/friend-avatars`: friends' profile photos;
- `claude/passport-search-contrast`: a readable Passport search,
  swipeable scores, and one visit/stay screen from every entry point;
- `claude/visit-venue-link`: from a visit or stay to its venue;
- `claude/stranger-profile`: the profile of someone who isn't a friend
  yet;
- `claude/nl-venue-contacts`: the record of the NL websites and phones
  apply (QA-375, QA-376; the data itself was written to production on
  2026-10-31 and needs no build).
Main had also gained the website journey page (PRs #6, #7, #9, #10);
those site-only entries are listed here because they reached main before
this build, though they ship with the site, not the app.

One migration went to production after 1.5.1 (19) and before this
build: `20261031120000_share_member_avatars.sql` (2026-10-31). Ledger at
the version bump: 121 migrations, local and remote in agreement.

**Schema diff at the version bump** (CLAUDE.md; method in
`NEW_MACHINE_SETUP.md` §4), 2026-10-31, after `20261031120000` was
applied:
- **Replay:** all 121 migrations applied cleanly from scratch on a
  fresh full stack.
- **`supabase db dump`:** identical on both sides apart from blank
  lines.
- **Storage and auth, compared directly:** buckets, `storage.objects`
  policies (including the new `profile_photos_read_visible_members`),
  triggers and RLS on both storage tables are identical, apart from the
  expected local-only `enforce_versioning_status_transition` trigger.
- **`anon` execute:** false on production (and for PUBLIC), true for
  `authenticated`, on `can_view_member_avatar`,
  `get_member_avatar_paths` and `can_view_member_avatar_object`,
  checked with `has_function_privilege`.
- **Re-checked after the last four branches merged:** none adds a
  migration, and a fresh production dump plus the storage/auth query
  are identical to the ones that matched the replay.
- **Before the build:** `flutter analyze` was clean and all 2,719 tests
  passed on the merged tree.

**Near-miss, 2026-10-31.** This work was first folded into the 1.5.1
(19) section, on the assumption that 19 had not been archived yet. It
had: the archive in `~/Library/Developer/Xcode/Archives` is dated
2026-10-30 16:25, and 19 is live. Build 19 can't be reused, and its
changelog section must say only what it carried, so everything after
`a00d3e8` moved here and the 1.5.1 (19) section is back to that
commit's own text. Check the archive list before treating a version as
still open. Along the way main was once pushed at `d65f4fb`, one commit
before its changelog text was written: a failed text replacement
stopped the commit but not the push chained after it with `;`. The code
was complete and tested there. Chain a push to the commit it depends on
with `&&`.

### Added
- **A journey page on the website.** `site/journey.html`, served at
  `https://mantelier.app/journey`: a scroll story in which a fictional
  traveller crosses a slowly spinning globe from Amsterdam to San
  Sebastián, Florence and Tokyo, a friend joins at each stop, and a stamp
  lands in a leather passport that turns its page along the way. It ends
  on "Start your own journey." with the home page's waitlist form (same
  `waitlist` table, same 409 handling), since the iPhone app isn't in the
  App Store yet. The globe is a plain canvas drawing of the app's own
  Natural Earth outlines (`assets/globe/countries.bin`, simplified to
  ~5,400 points and inlined), so the page loads no library and fetches
  no data. With `prefers-reduced-motion` it shows one still frame: the
  whole route, every stamp, and the story as a plain list. The four
  venues (Ciel Bleu ★★, Arzak ★★★, Four Seasons Firenze, 3 Keys,
  Sézanne ★★★) were checked against production on 2026-10-31, not
  only the 24 August export; the people and their dates are fictional
  and the page says so.
- **A way to the journey page from the home page.** A card under the
  waitlist form, "Explore your journey with us", links to `/journey`
  with a small drawn globe whose route slowly runs (still under
  `prefers-reduced-motion`). It is the home page's only link out, so it
  sits above "Nights we're watching" rather than in the footer, in place
  of the curved divider that stood there.
- **From a visit or stay to its venue** (2026-10-31, product owner). On
  Visit Detail and Stay Detail, opened from Friends' Activity, a friend's
  verdicts or Passport, the venue name is now tappable, with a quiet taupe
  chevron and no button chrome. A tap opens the real
  `RestaurantDetailScreen` / `HotelDetailScreen` for the restaurant or
  hotel the screen already holds, which was resolved by id from
  `restaurants_full` / `hotels_full`, never by name. The link is turned
  off (`linkToVenue: false`) when the visit was opened from that venue's
  own page ("Your visits" / "Your stays"), so a tap never stacks the same
  page twice. Event rows in Friends' Activity already open Event Detail
  directly, so they needed nothing. No migration.
  Checked in the simulator: Friends' Activity → "Test visited Flore" →
  "Flore ›" → Flore's restaurant page. There is no widget test, because
  both detail screens read the Supabase session at build time, as before.
  Analyze and all 2,710 tests pass.
- **Friends' profile photos** (2026-10-31, product owner). Until now
  only your own photo ever showed: every other member was initials,
  because the `profile-photos` bucket was owner-only on purpose
  (20260825170000, PROFILE_AVATAR_V1.md "Storage read visibility"), and
  the identity RPCs only return the never-populated `avatar_url`. Real
  photos, with initials as fallback, now show in the friends list, Your
  Circle, friend requests (incoming and sent), Find friends search
  (photo, name and @username, as `IdentityRow` already lays out),
  notifications, Friends' Activity, a friend's profile header, trip
  members, friends going/interested on events, and "friends who've
  been". Blocked users keep initials.

  How it works: the new `MemberAvatarRepository` asks
  `get_member_avatar_paths` which of the listed members have a photo you
  may see, signs those paths (with the same size transform as your own
  photo), and caches the URLs for 50 minutes. `FriendshipRepository`,
  `NotificationsRepository` and `loadTripMembers` merge them in;
  `Friendship`, `FriendRequest` and `ProfileIdentity` gained
  `withAvatar`. None of the existing RPCs changed, so build 1.5.0/1.5.1
  are untouched.

  **Migration `20261031120000_share_member_avatars.sql` — applied to
  production 2026-10-31**, before this build (its header still reads
  "NOT YET APPLIED": it was written before the apply, and an applied
  migration is not edited). The photo rule is the identity rule
  `search_profiles` already uses: you can see a member's photo when
  there is no block between you AND (they are discoverable, OR you are
  friends, OR a request is pending either way). A non-discoverable
  member's photo stays hidden from strangers. The migration adds
  `can_view_member_avatar(uuid)`, `get_member_avatar_paths(uuid[])` and
  `can_view_member_avatar_object(text)` (all SECURITY DEFINER, each with
  `revoke execute ... from public, anon` and a grant to `authenticated`),
  plus an extra storage SELECT policy on `profile-photos` covering
  exactly a visible member's current photo. The owner-only policy stays.
  The visibility rule's SQL ran read-only against production without
  error before the apply. After it: `has_function_privilege` is false
  for `anon` and PUBLIC and true for `authenticated` on all three
  functions, and `profile_photos_read_visible_members` sits beside the
  three owner policies. Before the apply the app was checked in the
  simulator with the RPC missing: Community → Friends, the feed and the
  lists all load as before, with initials. The photos themselves have
  not been seen on a device yet — only one member in production has a
  profile photo.
  Analyze and all 2,710 tests pass (new model tests; the paged
  notifications test now asserts only on the notifications call, since
  the photo lookup follows it).

### Changed
- **Profile of someone who isn't a friend yet, redesigned** (2026-10-31,
  approved by the product owner from a simulator screenshot). It is
  reached from Find friends, a request or a notification. The old screen
  was half green and half ivory, with the identity sitting high and
  left. It is now one deep-green page with everything centred (new
  `NonFriendProfile`): the member's photo or initial in a hairline ring,
  the name in the editorial serif, @USERNAME in small caps, a short rule,
  an italic invitation line, one sentence on what friends share, and one
  calm action.
  - No relationship yet: "Start enjoying the Mantelier journey
    together." and Add friend.
  - Request sent: "Your invitation is on its way." and a quiet "✓ Request
    sent".
  - Request received: "{First name} would like to share the journey with
    you." with Accept, and a quieter Decline beneath it.
  - Your own profile: no invitation and no action.

  Report and Block stay in the "⋯" menu. Only the minimal identity a
  non-friend could already see is shown (photo, name, username); the
  copy describes what friends share in general, never this member's
  activity. The old `_NonFriendBody`/`_Hero`/`_RelationshipAction` are
  removed. A new widget test covers the states and 320 pt; the navigation
  test now expects `@KYLAN` and the invitation line. Analyze and all
  2,715 tests pass.
- **One screen to log a visit or stay, wherever you start.** Restaurant
  and Hotel Detail's "Add your first visit" / "Add a stay" opened their
  own older white sheets (`add_visit_sheet.dart`, `add_stay_sheet.dart`),
  which looked nothing like Passport → + and, on their white card, left
  an unrated score meter's segments invisible. Both pages now open the
  Passport flow (`showAddVisitFlow(initialVenue: …)`) straight at its
  stamp step, with "Cancel" and "LOG YOUR VISIT"/"LOG YOUR STAY" instead
  of "‹ Back" and "STEP 2 OF 2". Nothing was dropped: the flow gained
  what only the old sheets had — menu type (restaurants), "Visible to
  friends" (off by default, as before) and photos (uploaded after the
  visit saves, a failure reported and never undoing the visit) — so the
  Passport route now records those too. It now returns a `SavedVisit`.
  The two old sheets are removed; `MenuTypeSelector` moved to its own
  file. The notes field is unfilled, like the search field, so it sits
  between its hairlines instead of in a white box. Checked in the
  simulator from De Librije (2026-10-31), cancelled without saving.
- **Scores can be swiped.** Every 1–10 score in the visit and stay
  sheets (`RatingMeter`: overall, food, service, wine, value, room,
  experience) took a tap per segment only. A horizontal drag now works
  too: start on the "—" pill or anywhere on the meter, the score follows
  the finger, and dragging back over the pill returns to "Not rated",
  with a light selection haptic per step. Tapping is unchanged. New
  `test/rating_meter_swipe_test.dart` covers the position-to-score
  mapping, a swipe out and back, and that a tap still scores. Checked in
  the simulator (2026-10-31): a swipe from "—" gave 8/10.

### Fixed
- **The journey page's passport ran off the right edge at medium
  widths.** Between the phone layout (≤860px) and roughly 1180px the
  side column is narrower than the full-size open booklet (2 × 196px),
  so its right page was cut off, as seen on mantelier.app/journey right
  after it went live on 2026-10-31. Pages, stamps and cover lettering
  now scale with the viewport in that range; checked at 900px and
  1100px.
- **The Arzak stamp's city line ran outside its oval.** "SAN
  SEBASTIÁN · ES" was set at 6.6 units with wide letter-spacing near the
  top of the inner ellipse, where the oval is narrowest, so it crossed
  the rings. It is now smaller, tighter and lower, with the stars,
  name and date moved down to match; measured inside the inner ring.
- **Passport → + → "Where did you go?": what you typed was nearly
  invisible.** The search field sits on the green step with ivory text,
  but the app theme fills every `TextField` with ivory, so the text was
  ivory on an ivory box. The field now sets `filled: false` and reads as
  the underline on green it was designed as. Checked in the simulator
  (2026-10-31); no widget test covers this sheet.
- **Create your account showed the product owner's own username as the
  example.** The Username field's placeholder was `kylan.s`, a real
  person's handle, left in from development. It is now `jane.doe`,
  matching the Name field's `Jane Doe`. Nothing else in the shipped app
  carries a real name: the only other hit, `lib/data/mock/mock_user.dart`,
  is imported nowhere in `lib/`, and the test fixtures never ship.

---

## v1.5.1 (19) — 2026-10-30

Built from `main`, after merging three branches into `release/1.5.1`:
- `claude/venue-follow-team`: the Follow pill, one wishlist heart, one
  notification flow after a follow, and the venue team;
- `claude/friends-activity-globe`: Friends' Activity, a friend's globe,
  friends who've been on venue pages, unclipped friend-profile avatars,
  and Community Rankings for restaurants, hotels and events with one
  Filters button;
- `claude/venue-guide-links`: the guide pages moved out of the venue
  action row.

Numbered 1.5.1 at the product owner's request, though it carries new
features. Three migrations went to production on 2026-10-30, after
1.5.0 (18) and before this build: `20261030160000`, `20261030170000` and
`20261030180000`. Ledger at the version bump: 120 migrations, local and
remote in agreement.

**Schema diff at the version bump** (CLAUDE.md; method in
`NEW_MACHINE_SETUP.md` §4), production against a fresh full-stack replay
of all 120 migrations, 2026-10-30:
- **Replay:** all 120 migrations applied cleanly from scratch, so the
  `20261030170000` rename (it was first written to sort before
  `20261030160000`, see its own entry) replays in the same order
  production ran.
- **`supabase db dump`:** identical on both sides apart from blank
  lines.
- **Storage and auth, compared directly:** buckets, `storage.objects`
  policies, triggers and RLS on both storage tables are identical, apart
  from the expected local-only `enforce_versioning_status_transition`
  trigger.
- **`anon` execute:** false on production for all three new
  `SECURITY DEFINER` functions (`remove_venue_team_member`,
  `admin_approve_venue_team`, `admin_reject_venue_team`), checked with
  `has_function_privilege`.
- **Before the build:** `flutter analyze` was clean and all 2,707 tests
  passed on the merged tree.

No manual steps outside the repo for this build.

### Added
- **The team on a venue's page.** A restaurant or hotel can show its
  chef and its manager ("Restaurant manager" / "Hotel manager"), each a
  name and an optional short text (80 / 280 characters), under "THE
  TEAM" below the about text. A manager edits them in Manage venue →
  Team (`VenueTeamScreen`); like an about text, a new name or text waits
  for an admin before it shows (decided 2026-10-30: it is new
  descriptive copy from the venue, not presentation of something already
  reviewed), and the outcome, with a rejection's note, shows on the Team
  screen. Taking someone off the page needs no review and happens at
  once; it also withdraws anything still waiting for that role, so it
  cannot reappear on approval. Admins review it in the existing queue
  (new kind `venue_team`, heading TEAM), with Preview page. Private
  chefs have no Team row: their page is the chef. "Preview my page"
  shows pending team changes through a new `teamOverride` on
  `RestaurantDetailScreen`/`HotelDetailScreen`, same as the about text.
- **Migration `20261030170000_add_venue_team.sql` — applied to
  production 2026-10-30.** `venue_team_submissions` (RLS on; insert only by an active
  venue manager via `is_active_venue_manager()`, only as pending — the
  insert grant covers the content columns alone; no client update or
  delete; `anon` may read only the columns the view needs, never who
  submitted), the `venue_team_current` view, `remove_venue_team_member`,
  `admin_approve_venue_team` / `admin_reject_venue_team`, and
  `get_review_queue()` recreated with the `venue_team` kind and
  `team_role`/`team_name`/`team_bio` appended (installed builds skip
  kinds they don't know). Every new `SECURITY DEFINER` function has its
  own `revoke execute ... from public, anon`. Checked 2026-10-30 on a
  fresh full-stack replay of all 118 migrations: `anon` has no execute
  on any of the four functions (`has_function_privilege`), a manager can
  insert pending but not approved rows and cannot update, a non-manager
  cannot insert or remove, a non-admin cannot approve or read the queue,
  approve/reject/remove behave as described, and `anon` sees only
  approved, not removed rows and cannot read `user_id`. Not in this
  migration, on purpose: a notification to the venue on approval or
  rejection (new notification types need a new `get_notifications_vN`
  pair), and the admin email on a new submission (`notify-venue-
  submission` rejects submission types it doesn't know, so it needs a
  function change and deploy first).
  Written as `20261030150000`; renamed to `20261030170000` before the
  apply because `20261030160000_add_hotel_and_event_rankings.sql`
  (branch `claude/friends-activity-globe`) reached production first,
  and a migration is named after the highest one. The two touch no
  shared object, so replay order cannot change the result. Verified on
  production after `db push`: table with RLS on, view present, `anon`
  has no execute on the four functions and no select on `user_id`,
  `authenticated` has execute, `get_review_queue()` returns the team
  columns, zero rows. `supabase migration list --linked` showed 119/119
  in agreement with `20261030160000` present locally; on this branch
  alone that file is missing until `claude/friends-activity-globe`
  lands, so the list shows it remote-only until then.
- **Friends' Activity on Community → Friends** (2026-10-30). The section
  was a placeholder line; it now shows what friends have shared, merged
  across friends and newest first: a visit or stay (each one a Passport
  stamp, with its 1–10 score when given), Interested or Going for an
  event that hasn't ended and isn't cancelled, and confirmed attendance
  ("collected a Passport stamp at"). Milestones sit on the visit that
  reached them, in small caps: first venue in a new country (not the
  very first stamp), the 10th/25th/50th/100th/… distinct MICHELIN-starred
  restaurant (stars at the visit, repeat visits don't count), and the
  first three-star restaurant. Five items preview, "All activity" opens
  the full list. Rows open the friend's visit, or the event. Visit dates
  are calendar dates and render as dates only; event dates use
  `formatEventDateRange`, in the event's own timezone.

  **No migration, no new visibility.** `FriendActivityRepository` reads
  `visits`, `event_attendance` and `event_confirmed_attendance` directly,
  filtered to the caller's friends, so the existing RLS decides what
  comes back: only rows the friend marked `friends`, nothing after an
  unfriend or a block. Milestones are counted over those same visible
  visits only, so a private visit can't surface as "10th starred". Five
  queries in all, regardless of how many friends
  (`VisitedRepository.loadPassportVenuesForUsers` is the batched
  version of `loadPassportVenues`). Personal community-ranking scores
  (`venue_ratings`) are deliberately left out: they are owner-only by
  design (`20260828120000`), and showing them would reverse that
  decision.
- **A friend's globe** (2026-10-30). Friend Profile → Overview has a
  "N countries on {Name}'s globe · Map →" line that opens the same
  `VisitedMapScreen` as My Map, given the friend's `userId`: their
  friends-visible visits, stays and confirmed event attendance. Titles
  and empty states name the friend, and it records no `screenOpened`
  (that event stays "my map").

- **Friends who've been, on Restaurant and Hotel Detail** (2026-10-30).
  Under the city line, a few overlapping friend faces and one line ("Anna
  & Bas have been here", "Anna, Bas & 2 other friends have been here").
  **No scores, by product-owner decision:** the venue page stays calm,
  and a friend's verdict is one tap further, on their profile. One friend
  opens their profile directly; several open a short list first. Only
  visits a friend marked `friends` count. The query reads `user_id` alone
  (`FriendActivityRepository.loadFriendsWhoVisited`), with no migration.
  The row renders nothing until at least one friend has been, and is left
  out of a manager's "Preview my page" because it is personal state.

### Changed
- **Restaurant and Hotel Detail: guide pages moved out of the action
  row.** On a venue with every recognition (De Librije, 2026-10-30) the
  `VenueUtilityActions` row had grown to six icons side by side —
  Directions, Website, Call, Michelin, 50 Best and Gault&Millau — with
  the last label shrunk to fit. The row is now only the practical
  Directions · Website · Call; the venue's own MICHELIN Guide, World's
  50 Best and Gault&Millau pages are quiet text links (new
  `VenueGuideLinks`, north-east arrow for "leaves the app") directly
  under Award history, with the awards they describe. Each still appears
  only when its URL is real. No link was removed and no tracking
  changed (guide-page taps were never tracked; Website and Call still
  are).
- **Follow is a labelled pill.** The hero's Follow control was a
  person-add glyph that only went from outline to filled, which on a
  photo did not read as a change, so people couldn't tell whether they
  followed a venue. It is now "+ Follow" (translucent, ivory outline) or
  "✓ Following" (solid ivory, forest green), on Restaurant, Hotel and
  Private Chef pages. Following is optimistic: the pill flips on tap and
  flips back, with an error snackbar, if the write fails. The success
  snackbars ("Following X" / "Unfollowed X") are gone — the pill is the
  feedback — and so is `followSnackMessage`.
- **One wishlist heart everywhere.** The wishlist and Passport cards
  showed a bookmark to remove (or add) what the Detail pages add with a
  heart. `PassportCardBookmark` now draws the same heart: filled means on
  the wishlist, a tap takes it off. Event Interested keeps its bookmark.
- **Notifications after a follow: one sheet, in sync with Settings.**
  The first follow on a device where iOS has never been asked now shows
  one sheet ("You follow X — want a notification when they announce an
  event?") instead of a snackbar plus a sheet. Saying yes there, and
  then yes to iOS, also switches on "Events from venues you follow" in
  Notification settings (and "Friend requests" for the friends prompt),
  so the two can't disagree. In Notification settings the switches now
  show what actually reaches the phone (off until iOS allows it), and
  turning one on before iOS was asked is what asks iOS — the separate
  "Turn on notifications" button above already-on-looking toggles is
  gone. A no in iOS saves nothing.
- **Community Rankings redesigned: restaurants, hotels and events,
  beyond stars** (2026-10-30, product owner). The screen (Community → "See
  full ranking") was restaurants-only, filtered by star count, in the old
  dark-and-gold style. It now has one row of kinds (Restaurants · Hotels ·
  Events) and, for restaurants and hotels, one quiet recognition row: All,
  ★/★★/★★★ (Keys for hotels) or World's 50 Best. Each row is the ivory
  `RankingEditorialCard` with the venue's card photo, the stars or Keys
  (the only gold), a "50 Best #n" when it has one, the community score in
  forest green, and "· N members". Hotel rows open Hotel Detail and event
  rows open Event Detail. Decided by the product owner: the score is the
  overall score members give a visit, stay or confirmed event, each
  member's latest per venue, and a venue appears from 3 members (the
  rule `restaurant_rankings` already used). The separate, unused
  `venue_ratings` system is untouched.

  **Migration `20261030160000_add_hotel_and_event_rankings.sql`, applied
  to production on 2026-10-30 at the product owner's request.** It
  appends `worlds_50_best_rank` and the card-photo columns to
  `restaurant_rankings`, leaving its rows and order the same. Build 1.5.0
  (18) selects named columns from that view, so appending is invisible
  to it. It also adds `hotel_rankings` and `event_rankings` with the same
  shape and threshold: owner-privileged views that return aggregates
  only, never a user id. Until a build with this screen ships, nothing
  reads the new views.
  - **Before the apply:** there was no Docker for a local replay. The
    three view SELECTs ran read-only against production without error
    (0 rows each: no venue clears 3 members yet), and the ledger showed
    117/117 with only this file pending.
  - **After the apply:** checked directly. `restaurant_rankings` keeps
    its anon + authenticated select and now has 13 columns.
    `hotel_rankings` (13) and `event_rankings` (9) are selectable by
    `authenticated` and not by `anon`. `supabase migration list --linked`
    shows 118/118, local and remote in agreement.
  - **Ordering:** `claude/venue-follow-team` renamed its unapplied
    `20261030150000_add_venue_team.sql` to `20261030170000` (content
    unchanged) so that it sorts after this one, and applied it. The
    production ledger is now 119/119. This migration's header still
    says it was "named after 20261030150000_add_venue_team.sql". That
    file no longer exists, and the header stays as it is, because an
    applied migration is not edited.

  Until a build with this screen ships, the app falls back on its own if
  a view is missing, so it is safe in either order. Analyze and all 2,699
  tests pass. In the simulator only the chips and empty state are
  checked, because no venue clears the threshold yet.

- **Community Rankings, layout B: one Filters button** (2026-10-30,
  chosen by the product owner from four visual options). This replaces
  the earlier two permanent chip rows, following CLAUDE.md's UI
  principle. The page now has one quiet "Filters" pill ("Filters · 2"
  when something narrows the list) and a one-line summary beside it
  ("Restaurants · Italy · ★★"). The list itself is calm editorial rows
  with hairlines between them: a serif rank, a small framed photo, the
  name, the city with stars or Keys (the only gold), any World's 50 Best
  rank, and the score over "N members". The ivory sheet holds TYPE,
  COUNTRY (only countries the list actually contains), RECOGNITION
  (stars, Keys or World's 50 Best; not shown for events), Reset, and a
  full-width "Show N places". Closing the sheet changes nothing. Each
  type's list loads once and is filtered in the app
  (`applyCommunityFilters`), because it only holds venues with 3+
  members. A failed load offers Retry.

  **Migration `20261030180000_add_country_to_rankings.sql`, applied to
  production on 2026-10-30 at the product owner's request.** It appends
  `country_code` to `restaurant_rankings` and `hotel_rankings`
  (`event_rankings` already had it). Rows, order and grants are
  unchanged. A period filter (last 12 months) is left out on purpose: it
  needs an RPC rather than a view.
  - **Before the apply:** both view SELECTs ran read-only against
    production without error (0 rows: nothing clears 3 members yet).
    Production already had `20261030170000` (venue team), which this
    branch doesn't carry. Its file was copied unchanged from
    `claude/venue-follow-team` for the push only, then removed; it is not
    committed here.
  - **After the apply:** checked directly. `restaurant_rankings` (14
    columns) is selectable by anon and authenticated, as before.
    `hotel_rankings` (14) and `event_rankings` (9) are selectable by
    authenticated only. All three have `country_code`. `supabase
    migration list --linked` shows 120/120, local and remote in
    agreement.

  Checked in the simulator with temporary demo rows (not committed),
  because no venue in production clears the threshold yet.
  Analyze and all 2,700 tests pass.

- **Friend verdicts and visit/stay detail in the green-and-ivory design**
  (2026-10-30, at the product owner's request).
  - Friend Profile → "{NAME}'S VERDICTS" (and its "All →" list) were a
    dark tile with a gold border and a 40pt score. They are now the same
    ivory `RankingEditorialCard` that My Rankings uses, without a rank.
    Each card shows the photo, name, stars or Keys, city, then "8/10 ·
    Visited 23 Sep" (the year only when it isn't this year). An unrated
    visit shows no score. `RankingEditorialCard` now takes an optional
    `rank` and an optional `scoreText` for this; every existing caller
    passes both, so nothing else changes.
  - Visit Detail and Stay Detail (reached from a verdict, Passport and
    the activity feed) used ten-segment gold bars and a gold "8/10". They
    are now ivory with the forest-green score rings the venue page
    already shows (`VenueScoreStrip`). The headings are taupe eyebrows,
    the title uses the editorial serif, and the spinner and snackbar are
    no longer gold. These are the viewer's own visits too, so their
    Passport detail changes the same way. `RatingDisplayRow`, the
    gold-bar widget, had no other users and is removed.

### Fixed
- **Friend Profile avatars were clipped.** The box holding the two
  overlapping avatars was 54pt high, but each avatar sits in a 3pt ring,
  so the Stack cut 3pt off the bottom and right of both circles at every
  screen size. The box now includes the ring, and the Stack no longer
  clips. A widget test checks both avatars sit inside it at 320, 390 and
  1024pt wide; it fails against the old header.

---

## v1.5.0 (18) — 2026-10-30

Built from `main`, after merging six branches into `release/1.5.0`:
- `claude/usage-tracking`: usage tracking;
- `claude/push-notifications` (PR #5): push notifications;
- `claude/fix-signup-confirmation`: the sign-up confirmation fix;
- `claude/passport-stamp-ceremony-e750d7` (PR #4): the Passport stamp
  ceremony;
- `claude/launch-egress`: the download-traffic work;
- `claude/jolly-engelbart-47d9a4`: the Yi Long Court data fix.

A minor version bump, because push notifications and the stamp ceremony
are visible new features. Three migrations went to production on
2026-10-30, after 1.4.0 (17) and before this build: `20261023200000`,
`20261030130000` and `20261030140000`, plus the Yi Long Court
correction. Ledger at the version bump: 117 migrations, local and remote
in agreement.

**Schema diff at the version bump** (CLAUDE.md; method in
`NEW_MACHINE_SETUP.md` §4), production against a fresh full-stack replay of
all 117 migrations, 2026-10-30:
- **Before the apply:** the only difference was the pending
  `20261030140000`: `get_visit_cover_photos`, its grants and the new
  `photos` index.
- **After the apply:** `supabase db dump` is identical on both sides
  apart from the same 6 blank lines.
- **Storage and auth, compared directly:** buckets, `storage.objects`
  policies, triggers and RLS on both storage tables are identical, apart
  from the expected local-only `enforce_versioning_status_transition`
  trigger.
- **Before the build:** `flutter analyze` was clean and all 2,681 tests
  passed on the merged tree.

**Manual steps outside the repo, already done:**
- the Supabase Auth Site URL and redirect URLs, and the mantelier.app
  site deploy, for sign-up;
- the APNs key "Mantelier Push" (team-scoped, Sandbox & Production);
- Push Notifications enabled on the `app.mantelier` App ID;
- the five `send-push` secrets.

### Added
- **Usage tracking for venue actions and feature use** (2026-10-30;
  migration applied to production the same day, at the product owner's
  request, ahead of the build that sends the new events). Migration
  `20261023200000_add_venue_action_and_app_usage_tracking.sql`:
  `venue_link_clicks` accepts `phone` and `directions` destinations and a
  `private_chef_detail` source screen; new `venue_page_opens` (with
  internal and k≥5 shareable stats views) and `app_usage_events` (an
  allowlist of `screen_opened`, `explore_search_performed`,
  `explore_filter_applied`, `event_opened`, with an internal stats
  view). Same ownership model as `venue_link_clicks`: insert-only for the
  user themself, never readable by any client role. App side:
  - new events `venuePhoneTapped`, `venueDirectionsOpened`,
    `venueDetailOpened`, `screenOpened`, `exploreSearchPerformed` and
    `exploreFilterApplied`;
  - Restaurant, Hotel and Private Chef Detail record page opens, Call and
    Directions; Private Chef Detail now also records website taps;
  - Event Detail records `eventOpened` on landing, so opens from any
    surface count (EventsScreen's own feed-tap call stays Noop, so
    nothing is counted twice);
  - the tab bar and the Events, Guides, Map, Friends, Friend profile,
    Notifications and Trip screens record `screenOpened`;
  - Explore counts one search for each query typed into an empty field,
    and each filter change. The query text and filter values are never
    stored.

  Replayed from scratch on a local stack (all 115 migrations), with RLS
  and CHECKs exercised there: own-user insert accepted, another user's
  id, unknown destination/event and screen-shape violations rejected,
  authenticated reads return 0 rows, both views denied, anon insert
  denied. After the apply, production was checked directly: both tables
  with RLS on and only their insert policy, all three views present and
  not selectable by `authenticated`, no anon insert, the widened CHECKs
  in place, the 3 existing click rows intact, and `supabase migration
  list --linked` at 115/115 local = remote.

- 2026-10-30 — Push notifications (iOS, APNs directly, no Firebase), with
  per-type toggles. Two kinds push: a friend request received, and a new
  event from a restaurant, hotel or private chef the person follows.
  **Applied to production 2026-10-30**, after build 1.4.0 (17), so the
  server side is live but no shipped build registers devices or shows the
  settings yet. That needs the next build.
  - **Secrets:** the five function secrets (`APNS_KEY_P8`, `APNS_KEY_ID`,
    `APNS_TEAM_ID`, `APNS_BUNDLE_ID`, `SEND_PUSH_WEBHOOK_SECRET`) and the
    vault secret `send_push_webhook_secret` were set by the product owner.
    The key is team-scoped, Sandbox & Production.
  - **Deploy:** `send-push` deployed. A probe without the secret returns 401,
    and a GET returns 405, so `verify_jwt = false` took effect.
  - **Apply:** one plain `supabase db push --linked`, which applied only
    `20261030130000`. The ledger now has 116 rows, local and remote in
    agreement.
  - **Ledger note:** production already had `20261023200000` (from
    `claude/usage-tracking`, applied but not merged), and `db push`
    refuses to run while a remote migration has no local file. That file
    was copied into this branch byte for byte from its own branch first;
    it changed nothing in production.
  - **Checked on production:** RLS is on both new tables, and all five
    triggers exist. `has_function_privilege('anon', …)` is false for all
    eight new functions. `authenticated` can't call the fan-out but can
    register. The vault secret is present. v1–v4 and the unread counts all
    execute.
  - **Migration `20261030130000_add_push_notifications.sql`:**
    - `push_devices` (APNs tokens): RLS lets the owner read and delete
      only. Writes go only through `register_push_device` /
      `unregister_push_device`, because a device signing in to another
      account has to take over a token row that RLS would never let it
      touch.
    - `notification_preferences`: one row per person, owner-only RLS. No
      row means both toggles on (iOS's own prompt is the real opt-in).
      The toggles affect push only, never the in-app list.
    - A new notification type, `followed_venue_event`. Deferred constraint
      triggers on `events` and the three link tables call
      `fan_out_followed_venue_event` at commit, so the host link always
      exists by then:
      - recipients are the followers of the event's **host** venue
        (decided 2026-10-30), through approved host links only;
      - the host's own active managers and past or cancelled events are
        skipped;
      - a partial unique index stops a republished event from notifying
        anyone twice;
      - the 28 already-published events never fire.
    - `notifications_push_on_insert`, a statement-level trigger, hands
      push-worthy ids to `send-push` through pg_net, 500 per call. It is
      best-effort, the same as `notify-venue-claim`, and reads its webhook
      secret from vault (`send_push_webhook_secret`, set out of band).
    - `get_notifications_v4` / `get_unread_notification_count_v4` return
      the new type. v4 is v3's body copied verbatim (diffed). v3, v2, v1
      and their counts now filter the type out, so 1.4.0 and older never
      see a row they can't render or count.
    - Every new `SECURITY DEFINER` function has its own
      `revoke execute … from public, anon`. The fan-out is revoked from
      `authenticated` too.
  - **Edge Function `send-push`** (`verify_jwt = false`, x-webhook-secret):
    - reads the notifications, preferences and tokens with service_role;
    - signs its own ES256 APNs token from the `.p8` key;
    - deletes tokens APNs reports as gone, and retries a BadDeviceToken
      once on the other APNs environment, correcting the stored one.
  - **App:**
    - `PushNotificationsPlugin` in `AppDelegate.swift` (no push SDK);
    - the `aps-environment` entitlement;
    - `PushService`, which registers the token whenever iOS allows it and
      unregisters it before sign-out;
    - a pre-prompt sheet shown once, after the first venue follow or
      friend request sent or accepted. iOS's prompt only follows
      "Turn on", and "Not now" is remembered (`shared_preferences`, now a
      direct dependency);
    - Profile → Notification settings with the two toggles;
    - a tapped push opens the event or the Notifications list;
    - the in-app list shows the new type.
  - **Tested:**
    - 18 Deno tests for `send-push`, including signing a JWT and verifying
      it.
    - New Flutter tests for `PushService`, the settings screen and the
      model. The full suite passes: 2,613 tests.
    - Sections 1–5 of the migration ran against a scratch Postgres 17 with
      stub tables: 29 scenario checks pass (fan-out paths, dedupe,
      managers, past and cancelled events, pending host links, missing
      secret, token takeover, RLS, `has_function_privilege('anon', …)`
      false for all six new functions).
  - **Not tested:**
    - a full-stack replay (Docker was not running);
    - section 6 with a signed-in user (it executes on production with none);
    - a real APNs delivery, including whether the Edge runtime's fetch
      speaks HTTP/2 to APNs. That is the first thing to check after the
      deploy.

- **A confirmation landing page and a way back from an expired link.**
  `site/auth/confirm.html`, served at `https://mantelier.app/auth/confirm`
  and (through `site/_redirects`) at `/auth/confirmed`, in the same branded
  style as `reset-password.html`. It says the account is confirmed when the
  link worked. When the link has expired or was already used, it says so
  and tells the person what to do next. `/auth/confirm` is now a Universal
  Link (AASA, and the Android intent filter), so with the app installed the
  link opens Mantelier, which signs the person in with the PKCE code and
  shows the welcome flow. `/auth/confirmed` is deliberately web-only (see
  Fixed).

- **A `mantelier://` URL scheme** (iOS `CFBundleURLTypes`, Android intent
  filter on host `auth`). The "Open Mantelier" buttons on
  `/auth/confirm` and `/auth/reset-password` now use it. On
  `/auth/confirm` the button links to `mantelier://auth/confirm?code=…`.
  On `/auth/reset-password` it links to the same path, query and fragment
  on the new scheme. supabase_flutter's PKCE handling reads `?code=`
  whatever the scheme. Checked in the iOS simulator: `simctl openurl
  "mantelier://auth/confirm?code=…"` asks "Open in Mantelier?" and
  brings the app to the front with no crash. The probe code was bogus
  and the simulator was already signed in, so this showed the scheme
  works, not a sign-in through it. Builds up to 1.4.0 (17) don't
  register the scheme, so on those Safari reports an invalid address.

- **"Send a new confirmation link" on sign-in.** When sign-in is refused
  with `email_not_confirmed`, LoginScreen offers to resend the confirmation
  (`AuthRepository.resendSignupConfirmation`).

- **Stamp ceremony.** When a member earns a new Passport stamp, their own
  Passport opens full screen over the screen they are on. The real cover
  swings open, and the book turns one page to where the stamp lands. A
  small wooden rubber stamp appears over an ink pad beside the book. It
  dips into the pad, and its rubber face takes on the stamp's own ink
  colour. It then lifts, arcs over the page and presses down. On contact,
  the real impression appears at full strength, one medium haptic fires,
  and the ink settles to 90%. The stamper lifts away, the book closes, and
  the member is back where they were. The whole ceremony takes about
  3.1s, and a tap skips it. Under reduce motion there is no flip and no page turn: the
  open book fades in already on the right page, and the stamp fades in.
  - It is one entry point, `celebrateNewStamp`
    (`lib/features/passport/stamp_ceremony.dart`), called from all five
    places a stamp is earned:
    - Log visit on the restaurant page;
    - Log stay on the hotel page;
    - the Passport's "Add your next stamp" flow;
    - the event page's attendance confirmation (both "Yes" and "Add to
      Passport");
    - the Events feed's post-event prompt.
  - For events it runs after the confirmation, before the optional rating
    sheet.
  - It runs on the real booklet (`PassportFlipBook`, cover, pages and
    stamp painters), not a replica. The stamp being pressed hands its
    entrance to a `StampCeremonyScope`, and it reports its position and
    ink to the stamper through that scope. The stamper and pad
    (`stamp_ceremony_stamper.dart`) are the only new artwork. They are
    decoration around the impression; the impression itself is still the
    stamp's own painter.
  - Trigger rules:
    - An `EarnedStamp` can only be built from a saved `Visit` or a saved
      `EventConfirmedAttendance`, so Interested/Going and failed saves
      have nothing to pass.
    - The stamp must be in the freshly loaded booklet, so a back-dated
      visit outside the 5-year window gets no ceremony.
    - It shows once per stamp per app session.
    - It never throws, because the stamp is already saved by the time it
      runs.
  - The Passport tab no longer replays its own "just stamped" entrance for
    a stamp the ceremony already pressed.
  - The two Add sheets and the Passport add flow now return the saved row
    (`SavedVisit`, `Visit?`) instead of a bare outcome or bool.
  - `loadOwnPassport` (`own_passport_loader.dart`) is the Passport tab's
    load, moved out of `PassportCollectionBody` so the ceremony and the
    tab read exactly the same booklet.
  - No schema or Supabase changes.

### Changed
- `SupabaseAnalyticsService.ofInstance()` resolves the Supabase client
  only inside each insert's own try, so a screen can track from
  `initState` where Supabase isn't initialised (widget tests) without
  failing. Every insert now reads the signed-in user inside that try
  too.

- 2026-10-30 — **Download traffic cut before the App Store launch.**
  Supabase bills egress, and it is the binding cost at launch. The
  database itself has room for thousands of daily users. Measured figures
  come from read-only requests against production on 2026-10-30; the
  others are estimates.

  | | Before | After |
  |---|---|---|
  | Explore, each mount (measured) | 985 KB gzipped (all 3,480 restaurants + 1,830 hotels) | ~5 KB (9 + 9 rows) |
  | Venue photo on a card (one 1536x2048 original, measured) | 1.6 MB | 69 KB at 512, 274 KB at 1024 |
  | Visit-photo tile (estimated) | the 1600 px upload, ~300–400 KB | unchanged until the switch below is on, then a 512 px copy, ~40–70 KB |
  | Own avatar (measured, one avatar) | 285 KB | unchanged until the switch is on, then a 384 px copy, 33 KB |
  | Flore's card photo / a news card (measured in the simulator) | 353 KB / 279 KB | 28 KB at 512 / 168 KB at 1536 |
  | The same photo seen again | downloaded again (new signed URL each time) | from disk, for 30 days |
  | Notifications | whole history | 50 per page |

  Rough per active user per day: about 1 MB of catalogue per app start
  plus several MB of photos before, against tens of KB of catalogue and a
  few hundred KB of photos, mostly first views, after. That should be
  about an order of magnitude more users per GB. It is an estimate, not a
  measurement of real sessions.
  - **Explore** fetches only the rows its sections can show. The server
    sorts on stars or Keys, then World's 50 Best rank. It returns the whole
    tie group when that group runs past eighth place, so the existing
    selectors still choose by name, and what Explore shows is unchanged.
    Fresh Finds reads only reported rows. `getAll()` is gone from both
    repositories.
  - **Every image goes through `AppNetworkImage`**
    (`lib/core/widgets/app_network_image.dart`) instead of `Image.network`.
    A public Storage photo comes from the render endpoint, sized to its slot
    times the pixel ratio and framing zoom, in six shared sizes. It is
    contain-fit: width alone keeps the original height and distorts the
    photo, measured on production. Focus-point framing still crops on the
    device. The full-screen viewers, the framing editors and admin review
    keep the original. The project is on Pro (the product owner confirmed
    it on 2026-10-30), which the render endpoint needs.
  - **Member photos are not transformed yet.** Visit, stay and attendance
    photos and avatars have signed transformed copies built and tested,
    but they are behind `memberPhotoTransformsEnabled`, which is off. The
    product owner hasn't decided, and the comparison below argues against
    it. While the switch is off, those photos show the cached original,
    exactly as before.
  - **Cost comparison for member photos** (Pro pricing from Supabase's
    docs, 2026-10-30): transformations are $5 per 1,000 distinct origin
    images per billing cycle after 100. Storage is $0.0213 per GB after
    100 GB, and egress is $0.09 per GB after 250 GB. The usage figures are
    assumptions, not data: each active member logs 3 visits a month with
    4 photos each, and views about 30 distinct member photos a month.
    Each tile view saves about 300 KB once per device, since caching
    covers repeats.

    | 5,000 monthly members | Transforms | Small copy uploaded alongside |
    |---|---|---|
    | Running cost | ~150,000 origin images: **~$750/month** | +0.6 MB storage per member a month (3 GB/month in all), inside the 100 GB quota: **~$0** |
    | Egress saved | ~75 GB/month, ~$7 | the same ~75 GB, ~$7 |
    | Build work | none (built, behind the switch) | resize at upload, a second object per photo, delete both together, older photos fall back to the original |

    At 1,000 members, transforms cost about $150 a month. Either way the
    egress saved is a few dollars, because caching already removes the
    repeat views. Transforms would cost about 100 times what they save. A
    small copy costs almost nothing, but it is real work for little gain.
    For avatars, setting the picker's existing `maxWidth` from 1024 to
    512 gets most of the saving with no new mechanism. Venue photos stay
    on transforms: they are a catalogue, not per member (6 today; 5,000 of
    them would be about $25 a month).
  - **Disk cache** (`cached_network_image`). A signed URL is keyed on its
    bucket and path, plus the `transformations` claim of its token, so a
    thumbnail never stands in for an original. Storage answers
    `private, no-cache`, which would have made every view revalidate. Its
    paths are never reused, so cached entries stay valid for 30 days.
  - **Notifications** load 50 at a time, newest first, and the rest as the
    list reaches its end. The ordering and range are applied to the
    existing RPC result, so no server change is needed. The unread badge
    still comes from its own count.
  - **Friend Profile** loads covers for the three verdicts it shows, and
    All visits loads 20 rows' covers at a time as they appear.
  - **Profile** derives its Journey Stats from the Passport load it already
    makes, instead of downloading the visits and restaurants twice.
  - **Checked in the iOS simulator against production, read-only**
    (2026-10-30, signed in by the product owner):
    - Worth the Journey and Stay a Little Longer show three-star
      restaurants and three-Key hotels in World's 50 Best rank order.
    - Search, a restaurant detail page and Profile (4 places, 4 countries,
      2 friends) load.
    - Flore's card photo renders from the 512 variant.
    - The image cache's index stored a real signed avatar under
      `…/render/image/sign/profile-photos/…#height:384,width:384,resize:undefined`,
      which confirms the token claim the key reads.
    - After a relaunch, the avatar (re-signed with a new token) and the
      news image came from disk: the same cached files were touched, and
      nothing was downloaded again.
    - Not exercised: Notifications (opening it marks everything read, a
      write), Friend Profile's All visits, and venue photo upload (a
      write).
  - **Not paged, on purpose:** Passport venues and events, friends, and
    event attendance. Their totals and the "friends going" logic need every
    row.

- `20261030140000_add_get_visit_cover_photos.sql` (written as `20261030120000`, renamed before it was applied, see Fixed): one cover per visit
  (`DISTINCT ON`, `SECURITY INVOKER` so `photos_read` RLS still applies,
  `revoke ... from public, anon`), plus an index on
  `photos (visit_id, taken_at desc nulls last)`, which `photos` had none
  of. It was written and checked against a scratch PG 17. It picks the
  same cover as the old query, which postgrest-dart sends as
  `taken_at.desc.nullslast`, not Postgres' own DESC default, and anon
  cannot execute it. **Applied to production 2026-10-30**, with this build's version bump,
  at the product owner's request; the client still falls back to the old
  query on PGRST202 for any server without it.

### Fixed
- A manager's "Preview my page" no longer records a website tap on
  Restaurant/Hotel Detail. It previously did, since `isPreview` only
  gated personal state, so a manager could inflate their own venue's
  click counts.

- 2026-10-30 — Near-miss: the migration was first named `20261023210000`,
  after `claude/usage-tracking`'s `20261023200000` as briefed. A check of
  every remote branch found `claude/launch-egress` already at
  `20261030120000`, so it was renamed `20261030130000` before any commit.
  "The highest migration" has to be checked across all branches, not taken
  from a brief.

- **mantelier.app's "Nights we're watching" list is current again.** The
  three hard-coded events, from August and September 2026, were replaced
  on 2026-10-30 with the next three published, uncancelled events in
  production, read with the anon key: 9 Nov (Amsterdam), 22 Nov (Schoorl)
  and 24–25 Dec (Eijsden). The 1 Nov dinner in Aalten was left out
  because it was two days away. Names, dates and cities are exactly as
  stored. The list is still static, so it goes stale again after 9 Nov.
  On screens narrower than 480px the date now sits above the name, since
  the real names wrapped to five lines beside it.

- **New users saw "server not available" after tapping the confirmation
  link, although the account had been created and confirmed.**
  `AuthRepository.signUp()` passed no `emailRedirectTo`, so GoTrue sent the
  user to the project's Site URL after confirming. In production that was
  still Supabase's default `http://localhost:3000`. This was verified on
  2026-10-30 with a read-only probe: a GET to production's
  `/auth/v1/verify` with an invalid token returns a `303` to
  `http://localhost:3000#error=…`. The same probe with
  `redirect_to=https://mantelier.app/auth/reset-password`, which is on the
  allow-list, returns a `303` to that URL. GoTrue confirms the email
  *before* it redirects, so the account was always fine. The phone was
  sent to `localhost`, where nothing answers. `signUp()` now passes
  `https://mantelier.app/auth/confirm`. This needed the production Auth
  changes and site deploy below, both done on 2026-10-30.
  - **Near-miss:** gotrue-dart's `resend()` sends no PKCE code challenge,
    so a resent confirmation comes back with implicit-flow tokens. In PKCE
    mode, supabase_flutter ignores those tokens. Sent to the Universal
    Link, the resent link would have opened the app to a silent sign-in
    screen. Resends therefore go to the web-only `/auth/confirmed`.
  - **Near-miss:** the "Open Mantelier" buttons on the confirm and
    reset-password pages did nothing. The product owner found this while
    testing on 2026-10-30. Both linked to the page's own https URL, and
    iOS never hands a Universal Link to the app when it is tapped on its
    own domain, so the tap only reloaded the page. `reset-password.html`
    has done this since 2026-09-24, where its comment claimed the
    opposite. Both buttons now use `mantelier://` (see Added).
  - **Near-miss:** supabase_flutter reports a failed link only as an error
    on `onAuthStateChange`. AuthGate's subscription had no `onError`, so
    an expired link left a silent sign-in screen. AuthGate now shows a
    notice for the two link failures it can identify (`otp_expired`, and a
    missing PKCE verifier or flow state). It deliberately ignores every
    other stream error, such as a failed session refresh, because the
    same stream carries errors that have nothing to do with a link.
  - **Production Auth settings, for the product owner** (Dashboard →
    Authentication → URL Configuration): set **Site URL** to
    `https://mantelier.app/auth/confirm`, which also fixes 1.4.0 (17) and
    older builds because they send no redirect. Add
    `https://mantelier.app/auth/confirm` and
    `https://mantelier.app/auth/confirmed` to **Redirect URLs**. Then
    deploy `site/` (`auth/confirm.html`, `_redirects` and the updated
    `.well-known/apple-app-site-association`) to mantelier.app.
    `supabase/config.toml` lists the same redirect URLs for the local
    stack only.
  - **Done, 2026-10-30.** The product owner changed both dashboard
    settings. The `/verify` probe now redirects to
    `https://mantelier.app/auth/confirm`, and accepts `/auth/confirmed`.
    `site/` was deployed with `wrangler pages deploy … --project-name
    mantelier --branch main`. mantelier.app serves `/auth/confirm`,
    `/auth/confirmed` (through the rewrite) and the new AASA, and Apple's
    AASA CDN already has the `/auth/confirm` entry. A full sign-up on a
    device has not been run yet.

- **Near-miss: the ceremony route rendered every booklet label with
  Flutter's yellow-underlined debug text style.** A pushed route has no
  Scaffold, and therefore no `Material`, above it. The Passport tab
  inherits one, so the shared booklet widgets had never needed their own.
  The widget tests passed; it was the simulator that showed it. The
  overlay now provides its own `Material`, and a test checks the
  inherited text style. That test fails without the fix. This would recur
  for any booklet widget shown from a new route.

- **Near-miss: the stamper drew nothing on the device.** Its `CustomPaint`
  was given the Stack's own `Size` object, which trips Flutter's "size
  assigned inappropriately" layout assertion. Nothing painted, while the
  impression underneath still landed on time, so it looked like a timing
  problem. `Positioned.fill` already sizes the layer, and the argument is
  gone. A test now checks that the stamper is on screen during its run.

- 2026-10-30 — **A PNG venue photo was stored as `.jpg` with
  `image/jpeg`, and could exceed the 5 MiB limit.** The pipeline
  re-encoded every photo at full resolution, so a file that passed the
  5 MiB check could come out larger. That limit is also the bucket's own.
  `prepareVenuePhoto` now returns the bytes together with their real
  extension and content type. It caps the long edge at 2560 px and steps
  down 15% at a time while the file is still too big, never below the
  1200 px short side. Only a PNG that cannot fit even then becomes a JPEG,
  and it is labelled as one. `publish-venue-photo` copies the object, so
  the published photo keeps the right type.

- 2026-10-30 — **Near-miss: two migrations reached production out of
  filename order.** `20261030130000` (push notifications) was named after
  launch-egress's `20261030120000` but was applied first, from its own
  branch. Applied as named, a fresh replay would have run them in the
  opposite order from production. They touch no common object, but
  filename order is replay order, so the unapplied one was renamed
  `20261030140000` before it went anywhere. The push migration's header,
  already applied, still says it was named after `20261030120000`; it is
  left as it is.

- 2026-10-30 — **Merging launch-egress's notification paging with push
  notifications' `get_notifications_v4`.** Each branch rewrote
  `NotificationsRepository.getNotifications`, and git could not combine
  them. The merged version pages the result and asks for v4 first, then
  falls back through v3, v2 and v1. Two paging tests still expected v3
  first and were updated.

- 2026-10-30 — **Near-miss: Yi Long Court's website and phone were
  confirmed after the China import was applied**, so merging the data
  branch alone would never have reached production. Written as its own
  guarded correction and applied with this build (Michelin_Database
  CHANGELOG, QA-299).

### Known limits
- "Once per stamp" is per app session. Re-confirming an event that was
  already confirmed in an earlier session would show the ceremony again,
  because `confirmAttendance` returns the existing row. Neither event
  surface offers confirmation once attendance exists, so this was not
  guarded against further.
- The five call sites were not pumped in widget tests: they build their
  repositories against `Supabase.instance.client`, the same limitation as
  `add_visit_sheet_shell_test.dart`. They were checked by reading. The
  simulator check used a throwaway preview with fixture stamps rather
  than a real save, so nothing was written to production.

---

## v1.4.0 (17) — 2026-10-30

Built from `main`, after merging `claude/passport-globe` into
`release/1.4.0`. The app change is the 3D globe for My Map, plus MapTiler
tiles for the event location picker. A minor version bump, because the
globe is a visible new feature. The five MICHELIN imports below were
applied to production before this build. Ledger at the version bump: 114
migrations, local and remote in agreement.

**Schema diff at the version bump** (CLAUDE.md; method in
`NEW_MACHINE_SETUP.md` §4), production against a fresh full-stack replay of
all 114 migrations, 2026-10-30:
- **The replay:** all 114 files applied with no error, giving 114 ledger
  rows.
- **`supabase db dump`, both sides:** identical apart from the same 6 blank
  lines (platform statements the CLI filters out).
- **Storage and auth, compared directly:** all 5 buckets, 13
  `storage.objects` policies, triggers and RLS on both storage tables are
  identical.
- **Expected noise:** the only extra row is the local-only
  `enforce_versioning_status_transition` trigger.
- **Before the build:**
  - `flutter analyze` was clean and all 2,595 tests passed on the merged
    tree.
  - My Map was checked in the iOS simulator against production: the globe
    spins with inertia, the visited countries are highlighted, and pins
    cluster.
  - The build's `.env` carries `MAPTILER_KEY`.

### Added
- 2026-10-30 — Catalogue: five MICHELIN imports, applied to production.
  None needs an app change; build 1.3.0 (16) pages past PostgREST's
  1000-row cap, so it shows them in full. Details are in the
  Michelin_Database CHANGELOG.
  - **Migrations:** `20261023150000` (CN), `20261023160000` (US/CA/MX,
    adds the `countries` row for Canada), `20261023170000` (HK/MO/TW),
    `20261023180000` (CH/AT/Nordics, adds the `countries` row for Iceland)
    and `20261023190000` (FR Key hotel towns). All five went in one plain
    `supabase db push --linked`, in filename order.
  - **Ledger:** 109 → 114/114, local and remote in agreement.
  - **Data:** one guarded file per import, applied in the same order, then
    Monaco's Key hotel file. None aborted.
  - **Totals:** the catalogue now holds 3,439 starred restaurants, 1,830
    hotels and 317 hotel links.
  - **Not filled:** none of the new rows has a Google Place ID (QA-289,
    QA-300, QA-350 and the CH/AT/Nordic equivalent).
  - **Schema diff:** covered by this release's version-bump diff above.

### Changed
- **My Map is now a 3D globe.** The map behind Passport's top-right corner
  was a flat `flutter_map` view. It is now a globe drawn in Flutter
  (`lib/features/map/globe/`). It shows the same places as before (visited
  restaurants, hotel stays, events with confirmed attendance) with the same
  All / Restaurants / Hotels / Events filters, and a pin tap still opens
  the preview sheet that leads to the venue or event detail.
  - Drag spins it with inertia, and pinch zooms from the whole world down
    to about 250 km across.
  - It turns slowly while idle. Any touch stops it, and it starts again
    after 12 seconds untouched, but only when zoomed out. Reduced motion
    turns it off.
  - Tapping a pin flies the globe to it, then opens the preview sheet.
  - Pins within a finger's width of each other merge into a numbered
    marker. Tapping it flies in until they separate. When zooming can't
    separate them (one address, or one city at maximum zoom), it opens a
    short list of those places, and each one opens its preview sheet.
  - Countries with at least one pin under the current filter are drawn in
    full ivory and the rest are muted. This keys on the stored
    `country_code`, never on the coordinate. All 59 codes in production
    `countries` exist in the outline data (checked 2026-10-30).
  - The first view shows the whole globe turned towards the user's places.
    Choosing a filter flies in to frame them.
- **No map tiles, no API key, works offline.** The outlines are Natural
  Earth 1:50m countries (public domain, v5.1.2), simplified and bundled as
  `assets/globe/countries.bin` (212 KB) by
  `scripts/build_globe_outlines.py`. My Map no longer requests tiles from
  `tile.openstreetmap.org`. OpenStreetMap's tile usage policy doesn't allow
  a published app to load its tiles directly at volume, so this also
  removes a compliance risk. `flutter_map` stays as a dependency because
  the event location picker still uses it.
- **The event location picker now uses MapTiler tiles.** It was the last
  screen loading tiles straight from `tile.openstreetmap.org`, and it showed
  none of the credit those tiles require. It keeps `flutter_map` and works
  exactly as before (tap to drop the pin, "Use this location"), now with
  MapTiler's Streets map (`streets-v2`, sharp tiles on high-density
  screens) and the required "© MapTiler © OpenStreetMap contributors"
  credit, each name linking to its copyright page.
  - The key is a MapTiler client key, read from `MAPTILER_KEY` in `.env`
    (`MapTilerConfig`, `lib/core/maps/`). It is public by design, like the
    anon key. On MapTiler's free plan a copied key can only use up the
    monthly allowance, after which tiles stop: there is no bill.
  - With no key, the picker says the map can't be shown and offers no pin.
    It never falls back to OpenStreetMap's servers. **`MAPTILER_KEY` must
    be in the `.env` of whatever build ships this**, or managers can't set
    an event location on the map.
  - The key is restricted on MapTiler's side to the user-agent the picker
    sends, `flutter_map (app.mantelier)` (set by `userAgentPackageName`),
    with no HTTP origins listed, since a native app sends none. This is a
    deterrent, not real security: the header is easy to copy. Checked
    2026-10-30: a tile request with that user-agent returns 200, the same
    request as `curl` returns 403.
  - Checked in the iOS simulator through a throwaway entry point that opens
    the picker directly, since the test account manages no venue: street
    tiles of Amsterdam load sharp, with the credit visible.

### Fixed
- **Near-miss: a merge script committed conflict markers.** While merging
  the import branches, a helper script checked that each branch only
  appended rows to `qa_issues.csv`. When that check failed for one branch
  it raised, but the shell carried on, staged the file with conflict
  markers still in it, and committed the merge. It was caught before
  anything was pushed, and the file was rebuilt from the branch's own
  appended rows.
  - **Why it would recur:** a script that raises doesn't stop the commands
    after it unless the shell is told to, so any merge helper should stop
    on its first error.
  - **Also found:** the CH/AT/Nordic branch cited QA-360–374 in its README
    but had not added those rows to `qa_issues.csv`. That branch added them
    afterwards (b566df8), and they are carried here.

---

## v1.3.0 (16) — 2026-10-29

Built from `main`, after merging `release/1.3.0`, `data/de-it-2026`, and the
two data branches `claude/kind-rubin-d65c44` (Key hotel contacts) and
`claude/stoic-austin-e5e924` (UK and Ireland). This is 1.3.0 (15) plus two
app changes: the 1000-row catalogue fix and "Invite friends" on Trip Detail.

It goes out alongside three catalogue imports, all applied to production
before this build:
- MICHELIN Germany and Italy 2026;
- MICHELIN UK and Ireland 2026;
- the contact fields for Key hotels in ten countries.

They added two migrations (`20261023130000`, `20261023140000`), so the
ledger at the version bump is 109 migrations, local and remote in
agreement. The data is live on 14 and 15 too, but only this build shows
past the first 1000 places, and the catalogue now holds 2,611 starred
restaurants.

**Schema diff at the version bump** (CLAUDE.md; method in
`NEW_MACHINE_SETUP.md` §4), production against a fresh full-stack replay of
all 109 migrations, 2026-10-29, after the UK and Ireland migration was
applied:
- **The replay:** all 109 files applied with no error, giving 109 ledger
  rows.
- **`supabase db dump`, both sides:** identical apart from the same 6 blank
  lines (platform statements the CLI filters out).
- **Storage and auth, compared directly:** all 5 buckets, 13
  `storage.objects` policies, triggers and RLS on both storage tables are
  identical.
- **Expected noise:** the only extra row is the local-only
  `enforce_versioning_status_transition` trigger.
- **Earlier run:** the same diff on 108 migrations, before the UK and
  Ireland migration, was equally clean.
- **Before the build:** `flutter analyze` was clean and all 2,572 tests
  passed on the merged tree.

### Added
- 2026-10-29 — Catalogue: MICHELIN United Kingdom and Ireland 2026.
  - **Migration:** `20261023140000_add_gb_ie_2026_star_and_key_cities`
    adds the `countries` row for Ireland (`IE`, `{Europe/Dublin}`), then
    132 GB and 24 IE towns. Applied with plain `supabase db push --linked`.
  - **Ledger:** 108 → 109/109, local and remote in agreement.
  - **Data:** then `michelin_gb_ie_2026/prepared_gb_ie_stars_2026.sql`.
    It adds 214 restaurants and 139 Key hotels, with 39 hotel links.
  - **Not filled:** the new rows have no Google Place IDs yet (QA-280).
  - **Details:** in the Michelin_Database CHANGELOG.
- 2026-10-29 — Catalogue: phone, website and MICHELIN link for Key hotels
  in ES, IT, DE, JP, AT, CH, BE, HU, PL and HR.
  - **Files:** ten fill-only data files in `michelin_key_hotel_contacts/`.
    No migration.
  - **Result:** all 646 Key hotels in those countries now have a MICHELIN
    link; 29 phones and 20 websites are still blank.
- 2026-10-29 — Catalogue: MICHELIN Germany 2026 and Italy 2026.
  - **Migration:** `20261023130000_add_de_it_2026_star_cities` (330 DE/IT
    towns), applied with plain `supabase db push --linked`.
  - **Ledger:** 107 → 108/108, local and remote in agreement.
  - **Data:** then `michelin_de_it/prepared_de_it_stars_2026.sql` and
    `prepared_aqua_closure.sql`. Details are in the Michelin_Database
    CHANGELOG.
  - **No app change** is needed to show the new rows. However, the
    catalogue now holds 2,397 starred restaurants, so builds without the
    row-cap fix below (14 and 15) still show only the first 1000 in Guides.

### Changed
- Trip Detail: a trip with nobody else on it or invited now shows
  "Invite friends" (with an add-person icon) where it said "Just you so
  far", and the ⋯ menu item reads "Invite friends" until someone else is
  on the trip. On a real phone the old line didn't read as the way to
  invite, so the feature went unfound.

### Fixed
- **Guides' MICHELIN catalogue said "1000 places" while production holds
  1,797 starred restaurants.**
  - **Cause:** PostgREST returns at most `max_rows` (1000) rows per
    request and says nothing when it truncates. `RestaurantRepository.search`
    read the whole catalogue in one request, so it stopped at row 1000
    once the Spain and Belgium imports took the catalogue past 1000.
  - **Fix:** every unbounded catalogue read now pages through
    `fetchAllRows`, 1000 at a time, with `id` as a unique last sort key so
    pages can't skip or repeat rows. That covers `search`, `getAll`,
    `searchInPlaces` and `getCountries` on both repositories.
  - **Hidden side effect:** the country pickers had the same bug. They
    read one `country_code` per row, so any country whose rows fell
    after row 1000 dropped out of the picker.
  - **Hotels:** 811 rows, under the cap for now. They are paged the same
    way before Germany and Italy push them closer.
  - **Verified:** on the simulator against production, the catalogue shows
    "1797 places". `test/fetch_all_rows_test.dart` runs against a fake
    server that caps at 1000 like PostgREST; its country test fails
    without the fix. Analyze clean, 2,572 tests pass.
  - **Why it would recur:** any new query over the catalogue that skips
    `fetchAllRows` works in testing and breaks silently once the table
    passes 1000 rows.

---

## v1.3.0 (15) — 2026-10-29

Built from `release/1.3.0`: 1.3.0 (14) plus one app fix. No database change;
the ledger is still 107 migrations, local and remote in agreement. No
migration was added since (14)'s schema diff, so that diff still stands.

### Fixed
- **Splitting a trip into destinations could be refused with "Each
  destination's dates must fall within the trip".** Create Trip's default
  dates kept the current time of day (`now + 30 days`), and the
  destination check compared full timestamps. A destination lining up with
  a default trip date therefore counted as outside the trip. Dates in the
  sheet are now calendar days and compared by day. If a destination really
  is outside the trip, the message names it and both date ranges. A
  database refusal shows the database's own text. Reported on 1.3.0 (14)
  with a 10 Nov – 1 Dec trip split in two. Those exact steps weren't
  reproduced; the failing path is covered in
  `test/create_trip_leg_dates_test.dart`. (Cherry-picked from
  `feature/trips-redesign`, `8ae87c5`.)

---

## v1.3.0 (14) — 2026-10-29

Built from `release/1.3.0`. Every database change below was applied to
production before this build, so the build only adds the screens that use
them. Installed 1.2.0 (13) builds keep working against the same database:
the trips migration keeps `planned_trips.country_code`/`city` in step for
them, and the Selection and 50 Best columns are additions they don't read.
Ledger at the version bump: 107 migrations, local and remote in agreement.

**Schema diff at the version bump** (CLAUDE.md; method in
`NEW_MACHINE_SETUP.md` §4), production against a fresh full-stack replay of
all 107 migrations, 2026-10-29:
- **The replay:** all 107 files applied with no error, giving 107 ledger
  rows.
- **`supabase db dump`, both sides:** identical apart from 6 blank lines,
  the platform statements the CLI filters out.
- **Storage and auth, compared directly:** all 5 buckets, 13
  `storage.objects` policies, 8 triggers and RLS on both storage tables
  are identical.
- **Expected noise:** the one extra local trigger,
  `enforce_versioning_status_transition`, comes from the newer local
  storage service, not from drift.
- **Before the bump:** `flutter analyze` was clean and all 2,560 tests
  passed, on `main` after merging `feature/trips-redesign` and
  `feature/editorial-selection`.

**In this release, for testers:**
- **Trips, restyled and multi-destination.**
  - **Destinations:** a trip can cover several countries and cities, each
    leg with its own stays, dining and events.
  - **Shared trips:** invite friends onto a trip.
  - **Pickers:** "Add stay" and "Add restaurant" offer only venues in that
    leg's destination.
- **Mantelier Selection.** Our own picks, as "Mantelier's latest" on
  Explore and a Selection guide on Guides. Tacite and Petit Péché are the
  first two.
- **Guide links.**
  - **World's 50 Best:** a "50 Best" link to the venue's own page.
  - **Gault&Millau:** the restaurant's awards and a link to its page.
  - **Award History:** shows MICHELIN, World's 50 Best and Gault&Millau
    side by side.
- **Catalogue:**
  - MICHELIN Spain 2026 (296 starred), Belgium & Luxembourg 2026 and
    Monaco;
  - more World's 50 Best history, including 51–100 ranks;
  - QA fixes: Kjolle's location, the Plaza Athénée rename and Peru hotel
    phones.

### Added

- 2026-10-28 — The editorial Selection ("Mantelier Selection"), a fourth
  way into the catalogue next to a MICHELIN star, World's 50 Best and the
  hall of fame, decided by the product owner so restaurants we choose
  ourselves can be listed without an award. **Applied to production
  2026-10-28**, with Tacite (`rest_1840`) and Petit Péché (`rest_1841`),
  Amsterdam, as its first two entries.
  - Verified in production after the apply: ledger row present; the check
    constraint lists all six values; RLS on `editorial_selections`; `anon`
    can read but not write, `authenticated` can't write. Both restaurants
    inserted in one statement (`prepared_insert.sql` step 1), and
    `restaurants_full` returns both: Amsterdam, NL, `michelin_stars` NULL,
    `open`. Google Place IDs left NULL until found.
  - Checked on the simulator against production: "Mantelier's latest"
    below What's On with both restaurants; "Mantelier Selection" first on
    Guides, opening a two-restaurant catalogue; Tacite's detail page with
    no empty star row. The Explore "Collections" line now names the
    Selection first.
  - **`20261023120000_add_editorial_selection.sql`:** widens
    `restaurants.inclusion_reason` with `editorial_selection`, and adds
    `public.editorial_selections` (one row per entry, `removed_on` instead
    of deleting, at most one current entry per restaurant). Public read,
    select-only grant to `anon`/`authenticated`, no client write. Replayed
    on a throwaway local Postgres 17 against a stub `restaurants` table:
    the constraint, the one-current-entry index, the date check and the
    grants behave as intended; not replayed on the full Supabase stack.
  - First two entries prepared in
    `supabase/data/enrichment/editorial_selection/`: Tacite and Petit
    Péché, Amsterdam. Google Place IDs still to be found before apply.
  - Scope rule updated in `DATABASE_ARCHITECTURE.md`, `START_HERE.md` and
    `CLAUDE.md`. The product owner then dropped the restriction outright
    (2026-10-28: the catalogue is no longer limited to MICHELIN, World's 50
    Best and Gault&Millau restaurants); `CLAUDE.md` now says so.
  - Renumbered to `20261023120000` before apply: `20261019140000`,
    `20261019150000`, `20261021120000` and `20261022120000` were applied in
    between. Re-tested on a full local replay of production's exact
    migration set, seeded with restaurants carrying every
    `inclusion_reason` value in use: the constraint accepts every existing
    row, the prepared insert gives `rest_1840` Tacite and `rest_1841`
    Petit Péché, and `restaurants_full` shows both.
  - **App:** "Mantelier's latest" on Explore, directly below What's On (the
    eight newest Selection restaurants), and a "Mantelier Selection" family
    on Guides above MICHELIN, opening a catalogue of every Selection
    restaurant with on-device search and a country filter. The label is
    forest green, never gold; a starred Selection restaurant still shows
    its stars. Reads `editorial_selections` (`removed_on is null`), never
    `inclusion_reason`, and leaves the Selection out when the table doesn't
    exist yet.
- 2026-10-28 — Catalogue: MICHELIN Spain 2026 and Belgium & Luxembourg 2026.
  - **Migrations:** `20261019140000_add_es_2026_star_cities` (123 ES towns)
    and `20261019150000_add_be_2026_star_cities` (7 BE cities).
  - **Applied 2026-10-28,** after the v1.2.0 (13) build, so they are
    recorded here rather than in that section. Both went out in one
    `supabase db push --linked`, Spain sorting first; the ledger went from
    102 to 104/104, with local and remote in agreement. The data files
    (`michelin_es_stars/`, `michelin_be_lu_stars_2026/` and the Belgian
    Place IDs) were then run. Details are in the Michelin_Database CHANGELOG.
  - **No app change:** installed builds read the new rows as they are.

- Restaurant Detail shows the latest Gault&Millau award as a hero badge
  and links to the restaurant's own Gault&Millau page from the utility
  row. Award History gains a Gault&Millau section beside MICHELIN and
  World's 50 Best. App only, no schema change. A plan for World's 50 Best
  page links (no URL is stored yet) is in
  `docs/Architecture/GUIDE_SOURCE_LINKS_PLAN.md`.
- 2026-10-28 — World's 50 Best links. Restaurant and Hotel Detail get a
  "50 Best" action that opens the venue's own the50.com page.
  - **Migration:** `20261021120000_add_worlds_50_best_urls` adds
    `worlds_50_best_url` to `restaurants`/`hotels` and appends it to both
    `_full` views.
  - **Applied 2026-10-28,** after the v1.2.0 (13) build. Ledger 104 → 105,
    local and remote in agreement. Then
    `guide_source_links/apply_guide_source_links.sql` filled 113
    restaurant and 123 hotel URLs, plus the Gault&Millau fixes below.
  - **Order matters:** a build carrying the new column lists must not ship
    to a database without the migration. The migration is live, so any
    build from here on is safe.
  - **Not replay-tested:** no Docker on this machine. The view columns
    were checked against production instead.
- **Multi-destination trips.** Create/Edit Trip holds a list of destinations:
  a catalogue country, optionally narrowed to a catalogue city (new city
  picker, by `cities.id`), with Arrive/Leave dates required once there's more
  than one. Saved atomically through `save_trip_destinations`.
- **Trip Detail by leg.** A multi-destination trip shows one section per
  leg with its own stays and dining, and an "Elsewhere" section for plans
  outside every destination. A leg's "Add stay"/"Add" pickers are scoped to
  that leg (city id or country code), and new plans default to its dates.
- **Events per leg** (decision 2). Events are fetched for every destination
  country and matched on each leg's own dates and country, in Trip Detail,
  on the featured trip card and in discovery ranking's trip signal, which now
  names the matching leg's city.
- **Shared trips.** A "Travelling with" row and sheet on Trip Detail.
  Any member invites their own friends; the owner removes anyone; whoever
  sent a pending invite can withdraw it; members can leave. Other members'
  plans show read-only with "Added by …". Open invitations appear at the top
  of Trips and in Notifications (Join trip / Decline), read through
  `get_notifications_v3`.
- Catalogue venues now carry `city_id` (`Restaurant.cityId`/`Hotel.cityId`).
  The scoped `searchInPlaces` sorts A→Z.
- **Works before the migration too.** Against a server without
  20261022120000, Trips behaves exactly as the single-
  destination, owner-only build: the repository falls back on PostgREST's
  "not found" errors and hides destinations and sharing. Verified against
  production on the simulator.
- Verified end to end on the simulator against a local stack with the
  migration (`docs/Engineering/checks/trips_local_fixtures.sql`: local-only
  test accounts and fake venues). Checked: accept an invitation, create a
  two-leg trip with a city, legs, Elsewhere, per-leg events (an Italian
  event during the French dates correctly excluded), the leg-scoped picker,
  another member's read-only plan, the members sheet, and Edit pre-fill.

### Changed

- **Trips restyled** (Passport → Trips, Trip Detail, Create/Edit Trip, the
  venue pickers). The sections follow Explore's header pattern, and planned
  stays and visits are now the same ivory photo cards Passport uses
  (`CsPlaceCard` with the venue's card photo). Trip Detail gets a display-scale
  header with the destination and a pull-quote for notes. Dialogs, action
  sheets and snackbars are shared across Trips (`trip_chrome.dart`). Gold
  appears only on stars and Keys: removed from the Add/Change actions, the
  focus underline, spinners and the forest-green snackbars.
- **Pickers scoped to the trip's destination.** "Add stay"/"Add restaurant"
  offer only venues in the trip's own country, filtered server-side on
  `country_code` (never a name, never `property_name`). In Create Trip they
  stay disabled until a destination is chosen, and changing the destination
  drops picks from another country.
- A stay's date eyebrow uses the shortest unambiguous range
  ("27–30 Nov 2026") so it fits on one line; Trip Detail's start label
  ("IN 30 DAYS") is uppercase like the other eyebrows.
- `CsPlaceCard` gains an optional `onLongPress` (null by default, so
  existing cards are unchanged).

### Database

- **Applied 2026-10-28: `20261022120000_add_trip_destinations_and_members.sql`.**
  Several destinations per trip (`planned_trip_destinations`: a catalogue
  country plus an optional catalogue city, with leg dates required once
  there's more than one) and shared trips (`planned_trip_members`, plus
  invite/respond/leave/remove RPCs). Any member can invite their own
  friends. Unfriending or blocking removes the other person from your trips
  that haven't ended yet; past trips are untouched.
  Installed 1.2.0 builds keep working: `planned_trips.country_code`/`city`
  stay in step with the first destination, and they never see shared trips
  or the new notification types (`get_notifications_v3`/`_count_v3` are the
  only readers that include them).
  A plan can now only be attached to a trip you're on; before, any trip id
  was accepted.
  Verified in production after the apply:
  - ledger row present; both tables exist with RLS on;
  - all 5 existing trips have a first destination; the 16 planned venues are untouched;
  - anon can execute none of the 16 new functions;
  - the 8 client RPCs are callable by `authenticated`, the internal helpers are not;
  - all 7 triggers are present.
  `supabase migration list --linked` agrees, 106/106. That's measured with
  main and `feature/guide-sources`' applied `20261021120000`; this branch
  alone lacks those three files until it's merged.
  Checks: `docs/Engineering/checks/trip_destinations_and_members_checks.sql`,
  44/44 on a fresh replay of production's exact migration set, and again on
  a replay seeded with five pre-existing trips.
  Plan: `docs/Architecture/TRIPS_MULTI_DESTINATION_AND_SHARING_PLAN.md`.

### Fixed

- 2026-10-28 — Near-miss, caught before anything was applied. The
  Belgian update had picked `rest_1405`–`1417` for its new restaurants
  while France 2026 took the same codes on production. Its Place ID file
  checked only that each code existed, so it would have written Belgian
  Google records onto 13 French starred restaurants (Paul Bocuse among
  them).
  - **Renumbering:** Belgium was renumbered to `rest_1827`–`1839`.
  - **New guard:** every prepared Place ID file, and the Spanish file,
    now stops unless each code is the restaurant it was researched for,
    identified by its MICHELIN page.
  - **Why it would recur:** codes are picked as "the next free one" on a
    branch, while other branches pick from the same range. Only an
    identity check at apply time catches a code that someone else has
    taken since.
  - **Checked after the apply:** `rest_1405`–`1417` are still 13 French
    rows.

- Near-miss: 8 `gault_millau_awards.gault_millau_url` values in production
  are the import's `"not found"` placeholder text, not NULL. Linking the
  column directly would have opened a broken URL. The app now links only
  absolute http(s) values (`GaultMillauAward.profileUrl`). The data was
  then corrected on 2026-10-28 (QA-244): placeholders to NULL, 7 real
  pages filled.

- **"Change hotel" deleted every stay on the trip.** Trip Detail assumed one
  hotel per trip, but `planned_venues` allows several, and a second stay
  planned from the venue's own Plan sheet was silently removed. "Add stay"
  now only adds; each stay is removed on its own.
- **Countries listed Z→A in Create Trip, and the pickers listed venues Z→A.**
  postgrest-dart's `.order()` defaults to descending: `loadAllCountries`
  now passes `ascending: true`, and the pickers sort by name. The shared
  `RestaurantRepository.search`/`HotelRepository.search` still order
  `name` descending for every other caller (left alone here, logged as a
  follow-up), the same trap their own comment already warns about.

- **Migration filename collision, caught before apply.** This migration was
  written as `20261021120000`, but `feature/guide-sources` independently took
  the same version (`add_worlds_50_best_urls`) and applied it first; the
  ledger keys on the version alone. Renamed to `20261022120000` before it
  ever ran. It would recur whenever two branches pick "the next" timestamp
  without checking the remote ledger and every branch first.
- **First production apply failed and rolled back; no data or schema
  changed.** The backfill (one destination per existing trip) ran before
  the RLS section, so each inserted row queued a deferred date-check trigger,
  and Postgres refuses `ALTER TABLE … enable row level security` on a table
  with pending trigger events (SQLSTATE 55006). Local replays had passed
  because they had no trips to backfill; production had 5.
  Rollback verified in production: no new tables, functions or triggers;
  no ledger row; the `planned_trips` policy unchanged. Fixed by moving the
  backfill to the end of the migration, then re-tested on a replay seeded
  with five trips before re-applying. The lesson: a local replay with empty
  user tables doesn't exercise a migration's backfill path. Seed
  representative rows before applying anything that backfills.

---

## v1.2.0 (13) — 2026-10-28

Built from `release/1.2.0`. Every database change below was applied to
production before this build, so the build only adds the screens that use
them; installed 1.1.0 (12) builds keep working against the same database.
Ledger at the version bump: 102 migrations, local and remote in agreement.

**Schema diff at the version bump** (CLAUDE.md; method in
`NEW_MACHINE_SETUP.md` §4), production against a fresh full-stack replay of
all 102 migrations, 2026-10-28:
- `supabase db dump`, both sides: identical apart from 6 blank lines, the
  platform statements the CLI filters out.
- Storage and auth, compared directly: all 5 buckets, 13 `storage.objects`
  policies, 8 triggers and RLS on both storage tables identical. The one
  extra local trigger, `enforce_versioning_status_transition`, comes from
  the newer local storage service: expected noise, not drift.

**In this release, for testers:**
- **Venue events.** A venue's managers create, edit and cancel their own
  events from My venues → a venue → Events. New events are reviewed first;
  edits to a live event go live straight away and are recorded for the
  admins.
- **A landing page per managed venue** with Profile, Photos and Events.
- **In-app review for admins**: claims, about texts, photos, events and
  changes to live events, with a real preview.
- **Photo framing and a separate card photo** for venue managers.
- **Friend requests** have their own Requests tab.
- **Catalogue:** MICHELIN Netherlands 2026, France 2026 (652 starred),
  Peru's 15 Key hotels, the completed World's 50 Best lists, phone numbers
  and Google Place IDs.
- **Minimum iOS raised to 15.0.**

### Added

- 2026-10-28 — MICHELIN France 2026 and Peru catalogue data, with two
  migrations. Data details and QA ids are in the Michelin_Database
  CHANGELOG.
  - **Migrations:** `20261019120000_add_fr_2026_star_cities` (82 FR
    cities) and `20261019130000_add_pe_key_hotel_cities` (5 PE cities),
    only `public.cities` rows. Ledger 100 → 102.
  - **Data files** (`supabase/data/enrichment/APPLY_FR_PE_2026.md`):
    - France: 14 star corrections, 410 MICHELIN URLs, 173 new starred
      restaurants and 533 phones. France is now 652 starred: 30 / 80 / 542.
    - Peru: 14 Key hotels (Peru now 15: 1 / 4 / 10), Palacio Nazarenas'
      Key row, and Central and Mil's World's 50 Best history.
  - **Checked before and after:** every pre-write check was rerun read-only
    against production with the files' own data first; afterwards the
    counts, award rows and `_full` views were verified on production.
  - **Applied 2026-10-28.** No app code changed.

- 2026-10-28 — Venue events, phase 3: the app. It reads only the
  `20261018130000` RPCs; none of it works until that migration is
  applied.
  - **Events screen** (My venues → a venue → Events): every event the
    venue hosts, from `get_venue_events`, so every active manager sees
    the same list.
    - It groups them as awaiting review, not approved (with the
      reviewer's note), live, past and cancelled.
    - "Create an event" opens the form, and tapping an event edits it.
    - The landing page's summary counts upcoming, awaiting review and
      not approved.
  - **The event form** (`VenueEventFormScreen`):
    - name, description, one of the 7 V1 types, and tags from
      `event_tags`;
    - a date, an optional end date, an optional start time, and an end
      time only once there is a start. A time left out is sent as
      nothing and shown as "not given", never guessed;
    - "At {venue}", where the server copies the venue's verified
      location, or a place, city, country and a map pin
      (`PickEventLocationScreen`, OpenStreetMap);
    - the timezone comes from the country, and a country with several
      zones is asked;
    - ticket link, admission type and admission note.

    The form checks the server's own rules first: the window up to one
    year ahead, with "today" in the event's timezone; an end before the
    start on one day; https only. A refusal from the server is shown in
    its own words. A live event says "changes go live straight away", and
    a rejected one shows the note and "Save and resubmit". Cancelling
    asks for confirmation first.
  - **Review:** the queue gains EVENTS and CHANGES TO LIVE EVENTS, listed
    by event name. `ReviewEventScreen` handles both:
    - **a submitted event** shows its details as entered and "Preview
      the event page", which opens the real `EventDetailScreen`. The
      admin chooses Approve and publish, or Reject with a note;
    - **a change to a live event** shows each changed field, old → new,
      with a value left empty shown as "not given". The admin chooses
      Mark as seen, or Take offline with a note.
  - **Notifications:**
    - `event_approved` opens the event's page, and `event_rejected` shows
      the note;
    - the list and the unread count read the `_v2` functions, falling
      back to the old ones while a server doesn't have `_v2` yet;
    - **a type this build doesn't know is skipped** (`tryFromRow`), no
      longer a reason the whole list fails to load. The next new type
      can't empty the screen again.
  - **Event times:** venues may submit date-only or start-only events.
    This was decided by the product owner on 2026-10-28, over the time
    audit's earlier rule that host events need both times. The audit's
    "Host-Created Events" section is marked superseded in place, and
    `satisfiesHostCreatedEventTimeRequirement` stays unused with a note
    saying why.
  - **Tests:** 20 new; the existing venue tests now run against the new
    repository. 2,511 tests pass and analyze is clean.

    **Not tried on the simulator:** the screens need the phase 3
    migrations, which aren't on production yet.

- 2026-10-28 — Venue events, phase 3 of
  `docs/Architecture/VENUE_EVENTS_AND_ADMIN_REVIEW_PLAN.md`: the database
  half. The design and the six decisions taken are in
  `docs/Architecture/VENUE_EVENTS_PHASE_3_DESIGN.md`. There are two
  migrations; no app code changes yet.
  - **`20261018120000_add_country_timezones`:**
    - adds `countries.timezones`, every IANA zone for each country
      (tzdata 2025b `zone.tab`; QA-226, see the Michelin_Database
      CHANGELOG);
    - with one zone, the event form uses it as the default; with
      several, the form asks.
  - **`20261018130000_add_venue_event_submission`, what a venue calls:**
    - venues write events only through `submit_venue_event`,
      `update_venue_event` and `cancel_venue_event`, and read their own
      with `get_venue_events`;
    - the rights are those of any active manager of a host venue, not
      "whoever submitted it";
    - submitting creates the event as `submitted`, with its host link and
      tags, in one transaction;
    - editing a rejected event resubmits it;
    - editing a live event keeps it live and records the change in
      `event_edits`; an unchanged save records nothing;
    - "held at the venue" copies the venue's own verified location.
  - **Same migration, the rules:** one validation function serves both
    submit and update:
    - the 7 V1 types, and only tags that exist;
    - start and end dates from today up to one year ahead, with "today"
      in the event's own timezone;
    - an end time only with a start time, and on a single day the end
      after the start (00:00 means the end of that day);
    - coordinates, and a timezone from the event country's own list;
    - `start_at`/`end_at` are set only from a known time, never invented.
  - **Same migration, what an admin calls:**
    - `admin_approve_event`, and `admin_reject_event`, which needs a note
      and also takes a live event offline;
    - `admin_mark_event_edit_seen`;
    - each sends `event_approved`/`event_rejected` to the submitter;
    - `get_review_queue()` gains the kinds `venue_event` and
      `venue_event_edit`; installed builds skip kinds they don't know;
    - admins can read events that aren't published yet, for the review
      preview;
    - `events` gains `submitted_at`, `reviewed_at`, `reviewed_by` and
      `review_note`.
  - **Same migration, policies dropped:** the loose write policies on
    `events` and its link tables, all keyed on `submitted_by`. They were
    an open insert and update with no window or field checks, plus the
    unused participant-link policies. Nothing wrote through them:
    production's 28 events have no `submitted_by`, and every app query on
    these tables is a read (checked 2026-10-28).
  - **Notifications for the new build:** `get_notifications_v2()` and
    `get_unread_notification_count_v2()` include the event types (see
    Fixed for why the old functions hide them).
  - **Proof:** on a local stack, all 100 migrations replayed from empty,
    and a 53-check scenario passes:
    - permissions: non-managers, revoked managers, members and anon are
      refused;
    - each form rule, including a timezone edge (Auckland's "today");
    - unknown times stay null;
    - "held at the venue" ignores the location the app sent;
    - resubmit, edit history and cancel;
    - admin approve and reject with their notifications, and both new
      queue kinds;
    - direct table writes are refused, even for an admin.

    Every new `SECURITY DEFINER` function is closed to anon and PUBLIC,
    checked with `has_function_privilege`. The internal helpers are
    closed to `authenticated` too. The old `get_notifications()` result
    type is identical to production's.
  - **`notify-venue-submission` understands `events`.** The submitter
    comes from `submitted_by`, and the host venue is looked up like any
    other submission. The email gives the name, type, date, location,
    ticket link and the description verbatim. It shows only the times the
    venue gave: "Sat, 14 Nov 2026 (no time given)", "from 19:30", or a
    range, plus the event's timezone. The calendar date is never shifted.
    A previously reviewed event is marked "Event resubmitted". 9 new
    tests; all 29 pass.
  - **Applied and deployed 2026-10-28**, from `feature/venue-events`:
    - **Checked first** (read-only): production still had the 58
      countries the migration covers, all 6 tag ids, and 28 events with
      none written from the app.
    - **Migrations:** plain `supabase db push --linked`, ledger 98 →
      100/100, local and remote in agreement.
    - **Verified on production** (read-only):
      - every country has its zones (44 with one);
      - still 6 tags and 28 published events, and no `event_edits`;
      - no write policy left on `events` or its link tables, and the
        four admin read policies are in place;
      - no new function is executable by anon or PUBLIC, and the
        internal helpers aren't executable by `authenticated`;
      - `get_notifications()`'s result type is unchanged.
    - **Compared with a fresh local replay:** 39 objects identical. That
      covers every new or changed function with its grants, the new
      table and columns, the countries' zones and the tags, the three
      constraints, and every policy on the events tables.
    - **Edge Function:** `notify-venue-submission` deployed (version 4 →
      5, `verify_jwt` still off). A missing or wrong secret gets 401, so
      the smoke test sent no email.
    - The phase 3 build is on the same branch and not yet released.
    - **Tried on the simulator** against production, signed in as the
      test manager `@test` (Flore):
      - the landing page shows "1 upcoming";
      - Events lists Flore's events, grouped as live and past;
      - "Create an event" loads the 6 tags and "Times are in
        Europe/Amsterdam.";
      - a date-only event, "TEST please ignore", was submitted at Flore.
        Production stored it as `submitted`, with `start_at`/`end_at`
        and `start_time` null, Flore's own address and coordinates, and
        a host link with `is_venue`. The admin email call returned 200;
      - the event showed under Awaiting review, and reopened in the
        form with nothing guessed;
      - cancelling it asked for confirmation first; it is now
        `cancelled` and no longer in the review queue.

      The test event stays in `events` as a cancelled row.
    - **Admin side, signed in as `@kylan`:**
      - a second test event, "TEST review please ignore", was submitted
        as `@test`;
      - Review showed it under EVENTS · 1;
      - the review screen showed its details;
      - "Preview the event page" opened the real event page of the
        unpublished event;
      - Reject with a note stored `rejected`, the note, `@kylan` as
        reviewer, and an `event_rejected` notification to `@test`.

      This found the two bugs under Fixed.
    - **Back as `@test`, with the fixes in:**
      - Explore doesn't show the rejected event;
      - the Notifications badge counted 1 (through `_v2`);
      - the list showed '"TEST review please ignore" at Flore was not
        approved.' with the note, alongside every older notification;
      - Flore's landing page read "1 upcoming · 1 not approved";
      - Events listed it under NOT APPROVED with the note;
      - the form opened with "Saving your changes sends it back for
        review." (closed without saving).

      Still not tried: approving, a live edit, and the map pin.

- 2026-10-28 — A landing page per managed venue, phase 2 of
  `docs/Architecture/VENUE_EVENTS_AND_ADMIN_REVIEW_PLAN.md`. My Venues
  used to open one long screen with the about text and every photo
  control on it. Now:
  - **The landing page** (`VenueManagementScreen`) shows the venue's
    name with its card photo (card crop), then three rows, each with a
    one-line summary: **Profile** ("Published", "Awaiting review", "Not
    approved", "Nothing published yet"), **Photos** ("3 photos · 1
    awaiting review") and **Events** ("2 upcoming"). Preview my page and
    the contact line stay here. Coming back from any section reloads all
    three summaries. A failed lookup only blanks its own summary; the row
    still opens.
  - **Profile** (`VenueProfileScreen`) and **Photos**
    (`VenuePhotosScreen`) are the two halves of the old screen, moved
    unchanged. Nothing was removed.
  - **Events** (`VenueEventsScreen`) is new and read-only for now: the
    upcoming events the venue hosts, the same list its public page shows
    (`loadHostedEventsFor*`). Creating and editing events is phase 3, and
    deliberately has no placeholder button here.
  - Private chefs get the same page.
  - **App only:** no migration, nothing new read from the database.
  - **Tests:** the existing tests now run against the screen each one
    covers. New tests cover the landing page (summaries, card photo,
    failure isolation, navigation, reload on return, private chefs, no
    verified-data fields) and the Events screen.

- 2026-10-28 — In-app review for admins, phase 1 of
  `docs/Architecture/VENUE_EVENTS_AND_ADMIN_REVIEW_PLAN.md`. Reviewing a
  venue claim, an about text or a photo meant finding the row in the
  Supabase dashboard and running SQL by hand, or `curl` with a secret for
  a photo, with no way to see what the submission would look like. Now:
  - **Profile → Review**, shown only to admins, with the number waiting.
    The queue groups everything by kind, oldest first. Each item opens
    with what's needed to decide:
    - **claim:** the claimant's details;
    - **about text:** the text, plus "Preview the venue page", which
      opens the real detail screen with it in place;
    - **photo:** the photo in its real header and card frames with its
      framing, plus the same page preview.
    Approve, or reject with a note the venue receives through the
    notifications that already existed.
  - **`20261017120000_add_in_app_review.sql`:**
    - `public.admins` (RLS on, no client policy and no grant — admins are
      added by hand in the dashboard) and `is_admin()`;
    - `get_review_queue()`;
    - admin-only wrappers that call the existing dashboard functions with
      `auth.uid()` as the reviewer — the originals keep their
      dashboard-only ACL as the fallback;
    - an admin read policy on the private `venue-photo-submissions`
      bucket, for the preview.
    Every new SECURITY DEFINER function carries its `revoke … from
    public, anon`.
  - **`publish-venue-photo`** also accepts an admin's own login. On that
    path the reviewer is always the caller (a `reviewed_by` in the body is
    ignored); the secret path is unchanged. 22 deno tests pass (5 new).
  - **Settled decision revised, on purpose.** CLAUDE.md said "There is no
    in-app admin identity and none is planned"; the product owner decided
    on 2026-10-28 to review in the app, and that an admin may approve
    their own submissions. The rule now names `is_admin()` as the single
    source of review permission. `VENUE_CLAIM_OPERATIONS.md` keeps its
    snippets, marked as the fallback, and says how to add an admin.
  - **Proven locally only.** On a replay of the 97 existing migrations
    with an admin, a manager and a member, then this one: `is_admin()` is
    true only for the admin; the queue showed a claim, an about text and a
    photo with venue, city and submitter, and refused the other two; every
    admin action refused a non-admin; approving the about text made it
    current, the claim approval granted the manager permission, the photo
    rejection stored its note, and each recorded the admin as reviewer;
    the venue got all four notifications; a second approval of the same
    item was refused; nobody could insert into `admins` from the app;
    anon and PUBLIC hold no EXECUTE on any new function. A fresh replay
    of all 98 files gave identical definitions. Analyzer clean; 2,476
    tests pass (9 new). Not yet seen on the simulator: it needs this
    applied, an admin row and the function deployed.
  - **Rollout order:** the migration, then the admin row, then deploy
    `publish-venue-photo`, then the build. Installed builds are
    unaffected — they don't call any of this.
  - **Applied 2026-10-28**, in that order:
    - **Migration:** plain `supabase db push --linked` (ledger 97 → 98/98).
      The 9 objects (7 functions, `admins`, the storage policy) are
      identical to the fresh replay's, and only `authenticated` holds
      EXECUTE on the new functions (not anon, not PUBLIC); the dashboard
      originals remain uncallable from the app.
    - **Admin row:** the product owner's account (`@kylan`) added by hand,
      the only admin.
    - **Edge Function:** `publish-venue-photo` deployed (version 4 → 5,
      `verify_jwt` still off). Smoke-tested without side effects: no
      login, and the anon key as a bearer, are both refused with 401.
    - **App:** on the simulator, signed in as the non-admin `@test`, the
      Review row correctly stays hidden. Signed in as `@kylan`, Review
      shows with a badge of 2; the queue loads production's pending Flore
      about text and photo, and the photo item shows the private
      submission (signed URL, so the admin storage policy works) in both
      the header and card frames. The product owner then approved both
      from the app (photo 15:59:28, about text 15:59:57 UTC), each
      recorded with `@kylan` as reviewer — the first production run of
      the admin wrappers and of the Edge Function's admin-JWT publish.
    - **Coordination:** a parallel session's branch
      (`feature/editorial-selection`) builds on this commit and carries
      `20261017130000`. It was confirmed unapplied before this push, so
      only this migration went out.

- Project documentation
- Database organisation
- Architecture documentation
- 2026-10-28 — Hotel phone numbers, from user feedback asking for a phone
  on every World's 50 Best venue. `20261016130000_add_hotel_phone.sql`
  adds `hotels.phone` and appends it to `hotels_full` (the follow-up
  `20260819120000_add_restaurant_phone.sql` named); `Hotel.phone`,
  `hotelFullColumns` and a Call action on `HotelDetailScreen`, wired exactly
  like the restaurant one (hidden when closed or no usable number).
  `20261016120000_add_worlds_50_best_countries_and_cities.sql` adds the
  countries/cities the missing World's 50 Best venues need. Same day:
  `20261016140000_add_nl_2026_star_cities.sql` adds the five NL cities the
  MICHELIN Gids Nederland 2026 update needs
  (`supabase/data/enrichment/michelin_nl_stars_2026/`). **Applied to
  production 2026-10-28**, all three with plain `supabase db push --linked`
  following `supabase/data/enrichment/APPLY_2026-10-28.md` (ledger 94 →
  97/97, no hang). Checked afterwards: 3 countries and 16 + 5 cities
  present, `hotels.phone` and `hotels_full.phone` present, `hotels_full`'s
  grants unchanged. The seven catalogue files from the same guide then ran
  in order, none aborting; their results, measured against production, are
  in the Michelin_Database CHANGELOG (World's 50 Best completion, NL 2026
  stars at 1/20/98, phones for 318 restaurants and 103 hotels, Place IDs,
  QA-209/216/218). `live_view_full_columns_test` now passes against
  production, so a build carrying the new `hotelFullColumns` can ship.
  Compiled and tested on the branch afterwards: analyzer clean, full suite
  passes (2,467). Not yet seen in the app: a hotel's and an Amsterdam
  restaurant's Call button, Azurite's page, De Librije's award history.
- 2026-10-02/03 — Admin email on every new content report, generic over
  `content_type`: `20261010120000_add_content_report_admin_email_
  notification.sql` (trigger `content_reports_notify_admin_on_insert` →
  pg_net → new `notify-content-report` Edge Function → Resend, its own
  `notify_content_report_webhook_secret`, warn-never-block like every
  other `notify_admin_of_pending_*`). `content_reports` had carried
  reports since September with no admin notification at all. A reported
  photo's venue is resolved by name in the email (`c0ae732`), since
  `content_id` alone doesn't say which of three photo tables it's in.
  Applied after the 1.1.0+12 build, so it sits here. Its commit
  (`9f81977`) says "not yet applied"; it was applied later, on a date
  nothing recorded — this entry was missing until 2026-10-27, when the
  state below was read back from production.
  **Verified 2026-10-27, read-only:** remote ledger holds the migration
  (88/88, no mismatch); trigger exists and is enabled; `anon` cannot
  execute `notify_admin_of_pending_content_report()`; function deployed
  (version 2, 2026-10-03 11:05, one minute after `c0ae732` — so very
  likely that version, inferred from timing, not from comparing
  source); `NOTIFY_CONTENT_REPORT_WEBHOOK_SECRET` and `RESEND_API_KEY`
  set as function secrets, and the vault entry's value matches the
  function secret (SHA-256 compared, no value read out); all 18 of the
  function's deno tests pass.
  **Not proven end to end.** Exactly one real report exists (a photo,
  2026-10-11 01:31 UTC). pg_net no longer retains its response, and the
  one response it does retain (200, 2026-10-13) can't be tied to it, so
  whether that email reached `claimedvenues@mantelier.app` is unknown —
  the inbox is the only remaining evidence.
- 2026-10-27 — `20260820125000_events_v2_timezone_backfill.sql`: writes
  the `events.timezone` backfill into migration history, so a
  from-scratch replay can get past `20260820130000`'s NOT NULL. The
  production backfill (4 events, Europe/Amsterdam) was a separately
  approved out-of-band UPDATE and never in history, so a fresh build's
  only migration-inserted event ('t Preuvenemint, NL) reached NOT NULL
  with timezone NULL and failed. Matches `timezone is null and
  country_code = 'NL'` only — no stable event code exists and name
  matching is forbidden; any other NULL still fails loudly. Timestamp
  deliberately sits between the two timezone migrations under
  CLAUDE.md's new in-between-backfill exception. **Applied to production
  2026-10-27** with `supabase db push --include-all`, after a dry run
  listed only this file. Beforehand, a read-only check found 0 of 28
  events it would match (`timezone` already NOT NULL, no NULLs) and
  only row-level triggers on `events`, so nothing could fire. Push
  returned normally. Afterwards, verified directly: ledger 89/89 with no
  mismatch, the version present, events unchanged (28, no NULL
  timezones).
- 2026-10-28 — Venue managers can frame their own photos and choose the
  cover. Until now every venue photo was a plain centred crop:
  `focus_x`/`focus_y` had existed on the published photo tables since
  20260828130000, but nothing wrote or read them, and there was no zoom.
  - **Framing.** A focus point plus a zoom factor (1–4) per photo, set in
    a drag/pinch editor that shows the real header frame with the card
    frame updating beneath it. At upload it replaces the old read-only
    `VenuePhotoFramePreview` (removed) and travels on the submission;
    on a published photo, My Venues' new "Adjust framing" saves it
    straight away through `set_venue_photo_framing`, with no re-review.
    Applied by one shared `FramedImage` in the detail heroes and every
    card (Explore, search, Passport, Wishlist, Rankings, Guides, private
    chefs), using news_articles' existing focus semantics (cover
    alignment, zoomed around the same point). Private chef photos nobody
    has framed keep exactly their old hero (−0.8) and card (−0.3)
    placements.
  - **Cover.** The first photo is labelled "Cover", with a line saying
    it's the one on cards in Explore, search and Passport; "Make cover"
    on any other photo moves it to the front through the existing
    `reorder_venue_photos`.
  - **`20261014120000_add_venue_photo_framing.sql`:**
    - adds `zoom` to the three photo tables and `focus_x`/`focus_y`/`zoom`
      to `venue_photo_submissions`; existing rows default to centred, 1x,
      so nothing that shows today changes;
    - adds `set_venue_photo_framing()` (SECURITY DEFINER,
      `is_active_venue_manager()` as the only permission source,
      `revoke … from public, anon`);
    - extends the column-lock trigger to `zoom`, so direct client writes
      to the image, alt text, focus or zoom are still refused;
    - makes `approve_venue_photo` carry the submission's framing across
      (same signature, so its dashboard-only ACL is kept);
    - adds `cover_focus_x`/`cover_focus_y`/`cover_zoom` to
      `restaurants_full`/`hotels_full` (derived from 20261006120000's
      definitions, new columns appended).
  - **Settled decision revised, on purpose.** CLAUDE.md said a manager
    may change only `display_order` on published photos; the product
    owner decided on 2026-10-28 that framing should be adjustable without
    review, since it presents the same verified photo rather than adding
    content. The rule now reads "order and framing, never the image or
    its alt text", both through their RPCs only; CLAUDE.md also records
    that the cover is simply the lowest-`display_order` photo.
  - **Proven locally only.** On a replay of the existing 92 migrations,
    with a manager, a restaurant and two published photos, then the
    migration applied: existing photos stayed 0.5/0.5/1; the manager's
    RPC call worked; another user, out-of-range values and direct UPDATEs
    were refused; reordering still worked and the view's cover columns
    followed the cover; a submission framed 0.7/0.25/2.5 published with
    exactly those values; anon and PUBLIC hold no EXECUTE on the new
    RPC. A fresh replay of all 93 files gave identical definitions for
    the functions, views, columns and checks (39 objects). Analyzer
    clean; 2,449 tests pass, including new ones for the model, the
    framed image, the editor's drag maths on a real image (and that the
    page scroll can't take a drag inside the frame), the Adjust screen,
    and Cover/Make cover. The 2 failing are `live_view_full_columns_test`
    against production, which lacks the new view columns until this is
    applied — exactly what that guard is for.
  - **Rollout order: migration first.** The new build selects the new
    columns by name, so against a database without them photos would
    fail to load; installed builds select their own lists and are
    unaffected.
  - **Applied to production 2026-10-28** with plain `supabase db push
    --linked` (ledger 93/93). A read-only snapshot before and after shows
    the photo tables, submissions and both full views unchanged (5
    restaurant, 0 hotel, 1 private chef photo, 6 submissions, 1,363
    restaurants, 775 hotels); every existing photo is at 0.5/0.5/1, the
    one cover is centred, and venues without a cover have null cover
    framing. All 39 definitions and their ACLs (functions, views,
    columns, checks) are identical to the fresh replay's;
    `set_venue_photo_framing` is SECURITY DEFINER and executable by
    `authenticated` only (not anon, not PUBLIC); `approve_venue_photo`
    stays dashboard-only. `live_view_full_columns_test` now passes
    against production, and the full suite is green (2,451). The app
    change ships with the next build.
  - **Not covered:** the feature hasn't been seen signed in on a device
    (the simulator build talks to production); friend tiles fed by the
    friend RPCs (visits, wishlist, profile overview) still show covers
    centred, since those RPCs don't return framing.
- 2026-10-28 — A venue's card photo: which of its approved photos shows
  on the small cards, with its own crop, separate from the cover that
  leads the detail page. Asked for by the product owner (a restaurant may
  want a different photo, or a different crop, for the small picture).
  - **My Venues.** A Card photo section sits between the photo list and
    "Awaiting or not approved": the card photo at card size with its card
    crop, "Same as your cover" or "Your chosen photo", and Change into a
    new CardPhotoScreen — pick from the approved photos (cover labelled),
    frame it in an editable 1:1 card (4:5 for private chefs) with
    Explore's 4:3 card previewed beneath, Save live with no review;
    "Follow my cover" clears the choice. "Make cover" is gone from the
    photo rows (the top photo says Cover; the arrows reorder), and the
    header editor (Adjust framing, upload) now shows only the header —
    its card preview had shown a crop the card no longer uses.
  - **Every card** (Explore, search, Passport, Wishlist, Rankings,
    Guides, the chef card, the friend tiles) now shows the card photo
    and card crop; only the detail hero uses the cover. With no choice,
    or against a server without the columns, the card is the cover.
  - **`20261015120000_add_venue_card_photo.sql`:**
    - adds `is_card` (at most one per venue, partial unique index) and
      `card_focus_x`/`card_focus_y`/`card_zoom` to the three photo
      tables — a card crop on every photo, so even the cover can be
      cropped differently for the card; defaults keep today's cards;
    - adds `set_venue_card_photo()` (SECURITY DEFINER,
      `is_active_venue_manager()`, `revoke … from public, anon`); a null
      photo means "follow the cover";
    - extends the column-lock trigger to the four new columns;
    - makes `approve_venue_photo` keep a replaced card photo the card
      photo (its crop reset for the new image);
    - adds `card_photo_url`/`card_focus_x`/`card_focus_y`/`card_zoom` to
      `restaurants_full`/`hotels_full` (flagged first, then lowest
      position), leaving `cover_photo_url` unchanged so installed builds
      keep showing the cover on cards until they update.
  - **CLAUDE.md:** the photo rule now reads "order, framing and which
    approved photo is the card photo, never the image or its alt text",
    with header and card crops, the three RPCs and both migrations named.
  - **Proven locally only.** On a replay of the 93 existing migrations
    with a manager, a restaurant and two published photos, then this
    one: no choice gives the cover; choosing another photo with a crop
    works; re-choosing keeps one flag; follow-the-cover clears it;
    another user, a foreign photo, out-of-range values and direct
    UPDATEs were refused; an approved replacement of the card photo kept
    the flag; anon and PUBLIC hold no EXECUTE. A fresh replay of all 94
    files gave identical definitions (74 objects). Analyzer clean; 2,465
    tests pass, including new ones for CardPhotoScreen, the card fields,
    the editor's header and card modes, and the section's place on My
    Venues. The 2 failing are `live_view_full_columns_test` against
    production, which lacks the new view columns until this is applied.
  - **Rollout order: migration first** — the new build selects the card
    columns by name.
  - **Applied to production 2026-10-28** with plain `supabase db push
    --linked` (ledger 94/94). A read-only snapshot before and after shows
    the photo tables, submissions and both full views unchanged; every
    photo is at the defaults (no card chosen, centred card crop) and
    every venue's card equals its cover. All 74 definitions and ACLs are
    identical to the fresh replay's; `set_venue_card_photo` is SECURITY
    DEFINER, executable by `authenticated` only (not anon, not PUBLIC);
    `approve_venue_photo` stays dashboard-only. `live_view_full_columns_
    test` passes against production and the full suite is green (2,467).
    Not yet seen on the simulator; the app change ships with the next
    build.

### Changed

- 2026-10-27 — Minimum iOS raised from 13.0 to 15.0
  (`IPHONEOS_DEPLOYMENT_TARGET`, all three Runner build configurations in
  `ios/Runner.xcodeproj/project.pbxproj`). Forced by the toolchain, not
  chosen: Xcode 27.1 on the new machine rejects anything below 15.0
  ("supported deployment target versions is 15.0 to 27.1.x"), so
  `flutter build ios --no-codesign --simulator` failed outright until it
  moved; the old machine's Xcode 26.6 still accepted 13.0, which is why
  1.1.0+12 shipped on it. Would recur on any machine with a newer Xcode.
  The next build drops iOS 13 and 14 devices; nothing in the repo
  recorded why 13.0 was originally chosen. Simulator build verified
  after the change; a signed device build and `flutter build ipa` have
  not been run yet.

### Fixed

- 2026-10-28 — Two bugs found trying the phase 3 review side on the
  simulator as the admin `@kylan`, both fixed on `feature/venue-events`:
  - **Unpublished events showed in an admin's discovery lists.** After
    `@kylan` rejected the test event "TEST review please ignore", it
    still appeared in Explore's What's On. Every events list query
    (Explore, What's On, a country's events, hosted events, wishlists,
    friends' and past attendance) relied on RLS alone. Since
    `20261018130000`, RLS also lets admins (`events_admin_read`) and an
    event's own submitter (`events_own_submission_read`) read submitted,
    rejected and archived rows. A submitter would have seen their own
    unapproved event in Explore the same way.
    - Every list now filters `moderation_status = 'published'` itself
      (`publishedEventsOnly`), so admins and submitters see exactly what
      everyone else sees. Regular users and anon were never affected.
    - Only `loadEventById` stays unfiltered, so the review preview can
      open an event before it's published.
    - **Production:** no change needed, because the policies are
      correct. The shipped build has the same unfiltered queries, but
      until today no unpublished event existed for anyone to see.
    - **Test:** `events_published_only_test.dart` records the real REST
      requests and checks each one.
    - **Would recur** whenever a new read policy widens access to
      events. Lists must say what they list rather than inherit RLS.
  - **The review queue never reloaded** after a decision or a pull to
    refresh, in debug builds. `setState(() => _future = next)` returns
    the Future, which Flutter rejects in debug mode, so the state never
    changed. The decision itself saved; only the list stayed stale.
    - Fixed there, in the Profile review badge (`_reviewCountFuture`),
      and in `EventsScreen._reload`, which had the same shape.
    - Release builds skip that check, so shipped builds were unaffected.
      It is the same mistake that broke `VenueEventsScreen` during phase
      3 and was caught by its tests.

- 2026-10-28 — Two gaps found while drafting phase 3, both closed in
  `20261018130000`:
  - **The six event tags existed only in production.** They were
    inserted 2026-08-22 outside any migration, so a fresh replay had none
    and tags could never be assigned there. The migration seeds
    production's exact rows, ids included, with `on conflict do nothing`;
    on production that is a no-op, since all six ids are present
    (checked). Tag validation reads `event_tags` instead of a hardcoded
    list, so a missing tag is an error rather than being silently
    dropped. Would recur whenever reference data is entered by hand in
    the dashboard.
  - **Installed builds throw on a notification type they don't know**
    (`AppNotificationType.fromWire`). One `event_approved` row would have
    made the whole Notifications screen fail to load on every current
    build. `get_notifications()` and `get_unread_notification_count()`
    now return only the types those builds know, and the phase 3 build
    reads the `_v2` functions. `_v2` was built from production's live
    definition, which has one more column (`friendship_status`) than the
    migration first read for it. The phase 3 build should also make the
    parser skip unknown types, so the next new type can't cause this
    again.

- 2026-10-02 — `claims_*.review_note` was written by `reject_venue_claim`
  but `get_notifications()` never surfaced it: a claimant whose venue
  claim was rejected saw "not approved" with no reason anywhere in the
  app. Carried through the same way `venue_about_submissions`/
  `venue_photo_submissions`' own rejection notes already were. Applied
  after the 1.1.0+12 build, so it sits here rather than in that
  release's own section, per CLAUDE.md's migration-naming/changelog rule.
- 2026-10-27 — `20260925120000_add_profiles_member_number.sql`'s
  `setval(seq, coalesce(max(member_number), 0))` raised "value 0 is out
  of bounds" on an empty `profiles` table, since the sequence's minimum
  is 1. Production had profiles when it ran, so only a fresh build hit
  it, and every from-scratch replay died there. Edited in place to the
  three-argument `setval(seq, coalesce(max, 1), max is not null)`, with
  the original statement quoted in the file — the first use of
  CLAUDE.md's new correct-an-applied-migration exception. Proven by
  running both forms side by side in a throwaway Postgres 17: empty
  table, the original errors and the new form gives 1; non-empty (max
  7), identical sequence state (`last_value=7, is_called=true`) and the
  same next value, 8. So no member number, and nothing printed on a
  passport, changed. Nothing to apply: production never re-runs it.
  Would recur in any migration that seeds a sequence from `max()` of a
  table that can be empty.
- 2026-10-27 — Fresh replay proof, the one `NEW_MACHINE_SETUP.md` §4
  had owed since 2026-10-02, run locally via `supabase start` (full
  stack). A bare `supabase/postgres` container can't do it: it has no
  `storage.*` tables (the storage service creates them) and no pg_net,
  so it fails at migration 4. The full stack found the two gaps above,
  one after the other, beyond the known countries one. With both fixes,
  all 89 files apply cleanly (55 countries, the one event on
  Europe/Amsterdam, member sequence at 1 unused, 5 buckets). Without the
  countries seed, replay fails exactly where §4 predicted. Nothing
  touched production.
- 2026-10-28 — `visit-photos` behaved differently in production from a
  database rebuilt from migration history. The bucket was first made by
  hand in the dashboard on 2026-07-27 (15 MiB, jpeg/png/webp/heic plus
  `image/heif`) along with four owner-only "Users can … own stored visit
  photos" policies on `storage.objects`, one of them UPDATE.
  `20260807120000` then inserted the bucket with `on conflict do
  nothing`, so production kept the dashboard settings and the migration's
  own (10 MiB, no heif, no update policy) never took effect there. Found
  by the 2026-10-28 schema diff, which matched everything else migrations
  create. `20261011120000_converge_visit_photos_storage_to_migrations.sql`
  moves production toward history rather than the reverse: no update
  policy is the documented design (`20260825170000`'s header), the other
  three policies duplicate `visit_photos_read`/`_insert`/`_delete`, the
  app never sends heif, never upserts or moves an object (none of it in
  git history either), and compresses every pick well under 10 MiB.
  It drops the four policies (`if exists`) and resets the bucket limits.
  Proven locally only: with production's state recreated (hashes of all
  17 `storage.objects` policies and the bucket matched production's), it
  converges exactly to a fresh replay's state; re-running it changes
  nothing; a fresh replay of all 90 files applies cleanly and is
  identical. Through the storage API afterwards, overwrite, `image/heif`
  and an 11 MiB upload are refused, normal uploads, reads and deletes
  work, and an 11 MiB object stored beforehand stays readable. **Applied
  to production 2026-10-28** with plain `supabase db push --linked`
  (ledger 90/90). Afterwards production's `visit-photos` bucket and all
  12 `storage.objects` policies hash-identical to a fresh replay's, and
  all 11 existing objects are still there. Beforehand, a read-only check of production's 11 existing
  `visit-photos` objects (2026-10-28) found none over 10 MiB and none of
  type heif — largest 912,712 bytes, only `image/jpeg` recorded — so the
  looser dashboard limits were never actually used. Two of the 11 carry
  no metadata at all (no size, no mimetype, no version, no `photos` row,
  both created at the identical instant 2026-08-13 06:39:01 UTC, two path
  segments deep rather than the app's three); where they came from is
  unknown, nothing in the repo inserts into `storage.objects`, and the
  bucket limits can't affect them either way. Would recur with any
  bucket or policy created in the dashboard rather than in a migration.
- 2026-10-28 — An incoming friend request could be impossible to find.
  Profile's Friends row counts `get_incoming_friend_requests` ("1
  request") and opened the Friends screen, but Notifications V1 had
  moved incoming requests off that screen entirely — its tabs were
  Friends and Sent, and Sent lists only requests you sent. The request
  lived only in Notifications, which marks everything read on open, so
  after one look nothing pointed to it any more. Reported by the
  developer's own account (request of 2026-10-08, its notification
  present and already read). Incoming requests are back on Friends as a
  Requests tab between Friends and Sent, with the same Accept/Decline
  RPCs as Notifications (which keeps its own row), reading the same RPC
  as Profile's count so the two can't disagree; Profile's row opens
  straight onto Requests when it shows a count. Analyzer clean, full
  suite passes (2,420), simulator build launches; not exercised signed
  in, since the simulator build talks to production. Found alongside,
  not fixed: 4 pending requests from 2026-09-23 have no notification at
  all (the trigger arrived 2026-09-24 with no backfill) — the new tab
  shows them, Notifications never will; an answered request's
  notification keeps its Accept/Decline, and tapping it then fails, now
  more reachable with two places to answer; and the Accept/Decline pair
  overflows at 320px width combined with 1.6x text, on both screens.
  Would recur whenever an action moves between screens while a count
  elsewhere still points at the old one.
- 2026-10-28 — Two of the gaps found alongside the entry above. **(1)** A
  friend request's notification kept Accept/Decline after the request was
  accepted, declined, cancelled or removed; tapping either made the RPC
  raise "no longer available", which NotificationsScreen never caught, so
  nothing visible happened. `20261012120000_add_friendship_status_to_
  notifications.sql` recreates `get_notifications()` with one more
  column, `friendship_status` (from the `friendships` join it already
  had; NULL once the row is gone), the same pattern as `invite_status`.
  The row now offers Accept/Decline only while pending, then "You
  accepted"/"You declined", nothing for blocked or gone; `_accept`/
  `_decline` catch the error, say so and reload (invites too).
  `AppNotification` tells a missing column from a NULL value, so a server
  without the column keeps the old always-offer behaviour and build and
  migration can ship in either order; builds already out ignore the extra
  column. **(2)** The 4 pending requests from 2026-09-23, sent before the
  notification trigger existed, had no notification at all.
  `20261013120000_backfill_pre_trigger_friend_request_notifications.sql`
  inserts one for every pending friendship without one, dated with the
  friendship's own `created_at` and unread; it matches 0 rows on a fresh
  replay. Proven locally only: with production's situation recreated
  (pending, accepted, declined, sender-cancelled, and two pre-trigger
  requests in both directions), the backfill inserted exactly the two
  missing notifications to the right recipients at their original dates,
  re-running either migration changed nothing, `get_notifications()`
  returned the right status per row as each user, only `authenticated`/
  `service_role` hold EXECUTE (not anon or PUBLIC), and a fresh replay of
  all 92 files gives an identical function definition and ACL. Analyzer
  clean, full suite passes (2,424). Not exercised: the app against the
  new function end to end, and the row's three states in the simulator.
  **Applied to production 2026-10-28** with plain `supabase db push
  --linked` (ledger 92/92). A read-only count just before still found
  exactly 4 pending requests without a notification, all 2026-09-23.
  Afterwards: 0 left; notifications went from 8 to 12, the 4 new ones
  each dated with its friendship's own `created_at`, unread, addressed to
  the request's recipient (3 distinct people); `get_notifications()`'s
  definition hash and ACL identical to the fresh replay's, with no
  EXECUTE for anon or PUBLIC. The app change ships with the next build;
  until then, installed builds ignore the new column. The
  320px-plus-1.6x overflow stays open. Would recur with
  any trigger added to a table that already has rows it should have
  fired for.
- 2026-10-28 — The incoming friend request's Decline/Accept pair
  overflowed by 75px at 320px width with 1.6x text, on both FriendsScreen
  and NotificationsScreen. IdentityRow gives its trailing widget
  unbounded width, so nothing ever made the pair give way. Both rows now
  use one shared `FriendRequestRow`
  (`lib/features/friends/widgets/friend_request_row.dart`): it measures
  its own width, caps the actions at what's left after the avatar, gaps
  and a 56px minimum for the name, and lets a `Wrap` stack Decline above
  Accept, right-aligned, only when they don't fit (the `Wrap` then shrinks
  to the wider button, so the name gets the space back). Thresholds
  measured with the real Inter files google_fonts had cached in the
  simulator, since tests render in a square-glyph font that makes
  "Decline" 122px against 74px: no overflow at 320/375/390/402px across
  1.0/1.3/1.6/2.0x; inline at 1.0x on every width (320px included, as
  before), at 1.3–1.6x from 375px up, stacked otherwise. Tests now pump
  the real row on both screens' suites, plus its own (stacking, 2.0x with
  a long name, the name's minimum); full suite passes (2,431), analyzer
  clean, simulator build installs. Not looked at signed in on a device.
  Would recur with any IdentityRow trailing wider than one short label.
- 2026-10-28 — Three problems found trying photo framing on the simulator
  with the developer's test venue, each fixed:
  - **Every venue photo list was sorted backwards.** postgrest-dart's
    `order()` defaults to `ascending: false`, so the five
    `.order('display_order')` photo queries (`RestaurantRepository`/
    `HotelRepository.getPhotos`, `PrivateChefRepository.getChefPhotos`/
    `getCoverPhotos`, `VenuePhotoSubmissionRepository.loadPublishedPhotos`)
    returned the highest position first, while the cards'
    `restaurants_full`/`hotels_full` cover takes the lowest. My Venues'
    "first photo" (now "Cover") was therefore never the photo on the
    cards, the detail gallery opened on the last photo, and each reorder
    from My Venues wrote the reverse of what the screen showed. Now
    `ascending: true` on all five. Not fixed, same class: every other
    unqualified `.order('name')` and the chef history/education
    `display_order` lists also sort descending. Would recur with any new
    `order()` call that leaves `ascending` out.
  - **The framing editor's header frame didn't match the real hero.**
    VenueDetailHero/PrivateChefHero are SliverAppBars, so on a device the
    header is the full screen width by expandedHeight (300/320) plus the
    status bar, with the status bar and toolbar drawn over its top. The
    editor showed a fixed 300px frame at page width — a different shape —
    so a face framed there landed higher, half under the status bar, on
    the detail page. The frame now has the hero's exact proportions,
    scaled to the page, with that covered strip shaded. The status bar
    comes from `View.of(context).padding`, not MediaQuery: the editor sits
    under an AppBar, which zeroes MediaQuery's top padding (the first
    attempt read 0 there — caught on the simulator, now covered by a
    test that runs it under an AppBar).
  - **My Venues jumped to the top after every reorder.** Each reload
    swapped the photo list for a spinner, collapsing the page; the
    spinner now shows only on the first load, and a reload keeps the
    previous list on screen. This is how two of the test taps landed on
    the wrong row and briefly reordered the test venue's photos; the
    original order and framing were restored through the app and
    verified against production.
  Analyzer clean, full suite passes (2,453), including a test that fails
  without the reload fix (checked by reverting it). Seen on the
  simulator: My Venues, the gallery and the search card now agree on the
  cover; the editor frame measures 326pt on a 402pt phone, (300 + 62) ×
  0.9, with a 106pt strip.

---

## v1.1.0 — 2026-10-02

### Added

- Venue claim request flow: a manager/owner/chef picks their venue,
  submits role/business email/phone, with duplicate-claim protection and
  a domain-mismatch flag surfaced on the admin notification
- Venue manager permission model (`venue_managers_restaurants`/`_hotels`/
  `_private_chefs`), replacing the claim-based `has_approved_venue_claim()`
  check across every policy that gated on it
- My venues screen, where a manager finds and opens what they manage
- Six venue approval RPCs — approve/reject for both about-text and photo
  submissions
- `publish-venue-photo` Edge Function, the documented normal path for
  photo approval
- Photo publishing end to end: a manager's submitted photo moves through
  review to the live catalogue without a manual storage copy
- Swipeable photo galleries on the Restaurant/Hotel and Private Chef
  Detail hero screens
- Owner preview: a venue manager can see their page rendered with their
  own pending text and photos, in the same screen a visitor sees, before
  submitting
- Review notifications: a manager is notified in-app when an about-text
  or photo submission is approved or rejected, with the reviewer's own
  note carried on a rejection
- A contact line on the venue management screen
- Passport stamp designs rebuilt with larger, size-aware footprints
- Database foundation for venues and organisers eventually hosting their
  own events: `cancelled_at` as the maintained cancellation signal (with
  a compatibility shim keeping the old `status` column in sync for any
  app build still reading it), an owner `UPDATE` policy plus a
  column-restriction trigger so a host can edit everything about their
  own event except the moderation machinery, and a per-link approval
  marker on the three participant join tables so crediting a
  co-participant doesn't require republishing the whole event. Backend
  only — no new screen yet; the one user-visible effect this build ships
  is the Fixed item below.

### Fixed

- A hero's photo gallery swipe was silently swallowed on three separate
  hero widgets (Restaurant/Hotel, Private Chef, Event Detail): each
  stretched its bottom text overlay full-size via `StackFit.expand`, and
  `Scrollable` defaults to an opaque hit test regardless of
  `NeverScrollableScrollPhysics` — combined with `Stack` stopping at the
  first hit (topmost first), the overlay absorbed every pointer-down over
  the photo before the gallery underneath ever saw it. One of the three
  had previously been "fixed" by reordering z-order instead, which
  masked the symptom without touching the actual hit-test behaviour. All
  three now set `hitTestBehavior: HitTestBehavior.translucent` on the
  overlay instead.
- Restaurant and Hotel Detail never fetched a venue's full photo set at
  all — only ever a single cover image — invisible as a gap until the
  first venue with more than one photo actually existed to expose it.
- Two pre-existing bugs in `PrivateChefDetailScreen._load()`, both
  surfaced only once the owner-preview refactor made the screen directly
  testable: a secondary fetch left unawaited after an earlier one failed
  (an unhandled-rejection risk), and any one secondary fetch failing
  could flip the whole screen into its generic error state even though
  the chef's own data had already resolved successfully.
- The owner-preview "PREVIEW" marker inherited `MaterialApp`'s own
  placeholder error text style (a double yellow underline) because its
  text sat outside any `Material` ancestor in the widget tree.
- A Private Chef's page could show two "about" sections — the chef's own
  catalogue biography and a separately-submitted "from the team" text —
  at once. The venue's own submitted text now always takes precedence;
  the biography shows only as a fallback until one exists.
- A manager replacing a photo already occupying the same display slot
  could lose track of which photo was which; replacement is now indexed
  explicitly, with a message when this happens.
- Owner preview re-fetches the venue fresh rather than reusing a stale
  copy, and discloses to the manager when that refetch itself fails.
- No migration ever seeded `public.countries`, so a database built from
  the migration set alone (a disaster-recovery replay, a fresh preview
  branch) failed at the first insert carrying a real `country_code` —
  invisible until something actually needed to rebuild from scratch.
  Seeded now from the live table, in migration history, so the gap
  doesn't resurface on the next rebuild.
- A hotel or private chef claim generated no admin email at all — only
  `claims_restaurants` was ever wired to send one. Generalised into one
  function across all three claim types rather than duplicated, and the
  matching one-pending-claim-per-venue protection `claims_restaurants`
  already had is now on `claims_hotels`/`claims_private_chefs` too, so a
  second person can no longer hold a simultaneous pending claim on a
  venue someone else already claimed.
- Event cancellation now reads a real, maintained `cancelled_at` column
  instead of a `status` value nothing was keeping correct — the database
  already stored it and a trigger kept it in sync, but the app never read
  it, which is what made the drift invisible. `EventStatus` is removed
  from the Dart model entirely: `upcoming`/`completed` were never read
  anywhere beyond making this one field possible (confirmed by direct
  search before removing it). `status` itself stays in the database,
  kept correct by the same trigger, for any app build still reading it.

---

## v0.1.0

### Added

- Flutter project
- Supabase integration
- Restaurant database
- Authentication
- Restaurant overview
- My Stamps

### Improved

- Project structure
