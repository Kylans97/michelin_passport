# Changelog

All notable changes to Mantelier will be documented in this file.

The format follows Keep a Changelog.

---

## Unreleased

### Added

- Project documentation
- Database organisation
- Architecture documentation
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
