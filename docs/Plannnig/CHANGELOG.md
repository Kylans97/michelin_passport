# Changelog

All notable changes to Mantelier will be documented in this file.

The format follows Keep a Changelog.

---

## Unreleased

### Added

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
