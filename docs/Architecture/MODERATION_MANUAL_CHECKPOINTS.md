# Manual moderation checkpoints

Things the database does **not** validate automatically when approving
submitted content, and that the product owner must check by hand at
review time. Each entry exists because building the automated check
would need cross-table validation (a trigger spanning two independently-
submitted rows, or logic no single CHECK constraint can express) that
wasn't justified at the time the underlying feature shipped. New
entries get added here as they're found — this list is expected to
grow, not stay at one item.

---

## 1. An event scheduled after its venue's pop-up has ended

**Introduced by**: Pop-ups and temporary venues
(`20260829140000_add_popup_and_temporary_venue_fields.sql`), which added
`starts_on`/`ends_on` to `restaurants`/`hotels`/`private_chefs`.

**The gap**: nothing in the schema prevents linking a submitted event
(`event_restaurants`/`event_hotels`/`event_chefs`) to a venue whose
`ends_on` falls *before* the event's own `start_at`. A pop-up that ran
"eight weekends this summer" and then closed can still be named as the
host of an event scheduled for the following spring — the two tables
are validated independently, and nothing cross-checks them.

**Why no constraint was added**: catching this needs a trigger that
reads across `events` and whichever of `restaurants`/`hotels`/
`private_chefs` the link points at (the same generic-parent-type
problem the pop-up fields themselves have — there's no single FK to
attach a CHECK to). Not built as part of that migration; flagged here
instead so it isn't silently forgotten.

**What to check, manually, before approving**: when reviewing a
submitted event (`events.moderation_status: 'submitted' → 'published'`,
see `docs/Architecture/EVENTS_V2_ANALYTICS_CONTRACT.md` for the
moderation flow this sits inside), if the event is linked to a venue
that has `ends_on` set, confirm the event's `start_at` falls on or
before that date. If it doesn't, the event is describing something
that can't happen at that venue — reject or ask the submitter to
correct the date before publishing.

---

## 2. Restaurant/hotel photo galleries will ship without a Report action

**Introduced by**: Block and Report flows (September 2026) — Block on a
user's profile, Report on a friend's rating (`FriendVisitTile`) and on
a private chef's photo gallery (`PrivateChefHero`'s `_PhotoGallery`).

**The gap**: at the time this shipped, `restaurant_photos`/
`hotel_photos` existed only as tables (added by
`20260828120000_add_venue_claims_submissions_rankings.sql`) — nothing
in `lib/` reads either one, so restaurant/hotel detail screens show no
photo gallery at all. There was no gallery to attach a Report action
to, and building one wasn't in scope for this round (confirmed via a
repo-wide grep for `restaurant_photos`/`hotel_photos` returning zero
UI call sites before this entry was written).

**Why this isn't a database gap, unlike checkpoint 1 above**: nothing
to validate or constrain — it's a missing UI affordance, not a missing
CHECK. Logged here anyway because it's the same "known, deliberately
deferred gap" shape this doc exists to track, and because the private
chef gallery gave this app its one working precedent for what the fix
looks like.

**What to check, manually, before shipping that gallery**: once
`restaurant_photos`/`hotel_photos` are wired into a real gallery
widget on Restaurant/Hotel Detail — expected to happen once the venue
claims/photo-submission pipeline (`venue_photo_submissions`) is
connected to it, since those photos will come from claimed venue
owners, not editorial curation — confirm a Report action ships in the
*same* change, in the same form as `PrivateChefHero`'s
`_ReportPhotoButton`: `content_type: 'photo'`, `content_id` the
specific photo row's id, routed through the shared
`showReportSheet()`. Unlike the private chef gallery (admin-curated,
no `submitted_by`), these photos genuinely originate from another
user — this is real UGC, and Apple's user-generated-content
requirement applies to it the moment it's visible. Do not ship the
gallery and the Report action as separate rounds.
