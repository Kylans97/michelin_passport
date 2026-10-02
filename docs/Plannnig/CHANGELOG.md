# Changelog

All notable changes to Mantelier will be documented in this file.

The format follows Keep a Changelog.

---

## Unreleased

### Added

- Project documentation
- Database organisation
- Architecture documentation

---

## v1.1.0 — 2026-10-08

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
- The admin email on a new claim now reaches every claim type — a hotel
  or private chef claim previously generated no email at all — through
  one generic function rather than a duplicate per venue type
- Passport stamp designs rebuilt with larger, size-aware footprints
- Database foundation for venues and organisers eventually hosting their
  own events: `cancelled_at` as the maintained cancellation signal,
  owner edit rights on a submitted event, and a per-link approval marker
  so crediting a co-participant doesn't require republishing the whole
  event. Backend only — no new screen yet; the one user-visible effect
  this build ships is the Fixed item below.

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
