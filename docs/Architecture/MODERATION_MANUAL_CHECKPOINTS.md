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

---

## 3. La Paix (Brussels, `rest_0836`) is relocating 2026-09-15

**Found during**: the Belgium Place ID / cuisine backfill (September
2026, `supabase/data/enrichment/michelin_belgium_place_id/`,
`michelin_belgium_cuisine/`). A Google Places Text Search candidate for
La Paix was correctly rejected at the time (2,707.6 m from the address
on file — outside the >500 m reject threshold) before a follow-up
WebSearch surfaced why: the MICHELIN Guide's own listing states La
Paix is moving to a new address.

**The gap**: `restaurants.address`/`location` for `rest_0836` still
hold the old Anderlecht address. Applying the rejected Place ID now
would point the record at a location the restaurant doesn't occupy yet
(correct after 2026-09-15, wrong before it) — worse than leaving the
field empty, so it was deliberately left unset rather than "fixed"
early.

**New address, once the move has happened**: Corinthia Hotel Astoria –
Brussels, Rue Royale 103, 1000 Brussels. (The Google Place ID
candidate found for this address during the September 2026 pass was
not independently re-verified against the *new* location — re-run the
same name+street+city Text Search and distance check once the address
below has been updated, rather than reusing the old candidate id
untested.)

**What to check, manually, after 2026-09-15**: update `rest_0836`'s
`address`, `location` (coordinates), and `city_id` if the new address
resolves to a different `cities` row, then re-run the Place ID lookup
against the corrected address before writing `google_place_id`.

---

## 4. Zero Benelux restaurants or hotels are marked closed or relocated

**Found during**: the same Belgium backfill pass, prompted directly by
checkpoint 3 above — La Paix's relocation was only caught by accident
(a Google Places distance rejection led to a WebSearch), not by
anything in the data itself.

**The gap**: across all 251 Benelux restaurants and 33 Benelux hotels,
`status` reads `open` for every single row — 0% `temporarily_closed`,
0% `permanently_closed` (confirmed by direct query, not assumed; see
the Benelux inventory report from this same session). No venue has
ever been marked closed, relocated, or under a chef change severe
enough to affect identity, despite normal churn in high-end hospitality
over the time this catalogue has existed. `status_since` is empty for
every restaurant too, so there's no way to tell "checked recently, still
open" from "never checked since import."

**Why no constraint was added**: this isn't a schema gap — `status`
and its enum already support exactly this. It's an operational gap:
nothing has ever run a closure/relocation audit against the live
catalogue, and there's no scheduled or semi-automated process that
would surface one the way La Paix's was surfaced (by luck, during
unrelated Place ID work).

**What to check, manually**: no specific action per row — this is a
standing flag that a dedicated closure/relocation verification pass
(spot-checking a sample of the catalogue against current sources,
starting with the highest-profile venues) is overdue, not a one-off
fix. Until one runs, treat every `status: open` row as "unverified
since import," not "confirmed open."

---

## 5. Convention: recording a lost MICHELIN star

**Decided during**: the Netherlands completeness check (September
2026), on finding Zheng (`rest_0782`) and De Woage (`rest_0788`) both
still operating but no longer starred in the current guide — a
genuinely different situation from checkpoint 4 above (which is about
closures), and one `award_history`'s `UNIQUE (entity_type, entity_id,
guide_year, award_type)` constraint makes a real design question, not
just a data-entry detail: the table already holds exactly one
`guide_year: 2026` row for each, `award_value: 1`, `is_current: true`,
and that constraint blocks inserting a second 2026 row to represent
"now unstarred."

**The two options weighed, and which one won**: overwrite the
existing row's `award_value` to `NULL` in place (keeps one row per
entity per guide_year, matches how every other correction this
session was applied), or leave the row untouched and flip
`is_current` to `false` with no replacement row. **The second one is
the convention.** The restaurant genuinely held one star for real
stretches of the 2026 edition — overwriting `award_value` would erase
that this was ever true, which defeats the entire purpose of an
append-only history table: `award_history` should still be able to
answer "did this restaurant hold a star for part of 2026" correctly,
even after the star is gone.

**The convention, precisely**: when a restaurant loses a star while
remaining open,
1. `restaurants.michelin_stars` -> `NULL` (this is what "currently
   unstarred, remains in the catalogue" means — see
   `DATABASE_ARCHITECTURE.md` §3.3's `michelin_stars IS NULL, never
   zero` rule).
2. The relevant `award_history` row's `is_current` -> `false`. Do
   **not** change its `award_value` — it stays the true historical
   record for that `guide_year`.
3. No new `award_history` row is inserted. A genuinely new guide
   edition with a *different* `guide_year` would still get its own
   row per the table's normal append-only behaviour; this convention
   only covers a within-edition change discovered after the fact,
   where no second `guide_year` value exists to key a new row on.

**Net effect**: after this, a restaurant can have zero `is_current`
rows in `award_history` for a given award type — which is expected
and fine (the partial unique index only enforces uniqueness *among*
`is_current` rows, it never requires one to exist). The restaurant's
actual current standing lives in `restaurants.michelin_stars`, not in
whether an `award_history` row is flagged current — `award_history`'s
job is the timeline, not the live value.

Distinct from checkpoint 4: a closure is a `restaurants.status`
change and does not touch `award_history` at all — the venue's last
known award stays exactly as recorded, `is_current` included, because
it's still true right up to the day it closed.
